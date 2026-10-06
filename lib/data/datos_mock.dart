import '../models/pedido.dart';

/// Datos de prueba de la maqueta.
///
/// TODO(api): reemplazar por un repositorio que consuma `/api/v1/`
/// (ver docs/PLAN_APP_CAMIONERO.md, sección 4). Las pantallas no deben
/// conocer esta clase: hoy se usa directo para poder ver la interfaz.
class DatosMock {
  const DatosMock._();

  static const List<TipoBalon> balones = <TipoBalon>[
    TipoBalon(id: 1, nombre: 'Gas 5 kg', pesoNetoKg: 5, precioDomicilio: 8900, precioLocal: 8300),
    TipoBalon(id: 2, nombre: 'Gas 11 kg', pesoNetoKg: 11, precioDomicilio: 22900, precioLocal: 21500),
    TipoBalon(id: 3, nombre: 'Gas 15 kg', pesoNetoKg: 15, precioDomicilio: 31900, precioLocal: 30500),
    TipoBalon(id: 4, nombre: 'Gas 45 kg', pesoNetoKg: 45, precioDomicilio: 79900, precioLocal: 78000),
    TipoBalon(id: 5, nombre: 'Catalítico 5 kg', pesoNetoKg: 5, precioDomicilio: 12400, precioLocal: 11900),
  ];

  static TipoBalon balon(int id) =>
      balones.firstWhere((TipoBalon b) => b.id == id);

  static List<Pedido> pedidosEnRuta() => <Pedido>[
        Pedido(
          id: 4102,
          estado: EstadoPedido.enRuta,
          origen: OrigenPedido.telefono,
          sector: 'Población Recreo',
          direccionEntrega: 'Los Aromos 1234, casa esquina, reja verde',
          metodoPago: 'efectivo',
          fecha: _hoy(9, 15),
          lineas: <LineaPedido>[
            LineaPedido(balon: balon(2), cantidad: 2, precioVentaUnitario: 22900),
          ],
        ),
      ];

  static List<Pedido> pedidosPendientes() => <Pedido>[
        Pedido(
          id: 4107,
          estado: EstadoPedido.pendiente,
          origen: OrigenPedido.telefono,
          sector: 'Villa Tuniche',
          direccionEntrega: 'Pasaje Los Nogales 87, portón negro',
          metodoPago: 'transferencia',
          fecha: _hoy(10, 2),
          lineas: <LineaPedido>[
            LineaPedido(balon: balon(3), cantidad: 1, precioVentaUnitario: 31900),
            LineaPedido(balon: balon(1), cantidad: 1, precioVentaUnitario: 8900),
          ],
        ),
        Pedido(
          id: 4108,
          estado: EstadoPedido.pendiente,
          origen: OrigenPedido.telefono,
          sector: 'Centenario',
          direccionEntrega: 'Avenida Centenario 455, depto 3B',
          metodoPago: 'efectivo',
          fecha: _hoy(10, 18),
          lineas: <LineaPedido>[
            LineaPedido(balon: balon(4), cantidad: 1, precioVentaUnitario: 79900),
          ],
        ),
      ];

  static List<Pedido> pedidosDeHoy() => <Pedido>[
        ...pedidosEnRuta(),
        Pedido(
          id: 4098,
          estado: EstadoPedido.entregado,
          origen: OrigenPedido.telefono,
          sector: 'Manso de Velasco',
          direccionEntrega: 'Calle Los Maitenes 220',
          metodoPago: 'efectivo',
          fecha: _hoy(8, 40),
          lineas: <LineaPedido>[
            LineaPedido(balon: balon(2), cantidad: 3, precioVentaUnitario: 22900),
          ],
        ),
        Pedido(
          id: 4099,
          estado: EstadoPedido.entregado,
          origen: OrigenPedido.tarreo,
          direccionEntrega: 'Tarreo / venta directa en camión',
          metodoPago: 'efectivo',
          fecha: _hoy(9, 5),
          lineas: <LineaPedido>[
            LineaPedido(balon: balon(1), cantidad: 2, precioVentaUnitario: 8900),
          ],
        ),
        Pedido(
          id: 4100,
          estado: EstadoPedido.cancelado,
          origen: OrigenPedido.telefono,
          sector: 'Grecia',
          direccionEntrega: 'Pasaje Grecia 12',
          metodoPago: 'efectivo',
          fecha: _hoy(9, 32),
          lineas: <LineaPedido>[
            LineaPedido(balon: balon(3), cantidad: 1, precioVentaUnitario: 31900),
          ],
        ),
      ];

  static DateTime _hoy(int hora, int minuto) {
    final DateTime ahora = DateTime.now();
    return DateTime(ahora.year, ahora.month, ahora.day, hora, minuto);
  }
}
