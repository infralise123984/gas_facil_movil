import 'package:flutter/material.dart';

import '../data/datos_mock.dart';
import '../models/pedido.dart';
import '../theme/app_theme.dart';
import '../widgets/comunes.dart';
import '../widgets/tarjeta_pedido.dart';

/// Entregas del día.
///
/// Espejo de `entregas/mis_entregas_camionero.html` con los contadores y las
/// tarjetas de `partials/_mis_entregas_camionero_cards.html`.
class MisEntregasScreen extends StatelessWidget {
  const MisEntregasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Pedido> pedidos = DatosMock.pedidosDeHoy();
    final List<Pedido> entregados =
        pedidos.where((Pedido p) => p.estado == EstadoPedido.entregado).toList();

    final int totalMonto = entregados.fold(0, (int t, Pedido p) => t + p.montoTotal);
    final int totalKilos = entregados.fold(0, (int t, Pedido p) => t + p.kilos);

    return CuerpoPantalla(
      children: <Widget>[
        const TituloPantalla(icono: Icons.check_circle, texto: 'Mis Entregas Hoy'),
        const AvisoInfo(
          texto: 'Para días anteriores usa el historial mensual (llega en F6).',
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Flexible(
              child: _Contador(
                texto: '${entregados.length} '
                    '${entregados.length == 1 ? 'entrega' : 'entregas'} hoy',
                color: ColoresApp.exito,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: _Contador(texto: formatearClp(totalMonto), color: ColoresApp.primario),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: _Contador(texto: '$totalKilos kg vendidos', color: ColoresApp.secundario),
            ),
          ],
        ),
        const SizedBox(height: 22),
        if (pedidos.isEmpty)
          const EstadoVacio(
            titulo: 'Todo listo por hoy',
            mensaje: 'No tienes entregas registradas para este día.',
          )
        else
          for (final Pedido pedido in pedidos)
            TarjetaPedido(
              pedido: pedido,
              mostrarEncabezadoCancelado: true,
              mostrarFecha: true,
            ),
      ],
    );
  }
}

class _Contador extends StatelessWidget {
  const _Contador({required this.texto, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const <BoxShadow>[
          BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
