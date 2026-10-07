/// Códigos de error del contrato (docs/API_MOVIL.md §5.2).
///
/// Son estables y en minúsculas: la app decide con el código, nunca leyendo el
/// mensaje. Los tres últimos los produce la propia app, no el servidor.
abstract final class CodigosError {
  static const String validacion = 'validacion';
  static const String noAutenticado = 'no_autenticado';
  static const String sinPermiso = 'sin_permiso';
  static const String noEncontrado = 'no_encontrado';
  static const String metodoNoPermitido = 'metodo_no_permitido';
  static const String noDisponible = 'no_disponible';
  static const String conflictoEstado = 'conflicto_estado';
  static const String bloqueadoLogin = 'bloqueado_login';
  static const String demasiadasPeticiones = 'demasiadas_peticiones';
  static const String errorInterno = 'error_interno';

  /// El servidor no respondió (red caída, servidor apagado, tiempo agotado).
  static const String sinConexion = 'sin_conexion';

  /// Respondió algo que no es el sobre del contrato (HTML de error, por
  /// ejemplo el 403 de CSRF, que el middleware emite antes de llegar a la vista).
  static const String respuestaIlegible = 'respuesta_ilegible';
}

/// Error de dominio del API.
///
/// `mensaje` es apto para mostrar al usuario; `detalle` es información interna
/// que solo va al log (nunca a la pantalla).
class ErrorApi implements Exception {
  const ErrorApi({required this.codigo, required this.mensaje, required this.status, this.detalle});

  factory ErrorApi.sinConexion(String detalle) => ErrorApi(
    codigo: CodigosError.sinConexion,
    mensaje: 'No hay conexión con el servidor. Revisa tu señal e inténtalo de nuevo.',
    status: 0,
    detalle: detalle,
  );

  final String codigo;
  final String mensaje;

  /// Código HTTP de la respuesta. **0** significa que no hay uno aplicable:
  /// la app no pudo llegar al servidor o el cuerpo no era interpretable.
  final int status;

  final String? detalle;

  /// `true` si reintentar no sirve: el servidor bloqueó los intentos.
  bool get esBloqueoDeLogin => codigo == CodigosError.bloqueadoLogin;

  @override
  String toString() => 'ErrorApi($status, $codigo): $mensaje';
}

/// Mensaje presentable de cualquier error de carga.
///
/// Si es un error de dominio se muestra el suyo; cualquier otra cosa es un
/// fallo no previsto y no se le muestran detalles internos al usuario.
String mensajeDeError(Object error) =>
    error is ErrorApi ? error.mensaje : 'Ocurrió un error inesperado. Vuelve a intentarlo.';
