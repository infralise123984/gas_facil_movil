import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Prepara las notificaciones del sistema operativo.
///
/// Es una interfaz —y no una clase suelta— para poder sustituirla por un doble
/// en las pruebas: lo que se prueba no es el plugin, es que el registro del
/// teléfono y el permiso se pidan en el momento correcto.
///
/// **No** muestra notificaciones: el aviso de pedido nuevo lo pinta el propio
/// Android desde el mensaje de FCM, con la app cerrada y sin despertarla. Lo
/// único que hace falta de este lado es que el canal exista, con el mismo
/// identificador que manda el servidor, y que el permiso esté concedido.
abstract interface class ServicioNotificaciones {
  /// Canal de Android donde caen los avisos de pedidos.
  ///
  /// Tiene que coincidir con `CANAL_ANDROID` de
  /// `mockups/push_notifications_movil.py`. Si no coincidiera, Android usaría
  /// el canal genérico del sistema y el aviso perdería importancia y sonido —
  /// el mensaje igual llega, pero deja de ser un aviso que llama la atención.
  static const String canalPedidos = 'pedidos';

  /// Crea el canal y pide el permiso de notificaciones (Android 13+).
  ///
  /// Devuelve `true` si quedó concedido. Nunca lanza: quedarse sin permiso
  /// significa perder el aviso, no romper la app.
  Future<bool> preparar();
}

/// Implementación real, sobre `flutter_local_notifications`.
class ServicioNotificacionesLocal implements ServicioNotificaciones {
  ServicioNotificacionesLocal({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<bool> preparar() async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );

      final AndroidFlutterLocalNotificationsPlugin? android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (android == null) {
        // La app es Android: si no hay implementación, algo se armó mal en la
        // plataforma. Se sigue sin avisos en vez de reventar.
        debugPrint('NOTIFICACIONES_SIN_IMPLEMENTACION_ANDROID');
        return false;
      }

      await android.createNotificationChannel(
        const AndroidNotificationChannel(
          ServicioNotificaciones.canalPedidos,
          'Pedidos',
          description: 'Avisos de pedidos nuevos por repartir',
          importance: Importance.high,
        ),
      );

      final bool? concedido = await android.requestNotificationsPermission();
      debugPrint('NOTIFICACIONES_PERMISO | ${concedido == true ? 'concedido' : 'denegado'}');
      return concedido ?? false;
    } catch (error) {
      // Un fallo del plugin de notificaciones no puede dejar al camionero sin
      // ver sus pedidos: se pierde el aviso, no la app.
      debugPrint('NOTIFICACIONES_PREPARAR_FALLIDO | $error');
      return false;
    }
  }
}
