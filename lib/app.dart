import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

import 'core/config/api_config.dart';
import 'core/error/error_api.dart';
import 'core/notificaciones/registro_dispositivo.dart';
import 'core/notificaciones/servicio_notificaciones.dart';
import 'core/ubicacion/servicio_ubicacion.dart';
import 'core/time/reloj_servidor.dart';
import 'data/api_cliente.dart';
import 'data/controlador_balones.dart';
import 'data/controlador_entregas.dart';
import 'models/usuario.dart';
import 'screens/entregas_screen.dart';
import 'screens/historial_screen.dart';
import 'screens/inicio_screen.dart';
import 'screens/login_screen.dart';
import 'screens/mis_entregas_screen.dart';
import 'screens/tarreo_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/barra_navegacion.dart';
import 'widgets/comunes.dart';
import 'widgets/dialogo_confirmacion.dart';

/// Aplicación Kim Gas para el camionero.
///
/// Extensión del sistema web existente: replica su interfaz y flujo, y no
/// agrega pantallas ni funciones que la web no tenga.
/// Ver docs/PLAN_APP_CAMIONERO.md, secciones 2.1 y 15.
class AppGasFacil extends StatefulWidget {
  const AppGasFacil({super.key});

  @override
  State<AppGasFacil> createState() => _AppGasFacilState();
}

class _AppGasFacilState extends State<AppGasFacil> {
  /// Hora del servidor, compartida por el cliente y la pantalla de inicio.
  final RelojServidor _reloj = RelojServidor();

  /// Un solo cliente para toda la app: es quien guarda las cookies de sesión.
  late final ApiCliente _api = ApiCliente(config: ApiConfig.desdeEntorno(), reloj: _reloj);

  /// Un solo dueño de los datos del panel: las dos pantallas que los muestran
  /// leen de acá, así no se pisan ni quedan una más vieja que la otra.
  late final ControladorEntregas _entregas = ControladorEntregas(api: _api);

  /// Catálogo de balones del tarreo. Se pide al abrir esa pestaña y no al
  /// arrancar, porque la mayoría de las sesiones no pasa por la venta en la
  /// calle.
  late final ControladorBalones _balones = ControladorBalones(api: _api);

  /// Prepara el canal y el permiso de notificaciones. No muestra notificaciones:
  /// el aviso de pedido nuevo lo pinta Android desde el mensaje de FCM.
  late final ServicioNotificaciones _notificaciones = ServicioNotificacionesLocal();

  /// Mantiene el identificador de este teléfono registrado en el servidor.
  late final RegistroDispositivo _dispositivo = RegistroDispositivo(
    api: _api,
    versionApp: _versionApp,
  );

  /// Reporta la posición del camión durante la jornada (§7.8). Arranca junto con
  /// la sesión y se detiene al cerrarla.
  late final ServicioUbicacion _ubicacion = ServicioUbicacion(api: _api);

  /// Versión que viaja al servidor con el registro del teléfono, para saber desde
  /// qué build se registró un equipo. Mantener en sync con `pubspec.yaml`.
  static const String _versionApp = '0.1.0';

  Usuario? _usuario;
  bool _comprobandoSesion = true;

  /// Fallo de red al reabrir la sesión. La credencial **no** se borra en ese
  /// caso: se deja reintentar, porque el problema es la conexión, no la sesión.
  String? _falloDeArranque;

  @override
  void initState() {
    super.initState();
    _escucharMensajesDeFirebase();
    _recuperarSesion();
  }

  @override
  void dispose() {
    unawaited(_dispositivo.detener());
    unawaited(_ubicacion.detener());
    _api.cerrar();
    _entregas.dispose();
    _balones.dispose();
    super.dispose();
  }

