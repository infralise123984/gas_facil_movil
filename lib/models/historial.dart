/// Resúmenes del camionero (docs/API_MOVIL.md §7.5).
///
/// Los montos y los kilos vienen calculados del servidor: acá solo se arma el
/// objeto y el formato lo pone la interfaz.
library;

import 'pedido.dart';

/// Resumen de un mes del historial, día por día.
class HistorialMes {
  const HistorialMes({
    required this.mes,
    required this.mesNombre,
    required this.mesAnterior,
    required this.mesSiguiente,
    required this.mesSiguienteHabilitado,
    required this.diasConVenta,
    required this.entregas,
    required this.monto,
    required this.kilos,
    required this.dias,
  });

  factory HistorialMes.desdeJson(Map<String, dynamic> json) {
    final Map<String, dynamic> totales = json['totales'] as Map<String, dynamic>;

    return HistorialMes(
      mes: json['mes'] as String,
      mesNombre: json['mes_nombre'] as String,
      mesAnterior: json['mes_anterior'] as String,
      mesSiguiente: json['mes_siguiente'] as String,
      mesSiguienteHabilitado: json['mes_siguiente_habilitado'] as bool,
      diasConVenta: json['dias_con_venta'] as int,
      entregas: totales['entregas'] as int,
      monto: totales['monto'] as int,
      kilos: totales['kilos'] as int,
      dias: (json['dias'] as List<dynamic>)
          .map((dynamic dia) => DiaHistorial.desdeJson(dia as Map<String, dynamic>))
          .toList(),
    );
  }

  /// `AAAA-MM`, tal como lo entiende `?mes=`.
  final String mes;

  /// Nombre del mes en español, ya en la forma que muestra la web ("Octubre").
  final String mesNombre;

  final String mesAnterior;
  final String mesSiguiente;

  /// No se navega al futuro: no hay nada que mostrar.
  final bool mesSiguienteHabilitado;

  final int diasConVenta;
  final int entregas;
  final int monto;
  final int kilos;

  /// Todos los días del mes, en orden descendente. La web pinta también los que
  /// no tienen venta, en gris.
  final List<DiaHistorial> dias;

  /// Año del mes, para el encabezado ("Octubre 2026").
  int get anio => int.parse(mes.split('-').first);
}

/// Una fila del mes: un día con sus totales.
class DiaHistorial {
  const DiaHistorial({
    required this.fecha,
    required this.esHoy,
    required this.tieneVenta,
    required this.entregas,
    required this.monto,
    required this.kilos,
    required this.kilosDomicilio,
    required this.kilosTarreo,
  });

  factory DiaHistorial.desdeJson(Map<String, dynamic> json) => DiaHistorial(
    fecha: DateTime.parse(json['fecha'] as String),
    esHoy: json['es_hoy'] as bool,
    tieneVenta: json['tiene_venta'] as bool,
    entregas: json['entregas'] as int,
    monto: json['monto'] as int,
    kilos: json['kilos'] as int,
    kilosDomicilio: json['kilos_domicilio'] as int,
    kilosTarreo: json['kilos_tarreo'] as int,
  );

  final DateTime fecha;
  final bool esHoy;
  final bool tieneVenta;
  final int entregas;
  final int monto;
  final int kilos;
  final int kilosDomicilio;
  final int kilosTarreo;

  /// `AAAA-MM-DD`, que es lo que espera `/historial/<fecha>/`.
  String get fechaParametro {
    String dos(int valor) => valor.toString().padLeft(2, '0');
    return '${fecha.year}-${dos(fecha.month)}-${dos(fecha.day)}';
  }
}

/// Detalle de un día: sus totales y las ventas que lo componen.
class DetalleDia {
  const DetalleDia({
    required this.fecha,
    required this.mesNombre,
    required this.esHoy,
    required this.entregas,
    required this.monto,
    required this.kilos,
    required this.kilosDomicilio,
    required this.kilosTarreo,
    required this.pedidos,
  });

  factory DetalleDia.desdeJson(Map<String, dynamic> json) => DetalleDia(
    fecha: DateTime.parse(json['fecha'] as String),
    mesNombre: json['mes_nombre'] as String,
    esHoy: json['es_hoy'] as bool,
    entregas: json['entregas'] as int,
    monto: json['monto'] as int,
    kilos: json['kilos'] as int,
    kilosDomicilio: json['kilos_domicilio'] as int,
    kilosTarreo: json['kilos_tarreo'] as int,
    pedidos: (json['pedidos'] as List<dynamic>)
        .map((dynamic pedido) => Pedido.desdeJson(pedido as Map<String, dynamic>))
        .toList(),
  );

  final DateTime fecha;
  final String mesNombre;
  final bool esHoy;
  final int entregas;
  final int monto;
  final int kilos;
  final int kilosDomicilio;
  final int kilosTarreo;

  /// Solo entregados: un cancelado del día no es una venta.
  final List<Pedido> pedidos;
}
