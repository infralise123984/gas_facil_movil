import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda la credencial de sesión entre arranques de la app.
///
/// Se abstrae para que el cliente del API no dependa de un almacén concreto, y
/// para poder sustituirlo por un doble en memoria en las pruebas.
abstract interface class AlmacenSesion {
  /// La credencial guardada, o `null` si no hay ninguna.
  Future<String?> leer();

  Future<void> guardar(String sesion);

  Future<void> borrar();
}

/// Implementación real: el almacén cifrado del sistema (Keystore en Android).
///
/// Nunca en `SharedPreferences`: la cookie de sesión es una credencial y ahí
/// viajaría en claro (docs/PLAN_APP_CAMIONERO.md §9).
class AlmacenSesionSeguro implements AlmacenSesion {
  AlmacenSesionSeguro({FlutterSecureStorage? almacen})
    : _almacen = almacen ?? const FlutterSecureStorage();

  static const String _clave = 'kim_gas_sesion_camionero';

  final FlutterSecureStorage _almacen;

  @override
  Future<String?> leer() async {
    try {
      return await _almacen.read(key: _clave);
    } catch (error) {
      // Si el almacén del sistema falla (Keystore reiniciado, por ejemplo) se
      // sigue como si no hubiera sesión: se pide login otra vez.
      debugPrint('ALMACEN_SESION_LECTURA_FALLIDA | $error');
      return null;
    }
  }

  @override
  Future<void> guardar(String sesion) async {
    try {
      await _almacen.write(key: _clave, value: sesion);
    } catch (error) {
      // No se propaga: la sesión sigue viva en memoria y la app funciona. Lo
      // único que se pierde es no tener que loguear en el próximo arranque.
      debugPrint('ALMACEN_SESION_ESCRITURA_FALLIDA | $error');
    }
  }

  @override
  Future<void> borrar() async {
    try {
      await _almacen.delete(key: _clave);
    } catch (error) {
      debugPrint('ALMACEN_SESION_BORRADO_FALLIDO | $error');
    }
  }
}
