import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../data/api_cliente.dart';
import '../error/error_api.dart';

/// Mantiene el identificador de este teléfono registrado en el servidor.
///
/// **Se usa el *registration token* de FCM, no el FID.** La v1 de la API ya
/// deprecia `token` a favor de `fid`, pero el plugin de Flutter todavía **no**
/// expone los Firebase Installation IDs: `onRegistered` y `register()` no
/// existen en `firebase_messaging` 16.7.0. El camino del token sigue
/// plenamente soportado durante la transición, así que es el que se usa hoy.
/// Cuando el plugin exponga el FID, el cambio es de a un lado y del otro: el
/// cliente manda el FID y el servidor lo envía en `"fid"` (`docs/API_MOVIL.md` §7.7).
///
/// El token se reemite solo (reinstalación, limpieza de datos), así que se
/// escucha `onTokenRefresh` además de pedirlo al iniciar.
///
/// Es *best-effort* por diseño: si el registro falla, la app sigue funcionando
/// y el camionero se entera de los pedidos al abrir la pantalla. Lo único que se
/// pierde es el aviso con la app cerrada.
class RegistroDispositivo {
  RegistroDispositivo({required this.api, required this.versionApp, FirebaseMessaging? mensajeria})
    : _mensajeriaInyectada = mensajeria;

  final ApiCliente api;
  final String versionApp;

  /// Permite inyectar un doble en las pruebas. Se resuelve en el momento de
  /// usarlo y no al construir: si Firebase no arrancó, `FirebaseMessaging.instance`
  /// lanza, y eso no puede tumbar la app en el constructor.
  final FirebaseMessaging? _mensajeriaInyectada;

  StreamSubscription<String>? _suscripcion;

  /// El token que el servidor tiene registrado, para poder darlo de baja al
  /// cerrar la sesión.
  String? _tokenRegistrado;

  /// Pide el token y escucha sus reemisiones.
  Future<void> iniciar() async {
    try {
      final FirebaseMessaging mensajeria = _mensajeriaInyectada ?? FirebaseMessaging.instance;

      _suscripcion ??= mensajeria.onTokenRefresh.listen(
        _subir,
        onError: (Object error) => debugPrint('FCM_ON_TOKEN_REFRESH_ERROR | $error'),
      );

      // El token también llega al arrancar, pero pedirlo explícitamente evita
      // depender de que la emisión haya ocurrido antes de suscribirse.
      final String? token = await mensajeria.getToken();
      if (token != null) {
        await _subir(token);
      }
    } catch (error) {
      debugPrint('FCM_NO_DISPONIBLE | $error');
    }
  }

  Future<void> detener() async {
    await _suscripcion?.cancel();
    _suscripcion = null;
  }

  /// Le dice al servidor que este teléfono ya no debe recibir avisos.
  ///
  /// Tiene que llamarse **antes** de cerrar la sesión: después el API responde
  /// `401` y el teléfono seguiría registrado a nombre de un camionero que ya
  /// salió.
  Future<void> darDeBaja() async {
    final String? token = _tokenRegistrado;
    if (token == null) {
      return;
    }
    try {
      await api.darDeBajaDispositivo(token: token);
    } on ErrorApi catch (error) {
      debugPrint('FCM_TOKEN_BAJA_ERROR | ${error.codigo}');
    }
    _tokenRegistrado = null;
  }

  Future<void> _subir(String token) async {
    if (token.isEmpty) {
      return;
    }
    try {
      await api.registrarDispositivo(token: token, versionApp: versionApp);
      _tokenRegistrado = token;
      debugPrint('FCM_TOKEN_REGISTRADO');
    } on ErrorApi catch (error) {
      // Un 401 acá es normal si el token llega antes de que haya sesión: el
      // registro se reintenta solo en el próximo refresco de Firebase.
      debugPrint('FCM_TOKEN_ERROR | ${error.codigo}');
    }
  }
}
