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

/// Colores del tarreo de la PWA (`entregas/tarreo.html`). Están acá y no en el
/// tema general porque son de esta pantalla, igual que su gradiente.
const Color _naranjaTitulo = Color(0xFFE65100);
const Color _naranjaCatalitico = Color(0xFFFF6F00);
const Color _bordeTarjeta = Color(0xFFDEE2E6);
const Color _fondoElegido = Color(0xFFE8F5E9);
const Color _gradienteFin = Color(0xFF20C997);

/// Venta rápida en la calle.
///
/// Espejo de `entregas/tarreo.html`: total fijo arriba, tres pasos numerados
/// (pago, balones, dirección) y botón de guardar fijo abajo. La PWA es la
/// referencia: si esto se ve distinto, está mal.
///
/// Los precios y el total los calcula el servidor; el POST lleva balón y
/// cantidad nada más.
class TarreoScreen extends StatefulWidget {
  const TarreoScreen({
    super.key,
    required this.api,
    required this.balones,
    required this.entregas,
    required this.onVentaGuardada,
  });

  final ApiCliente api;

  /// Catálogo vigente (§7.5). Es la fuente de los precios que se muestran.
  final ControladorBalones balones;

  /// La venta queda como actividad del día del camionero: al registrarla se
  /// recarga este controlador para que aparezca en "Mis Entregas Hoy".
  final ControladorEntregas entregas;

  /// Se avisa al contenedor para que vuelva al inicio después de guardar: la
  /// web termina en un `redirect`, no dejando el formulario abierto.
  final VoidCallback onVentaGuardada;

  @override
  State<TarreoScreen> createState() => _TarreoScreenState();
}

class _TarreoScreenState extends State<TarreoScreen> {
  // Métodos de pago: la web ofrece solo Efectivo y Tarjeta en el tarreo.
  // `transferencia` existe en el modelo y el API lo acepta, pero la PWA no lo
  // muestra acá, así que la app tampoco: son la misma pantalla.
  final Map<int, int> _cantidades = <int, int>{};
  final TextEditingController _direccion = TextEditingController();

  /// Sin valor inicial: en la web el campo es obligatorio y no viene elegido.
  String? _metodoPago;

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

