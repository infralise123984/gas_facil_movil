import 'package:flutter/material.dart';

import '../data/datos_mock.dart';
import '../models/pedido.dart';
import '../theme/app_theme.dart';
import '../widgets/boton_accion.dart';
import '../widgets/comunes.dart';
import '../widgets/dialogo_confirmacion.dart';
import '../widgets/tarjeta_pedido.dart';

/// Panel de entregas del camionero.
///
/// Espejo de `entregas/camionero_entregas.html` con las dos secciones de
/// `partials/_entregas_cards.html`: En Ruta y Pendientes.
class EntregasScreen extends StatelessWidget {
  const EntregasScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Pedido> enRuta = DatosMock.pedidosEnRuta();
    final List<Pedido> pendientes = DatosMock.pedidosPendientes();

    return CuerpoPantalla(
      children: <Widget>[
        const TituloPantalla(icono: Icons.local_shipping, texto: 'Mis Entregas'),
        ContadorChip(
          texto: '${pendientes.length} '
              '${pendientes.length == 1 ? 'pendiente' : 'pendientes'}'
              ' • ${enRuta.length} en ruta',
        ),
        if (enRuta.isNotEmpty) ...<Widget>[
          EncabezadoSeccion(texto: 'En Ruta (${enRuta.length})', color: ColoresApp.exito),
          for (final Pedido pedido in enRuta) _tarjetaEnRuta(context, pedido),
        ],
        if (pendientes.isNotEmpty) ...<Widget>[
          EncabezadoSeccion(
            texto: 'Pendientes (${pendientes.length})',
            color: ColoresApp.info,
          ),
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
          onPressed: () => _confirmar(
            context,
            titulo: 'Marcar como Entregado',
            cuerpo: '¿Confirmas que el Pedido #${pedido.id} fue entregado correctamente?',
            color: ColoresApp.exito,
            textoConfirmar: 'Sí, marcar entregado',
            aviso: 'Maqueta: marcar entregado no llama a la API todavía.',
          ),
        ),
        BotonAccion(
          etiqueta: 'CANCELAR ENTREGA',
          icono: Icons.cancel,
          estilo: EstiloBoton.peligro,
          onPressed: () => _confirmar(
            context,
            titulo: 'Cancelar Entrega',
            cuerpo: '¿Cancelar la entrega del Pedido #${pedido.id}? '
                'El pedido quedará como cancelado.',
            color: ColoresApp.peligro,
            textoConfirmar: 'Sí, cancelar entrega',
            aviso: 'Maqueta: cancelar no llama a la API todavía.',
          ),
        ),
        BotonAccion(
          etiqueta: 'Editar Pedido',
          icono: Icons.edit,
          estilo: EstiloBoton.advertencia,
          onPressed: () => mostrarAviso(
            context,
            'Maqueta: la edición del pedido (venta extra) llega en F4.',
          ),
        ),
        BotonAccion(
          etiqueta: 'DEVOLVER PEDIDO',
          icono: Icons.undo,
          estilo: EstiloBoton.contorno,
          onPressed: () => _confirmar(
            context,
            titulo: 'Devolver Pedido',
            cuerpo: '¿Devolver el Pedido #${pedido.id}? Volverá a la lista de '
                'pendientes y otro camionero podrá tomarlo.',
            color: ColoresApp.secundario,
            textoConfirmar: 'Sí, devolver pedido',
            aviso: 'Maqueta: devolver no llama a la API todavía.',
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
          onPressed: () => _confirmar(
            context,
            titulo: 'Tomar Pedido',
            cuerpo: '¿Quieres tomar el Pedido #${pedido.id} para entregarlo?',
            color: ColoresApp.primario,
            textoConfirmar: 'Sí, tomar pedido',
            aviso: 'Maqueta: tomar pedido no llama a la API todavía. '
                'Además, no estará disponible sin conexión.',
          ),
        ),
      ],
    );
  }

  Future<void> _confirmar(
    BuildContext context, {
    required String titulo,
    required String cuerpo,
    required Color color,
    required String textoConfirmar,
    required String aviso,
  }) async {
    final bool confirmado = await confirmarAccion(
      context,
      titulo: titulo,
      cuerpo: cuerpo,
      color: color,
      textoConfirmar: textoConfirmar,
    );

    if (!context.mounted || !confirmado) {
      return;
    }
    mostrarAviso(context, aviso);
  }
}