  /// Reabre la sesión guardada, si la hay, antes de mostrar el login.
  ///
  /// Tener la cookie no es estar autenticado: se confirma contra
  /// `/auth/perfil/`, porque el servidor la vence a las 48 h
  /// (`SESSION_COOKIE_AGE = 172800`).
  Future<void> _recuperarSesion() async {
    if (!await _api.restaurarSesion()) {
      if (mounted) {
        setState(() => _comprobandoSesion = false);
      }
      return;
    }

    try {
      final Usuario usuario = await _api.perfil();
      if (!usuario.esCamionero) {
        await _api.cerrarSesion();
        if (mounted) {
          setState(() => _comprobandoSesion = false);
        }
        return;
      }
      if (mounted) {
        setState(() {
          _usuario = usuario;
          _comprobandoSesion = false;
        });
      }
      // Los servicios de fondo se preparan después de pintar: un permiso lento
      // no puede retrasar el arranque de la app.
      unawaited(_arrancarServiciosDeFondo());
    } on ErrorApi catch (error) {
      // Sesión vencida o rechazada: se descarta y se pide login de nuevo.
      if (error.codigo != CodigosError.sinConexion) {
        await _api.olvidarSesion();
      }
      if (mounted) {
        setState(() {
          _comprobandoSesion = false;
          _falloDeArranque = error.codigo == CodigosError.sinConexion ? error.mensaje : null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kim Gas',
      debugShowCheckedModeBanner: false,
      theme: construirTema(),
      home: _pantallaInicial(),
    );
  }

  Widget _pantallaInicial() {
    if (_comprobandoSesion) {
      return const Scaffold(
        body: CuerpoPantalla(
          children: <Widget>[PantallaCargando(mensaje: 'Comprobando tu sesión…')],
        ),
      );
    }

    final String? fallo = _falloDeArranque;
    if (fallo != null) {
      return Scaffold(
        body: CuerpoPantalla(
          children: <Widget>[PantallaError(mensaje: fallo, onReintentar: _reintentarArranque)],
        ),
      );
    }

    final Usuario? usuario = _usuario;
    if (usuario == null) {
      return LoginScreen(api: _api, onSesionIniciada: _iniciarSesion);
    }
    return PantallaCamionero(
      api: _api,
      entregas: _entregas,
      balones: _balones,
      reloj: _reloj,
      usuario: usuario,
      onSesionCerrada: _cerrarSesion,
    );
  }

  void _reintentarArranque() {
    setState(() {
      _falloDeArranque = null;
      _comprobandoSesion = true;
    });
    _recuperarSesion();
  }

  void _iniciarSesion(Usuario usuario) {
    setState(() => _usuario = usuario);
    unawaited(_arrancarServiciosDeFondo());
  }

  /// Cierra la sesión en el servidor y en el teléfono.
  ///
  /// El servidor es la fuente de verdad, pero si no responde se cierra igual: el
  /// camionero no puede quedar atrapado dentro de la app.
  Future<void> _cerrarSesion() async {
    // El reporte de posición muere con la jornada de quien se va, y lo pendiente
    // se descarta: son muestras de una jornada terminada y subirlas después
    // sería reportar fuera de hora.
    await _ubicacion.detener();
    await _ubicacion.descartarPendientes();

    // El teléfono se da de baja ANTES del logout: después el API responde 401 y
    // este teléfono seguiría recibiendo avisos de un camionero que ya salió.
    await _dispositivo.darDeBaja();

    try {
      await _api.cerrarSesion();
    } on ErrorApi catch (error) {
      debugPrint('LOGOUT_API_FALLIDO | ${error.codigo} | ${error.detalle ?? ''}');
    }

    // Los pedidos son del camionero que se va: no pueden quedar a la vista del
    // siguiente que use el teléfono.
    _entregas.limpiar();
    if (mounted) {
      setState(() => _usuario = null);
    }
  }

  /// Deja listos los servicios que trabajan con la app cerrada: el canal de
  /// avisos y el reporte de ubicación.
  ///
  /// Sin canal, Android no tiene dónde poner el aviso de pedido nuevo; sin
  /// permiso, lo descarta en silencio. El token se registra igual cuando el
  /// permiso se niega: si el camionero lo habilita después, el teléfono ya está
  /// del otro lado sin reinstalar nada.
  ///
  /// La ubicación es *best-effort*: sin permiso o sin GPS, el camión aparece
  /// como "sin señal" en el panel de la telefonista y nada más se rompe.
  Future<void> _arrancarServiciosDeFondo() async {
    await _notificaciones.preparar();
    await _dispositivo.iniciar();
    await _ubicacion.iniciar();
  }

  /// Con la app abierta, FCM entrega el mensaje sin pintar nada.
  ///
  /// No hace falta mostrarlo: la lista se recarga y el pedido aparece solo. Así
  /// el camionero no recibe un aviso duplicado sobre una pantalla que ya está
  /// mirando.
  void _escucharMensajesDeFirebase() {
    try {
      FirebaseMessaging.onMessage.listen((RemoteMessage mensaje) {
        // Se registra siempre, aunque no se muestre nada: sin esta línea, "el
        // aviso no llegó" y "llegó pero la app estaba abierta" se ven igual
        // desde afuera, y son dos problemas distintos.
        debugPrint('FCM_MENSAJE_EN_PRIMER_PLANO | tipo=${mensaje.data['tipo']}');
        if (mensaje.data['tipo'] == 'pedido_nuevo') {
          _entregas.cargar();
        }
      });

      // El camionero tocó la notificación con la app abierta en segundo plano.
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage mensaje) {
        debugPrint('FCM_AVISO_TOCADO | tipo=${mensaje.data['tipo']}');
        _entregas.cargar();
      });
    } catch (error) {
      // Firebase no está disponible: la app sigue igual, sin avisos.
      debugPrint('FCM_ESCUCHA_FALLIDA | $error');
    }
  }
}

/// Contenedor con la barra inferior de cuatro destinos.
///
/// Mismos destinos y mismo orden que la barra de `base.html`.
class PantallaCamionero extends StatefulWidget {
  const PantallaCamionero({
    super.key,
    required this.api,
    required this.entregas,
    required this.balones,
    required this.reloj,
    required this.usuario,
    required this.onSesionCerrada,
  });

