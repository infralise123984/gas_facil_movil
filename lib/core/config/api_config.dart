/// Configuración del API del camionero.
///
/// Los valores se inyectan al compilar, no se escriben en el código:
/// `flutter run --dart-define=API_BASE_URL=https://api.ejemplo.cl`
///
/// En desarrollo el teléfono llega al servidor del PC por USB con
/// `adb reverse tcp:8000 tcp:8000`, así que el destino por defecto es el
/// bucle local del propio teléfono.
class ApiConfig {
  const ApiConfig({required this.baseUrl, required this.origen});

  /// Toma los valores de `--dart-define`, con el entorno local por defecto.
  factory ApiConfig.desdeEntorno() {
    const String base = String.fromEnvironment(
      'API_BASE_URL',
      defaultValue: 'http://127.0.0.1:8000',
    );
    const String origen = String.fromEnvironment('API_ORIGEN');
    return ApiConfig(baseUrl: base, origen: origen.isEmpty ? base : origen);
  }

  /// Raíz del API, sin barra final. Ejemplo: `https://api.kimgas.cl`.
  final String baseUrl;

  /// Valor de la cabecera `Origin` de los POST.
  ///
  /// El doble envío CSRF la exige y debe coincidir con una entrada de
  /// `CSRF_TRUSTED_ORIGINS` en el servidor (docs/API_MOVIL.md §6.1).
  final String origen;

  Uri urlDe(String ruta) => Uri.parse('$baseUrl$ruta');
}
