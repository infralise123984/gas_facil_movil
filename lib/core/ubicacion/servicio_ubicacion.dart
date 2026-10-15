import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/api_cliente.dart';
import '../error/error_api.dart';
import 'cola_ubicaciones.dart';
import 'muestra_ubicacion.dart';

/// Id del canal del aviso permanente del servicio de ubicación.
///
/// Es el mismo que crea geolocator por su cuenta. Si el canal no existe, lo crea
/// él con importancia 0, y entonces la notificación permanente del servicio en
/// primer plano queda invisible para el camionero.
const String idCanalUbicacion = 'geolocator_channel_01';

/// Reporta la posición del camión mientras dura la jornada.
/// **Servicio en primer plano.** Android mata lo que corre en segundo plano, y
/// con la app cerrada el reporte se cortaría justo cuando el camionero no la
/// está mirando. El precio es la notificación permanente, que además hace
/// explícito ante el camionero que el teléfono está reportando: eso es lo
/// correcto, no un estorbo.
///
/// **El teléfono no decide la jornada.** Manda lo que tenga y el servidor
/// descarta lo de fuera de 08:00-20:00 (`docs/API_MOVIL.md` §7.8). Así, cambiar
/// el horario es cambiar una variable en el servidor, no recompilar el APK.
///
/// **Sin red no se pierde nada:** lo que no se puede enviar queda en la cola
/// local y sale en el ciclo siguiente.
///
/// Es *best-effort*, como el registro de avisos: si el permiso se niega o el GPS
/// está apagado, la app funciona igual y el camión aparece como "sin señal" en
/// el panel, que ya es información útil para la telefonista.
class ServicioUbicacion {
  ServicioUbicacion({
    required this.api,
    this.cola = const ColaUbicaciones(),
    GeolocatorPlatform? plataforma,
    this.intervaloSampleo = const Duration(minutes: 3),
    this.intervaloEnvio = const Duration(minutes: 2),
  }) : _plataforma = plataforma ?? GeolocatorPlatform.instance;

  final ApiCliente api;
  final ColaUbicaciones cola;

  /// Cada cuánto se pide una posición al GPS. Tres minutos alcanzan para ver
  /// una parada de media hora y gastan mucha menos batería que un reporte continuo.
  final Duration intervaloSampleo;

  /// Cada cuánto se intenta vaciar la cola hacia el servidor.
  final Duration intervaloEnvio;

  /// Inyectable para poder probar sin GPS real ni dispositivo.
  final GeolocatorPlatform _plataforma;

  StreamSubscription<Position>? _suscripcion;
  Timer? _relojEnvio;
  bool _activo = false;

  /// Serializa las escrituras en la cola.
  ///
  /// El stream puede entregar dos posiciones casi juntas: si dos `agregar()`
  /// corren a la vez, los dos leen la lista antes de que el otro escriba y una
  /// muestra se pierde en silencio. Encadenarlas en un solo futuro evita la
  /// carrera sin necesidad de un candado.
  Future<void> _escrituras = Future<void>.value();

  bool get activo => _activo;

  /// Pide permisos y arranca el reporte. Devuelve si quedó reportando.
  Future<bool> iniciar() async {
    if (_activo) {
      return true;
    }

    if (!await _hayUbicacionDisponible()) {
      return false;
    }

    await _prepararCanalDeAviso();

    _suscripcion = _plataforma
        .getPositionStream(locationSettings: _ajustesAndroid())
        .listen(
          _acumular,
          onError: (Object error) => debugPrint('UBICACION_STREAM_ERROR | $error'),
        );
    _relojEnvio = Timer.periodic(intervaloEnvio, (_) => enviarPendientes());

    await enviarPendientes();
    _activo = true;
    debugPrint('UBICACION_SERVICIO_INICIADO');
    return true;
  }

  /// Detiene el reporte. La cola **no** se vacía: lo pendiente pertenece a la
  /// jornada en curso y se sube al volver.
  Future<void> detener() async {
    _relojEnvio?.cancel();
    _relojEnvio = null;
    await _suscripcion?.cancel();
    _suscripcion = null;
    // La última posición alcanzada a guardar entra antes de cerrar.
    await _escrituras;
    _activo = false;
  }

