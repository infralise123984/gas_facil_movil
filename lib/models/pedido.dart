/// Objetos del contrato del API (docs/API_MOVIL.md §7.2).
///
/// Los nombres espejan los modelos Django de `gas_project` (`mockups/models.py`).
/// El servidor siempre manda enteros en pesos y fechas ISO: acá solo se arma el
/// objeto, el formato lo pone la interfaz.
library;

/// Estado del pedido. Coincide con `Pedido.ESTADOS` del servidor.
enum EstadoPedido {
  pendiente,
  enRuta,
  entregado,
  cancelado;

  /// Traduce el valor del servidor. Un valor desconocido es un desacuerdo de
  /// contrato, no algo que se pueda adivinar: se lanza y se detiene ahí.
  static EstadoPedido desdeApi(String valor) => switch (valor) {
    'pendiente' => EstadoPedido.pendiente,
    'en_ruta' => EstadoPedido.enRuta,
    'entregado' => EstadoPedido.entregado,
    'cancelado' => EstadoPedido.cancelado,
    _ => throw FormatException('Estado de pedido desconocido: $valor'),
  };
}

/// Origen del pedido. Coincide con `Pedido.ORIGENES` del servidor.
enum OrigenPedido {
  telefono,
  local,
  tarreo,
  ventaExtra;

  static OrigenPedido desdeApi(String valor) => switch (valor) {
    'telefono' => OrigenPedido.telefono,
    'local' => OrigenPedido.local,
    'tarreo' => OrigenPedido.tarreo,
    'venta_extra' => OrigenPedido.ventaExtra,
    _ => throw FormatException('Origen de pedido desconocido: $valor'),
  };
}

/// Balón del catálogo vigente, tal como lo entrega `serializar_balon` (§7.5).
///
/// Solo trae el precio de domicilio, que es el que rige para el tarreo. El
/// precio de compra **no** viaja al teléfono: con él se reconstruye el margen.
class TipoBalon {
  const TipoBalon({
    required this.id,
    required this.nombre,
    required this.pesoNetoKg,
    required this.precioDomicilio,
    this.tipoGas = '',
  });

  factory TipoBalon.desdeJson(Map<String, dynamic> json) => TipoBalon(
    id: json['id'] as int,
    nombre: json['nombre'] as String,
    pesoNetoKg: json['peso_neto_gas'] as int,
    precioDomicilio: json['precio_domicilio'] as int,
    tipoGas: json['tipo_gas'] as String? ?? '',
  );

  final int id;
  final String nombre;
  final int pesoNetoKg;

  /// Precio para pedidos telefónicos, tarreo y entregas a domicilio.
  final int precioDomicilio;

  /// `normal`, `catalitico` o `aluminio` (`TipoBalon.tipo_gas` en la web).
  final String tipoGas;

  /// Etiqueta que el tarreo de la web muestra bajo el nombre, o `null` si es un
  /// balón normal.
  String? get etiquetaTipo => switch (tipoGas) {
    'catalitico' => 'CATALÍTICO',
    'aluminio' => 'ALUMINIO',
    _ => null,
  };
}

/// Línea de un pedido, tal como la entrega `serializar_linea`.
///
/// Los montos vienen del servidor y no se recalculan. `subtotal` es el bruto y
/// `subtotalNeto` el que queda después del descuento de la línea.
class LineaPedido {
  const LineaPedido({
    required this.balonId,
    required this.balonNombre,
    required this.pesoNetoGas,
    required this.cantidad,
    required this.precioVentaUnitario,
    required this.descuentoUnitario,
    required this.subtotal,
    required this.subtotalNeto,
  });

  factory LineaPedido.desdeJson(Map<String, dynamic> json) => LineaPedido(
    balonId: json['balon_id'] as int,
    balonNombre: json['balon_nombre'] as String,
    pesoNetoGas: json['peso_neto_gas'] as int,
    cantidad: json['cantidad'] as int,
    precioVentaUnitario: json['precio_venta_unitario'] as int,
    descuentoUnitario: json['descuento_unitario'] as int,
    subtotal: json['subtotal'] as int,
    subtotalNeto: json['subtotal_neto'] as int,
  );

  final int balonId;
  final String balonNombre;
  final int pesoNetoGas;
  final int cantidad;
  final int precioVentaUnitario;
  final int descuentoUnitario;
  final int subtotal;
  final int subtotalNeto;

