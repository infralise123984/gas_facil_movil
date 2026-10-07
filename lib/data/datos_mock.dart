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
    TipoBalon(
      id: 2,
      nombre: 'Gas 11 kg',
      pesoNetoKg: 11,
      precioDomicilio: 22900,
      precioLocal: 21500,
    ),
    TipoBalon(
      id: 3,
      nombre: 'Gas 15 kg',
      pesoNetoKg: 15,
      precioDomicilio: 31900,
      precioLocal: 30500,
    ),
    TipoBalon(
      id: 4,
      nombre: 'Gas 45 kg',
      pesoNetoKg: 45,
      precioDomicilio: 79900,
      precioLocal: 78000,
    ),
    TipoBalon(
      id: 5,
      nombre: 'Catalítico 5 kg',
      pesoNetoKg: 5,
      precioDomicilio: 12400,
      precioLocal: 11900,
    ),
  ];

  static TipoBalon balon(int id) => balones.firstWhere((TipoBalon b) => b.id == id);
}
