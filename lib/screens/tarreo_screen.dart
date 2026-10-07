import 'package:flutter/material.dart';

import '../core/error/error_api.dart';
import '../data/api_cliente.dart';
import '../data/controlador_balones.dart';
import '../data/controlador_entregas.dart';
import '../models/pedido.dart';
import '../theme/app_theme.dart';
import '../widgets/boton_accion.dart';
import '../widgets/comunes.dart';
import '../widgets/dialogo_confirmacion.dart';

/// Venta rápida en la calle.
///
/// Espejo de `entregas/tarreo.html`: cantidades por tipo de balón, método de
/// pago obligatorio y dirección opcional. Sin descuentos.
///
/// Los precios y el total los pone el servidor: el POST lleva balón y cantidad
/// nada más, así que un teléfono intervenido no puede vender más barato que la
/// web. La pantalla solo los muestra.
class TarreoScreen extends StatefulWidget {
  const TarreoScreen({
    super.key,
    required this.api,
    required this.balones,
    required this.entregas,
  });

  final ApiCliente api;

  /// Catálogo vigente (§7.5). Es la fuente de los precios que se muestran.
  final ControladorBalones balones;

  /// La venta queda como actividad del día del camionero: al registrarla se
  /// recarga este controlador para que aparezca en "Mis Entregas Hoy".
  final ControladorEntregas entregas;

  @override
  State<TarreoScreen> createState() => _TarreoScreenState();
}

class _TarreoScreenState extends State<TarreoScreen> {
  static const List<String> _metodosPago = <String>['efectivo', 'tarjeta', 'transferencia'];

  final Map<int, int> _cantidades = <int, int>{};
  final TextEditingController _direccion = TextEditingController();
  String _metodoPago = 'efectivo';
  bool _enviando = false;

  @override
  void dispose() {
    _direccion.dispose();
    super.dispose();
  }

  int get _total {
    int total = 0;
    for (final TipoBalon balon in widget.balones.balones) {
      total += (_cantidades[balon.id] ?? 0) * balon.precioDomicilio;
    }
    return total;
  }

  int get _cantidadTotal =>
      _cantidades.values.fold(0, (int total, int cantidad) => total + cantidad);

  void _cambiarCantidad(TipoBalon balon, int delta) {
    setState(() {
      final int actual = _cantidades[balon.id] ?? 0;
      final int nuevo = (actual + delta).clamp(0, 99);
      if (nuevo == 0) {
        _cantidades.remove(balon.id);
      } else {
        _cantidades[balon.id] = nuevo;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.balones,
      builder: (BuildContext context, Widget? _) => CuerpoPantalla(
        onRefrescar: widget.balones.cargar,
        children: <Widget>[
          const TituloPantalla(
            icono: Icons.add_shopping_cart,
            texto: 'Venta Tarreo',
            color: ColoresApp.exito,
          ),
          ..._contenido(),
        ],
      ),
    );
  }

  List<Widget> _contenido() {
    final ControladorBalones controlador = widget.balones;

    if (controlador.sinDatosTodavia) {
      return const <Widget>[PantallaCargando(mensaje: 'Cargando precios…')];
    }

    // Error sin nada cargado antes: no hay con qué vender y hay que decirlo.
    if (controlador.error != null && controlador.balones.isEmpty) {
      return <Widget>[
        PantallaError(mensaje: controlador.error!, onReintentar: controlador.cargar),
      ];
    }

    if (controlador.balones.isEmpty) {
      return const <Widget>[
        EstadoVacio(
          titulo: 'Sin balones',
          mensaje: 'No hay balones activos para vender en este momento.',
        ),
      ];
    }

    final String? fallo = controlador.error;
    return <Widget>[
      // Se sigue vendiendo con los últimos precios conocidos, pero avisado:
      // cobrar con datos viejos sin decirlo sería peor que el corte mismo.
      if (fallo != null)
        AvisoInfo(
          texto: 'No se pudieron actualizar los precios: $fallo',
          icono: Icons.wifi_off,
        ),
      const AvisoInfo(
        texto: 'Venta directa en el camión. Se registra como entregada.',
        icono: Icons.shopping_cart,
      ),
      for (final TipoBalon balon in controlador.balones) _filaBalon(balon),
      const SizedBox(height: 10),
      const _Etiqueta(texto: 'Método de pago'),
      const SizedBox(height: 10),
      Wrap(
        spacing: 10,
        runSpacing: 10,
        children: <Widget>[
          for (final String metodo in _metodosPago)
            ChoiceChip(
              label: Text(
                _etiquetaMetodo(metodo),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: _metodoPago == metodo ? Colors.white : Colors.black87,
                ),
              ),
              selected: _metodoPago == metodo,
              selectedColor: ColoresApp.exito,
              backgroundColor: ColoresApp.grisClaro,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              onSelected: (_) => setState(() => _metodoPago = metodo),
            ),
        ],
      ),
      const SizedBox(height: 24),
      const _Etiqueta(texto: 'Dirección (opcional)'),
      const SizedBox(height: 10),
      TextField(
        controller: _direccion,
        maxLines: 2,
        style: const TextStyle(fontSize: 17),
        decoration: InputDecoration(
          hintText: 'Tarreo / venta directa en camión',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
      const SizedBox(height: 26),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: ColoresApp.grisClaro,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: <Widget>[
            Text(
              '$_cantidadTotal ${_cantidadTotal == 1 ? 'balón' : 'balones'}',
              style: const TextStyle(fontSize: 16, color: ColoresApp.secundario),
            ),
            const SizedBox(height: 6),
            Text(
              'Total: ${formatearClp(_total)}',
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: ColoresApp.exito,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      BotonAccion(
        etiqueta: _enviando ? 'REGISTRANDO…' : 'REGISTRAR VENTA',
        icono: Icons.save,
        estilo: EstiloBoton.exito,
        onPressed: _registrar,
      ),
    ];
  }

  Widget _filaBalon(TipoBalon balon) {
    final int cantidad = _cantidades[balon.id] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cantidad > 0 ? ColoresApp.exito : const Color(0xFFE9ECEF),
          width: cantidad > 0 ? 2 : 1,
        ),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  balon.nombre,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text(
                  formatearClp(balon.precioDomicilio),
                  style: const TextStyle(fontSize: 15, color: ColoresApp.secundario),
                ),
              ],
            ),
          ),
          _BotonCantidad(
            icono: Icons.remove,
            etiquetaAccesible: 'Quitar un ${balon.nombre}',
            onTap: cantidad == 0 ? null : () => _cambiarCantidad(balon, -1),
          ),
          SizedBox(
            width: 46,
            child: Text(
              '$cantidad',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          _BotonCantidad(
            icono: Icons.add,
            etiquetaAccesible: 'Agregar un ${balon.nombre}',
            onTap: () => _cambiarCantidad(balon, 1),
          ),
        ],
      ),
    );
  }

