import 'package:flutter/material.dart';

import '../core/error/error_api.dart';
import '../data/api_cliente.dart';
import '../models/historial.dart';
import '../models/pedido.dart';
import '../theme/app_theme.dart';
import '../widgets/comunes.dart';

/// Detalle resumido de las ventas de un día.
///
/// Espejo de `entregas/historial_camionero_dia.html`: totales del día y una
/// tarjeta por venta. Solo aparecen **entregados**: un cancelado del día no es
/// una venta, así que la app no lo lista acá (sí se ve en "Mis Entregas Hoy").
class DetalleDiaScreen extends StatefulWidget {
  const DetalleDiaScreen({super.key, required this.api, required this.fecha});

  final ApiCliente api;

  /// `AAAA-MM-DD`, ya validado por el servidor en el listado del mes.
  final String fecha;

  @override
  State<DetalleDiaScreen> createState() => _DetalleDiaScreenState();
}

class _DetalleDiaScreenState extends State<DetalleDiaScreen> {
  DetalleDia? _dia;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);

    try {
      final DetalleDia dia = await widget.api.historialDia(widget.fecha);
      if (!mounted) {
        return;
      }
      setState(() => _dia = dia);
    } on ErrorApi catch (fallo) {
      if (mounted) {
        setState(() => _error = fallo.mensaje);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final DetalleDia? dia = _dia;

    return Scaffold(
      appBar: AppBar(
        title: Text(dia == null ? 'Detalle del día' : formatearFecha(dia.fecha)),
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: _contenido(dia),
        ),
      ),
    );
  }

  List<Widget> _contenido(DetalleDia? dia) {
    if (dia == null) {
      if (_error != null) {
        return <Widget>[PantallaError(mensaje: _error!, onReintentar: _cargar)];
      }
      return const <Widget>[PantallaCargando(mensaje: 'Cargando el día…')];
    }

    if (dia.pedidos.isEmpty) {
      return const <Widget>[
        EstadoVacio(
          titulo: 'Sin ventas este día',
          mensaje: 'No hay entregas registradas para esta fecha.',
        ),
      ];
    }

    return <Widget>[
      Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          _EtiquetaTotal(
            texto: '${dia.entregas} ${dia.entregas == 1 ? 'venta' : 'ventas'}',
            color: ColoresApp.exito,
          ),
          _EtiquetaTotal(texto: '${dia.kilos} kg', color: ColoresApp.secundario),
          _EtiquetaTotal(texto: formatearClp(dia.monto), color: ColoresApp.primario),
        ],
      ),
      const SizedBox(height: 18),
      for (final Pedido pedido in dia.pedidos) _tarjetaPedido(pedido),
    ];
  }

  Widget _tarjetaPedido(Pedido pedido) {
    // La web no muestra la dirección de una venta de tarreo: no hay a dónde ir.
    final bool mostrarDireccion =
        pedido.origen != OrigenPedido.tarreo && pedido.direccionEntrega.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE9ECEF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                '#${pedido.id}',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              _EtiquetaOrigen(
                texto: pedido.origenEtiqueta,
                esTarreo: pedido.origen == OrigenPedido.tarreo,
              ),
              const Spacer(),
              Text(
                formatearHora(pedido.fecha),
                style: const TextStyle(fontSize: 14, color: ColoresApp.secundario),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pedido.resumenProductos,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          if (mostrarDireccion) ...<Widget>[
            const SizedBox(height: 6),
            Text(
              pedido.direccionEntrega,
              style: const TextStyle(fontSize: 14, color: ColoresApp.primario),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Text(
                formatearClp(pedido.montoTotal),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: ColoresApp.exito,
                ),
              ),
              const Spacer(),
              Text(
                '${pedido.kilos} kg',
                style: const TextStyle(fontSize: 14, color: ColoresApp.secundario),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EtiquetaTotal extends StatelessWidget {
  const _EtiquetaTotal({required this.texto, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _EtiquetaOrigen extends StatelessWidget {
  const _EtiquetaOrigen({required this.texto, required this.esTarreo});

  final String texto;
  final bool esTarreo;

  @override
  Widget build(BuildContext context) {
    final Color fondo = esTarreo ? ColoresApp.advertencia : ColoresApp.primario;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: esTarreo ? Colors.black87 : Colors.white,
        ),
      ),
    );
  }
}
