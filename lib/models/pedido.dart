/// Modelos de la maqueta.
///
/// Los nombres espejan los modelos Django de `gas_project` (`mockups/models.py`)
/// para que reemplazar `DatosMock` por la API sea un cambio acotado.
library;

enum EstadoPedido {
  pendiente('Pendiente'),
  enRuta('En ruta'),
  entregado('Entregado'),
  cancelado('Cancelado');

  const EstadoPedido(this.etiqueta);

  final String etiqueta;
}

enum OrigenPedido {
  telefono('Teléfono / Domicilio'),
  local('Venta en local'),
  tarreo('Venta por tarreo'),
  ventaExtra('Venta adicional en entrega');

  const OrigenPedido(this.etiqueta);

  final String etiqueta;
}

class TipoBalon {
  const TipoBalon({
    required this.id,
    required this.nombre,
    required this.pesoNetoKg,
    required this.precioDomicilio,
    required this.precioLocal,
  });

  final int id;
  final String nombre;
  final int pesoNetoKg;

  /// Precio para pedidos telefónicos, tarreo y entregas a domicilio.
  final int precioDomicilio;

  /// Precio en bodega o venta directa.
  final int precioLocal;
}

class LineaPedido {
  const LineaPedido({
    required this.balon,
    required this.cantidad,
    required this.precioVentaUnitario,
  });

  final TipoBalon balon;
  final int cantidad;
  final int precioVentaUnitario;

  int get subtotal => precioVentaUnitario * cantidad;
  int get kilos => balon.pesoNetoKg * cantidad;
}

class Pedido {
  const Pedido({
    required this.id,
    required this.estado,
    required this.origen,
    required this.lineas,
    required this.fecha,
    this.sector = '',
    this.direccionEntrega = '',
    this.metodoPago = 'efectivo',
  });

  final int id;
  final EstadoPedido estado;
  final OrigenPedido origen;
  final List<LineaPedido> lineas;
  final DateTime fecha;
  final String sector;
  final String direccionEntrega;
  final String metodoPago;

  int get montoTotal =>
      lineas.fold(0, (total, linea) => total + linea.subtotal);

  int get kilos => lineas.fold(0, (total, linea) => total + linea.kilos);

  /// Texto corto para listas: `2×11kg + 1×5kg`.
  String get resumenProductos =>
      lineas.map((linea) => '${linea.cantidad}×${linea.balon.pesoNetoKg}kg').join(' + ');
}

/// Formatea un monto en pesos chilenos con separador de miles.
///
/// Espeja `USE_THOUSAND_SEPARATOR = True` en la web. El servidor siempre
/// envía enteros sin formato: acá solo se presenta.
String formatearClp(int monto) {
  final digitos = monto.abs().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digitos[i]);
  }

  return '${monto < 0 ? '-' : ''}\$${buffer.toString()}';
}

/// Fecha y hora en el formato corto que usa la PWA: `06/10/2026 14:35`.
String formatearFechaHora(DateTime fecha) {
  String dos(int valor) => valor.toString().padLeft(2, '0');
  return '${dos(fecha.day)}/${dos(fecha.month)}/${fecha.year} '
      '${dos(fecha.hour)}:${dos(fecha.minute)}';
}
