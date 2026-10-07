import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/config/api_config.dart';
import '../core/error/error_api.dart';
import '../core/storage/almacen_sesion.dart';
import '../models/pedido.dart';
import '../models/resumen_entregas.dart';
import '../models/usuario.dart';

/// Resultado de un intento de inicio de sesión.
///
/// El contrato (§6.1) trata el `202 requiere_2fa` como un caso legítimo, no
/// como un error: por eso se modela explícitamente en vez de lanzar.
sealed class ResultadoLogin {
  const ResultadoLogin();
}

class LoginCorrecto extends ResultadoLogin {
  const LoginCorrecto(this.usuario);

  final Usuario usuario;
}

class LoginRequiereSegundoFactor extends ResultadoLogin {
  const LoginRequiereSegundoFactor();
}

/// Cliente del API v1 del camionero.
///
/// Responsabilidad única: hablar HTTP con el servidor y aplicar el sobre del
/// contrato (§5). No conoce la interfaz ni el negocio.
///
/// Guarda las cookies de sesión a mano porque `package:http` no las persiste y
/// el API usa la sesión de Django, no tokens (§6.1). Además el servidor marca
/// las cookies como `Secure`; al viajar por HTTP en el desarrollo por USB, un
/// gestor estándar las descartaría y el doble envío CSRF fallaría.
class ApiCliente {
  ApiCliente({required this.config, http.Client? clienteHttp, AlmacenSesion? almacen})
    : _http = clienteHttp ?? http.Client(),
      _almacenSesion = almacen ?? AlmacenSesionSeguro();

  final ApiConfig config;
  final http.Client _http;

  /// Dónde vive la credencial de sesión entre arranques de la app.
  final AlmacenSesion _almacenSesion;

  static const String rutaCsrf = '/api/v1/auth/csrf/';
  static const String rutaLogin = '/api/v1/auth/login/';
  static const String rutaLogout = '/api/v1/auth/logout/';
  static const String rutaPerfil = '/api/v1/auth/perfil/';
  static const String rutaEntregas = '/api/v1/entregas/';
  static const String rutaTarreo = '/api/v1/tarreo/';
  static const String rutaBalones = '/api/v1/balones/';

  /// Cookie de sesión de Django: es la credencial que se guarda.
  static const String _cookieSesion = 'sessionid';

  static const Duration _tiempoLimite = Duration(seconds: 20);

  final Map<String, String> _cookies = <String, String>{};

  void cerrar() => _http.close();

  /// Pide el token CSRF y siembra la cookie.
  ///
  /// Sin esto no hay forma de hacer el primer POST: el resto del API exige
  /// sesión, así que la app no tendría de dónde sacar el token (§6.1).
  Future<String> obtenerTokenCsrf() async {
    final Map<String, dynamic> sobre = await _enviar('GET', rutaCsrf);
    final Map<String, dynamic> datos = sobre['data'] as Map<String, dynamic>;
    return datos['csrf_token'] as String;
  }

  Future<ResultadoLogin> iniciarSesion({
    required String usuario,
    required String contrasena,
  }) async {
    final Map<String, dynamic> sobre = await _enviar(
      'POST',
      rutaLogin,
      cuerpo: <String, Object?>{'username': usuario, 'password': contrasena},
      exigeCsrf: true,
    );
    final Map<String, dynamic> datos = sobre['data'] as Map<String, dynamic>;

    if (datos['requiere_2fa'] == true) {
      return const LoginRequiereSegundoFactor();
    }

    // El servidor ya entregó su cookie de sesión: se guarda para no tener que
    // volver a escribir las credenciales en el próximo arranque.
    await _guardarCredencial();
    return LoginCorrecto(Usuario.desdeJson(datos['usuario'] as Map<String, dynamic>));
  }

  /// Recupera la sesión guardada, si la hay. Devuelve `false` si no había nada.
  ///
  /// Recuperar no es autenticar: hay que confirmarlo contra `/auth/perfil/`,
  /// porque el servidor la vence a las 48 h (`SESSION_COOKIE_AGE`).
  Future<bool> restaurarSesion() async {
    final String? sesion = await _almacenSesion.leer();
    if (sesion == null || sesion.isEmpty) {
      return false;
    }
    _cookies[_cookieSesion] = sesion;
    return true;
  }

