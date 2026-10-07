import 'package:flutter/material.dart';

import '../core/error/error_api.dart';
import '../data/api_cliente.dart';
import '../data/controlador_entregas.dart';
import '../models/pedido.dart';
import '../models/resumen_entregas.dart';
import '../theme/app_theme.dart';
import '../widgets/boton_accion.dart';
import '../widgets/comunes.dart';
import '../widgets/dialogo_confirmacion.dart';
import '../widgets/tarjeta_pedido.dart';

/// Panel de entregas del camionero.
///
/// Espejo de `entregas/camionero_entregas.html` con las dos secciones de
/// `partials/_entregas_cards.html`: En Ruta y Pendientes.
///
/// No carga por su cuenta: lee el `ControladorEntregas`, que es el único dueño
/// de los datos de las dos pantallas del panel.
class EntregasScreen extends StatelessWidget {
  const EntregasScreen({super.key, required this.api, required this.controlador});

  final ApiCliente api;
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
              children: <Widget>[PantallaCargando(mensaje: 'Cargando entregas…')],
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

        return _panel(context, datos);
      },
    );
  }

  Widget _panel(BuildContext context, ResumenEntregas resumen) {
    final List<Pedido> enRuta = resumen.enRuta;
    final List<Pedido> pendientes = resumen.pendientes;

    return CuerpoPantalla(
      onRefrescar: controlador.cargar,
      children: <Widget>[
        const TituloPantalla(icono: Icons.local_shipping, texto: 'Mis Entregas'),
        ContadorChip(
          texto:
              '${pendientes.length} '
              '${pendientes.length == 1 ? 'pendiente' : 'pendientes'}'
              ' • ${enRuta.length} en ruta',
        ),
        if (enRuta.isNotEmpty) ...<Widget>[
          EncabezadoSeccion(texto: 'En Ruta (${enRuta.length})', color: ColoresApp.exito),
          for (final Pedido pedido in enRuta) _tarjetaEnRuta(context, pedido),
        ],
        if (pendientes.isNotEmpty) ...<Widget>[
          EncabezadoSeccion(texto: 'Pendientes (${pendientes.length})', color: ColoresApp.info),
          for (final Pedido pedido in pendientes) _tarjetaPendiente(context, pedido),
        ],
        if (enRuta.isEmpty && pendientes.isEmpty) const EstadoVacio(),
      ],
    );
  }

  Widget _tarjetaEnRuta(BuildContext context, Pedido pedido) {
    return TarjetaPedido(
      pedido: pedido,
      mostrarTituloProductos: false,
      acciones: <Widget>[
        BotonAccion(
          etiqueta: 'MARCAR ENTREGADO',
          icono: Icons.check_circle,
          estilo: EstiloBoton.exito,
          onPressed: () => _ejecutarAccion(
            context,
            titulo: 'Marcar como Entregado',
            cuerpo: '¿Confirmas que el Pedido #${pedido.id} fue entregado correctamente?',
            color: ColoresApp.exito,
            textoConfirmar: 'Sí, marcar entregado',
            ejecutar: () => api.entregarPedido(pedido.id),
            exito: 'Pedido entregado',
          ),
        ),
        BotonAccion(
          etiqueta: 'CANCELAR ENTREGA',
          icono: Icons.cancel,
          estilo: EstiloBoton.peligro,
          onPressed: () => _ejecutarAccion(
            context,
            titulo: 'Cancelar Entrega',
            cuerpo:
                '¿Cancelar la entrega del Pedido #${pedido.id}? '
                'El pedido quedará como cancelado.',
            color: ColoresApp.peligro,
            textoConfirmar: 'Sí, cancelar entrega',
            ejecutar: () => api.cancelarPedido(pedido.id),
            exito: 'Entrega cancelada',
          ),
        ),
        BotonAccion(
          etiqueta: 'Editar Pedido',
          icono: Icons.edit,
          estilo: EstiloBoton.advertencia,
          onPressed: () =>
              mostrarAviso(context, 'Maqueta: la edición del pedido (venta extra) llega en F4.'),
        ),
        BotonAccion(
          etiqueta: 'DEVOLVER PEDIDO',
          icono: Icons.undo,
          estilo: EstiloBoton.contorno,
          onPressed: () => _ejecutarAccion(
            context,
            titulo: 'Devolver Pedido',
            cuerpo:
                '¿Devolver el Pedido #${pedido.id}? Volverá a la lista de '
                'pendientes y otro camionero podrá tomarlo.',
            color: ColoresApp.secundario,
            textoConfirmar: 'Sí, devolver pedido',
            ejecutar: () => api.devolverPedido(pedido.id),
            exito: 'Pedido devuelto al pool',
          ),
        ),
      ],
    );
  }

  Widget _tarjetaPendiente(BuildContext context, Pedido pedido) {
    return TarjetaPedido(
      pedido: pedido,
      mostrarTituloProductos: false,
      acciones: <Widget>[
        BotonAccion(
          etiqueta: 'TOMAR PEDIDO',
          icono: Icons.arrow_forward,
          onPressed: () => _ejecutarAccion(
            context,
            titulo: 'Tomar Pedido',
            cuerpo: '¿Quieres tomar el Pedido #${pedido.id} para entregarlo?',
            color: ColoresApp.primario,
            textoConfirmar: 'Sí, tomar pedido',
            ejecutar: () => api.tomarPedido(pedido.id),
            exito: 'Pedido tomado',
          ),
        ),
      ],
    );
  }

  /// Confirma, ejecuta la acción contra el API y recarga el panel.
  ///
  /// El §7.3 resuelve la carrera entre camioneros con un 409 `no_disponible`:
  /// en ese caso el pedido ya no está disponible, así que se recarga la lista en
  /// vez de dejar en pantalla una tarjeta que ya no sirve.
  Future<void> _ejecutarAccion(
    BuildContext context, {
    required String titulo,
    required String cuerpo,
    required Color color,
    required String textoConfirmar,
    required Future<Pedido> Function() ejecutar,
    required String exito,
  }) async {
    final bool confirmado = await confirmarAccion(
      context,
      titulo: titulo,
      cuerpo: cuerpo,
      color: color,
      textoConfirmar: textoConfirmar,
    );

    if (!confirmado || !context.mounted) {
      return;
    }

    try {
      final Pedido actualizado = await ejecutar();
      if (context.mounted) {
        mostrarAviso(context, '$exito: Pedido #${actualizado.id}');
      }
    } on ErrorApi catch (error) {
      // El mensaje del servidor ya es presentable (§5.2).
      if (context.mounted) {
        mostrarAviso(context, error.mensaje);
      }
    }

    // Se recarga en los dos casos: un 409 significa que el pedido ya no está
    // disponible, así que la lista en pantalla dejó de ser cierta.
    await controlador.cargar();
  }
}
