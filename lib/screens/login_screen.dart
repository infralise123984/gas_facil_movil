import 'package:flutter/material.dart';

import '../core/error/error_api.dart';
import '../data/api_cliente.dart';
import '../models/usuario.dart';
import '../theme/app_theme.dart';
import '../widgets/boton_accion.dart';
import '../widgets/comunes.dart';

/// Inicio de sesión del camionero.
///
/// Espejo de `auth/login.html`: mismo logo, mismos textos y misma disposición
/// de campos. La diferencia es que acá hay que resolver el doble envío CSRF,
/// cosa que la web obtiene gratis con la plantilla (`{% csrf_token %}`).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.api, required this.onSesionIniciada});

  final ApiCliente api;
  final ValueChanged<Usuario> onSesionIniciada;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usuario = TextEditingController();
  final TextEditingController _contrasena = TextEditingController();

  bool _enviando = false;
  bool _mostrarContrasena = false;
  bool _bloqueado = false;
  String? _error;
  String? _aviso;

  @override
  void dispose() {
    _usuario.dispose();
    _contrasena.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    final String usuario = _usuario.text.trim();
    final String contrasena = _contrasena.text;

    if (usuario.isEmpty || contrasena.isEmpty) {
      setState(() {
        _error = 'Escribe tu usuario y tu contraseña.';
        _aviso = null;
      });
      return;
    }

    setState(() {
      _enviando = true;
      _error = null;
      _aviso = null;
    });

    try {
      final ResultadoLogin resultado = await widget.api.iniciarSesion(
        usuario: usuario,
        contrasena: contrasena,
      );
      if (!mounted) {
        return;
      }

      switch (resultado) {
        case LoginRequiereSegundoFactor():
          setState(() {
            _enviando = false;
            _aviso =
                'Tu cuenta tiene verificación en dos pasos y esta app '
                'todavía no la soporta. Ingresa desde la web.';
          });
        case LoginCorrecto(:final Usuario usuario):
          await _continuarComoCamionero(usuario);
      }
    } on ErrorApi catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _enviando = false;
        _error = error.mensaje;
        // El contrato §6.1 es explícito: ante un bloqueo no se reintenta,
        // porque cada intento extiende la ventana de django-axes.
        _bloqueado = error.esBloqueoDeLogin;
      });
    }
  }

  /// Rechaza a quien no sea camionero: los endpoints de negocio exigen ese rol.
  Future<void> _continuarComoCamionero(Usuario usuario) async {
    if (usuario.esCamionero) {
      widget.onSesionIniciada(usuario);
      return;
    }

    // La sesión ya se abrió en el servidor: se cierra para no dejarla colgada.
    await widget.api.cerrarSesion();
    if (!mounted) {
      return;
    }
    setState(() {
      _enviando = false;
      _error =
          'Esta app es solo para camioneros. Tu rol es '
          '"${usuario.rolEtiqueta}".';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CuerpoPantalla(
        children: <Widget>[
          const SizedBox(height: 36),
          const _LogoKimGas(),
          const SizedBox(height: 18),
          const Text(
            'Iniciar sesión',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ingresa tus credenciales para continuar',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: ColoresApp.secundario),
          ),
          const SizedBox(height: 30),
          _CampoLogin(
            etiqueta: 'Usuario',
            icono: Icons.person,
            controlador: _usuario,
            pista: 'Nombre de usuario',
            autocompletado: <String>[AutofillHints.username],
            habilitado: !_enviando && !_bloqueado,
            onEnviar: _entrar,
          ),
          const SizedBox(height: 18),
          _CampoLogin(
            etiqueta: 'Contraseña',
            icono: Icons.lock,
            controlador: _contrasena,
            pista: 'Contraseña',
            autocompletado: <String>[AutofillHints.password],
            habilitado: !_enviando && !_bloqueado,
            onEnviar: _entrar,
            esContrasena: !_mostrarContrasena,
            accionFinal: IconButton(
              tooltip: _mostrarContrasena ? 'Ocultar contraseña' : 'Mostrar contraseña',
              icon: Icon(_mostrarContrasena ? Icons.visibility_off : Icons.visibility),
              onPressed: _enviando
                  ? null
                  : () => setState(() => _mostrarContrasena = !_mostrarContrasena),
            ),
          ),
          if (_aviso != null) ...<Widget>[
            const SizedBox(height: 20),
            AvisoInfo(texto: _aviso!, icono: Icons.info_outline),
          ],
          if (_error != null) ...<Widget>[
            const SizedBox(height: 20),
            _MensajeError(texto: _error!),
          ],
          const SizedBox(height: 26),
          if (_enviando)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 22),
                child: CircularProgressIndicator(),
              ),
            )
          else
            BotonAccion(
              etiqueta: 'Ingresar',
              icono: Icons.login,
              onPressed: _bloqueado ? () {} : _entrar,
            ),
          if (_bloqueado) ...<Widget>[
            const SizedBox(height: 14),
            const Text(
              'Espera antes de volver a intentarlo.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: ColoresApp.secundario),
            ),
          ],
        ],
      ),
    );
  }
}

/// Logo circular de la PWA: `bg-primary bg-opacity-10` con el ícono de fuego.
class _LogoKimGas extends StatelessWidget {
  const _LogoKimGas();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 88,
        height: 88,
        decoration: const BoxDecoration(
          // Azul primario al 10 % de opacidad, como `bg-opacity-10` de Bootstrap.
          color: Color(0x1A0D6EFD),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.local_fire_department, size: 46, color: ColoresApp.primario),
      ),
    );
  }
}

class _CampoLogin extends StatelessWidget {
  const _CampoLogin({
    required this.etiqueta,
    required this.icono,
    required this.controlador,
    required this.pista,
    required this.autocompletado,
    required this.habilitado,
    required this.onEnviar,
    this.esContrasena = false,
    this.accionFinal,
  });

  final String etiqueta;
  final IconData icono;
  final TextEditingController controlador;
  final String pista;
  final List<String> autocompletado;
  final bool habilitado;
  final VoidCallback onEnviar;
  final bool esContrasena;
  final Widget? accionFinal;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(etiqueta, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: controlador,
          enabled: habilitado,
          obscureText: esContrasena,
          // `autocorrect: false` + `enableSuggestions: false` dejan el campo en
          // modo "sin sugerencias", y el teclado de Samsung responde apagando la
          // tecla Mayús: la credencial con mayúsculas no se puede escribir.
          // `visiblePassword` es el tipo que Flutter recomienda para credenciales
          // (no capitaliza ni sugiere) y conserva el Shift. No afecta a
          // `obscureText`: lo que se ve en pantalla sigue igual.
          keyboardType: TextInputType.visiblePassword,
          autocorrect: false,
          enableSuggestions: false,
          textInputAction: TextInputAction.next,
          autofillHints: autocompletado,
          onSubmitted: (_) => onEnviar(),
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(
            hintText: pista,
            prefixIcon: Icon(icono, color: ColoresApp.secundario),
            suffixIcon: accionFinal,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          ),
        ),
      ],
    );
  }
}

/// Bloque de error visible para el usuario: borde y fondo rojos, texto oscuro.
class _MensajeError extends StatelessWidget {
  const _MensajeError({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0x1ADC3545),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ColoresApp.peligro),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.error_outline, color: ColoresApp.peligro, size: 26),
          const SizedBox(width: 12),
          Expanded(
            child: Text(texto, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
