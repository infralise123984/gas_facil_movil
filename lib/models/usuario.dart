/// Usuario autenticado, tal como lo entrega `serializar_usuario` del API.
///
/// Solo los campos que el contrato expone: el servidor nunca manda secretos.
class Usuario {
  const Usuario({
    required this.id,
    required this.username,
    required this.nombre,
    required this.rol,
    required this.rolEtiqueta,
    required this.totpActivo,
  });

  factory Usuario.desdeJson(Map<String, dynamic> json) => Usuario(
    id: json['id'] as int,
    username: json['username'] as String,
    nombre: json['nombre'] as String,
    rol: json['rol'] as String,
    rolEtiqueta: json['rol_etiqueta'] as String,
    totpActivo: json['totp_activo'] as bool,
  );

  final int id;
  final String username;
  final String nombre;
  final String rol;
  final String rolEtiqueta;
  final bool totpActivo;

  /// Solo el camionero usa esta app: cualquier otro rol es un error de datos.
  bool get esCamionero => rol == 'camionero';

  @override
  String toString() => 'Usuario($id, $username, $rol)';
}