  int get kilos => pesoNetoGas * cantidad;
}

class Pedido {
  const Pedido({
    required this.id,
    required this.estado,
    required this.origen,
    required this.lineas,
    required this.fecha,
    required this.montoTotal,
    required this.kilos,
    required this.subtotalBruto,
    required this.descuentoTotal,
    required this.tieneDescuento,
    this.sector = '',
    this.direccionEntrega = '',
    this.metodoPago = 'efectivo',
    this.origenEtiqueta = '',
  });

  factory Pedido.desdeJson(Map<String, dynamic> json) {
    final List<dynamic> lineasJson = json['lineas'] as List<dynamic>;

    return Pedido(
      id: json['id'] as int,
      estado: EstadoPedido.desdeApi(json['estado'] as String),
      origen: OrigenPedido.desdeApi(json['origen'] as String),
      origenEtiqueta: json['origen_etiqueta'] as String? ?? '',
      lineas: lineasJson
          .map((dynamic linea) => LineaPedido.desdeJson(linea as Map<String, dynamic>))
          .toList(),
      fecha: _fechaDesde(json['fecha']),
      montoTotal: json['monto_total'] as int,
      kilos: json['kilos'] as int,
      subtotalBruto: json['subtotal_bruto'] as int,
      descuentoTotal: json['descuento_total'] as int,
      tieneDescuento: json['tiene_descuento'] as bool,
      sector: json['sector'] as String? ?? '',
      direccionEntrega: json['direccion_entrega'] as String? ?? '',
      metodoPago: json['metodo_pago'] as String? ?? 'efectivo',
    );
  }

  final int id;
  final EstadoPedido estado;
  final OrigenPedido origen;

  /// Etiqueta del origen tal como la manda el servidor ("Teléfono /
  /// Domicilio", "Tarreo"): la app no la traduce.
  final String origenEtiqueta;

  final List<LineaPedido> lineas;
  final DateTime fecha;

  /// Monto **neto** (bruto menos descuentos). Viene calculado del servidor: la
  /// app no lo recalcula, porque el servidor es la única fuente de verdad del
  /// dinero (docs/API_MOVIL.md §7.2).
  final int montoTotal;

  final int kilos;
  final int subtotalBruto;
  final int descuentoTotal;
  final bool tieneDescuento;

  /// Sector tal cual lo guardó el servidor. Es texto libre sin catálogo: no se
  /// intenta mapear ni traducir.
  final String sector;

  final String direccionEntrega;
  final String metodoPago;

  /// Texto corto para listas: `2×11kg + 1×5kg`. Espeja
  /// `Pedido.resumen_productos` de la web; los kilos por balón ya vienen en cada
  /// línea, así que no hace falta otra consulta.
  String get resumenProductos => lineas.isEmpty
      ? '—'
      : lineas
            .map((LineaPedido linea) => '${linea.cantidad}×${linea.pesoNetoGas}kg')
            .join(' + ');
}

DateTime _fechaDesde(Object? valor) {
  if (valor is! String) {
    throw const FormatException('El pedido llegó sin fecha.');
  }
  // El servidor ya manda la hora de Chile y así la muestra la web. Se lee como
  // hora de pared, sin desplazamiento: `DateTime.parse` con desfase devolvería
  // UTC y el huso del teléfono correría la hora que ve el camionero.
  final String horaDePared = valor.length > 19 ? valor.substring(0, 19) : valor;
  return DateTime.parse(horaDePared);
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

String _dosDigitos(int valor) => valor.toString().padLeft(2, '0');

/// Fecha en el formato corto que usa la PWA: `06/10/2026`.
String formatearFecha(DateTime fecha) =>
    '${_dosDigitos(fecha.day)}/${_dosDigitos(fecha.month)}/${fecha.year}';

/// Hora en el formato corto que usa la PWA: `14:35`.
String formatearHora(DateTime fecha) =>
    '${_dosDigitos(fecha.hour)}:${_dosDigitos(fecha.minute)}';

/// Fecha y hora en el formato corto que usa la PWA: `06/10/2026 14:35`.
String formatearFechaHora(DateTime fecha) =>
    '${formatearFecha(fecha)} ${formatearHora(fecha)}';
