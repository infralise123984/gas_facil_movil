import 'pedido.dart';

/// Las tres listas del panel del camionero (docs/API_MOVIL.md §7.1).
class ResumenEntregas {
  const ResumenEntregas({
    required this.hoy,
    required this.pendientes,
    required this.enRuta,
    required this.entregadosHoy,
    required this.actividadHoy,
  });

  factory ResumenEntregas.desdeJson(Map<String, dynamic> json) => ResumenEntregas(
    hoy: DateTime.parse(json['hoy'] as String),
    pendientes: _pedidosDesde(json['pendientes']),
    enRuta: _pedidosDesde(json['en_ruta']),
    entregadosHoy: _pedidosDesde(json['entregados_hoy']),
    actividadHoy: _pedidosDesde(json['actividad_hoy']),
  );

  /// Día del **servidor**. La app nunca calcula "hoy" con el reloj del teléfono.
  final DateTime hoy;

  /// Pedidos telefónicos de hoy que todavía no tomó nadie.
  final List<Pedido> pendientes;

  /// Los que ya tomó este camionero, sin límite de fecha.
  final List<Pedido> enRuta;

  /// Actividad del día que este camionero ya entregó.
  final List<Pedido> entregadosHoy;

  /// Toda la actividad del día que le pertenece: entregados, en ruta y
  /// cancelados. Es lo que lista `mis_entregas_camionero`, y `entregadosHoy` es
  /// su subconjunto entregado.
  final List<Pedido> actividadHoy;
}

List<Pedido> _pedidosDesde(Object? valor) {
  final List<dynamic> lista = valor as List<dynamic>;
  return lista.map((dynamic pedido) => Pedido.desdeJson(pedido as Map<String, dynamic>)).toList();
}