  /// Descarta la credencial guardada. Se usa al cerrar sesión y cuando el
  /// servidor rechaza la que estaba guardada.
  Future<void> olvidarSesion() async {
    _cookies.clear();
    await _almacenSesion.borrar();
  }

  Future<void> _guardarCredencial() async {
    final String? sesion = _cookies[_cookieSesion];
    if (sesion != null && sesion.isNotEmpty) {
      await _almacenSesion.guardar(sesion);
    }
  }

  /// Identidad de la sesión abierta. También devuelve un token CSRF fresco.
  Future<Usuario> perfil() async {
    final Map<String, dynamic> sobre = await _enviar('GET', rutaPerfil);
    final Map<String, dynamic> datos = sobre['data'] as Map<String, dynamic>;
    return _mapear(() => Usuario.desdeJson(datos['usuario'] as Map<String, dynamic>));
  }

  /// Panel del camionero: pendientes disponibles, las que van en ruta y las ya
  /// entregadas hoy (§7.1).
  Future<ResumenEntregas> listarEntregas() async {
    final Map<String, dynamic> sobre = await _enviar('GET', rutaEntregas);
    return _mapear(() => ResumenEntregas.desdeJson(sobre['data'] as Map<String, dynamic>));
  }

  /// Las cuatro acciones del §7.3. Devuelven el pedido ya actualizado.
  Future<Pedido> tomarPedido(int pedidoId) => _accion('tomar', pedidoId);

  Future<Pedido> entregarPedido(int pedidoId) => _accion('entregar', pedidoId);

  Future<Pedido> cancelarPedido(int pedidoId) => _accion('cancelar', pedidoId);

  Future<Pedido> devolverPedido(int pedidoId) => _accion('devolver', pedidoId);

  Future<Pedido> _accion(String accion, int pedidoId) async {
    final Map<String, dynamic> sobre = await _enviar(
      'POST',
      '$rutaEntregas$pedidoId/$accion/',
      cuerpo: const <String, Object?>{},
      exigeCsrf: true,
    );
    final Map<String, dynamic> datos = sobre['data'] as Map<String, dynamic>;
    return _mapear(() => Pedido.desdeJson(datos['pedido'] as Map<String, dynamic>));
  }

  /// Catálogo vigente de balones (§7.5).
  ///
  /// Es la fuente de los precios del tarreo: la app los muestra y **no** los
  /// manda al servidor, que vuelve a calcular el total por su cuenta.
  Future<List<TipoBalon>> listarBalones() async {
    final Map<String, dynamic> sobre = await _enviar('GET', rutaBalones);
    return _mapear(
      () => (sobre['data'] as List<dynamic>)
          .map((dynamic balon) => TipoBalon.desdeJson(balon as Map<String, dynamic>))
          .toList(growable: false),
    );
  }

  /// Venta en la calle (§7.4). Devuelve el pedido ya creado y entregado.
  ///
  /// Solo viajan balón y cantidad: el precio y los totales los pone el
  /// servidor, para que el teléfono no pueda vender a un precio inventado. Una
  /// dirección vacía queda con la que define el contrato.
  Future<Pedido> registrarVentaTarreo({
    required Map<int, int> cantidades,
    required String metodoPago,
    String direccion = '',
  }) async {
    final Map<String, dynamic> sobre = await _enviar(
      'POST',
      rutaTarreo,
      cuerpo: <String, Object?>{
        'metodo_pago': metodoPago,
        'direccion_entrega': direccion,
        'lineas': <Map<String, Object?>>[
          for (final MapEntry<int, int> linea in cantidades.entries)
            <String, Object?>{'balon_id': linea.key, 'cantidad': linea.value},
        ],
      },
      exigeCsrf: true,
    );
    final Map<String, dynamic> datos = sobre['data'] as Map<String, dynamic>;
    return _mapear(() => Pedido.desdeJson(datos['pedido'] as Map<String, dynamic>));
  }

  Future<void> cerrarSesion() async {
    try {
      await _enviar('POST', rutaLogout, cuerpo: const <String, Object?>{}, exigeCsrf: true);
    } finally {
      // Aunque el servidor no responda, la credencial guardada se borra: el
      // camionero pidió salir y el teléfono no puede quedarse con la sesión.
      await olvidarSesion();
    }
  }