  final ApiCliente api;
  final ControladorEntregas entregas;
  final ControladorBalones balones;
  final RelojServidor reloj;
  final Usuario usuario;

  /// Cierra la sesión: la orquesta el padre, que es quien conoce el servidor, el
  /// almacén de la credencial y el registro del teléfono.
  final Future<void> Function() onSesionCerrada;

  @override
  State<PantallaCamionero> createState() => _PantallaCamioneroState();
}

class _PantallaCamioneroState extends State<PantallaCamionero> with WidgetsBindingObserver {
  int _indice = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.entregas.cargar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Al volver del bloqueo o del segundo plano se recarga.
  ///
  /// Con la pantalla apagada Flutter deja de dibujar: la lista que se ve al
  /// desbloquear puede ser de antes.
  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) {
      widget.entregas.cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kim Gas'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Perfil',
            icon: const Icon(Icons.account_circle),
            onPressed: _mostrarPerfil,
          ),
        ],
      ),
      body: IndexedStack(
        index: _indice,
        children: <Widget>[
          InicioScreen(
            onIrAPestana: _cambiarPestana,
            nombreUsuario: widget.usuario.nombre,
            reloj: widget.reloj,
            onVerHistorial: _abrirHistorial,
          ),
          EntregasScreen(api: widget.api, controlador: widget.entregas),
          MisEntregasScreen(controlador: widget.entregas),
          TarreoScreen(
            api: widget.api,
            balones: widget.balones,
            entregas: widget.entregas,
            onVentaGuardada: () => _cambiarPestana(0),
          ),
        ],
      ),
      bottomNavigationBar: BarraNavegacionCamionero(indice: _indice, onCambiar: _cambiarPestana),
    );
  }

  void _cambiarPestana(int nuevoIndice) {
    setState(() => _indice = nuevoIndice);

    // Las dos pestañas que muestran pedidos se recargan al entrar: si no, al
    // volver a una de ellas se vería la lista de la última vez que se cargó.
    if (nuevoIndice == 1 || nuevoIndice == 2) {
      widget.entregas.cargar();
    }
    if (nuevoIndice == 3) {
      // Los precios del tarreo también se actualizan al entrar, no solo una vez
      // por sesión: si el mostrador los cambia, el camionero cobra lo nuevo.
      widget.balones.cargar();
    }
  }

  /// El historial es una pantalla aparte, no una pestaña: la PWA también lo
  /// sirve como página propia (`entregas_historial`).
  void _abrirHistorial() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (BuildContext _) => HistorialScreen(api: widget.api)));
  }

  /// Confirma y delega el cierre de sesión en el padre.
  ///
  /// Acá no se llama al API: dar de baja el teléfono tiene que ocurrir **antes**
  /// del logout, y ese orden lo garantiza quien conoce las dos cosas.
  Future<void> _mostrarPerfil() async {
    final bool salir = await confirmarAccion(
      context,
      titulo: 'Cerrar sesión',
      cuerpo:
          '${widget.usuario.nombre} · ${widget.usuario.rolEtiqueta}\n\n'
          '¿Quieres cerrar la sesión?',
      color: ColoresApp.peligro,
      textoConfirmar: 'Sí, cerrar sesión',
    );
    if (!salir || !mounted) {
      return;
    }

    // El cierre lo hace el padre: acá solo se confirma, porque dar de baja el
    // teléfono tiene que ocurrir antes del logout.
    await widget.onSesionCerrada();
  }
}
