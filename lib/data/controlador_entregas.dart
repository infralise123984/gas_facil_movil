import 'package:flutter/foundation.dart';

import '../core/error/error_api.dart';
import '../models/resumen_entregas.dart';
import 'api_cliente.dart';

/// Datos del panel del camionero, compartidos por las pantallas que los muestran.
///
/// Un solo dueño evita dos problemas que ya aparecieron en el teléfono:
///
/// * cada pantalla pedía lo mismo por su lado (dos peticiones por login);
/// * una de las dos quedaba con datos más viejos que la otra, porque solo se
///   cargaba al construirla y nunca al volver a su pestaña.
class ControladorEntregas extends ChangeNotifier {
  ControladorEntregas({required this.api});

  final ApiCliente api;

  ResumenEntregas? _datos;
  String? _error;
  bool _cargando = false;

  ResumenEntregas? get datos => _datos;

  /// Mensaje presentable del último fallo, o `null` si la última carga fue bien.
  String? get error => _error;

  bool get cargando => _cargando;

  /// Todavía no hay nada que mostrar: ni datos ni error.
  bool get sinDatosTodavia => _datos == null && _error == null;

  Future<void> cargar() async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      _datos = await api.listarEntregas();
    } on ErrorApi catch (fallo) {
      // Los datos ya cargados se conservan a propósito: en la calle es mejor
      // ver la última lista conocida, marcada como vieja, que una pantalla
      // vacía por un corte de señal.
      _error = fallo.mensaje;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// Descarta lo cargado al cerrar sesión, para que el siguiente camionero no
  /// alcance a ver los pedidos del anterior.
  void limpiar() {
    _datos = null;
    _error = null;
    _cargando = false;
    notifyListeners();
  }
}