  /// Envía lo acumulado. Devuelve si la cola quedó vacía.
  ///
  /// Se vacía **después** de que el servidor confirma: si el envío falla a
  /// medias, lo pendiente se reintenta en el ciclo siguiente en lugar de
  /// perderse. Reenviarlo no duplica: el servidor es idempotente por
  /// `(trabajador, capturado_el)`.
  Future<bool> enviarPendientes() async {
    final List<MuestraUbicacion> pendientes = await cola.leer();
    if (pendientes.isEmpty) {
      return true;
    }

    try {
      await api.enviarUbicaciones(pendientes);
      await cola.limpiar();
      debugPrint('UBICACION_ENVIADAS | ${pendientes.length}');
      return true;
    } on ErrorApi catch (error) {
      // 401 (sesión vencida) entra acá: la cola espera y se reintenta cuando el
      // camionero vuelva a entrar. Es el hueco conocido del §10 #17.
      debugPrint('UBICACION_ENVIO_FALLIDO | ${error.codigo} | ${pendientes.length}');
      return false;
    }
  }

  /// Descarta lo pendiente al cerrar sesión: son muestras de una jornada que ya
  /// terminó, y subirlas después sería reportar fuera de hora.
  Future<void> descartarPendientes() => cola.limpiar();

  Future<bool> _hayUbicacionDisponible() async {
    if (!await _plataforma.isLocationServiceEnabled()) {
      debugPrint('UBICACION_GPS_APAGADO');
      return false;
    }

    LocationPermission permiso = await _plataforma.checkPermission();
    if (permiso == LocationPermission.denied) {
      permiso = await _plataforma.requestPermission();
    }
    if (permiso == LocationPermission.denied) {
      debugPrint('UBICACION_PERMISO_DENEGADO');
      return false;
    }
    if (permiso == LocationPermission.deniedForever) {
      debugPrint('UBICACION_PERMISO_BLOQUEADO');
      return false;
    }
    return true;
  }

  /// Prepara el canal del aviso permanente **antes** de que geolocator cree el suyo.
  ///
  /// Si lo crea geolocator, queda con importancia 0 y la notificación permanente
  /// no se ve: el rastreo funciona, pero el camionero no tiene delante la señal
  /// de que su teléfono está reportando. Crear el canal primero —mismo id— deja
  /// el aviso visible, que es lo que corresponde.
  Future<void> _prepararCanalDeAviso() async {
    const AndroidNotificationChannel canal = AndroidNotificationChannel(
      idCanalUbicacion,
      'Ubicación',
      description: 'Reporte de posición del camión durante la jornada.',
      importance: Importance.high,
    );
    try {
      await FlutterLocalNotificationsPlugin()
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(canal);
    } catch (error) {
      // El canal es un extra de transparencia: si falla, el rastreo sigue.
      debugPrint('UBICACION_CANAL_ERROR | $error');
    }
  }

  AndroidSettings _ajustesAndroid() {
    return AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 0,
      intervalDuration: intervaloSampleo,
      // La notificación es obligatoria para un servicio en primer plano y, de
      // paso, deja claro que el teléfono está reportando.
      foregroundNotificationConfig: const ForegroundNotificationConfig(
        notificationTitle: 'Kim Gas · Jornada activa',
        notificationText: 'Compartiendo la ubicación del camión durante la jornada.',
        notificationChannelName: 'Ubicación',
        enableWakeLock: true,
        setOngoing: true,
      ),
    );
  }

  void _acumular(Position posicion) {
    _escrituras = _escrituras.then((_) => _guardar(_muestra(posicion)));
  }

  Future<void> _guardar(MuestraUbicacion muestra) async {
    final int tamano = await cola.agregar(muestra);
    if (tamano >= ColaUbicaciones.tope) {
      // La cola topó: hace rato que no se puede enviar. Se deja rastro para
      // saber que hay huecos que no son del GPS.
      debugPrint('UBICACION_COLA_LLENA | $tamano');
    }
    if (tamano == 1) {
      // La primera muestra sale en cuanto llega: esperar al ciclo de envío
      // dejaría al camión recién arrancado como "sin señal" en el panel.
      await enviarPendientes();
    }
  }

  MuestraUbicacion _muestra(Position posicion) {
    return MuestraUbicacion(
      lat: posicion.latitude,
      lng: posicion.longitude,
      capturadoEl: posicion.timestamp,
      precisionM: posicion.accuracy,
      // `speed` llega negativo cuando el GPS no puede estimarla: no es "0 m/s",
      // es "no sé". Se manda sin velocidad y el servidor lo acepta igual.
      velocidad: posicion.speed >= 0 ? posicion.speed : null,
    );
  }
}