  /// Confirma y registra la venta contra `/api/v1/tarreo/` (§7.4).
  Future<void> _registrar() async {
    // Doble toque mientras viaja la petición: la venta se registra una sola vez.
    if (_enviando) {
      return;
    }
    if (_cantidadTotal == 0) {
      mostrarAviso(context, 'Debe agregar al menos un producto.');
      return;
    }

    final bool confirmado = await confirmarAccion(
      context,
      titulo: 'Registrar venta',
      cuerpo:
          '$_cantidadTotal ${_cantidadTotal == 1 ? 'balón' : 'balones'} · '
          '${formatearClp(_total)}\n\n'
          'Se registrará como entregada en el acto. ¿Confirmas la venta?',
      color: ColoresApp.exito,
      textoConfirmar: 'Sí, registrar',
    );
    if (!confirmado || !mounted) {
      return;
    }

    setState(() => _enviando = true);
    try {
      final Pedido pedido = await widget.api.registrarVentaTarreo(
        cantidades: Map<int, int>.of(_cantidades),
        metodoPago: _metodoPago,
        direccion: _direccion.text,
      );
      if (!mounted) {
        return;
      }

      // El formulario vuelve a cero: la próxima venta empieza limpia, igual que
      // en la web, que redirige después de guardar.
      setState(() {
        _cantidades.clear();
        _direccion.clear();
        _metodoPago = 'efectivo';
      });
      mostrarAviso(
        context,
        'Venta #${pedido.id} registrada por ${formatearClp(pedido.montoTotal)}.',
      );

      // La venta ya es actividad del día: se recarga para que el camionero la
      // vea en "Mis Entregas Hoy" sin tener que salir y volver a entrar.
      await widget.entregas.cargar();
    } on ErrorApi catch (error) {
      if (mounted) {
        mostrarAviso(context, error.mensaje);
      }
    } finally {
      if (mounted) {
        setState(() => _enviando = false);
      }
    }
  }

  String _etiquetaMetodo(String metodo) {
    switch (metodo) {
      case 'efectivo':
        return 'Efectivo';
      case 'tarjeta':
        return 'Tarjeta';
      default:
        return 'Transferencia';
    }
  }
}

class _Etiqueta extends StatelessWidget {
  const _Etiqueta({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Text(texto, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));
  }
}

class _BotonCantidad extends StatelessWidget {
  const _BotonCantidad({
    required this.icono,
    required this.etiquetaAccesible,
    required this.onTap,
  });

  final IconData icono;

  /// Los botones son solo un signo; sin esto un lector de pantalla no puede
  /// decir cuál balón está sumando.
  final String etiquetaAccesible;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bool habilitado = onTap != null;

    return Semantics(
      label: etiquetaAccesible,
      button: true,
      child: SizedBox(
        width: 52,
        height: 52,
        child: Material(
          color: habilitado ? ColoresApp.primario : const Color(0xFFE9ECEF),
          borderRadius: BorderRadius.circular(12),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Icon(
              icono,
              size: 28,
              color: habilitado ? Colors.white : ColoresApp.secundario,
            ),
          ),
        ),
      ),
    );
  }
}