  Future<Map<String, dynamic>> _enviar(
    String metodo,
    String ruta, {
    Map<String, Object?>? cuerpo,
    bool exigeCsrf = false,
  }) async {
    final http.Request peticion = http.Request(metodo, config.urlDe(ruta));
    peticion.headers['Accept'] = 'application/json';

    if (cuerpo != null) {
      peticion.headers['Content-Type'] = 'application/json; charset=utf-8';
      peticion.body = jsonEncode(cuerpo);
    }
    if (exigeCsrf) {
      // Doble envío: cookie `csrftoken` + cabecera que coincida, y un `Origin`
      // que esté en CSRF_TRUSTED_ORIGINS.
      peticion.headers['Origin'] = config.origen;
      peticion.headers['X-CSRFToken'] = await obtenerTokenCsrf();
    }
    if (_cookies.isNotEmpty) {
      peticion.headers['Cookie'] = _cookies.entries
          .map((MapEntry<String, String> cookie) => '${cookie.key}=${cookie.value}')
          .join('; ');
    }

    final http.Response respuesta;
    try {
      respuesta = await http.Response.fromStream(await _http.send(peticion).timeout(_tiempoLimite));
    } on SocketException catch (error) {
      throw ErrorApi.sinConexion(error.message);
    } on http.ClientException catch (error) {
      throw ErrorApi.sinConexion(error.message);
    } on TimeoutException catch (error) {
      throw ErrorApi.sinConexion('${error.runtimeType}');
    }

    _guardarCookies(respuesta);
    return _interpretarSobre(respuesta);
  }

  /// Aplica el sobre del §5: si viene `error`, se lanza con su código estable.
  Map<String, dynamic> _interpretarSobre(http.Response respuesta) {
    final Map<String, dynamic> sobre = _decodificar(respuesta);

    final Object? error = sobre['error'];
    if (error is Map<String, dynamic>) {
      throw ErrorApi(
        codigo: error['codigo'] as String? ?? CodigosError.errorInterno,
        mensaje: error['mensaje'] as String? ?? 'Ocurrió un error inesperado.',
        status: respuesta.statusCode,
      );
    }
    return sobre;
  }

  Map<String, dynamic> _decodificar(http.Response respuesta) {
    try {
      final Object? decodificado = jsonDecode(utf8.decode(respuesta.bodyBytes));
      if (decodificado is Map<String, dynamic>) {
        return decodificado;
      }
    } on FormatException {
      // Se transforma abajo: no todo 403 trae el sobre. Un rechazo de CSRF lo
      // emite el middleware antes de llegar a la vista y devuelve HTML.
    }
    throw ErrorApi(
      codigo: CodigosError.respuestaIlegible,
      mensaje:
          'El servidor respondió de una forma que la app no entiende. '
          'Vuelve a iniciar sesión.',
      status: respuesta.statusCode,
      detalle: utf8.decode(respuesta.bodyBytes, allowMalformed: true),
    );
  }

  /// Convierte el JSON en objetos del dominio.
  ///
  /// Un `FormatException` o un casteo fallido significa que el servidor cambió
  /// el contrato. Se transforma en error de dominio para que la interfaz
  /// muestre un mensaje en vez de reventar.
  T _mapear<T>(T Function() construir) {
    try {
      return construir();
    } on FormatException catch (error) {
      throw ErrorApi(
        codigo: CodigosError.respuestaIlegible,
        mensaje:
            'El servidor respondió de una forma que la app no entiende. '
            'Actualiza la app o avisa al administrador.',
        status: 0,
        detalle: error.message,
      );
    } on TypeError catch (error) {
      throw ErrorApi(
        codigo: CodigosError.respuestaIlegible,
        mensaje:
            'El servidor respondió de una forma que la app no entiende. '
            'Actualiza la app o avisa al administrador.',
        status: 0,
        detalle: '$error',
      );
    }
  }

  /// Guarda, reemplaza o borra las cookies que devolvió el servidor.
  void _guardarCookies(http.Response respuesta) {
    final List<String> cabeceras = respuesta.headersSplitValues['set-cookie'] ?? const <String>[];

    for (final String cabecera in cabeceras) {
      final int finAtributos = cabecera.indexOf(';');
      final String par = finAtributos == -1 ? cabecera : cabecera.substring(0, finAtributos);
      final int separador = par.indexOf('=');
      if (separador <= 0) {
        continue;
      }
      final String nombre = par.substring(0, separador).trim();
      final String valor = par.substring(separador + 1).trim();
      if (valor.isEmpty) {
        _cookies.remove(nombre);
      } else {
        _cookies[nombre] = valor;
      }
    }
  }
}