  /// Balones que entraron en la venta, en el orden del catálogo.
  List<MapEntry<TipoBalon, int>> get _lineas => <MapEntry<TipoBalon, int>>[
    for (final TipoBalon balon in widget.balones.balones)
      if ((_cantidades[balon.id] ?? 0) > 0)
        MapEntry<TipoBalon, int>(balon, _cantidades[balon.id]!),
  ];

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
      builder: (BuildContext context, Widget? _) => Column(
        children: <Widget>[
          _totalEnCurso(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: widget.balones.cargar,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                children: <Widget>[
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: MedidasApp.anchoMaximoContenido,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: _pasos(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          _barraGuardar(),
        ],
      ),
    );
  }

  /// Total siempre a la vista, como el `sticky-top` de la web.
  Widget _totalEnCurso() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[ColoresApp.exito, _gradienteFin],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: <Widget>[
          Text(
            formatearClp(_total),
            style: const TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const Text(
            'Total venta en curso',
            style: TextStyle(fontSize: 13, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  List<Widget> _pasos() {
    final ControladorBalones controlador = widget.balones;

    if (controlador.sinDatosTodavia) {
      return const <Widget>[PantallaCargando(mensaje: 'Cargando precios…')];
    }
    if (controlador.error != null && controlador.balones.isEmpty) {
      return <Widget>[
        PantallaError(mensaje: controlador.error!, onReintentar: controlador.cargar),
      ];
    }
    if (controlador.balones.isEmpty) {
      return const <Widget>[
        EstadoVacio(
          titulo: 'Sin balones',
          mensaje: 'No hay balones disponibles para venta.',
        ),
      ];
    }

    final String? fallo = controlador.error;
    return <Widget>[
      if (fallo != null)
        AvisoInfo(
          texto: 'No se pudieron actualizar los precios: $fallo',
          icono: Icons.wifi_off,
        ),
      _pasoPago(),
      _pasoBalones(controlador.balones),
      _pasoDireccion(),
    ];
  }

  /// Paso 1: "¿Cómo pagó?".
  Widget _pasoPago() {
    return _Seccion(
      numero: '1',
      titulo: '¿Cómo pagó?',
      colorNumero: ColoresApp.primario,
      colorTitulo: ColoresApp.primario,
      fondo: const LinearGradient(
        colors: <Color>[Color(0xFFE7F1FF), Color(0xFFF8F9FA)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      hijos: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: _BotonPago(
                etiqueta: 'Efectivo',
                icono: Icons.payments,
                color: ColoresApp.exito,
                elegido: _metodoPago == 'efectivo',
                onTap: () => setState(() => _metodoPago = 'efectivo'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _BotonPago(
                etiqueta: 'Tarjeta',
                icono: Icons.credit_card,
                color: ColoresApp.primario,
                elegido: _metodoPago == 'tarjeta',
                onTap: () => setState(() => _metodoPago = 'tarjeta'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Paso 2: "¿Qué balones lleva?".
  Widget _pasoBalones(List<TipoBalon> balones) {
    return _Seccion(
      numero: '2',
      titulo: '¿Qué balones lleva?',
      colorNumero: ColoresApp.advertencia,
      colorTitulo: _naranjaTitulo,
      fondo: const LinearGradient(
        colors: <Color>[Color(0xFFFFF3E0), Color(0xFFF8F9FA)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ),
      hijos: <Widget>[
        for (final TipoBalon balon in balones) _tarjetaBalon(balon),
      ],
    );
  }

  /// Paso 3: dirección opcional.
  Widget _pasoDireccion() {
    return _Seccion(
      numero: '3',
      titulo: 'Dirección (opcional)',
      colorNumero: ColoresApp.secundario,
      colorTitulo: ColoresApp.secundario,
      fondo: const LinearGradient(
        colors: <Color>[Color(0xFFF8F9FA), Color(0xFFF8F9FA)],
      ),
      hijos: <Widget>[
        TextField(
          controller: _direccion,
          maxLines: 2,
          style: const TextStyle(fontSize: 17),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            prefixIcon: const Icon(Icons.place, color: ColoresApp.secundario),
            hintText: 'Ej: casa azul esquina Los Aromos',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        const SizedBox(height: 6),
        const Row(
          children: <Widget>[
            Icon(Icons.info_outline, size: 16, color: ColoresApp.secundario),
            SizedBox(width: 6),
            Expanded(
              child: Text(
                'Deja vacío si es venta directa en el camión.',
                style: TextStyle(fontSize: 13, color: ColoresApp.secundario),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _tarjetaBalon(TipoBalon balon) {
    final int cantidad = _cantidades[balon.id] ?? 0;
    final bool elegido = cantidad > 0;
    final String? etiqueta = balon.etiquetaTipo;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: elegido ? _fondoElegido : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: elegido ? ColoresApp.exito : _bordeTarjeta,
          width: elegido ? 4 : 3,
        ),
      ),
      child: Column(
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      balon.nombre,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (etiqueta != null) ...<Widget>[
                      const SizedBox(height: 4),
                      _EtiquetaBalon(etiqueta: etiqueta, tipoGas: balon.tipoGas),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                formatearClp(balon.precioDomicilio),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: ColoresApp.exito,
                ),
              ),
            ],
          ),
          // El contador recién aparece cuando el balón entra en la venta: antes
          // solo está el botón AGREGAR, igual que en la web.
          if (elegido) ...<Widget>[
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                _BotonRedondo(
                  icono: Icons.remove,
                  color: ColoresApp.peligro,
                  etiquetaAccesible: 'Quitar un ${balon.nombre}',
                  onTap: () => _cambiarCantidad(balon, -1),
                ),
                SizedBox(
                  width: 70,
                  child: Text(
                    '$cantidad',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
                  ),
                ),
                _BotonRedondo(
                  icono: Icons.add,
                  color: ColoresApp.exito,
                  etiquetaAccesible: 'Agregar un ${balon.nombre}',
                  onTap: () => _cambiarCantidad(balon, 1),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          BotonAccion(
            etiqueta: 'AGREGAR',
            icono: Icons.add_circle,
            estilo: EstiloBoton.advertencia,
            onPressed: () => _cambiarCantidad(balon, 1),
          ),
        ],
      ),
    );
  }

  /// Botón fijo abajo, como el `fixed-bottom` de la web.
  Widget _barraGuardar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _bordeTarjeta)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: MedidasApp.anchoMaximoContenido),
          child: BotonAccion(
            etiqueta: _enviando ? 'Guardando…' : 'Guardar Venta',
            icono: Icons.check_circle,
            estilo: EstiloBoton.exito,
            onPressed: _registrar,
          ),
        ),
      ),
    );
  }

  /// Validaciones y confirmación, con los mismos textos que la web.
  Future<void> _registrar() async {
    // Doble toque mientras viaja la petición: la venta se registra una sola vez.
    if (_enviando) {
      return;
    }
    if (_metodoPago == null) {
      mostrarAviso(context, 'Selecciona cómo pagó el cliente');
      return;
    }
    if (_cantidadTotal == 0) {
      mostrarAviso(context, 'Debe agregar al menos un balón');
      return;
    }

    if (!await _confirmarVenta() || !mounted) {
      return;
    }

    setState(() => _enviando = true);
    try {
      final Pedido pedido = await widget.api.registrarVentaTarreo(
        cantidades: Map<int, int>.of(_cantidades),
        metodoPago: _metodoPago!,
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
        _metodoPago = null;
      });
      mostrarAviso(
        context,
        '¡Venta tarreo #${pedido.id} guardada! Total: ${formatearClp(pedido.montoTotal)}',
      );

      // La venta ya es actividad del día: se recarga para que el camionero la
      // vea en "Mis Entregas Hoy" sin tener que salir y volver a entrar.
      await widget.entregas.cargar();
      if (!mounted) {
        return;
      }

      // Como la web, que redirige al guardar: el formulario no se queda
      // abierto. El aviso de éxito lo sigue mostrando el mismo Scaffold.
      widget.onVentaGuardada();
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

  /// Réplica del modal `#modalConfirmarVentaTarreo`: productos, método y total.
  Future<bool> _confirmarVenta() async {
    final bool? confirmado = await showDialog<bool>(
      context: context,
      builder: (BuildContext contexto) => AlertDialog(
        title: const Row(
          children: <Widget>[
            Icon(Icons.shopping_cart_checkout, color: ColoresApp.exito),
            SizedBox(width: 10),
            Text('Confirmar Venta', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('¿Guardar esta venta?', style: TextStyle(fontSize: 17)),
            const SizedBox(height: 10),
            for (final MapEntry<TipoBalon, int> linea in _lineas)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${linea.value} × ${linea.key.nombre}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            const Divider(height: 22),
            Text(
              'Método de pago: ${_etiquetaMetodo(_metodoPago ?? '')}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 4),
            Text(
              'Total: ${formatearClp(_total)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: ColoresApp.exito,
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(contexto).pop(false),
            child: const Text('Volver', style: TextStyle(fontSize: 16)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(contexto).pop(true),
            style: FilledButton.styleFrom(backgroundColor: ColoresApp.exito),
            child: const Text(
              'Sí, guardar venta',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );

    return confirmado ?? false;
  }

  String _etiquetaMetodo(String metodo) => switch (metodo) {
    'efectivo' => 'Efectivo',
    'tarjeta' => 'Tarjeta',
    'transferencia' => 'Transferencia',
    _ => '—',
  };
}

/// Sección numerada de la web: círculo con el paso, título y contenido.
class _Seccion extends StatelessWidget {
  const _Seccion({
    required this.numero,
    required this.titulo,
    required this.colorNumero,
    required this.colorTitulo,
    required this.fondo,
    required this.hijos,
  });

  final String numero;
  final String titulo;
  final Color colorNumero;
  final Color colorTitulo;
  final LinearGradient fondo;
  final List<Widget> hijos;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: fondo,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(color: colorNumero, shape: BoxShape.circle),
                child: Center(
                  child: Text(
                    numero,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                    color: colorTitulo,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...hijos,
        ],
      ),
    );
  }
}

class _BotonPago extends StatelessWidget {
  const _BotonPago({
    required this.etiqueta,
    required this.icono,
    required this.color,
    required this.elegido,
    required this.onTap,
  });

  final String etiqueta;
  final IconData icono;
  final Color color;
  final bool elegido;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color texto = elegido ? Colors.white : color;

    return Semantics(
      button: true,
      selected: elegido,
      label: 'Pago $etiqueta',
      child: Material(
        color: elegido ? color : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color, width: 3),
            ),
            child: Column(
              children: <Widget>[
                Icon(icono, size: 34, color: texto),
                const SizedBox(height: 6),
                Text(
                  etiqueta,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: texto,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BotonRedondo extends StatelessWidget {
  const _BotonRedondo({
    required this.icono,
    required this.color,
    required this.etiquetaAccesible,
    required this.onTap,
  });

  final IconData icono;
  final Color color;
  final String etiquetaAccesible;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: etiquetaAccesible,
      button: true,
      child: SizedBox(
        width: 60,
        height: 60,
        child: Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Icon(icono, size: 32, color: Colors.white),
          ),
        ),
      ),
    );
  }
}

/// Etiqueta CATALÍTICO / ALUMINIO de la tarjeta del balón.
class _EtiquetaBalon extends StatelessWidget {
  const _EtiquetaBalon({required this.etiqueta, required this.tipoGas});

  final String etiqueta;
  final String tipoGas;

  @override
  Widget build(BuildContext context) {
    final bool catalitico = tipoGas == 'catalitico';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: catalitico ? _naranjaCatalitico : ColoresApp.secundario,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        etiqueta,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
