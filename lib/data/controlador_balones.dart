import 'package:flutter/foundation.dart';

import '../core/error/error_api.dart';
import '../models/pedido.dart';
import 'api_cliente.dart';

/// Catálogo de balones vigente, para la venta en la calle (docs/API_MOVIL.md
/// §7.4 y §7.5).
///
/// Mismo patrón que `ControladorEntregas`: la pantalla no pide datos, los lee.
/// Los precios son los del servidor; la app no los inventa ni los manda de
/// vuelta, porque el total lo calcula el servidor.
class ControladorBalones extends ChangeNotifier {
  ControladorBalones({required this.api});

  final ApiCliente api;

  List<TipoBalon> _balones = const <TipoBalon>[];
  String? _error;
  bool _cargando = false;
  bool _cargado = false;

  List<TipoBalon> get balones => _balones;

  /// Mensaje presentable del último fallo, o `null` si la última carga fue bien.
  String? get error => _error;

  bool get cargando => _cargando;

  /// Nunca se pidió el catálogo. Una lista vacía que llegó del servidor ya es
  /// una respuesta —"no hay balones activos"—, no un estado de espera.
  bool get sinDatosTodavia => !_cargado;

  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      _balones = await api.listarBalones();
      _cargado = true;
    } on ErrorApi catch (fallo) {
      // Se conserva lo ya cargado: si el catálogo se pidió una vez, es mejor
      // seguir vendiendo con el último precio conocido que dejar la pantalla
      // vacía por un corte de señal.
      _error = fallo.mensaje;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }
}
