import 'package:flutter/material.dart';

import '../core/error/error_api.dart';
import '../data/api_cliente.dart';
import '../models/historial.dart';
import '../models/pedido.dart';
import '../theme/app_theme.dart';
import '../widgets/comunes.dart';
import 'detalle_dia_screen.dart';

/// Historial de ventas del camionero.
///
/// Espejo de `entregas/historial_camionero.html`: totales del mes, navegación
/// entre meses y la lista de días. Los días sin venta también se listan, en
/// gris y sin poder tocarlos, igual que en la web.
class HistorialScreen extends StatefulWidget {
  const HistorialScreen({super.key, required this.api});

  final ApiCliente api;

  @override
  State<HistorialScreen> createState() => _HistorialScreenState();
}

class _HistorialScreenState extends State<HistorialScreen> {
  /// Mes pedido en `AAAA-MM`. Empieza en `null` para que sea el servidor quien
  /// decida cuál es el mes actual y lo devuelva; la app no lo adivina con el
  /// reloj del teléfono.
  String? _mesPedido;

  HistorialMes? _mes;
  String? _error;
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final HistorialMes mes = await widget.api.historialMes(mes: _mesPedido);
      if (!mounted) {
        return;
      }
      setState(() {
        _mes = mes;
        // Desde acá se navega con el mes que devolvió el servidor.
        _mesPedido = mes.mes;
      });
    } on ErrorApi catch (fallo) {
      if (mounted) {
        setState(() => _error = fallo.mensaje);
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  void _irAMes(String mes) {
    _mesPedido = mes;
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de Ventas')),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          // Sin esto no se puede deslizar cuando el mes tiene pocos días.
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          children: _contenido(),
        ),
      ),
    );
  }

  List<Widget> _contenido() {
    final HistorialMes? mes = _mes;

    if (mes == null) {
      if (_error != null) {
        return <Widget>[PantallaError(mensaje: _error!, onReintentar: _cargar)];
      }
      return const <Widget>[PantallaCargando(mensaje: 'Cargando historial…')];
    }

    final String? fallo = _error;
    return <Widget>[
      // Si falló la recarga, se sigue viendo el mes que ya estaba, avisado.
      if (fallo != null)
        AvisoInfo(
          texto: 'No se pudo actualizar el historial: $fallo',
          icono: Icons.wifi_off,
        ),
      _selectorDeMes(mes),
      _totalesDelMes(mes),
      const SizedBox(height: 14),
      const Text(
        'Toca un día con ventas para ver el detalle resumido.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: ColoresApp.secundario),
      ),
      const SizedBox(height: 12),
      for (final DiaHistorial dia in mes.dias) _filaDia(dia),
    ];
  }

  Widget _selectorDeMes(HistorialMes mes) {
    return Row(
      children: <Widget>[
        IconButton(
          tooltip: 'Mes anterior',
          icon: const Icon(Icons.chevron_left, size: 30),
          onPressed: _cargando ? null : () => _irAMes(mes.mesAnterior),
        ),
        Expanded(
          child: Text(
            '${mes.mesNombre} ${mes.anio}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          tooltip: 'Mes siguiente',
          icon: const Icon(Icons.chevron_right, size: 30),
          // Deshabilitado cuando no hay futuro que mostrar.
          onPressed: _cargando || !mes.mesSiguienteHabilitado
              ? null
              : () => _irAMes(mes.mesSiguiente),
        ),
      ],
    );
  }

  Widget _totalesDelMes(HistorialMes mes) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: ColoresApp.grisClaro,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              _ColumnaTotal(
                etiqueta: 'Kilos mes',
                valor: '${mes.kilos}',
                color: ColoresApp.primario,
              ),
              _ColumnaTotal(
                etiqueta: 'Ventas',
                valor: '${mes.entregas}',
                color: ColoresApp.exito,
              ),
              _ColumnaTotal(
                etiqueta: 'Monto',
                valor: formatearClp(mes.monto),
                color: Colors.black87,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${mes.diasConVenta} ${mes.diasConVenta == 1 ? 'día' : 'días'} '
            'con ventas en este mes',
            style: const TextStyle(fontSize: 13, color: ColoresApp.secundario),
          ),
        ],
      ),
    );
  }

  Widget _filaDia(DiaHistorial dia) {
    if (!dia.tieneVenta) {
      return Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF1F3F5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: <Widget>[
            Text(
              formatearFecha(dia.fecha),
              style: const TextStyle(fontSize: 15, color: ColoresApp.secundario),
            ),
            if (dia.esHoy) const _ChipHoy(),
            const Spacer(),
            const Text(
              'Sin ventas',
              style: TextStyle(fontSize: 14, color: ColoresApp.secundario),
            ),
          ],
        ),
      );
    }

    final bool hoy = dia.esHoy;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hoy ? ColoresApp.primario : const Color(0xFFE9ECEF),
          width: hoy ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _abrirDia(dia),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Text(
                          formatearFecha(dia.fecha),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (hoy) const _ChipHoy(),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _detalleDiaTexto(dia),
                      style: const TextStyle(
                        fontSize: 13,
                        color: ColoresApp.secundario,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  Text(
                    '${dia.kilos} kg',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: ColoresApp.secundario,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatearClp(dia.monto),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: ColoresApp.exito,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "2 ventas · Dom. 15 kg · Tarreo 33 kg", con el mismo recorte que la web.
  String _detalleDiaTexto(DiaHistorial dia) {
    final StringBuffer texto = StringBuffer(
      '${dia.entregas} ${dia.entregas == 1 ? 'venta' : 'ventas'}',
    );
    if (dia.kilosTarreo > 0 && dia.kilosDomicilio > 0) {
      texto.write(' · Dom. ${dia.kilosDomicilio} kg · Tarreo ${dia.kilosTarreo} kg');
    } else if (dia.kilosTarreo > 0) {
      texto.write(' · Tarreo');
    }
    return texto.toString();
  }

  Future<void> _abrirDia(DiaHistorial dia) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) => DetalleDiaScreen(
          api: widget.api,
          fecha: dia.fechaParametro,
        ),
      ),
    );
  }
}

class _ColumnaTotal extends StatelessWidget {
  const _ColumnaTotal({
    required this.etiqueta,
    required this.valor,
    required this.color,
  });

  final String etiqueta;
  final String valor;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            etiqueta.toUpperCase(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: ColoresApp.secundario,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            valor,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }
}

class _ChipHoy extends StatelessWidget {
  const _ChipHoy();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: ColoresApp.primario,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Hoy',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ),
    );
  }
}
