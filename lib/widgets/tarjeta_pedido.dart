import 'package:flutter/material.dart';

import '../models/pedido.dart';
import '../theme/app_theme.dart';

/// Tarjeta de pedido.
///
/// Espejo de `partials/_entregas_cards.html` (panel de entregas) y de
/// `partials/_mis_entregas_camionero_cards.html` (entregas del día).
class TarjetaPedido extends StatelessWidget {
  const TarjetaPedido({
    super.key,
    required this.pedido,
    this.acciones = const <Widget>[],
    this.mostrarEncabezadoCancelado = false,
    this.mostrarFecha = false,
    this.mostrarTituloProductos = true,
  });

  final Pedido pedido;
  final List<Widget> acciones;

  /// Los pedidos cancelados llevan una franja roja "PEDIDO CANCELADO".
  final bool mostrarEncabezadoCancelado;

  /// Pie con la fecha según estado ("Entregado: 06/10/2026 09:15").
  final bool mostrarFecha;

  /// El panel de entregas (`_entregas_cards.html`) usa un parcial que **no**
  /// lleva título de productos; el resumen del día sí lo lleva.
  final bool mostrarTituloProductos;

  bool get _cancelado => pedido.estado == EstadoPedido.cancelado;

  Color get _colorBorde => switch (pedido.estado) {
    EstadoPedido.pendiente => ColoresApp.info,
    EstadoPedido.enRuta => ColoresApp.advertencia,
    EstadoPedido.entregado => ColoresApp.exito,
    EstadoPedido.cancelado => ColoresApp.peligro,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _colorBorde, width: 2.5),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (mostrarEncabezadoCancelado && _cancelado) _franjaCancelado(),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Pedido #${pedido.id}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: MedidasApp.tamanoTextoPedido,
                    fontWeight: FontWeight.bold,
                    color: _cancelado ? ColoresApp.peligro : Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),
                _DesgloseProductos(pedido: pedido, mostrarTitulo: mostrarTituloProductos),
                const SizedBox(height: 16),
                _Ubicacion(pedido: pedido),
                if (mostrarFecha) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    _textoFecha(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: ColoresApp.secundario, fontSize: 14),
                  ),
                ],
                if (acciones.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 20),
                  for (final Widget accion in acciones) ...<Widget>[
                    accion,
                    const SizedBox(height: 12),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _franjaCancelado() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        color: ColoresApp.peligro,
        borderRadius: BorderRadius.vertical(top: Radius.circular(13)),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.cancel, color: Colors.white, size: 22),
          SizedBox(width: 8),
          Text(
            'PEDIDO CANCELADO',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ],
      ),
    );
  }

  String _textoFecha() {
    final String prefijo = switch (pedido.estado) {
      EstadoPedido.cancelado => 'Cancelado',
      EstadoPedido.enRuta => 'En ruta desde',
      EstadoPedido.entregado => 'Entregado',
      EstadoPedido.pendiente => 'Registrado',
    };
    return '$prefijo: ${formatearFechaHora(pedido.fecha)}';
  }
}

class _DesgloseProductos extends StatelessWidget {
  const _DesgloseProductos({required this.pedido, required this.mostrarTitulo});

  final Pedido pedido;
  final bool mostrarTitulo;

  @override
  Widget build(BuildContext context) {
    final bool cancelado = pedido.estado == EstadoPedido.cancelado;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (mostrarTitulo)
          Text(
            // Regla exacta de `_mis_entregas_camionero_cards.html`: solo los
            // cancelados pierden la palabra "entregados".
            cancelado ? 'Productos:' : 'Productos entregados:',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        if (mostrarTitulo) const SizedBox(height: 10),
        for (final LineaPedido linea in pedido.lineas)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${linea.cantidad} × ${linea.balonNombre}',
                    style: TextStyle(
                      fontSize: 18,
                      decoration: cancelado ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: cancelado ? ColoresApp.peligro : ColoresApp.exito,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        // El distintivo muestra el **neto** de la línea, igual que
                        // `_pedido_desglose_camionero.html`: si mostrara el bruto, no
                        // cuadraría con el total cuando hay descuento.
                        formatearClp(linea.subtotalNeto),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    if (linea.descuentoUnitario > 0) ...<Widget>[
                      const SizedBox(height: 4),
                      Text(
                        '−${formatearClp(linea.descuentoUnitario)} por balón',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: ColoresApp.peligro,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        if (pedido.tieneDescuento) ...<Widget>[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0x1ADC3545),
              border: Border.all(color: ColoresApp.peligro),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: <Widget>[
                Text(
                  'CON DESCUENTO −${formatearClp(pedido.descuentoTotal)}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: ColoresApp.peligro,
                  ),
                ),
                const SizedBox(height: 8),
                _FilaDescuento(etiqueta: 'Subtotal', valor: formatearClp(pedido.subtotalBruto)),
                _FilaDescuento(
                  etiqueta: 'Descuento',
                  valor: '−${formatearClp(pedido.descuentoTotal)}',
                  destacado: true,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (cancelado) ...<Widget>[
          Text(
            formatearClp(pedido.montoTotal),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: ColoresApp.peligro,
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'NO COBRADO',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ColoresApp.peligro),
          ),
        ] else
          Text(
            'Total: ${formatearClp(pedido.montoTotal)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: ColoresApp.exito,
            ),
          ),
      ],
    );
  }
}

/// Fila de etiqueta y monto del recuadro de descuento.
class _FilaDescuento extends StatelessWidget {
  const _FilaDescuento({required this.etiqueta, required this.valor, this.destacado = false});

  final String etiqueta;
  final String valor;
  final bool destacado;

  @override
  Widget build(BuildContext context) {
    final Color color = destacado ? ColoresApp.peligro : ColoresApp.secundario;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Text(
          etiqueta,
          style: TextStyle(
            fontSize: 15,
            color: color,
            fontWeight: destacado ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        Text(
          valor,
          style: TextStyle(
            fontSize: 15,
            color: color,
            fontWeight: destacado ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
    );
  }
}

class _Ubicacion extends StatelessWidget {
  const _Ubicacion({required this.pedido});

  final Pedido pedido;

  @override
  Widget build(BuildContext context) {
    if (pedido.direccionEntrega.isEmpty) {
      return const Text(
        'Sin dirección específica',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 17, color: ColoresApp.secundario),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const Text('Dirección:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          pedido.direccionEntrega,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: ColoresApp.primario,
          ),
        ),
        if (pedido.sector.isNotEmpty) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            'Sector: ${pedido.sector}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: ColoresApp.secundario),
          ),
        ],
      ],
    );
  }
}
