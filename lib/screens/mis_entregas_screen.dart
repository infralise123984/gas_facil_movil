import 'package:flutter/material.dart';

import '../data/controlador_entregas.dart';
import '../models/pedido.dart';
import '../models/resumen_entregas.dart';
import '../theme/app_theme.dart';
import '../widgets/comunes.dart';
import '../widgets/tarjeta_pedido.dart';

/// Entregas del día.
///
/// Espejo de `entregas/mis_entregas_camionero.html` con los contadores y las
/// tarjetas de `partials/_mis_entregas_camionero_cards.html`.
///
/// No carga por su cuenta: lee el `ControladorEntregas`, que es el único dueño
/// de los datos de las dos pantallas del panel.
class MisEntregasScreen extends StatelessWidget {
  const MisEntregasScreen({super.key, required this.controlador});

  final ControladorEntregas controlador;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controlador,
      builder: (BuildContext context, Widget? _) {
        final ResumenEntregas? datos = controlador.datos;

        if (datos == null) {
          if (controlador.sinDatosTodavia) {
            return const CuerpoPantalla(
              children: <Widget>[PantallaCargando(mensaje: 'Cargando tus entregas…')],
            );
          }
          return CuerpoPantalla(
            children: <Widget>[
              PantallaError(
                mensaje: controlador.error ?? 'Ocurrió un error inesperado.',
                onReintentar: controlador.cargar,
              ),
            ],
          );
        }

        return _panel(datos);
      },
    );
  }

  Widget _panel(ResumenEntregas resumen) {
    // Los contadores salen de lo **entregado**; el listado muestra toda la
    // actividad del día, igual que la web: cancelados (con franja roja) y los
    // que siguen en ruta incluidos.
    final List<Pedido> entregados = resumen.entregadosHoy;
    final List<Pedido> pedidos = resumen.actividadHoy;
    final int totalMonto = entregados.fold(0, (int t, Pedido p) => t + p.montoTotal);
    final int totalKilos = entregados.fold(0, (int t, Pedido p) => t + p.kilos);

    return CuerpoPantalla(
      onRefrescar: controlador.cargar,
      children: <Widget>[
        const TituloPantalla(icono: Icons.check_circle, texto: 'Mis Entregas Hoy'),
        const AvisoInfo(texto: 'Para días anteriores usa el historial mensual (llega en F6).'),
        if (controlador.error != null) ...<Widget>[
          AvisoInfo(
            texto: 'Sin conexión: puede que esta lista no esté al día.',
            icono: Icons.cloud_off,
          ),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Flexible(
              child: _Contador(
                texto:
                    '${entregados.length} '
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
            TarjetaPedido(pedido: pedido, mostrarEncabezadoCancelado: true, mostrarFecha: true),
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
        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
      ),
    );
  }
}
