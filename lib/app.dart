import 'package:flutter/material.dart';

import 'core/config/api_config.dart';
import 'core/error/error_api.dart';
import 'data/api_cliente.dart';
import 'data/controlador_entregas.dart';
import 'models/usuario.dart';
import 'screens/entregas_screen.dart';
import 'screens/inicio_screen.dart';
import 'screens/login_screen.dart';
import 'screens/mis_entregas_screen.dart';
import 'screens/tarreo_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/barra_navegacion.dart';
import 'widgets/comunes.dart';
import 'widgets/dialogo_confirmacion.dart';

/// Aplicación Kim Gas para el camionero.
///
/// Extensión del sistema web existente: replica su interfaz y flujo, y no
/// agrega pantallas ni funciones que la web no tenga.
/// Ver docs/PLAN_APP_CAMIONERO.md, secciones 2.1 y 15.
class AppGasFacil extends StatefulWidget {
  const AppGasFacil({super.key});

  @override
  State<AppGasFacil> createState() => _AppGasFacilState();
}

class _AppGasFacilState extends State<AppGasFacil> {
  /// Un solo cliente para toda la app: es quien guarda las cookies de sesión.
  final ApiCliente _api = ApiCliente(config: ApiConfig.desdeEntorno());

  /// Un solo dueño de los datos del panel: las dos pantallas que los muestran
  /// leen de acá, así no se pisan ni quedan una más vieja que la otra.
  late final ControladorEntregas _entregas = ControladorEntregas(api: _api);

  Usuario? _usuario;
  bool _comprobandoSesion = true;

  /// Fallo de red al reabrir la sesión. La credencial **no** se borra en ese
  /// caso: se deja reintentar, porque el problema es la conexión, no la sesión.
  String? _falloDeArranque;

  @override
  void initState() {
    super.initState();
    _recuperarSesion();
  }

  @override
  void dispose() {
    _api.cerrar();
    _entregas.dispose();
    super.dispose();
  }

  /// Reabre la sesión guardada, si la hay, antes de mostrar el login.
  ///
  /// Tener la cookie no es estar autenticado: se confirma contra
  /// `/auth/perfil/`, porque el servidor la vence a las 48 h
  /// (`SESSION_COOKIE_AGE = 172800`).
  Future<void> _recuperarSesion() async {
    if (!await _api.restaurarSesion()) {
      if (mounted) {
        setState(() => _comprobandoSesion = false);
      }
      return;
    }

    try {
      final Usuario usuario = await _api.perfil();
      if (!usuario.esCamionero) {
        await _api.cerrarSesion();
        if (mounted) {
          setState(() => _comprobandoSesion = false);
        }
        return;
      }
      if (mounted) {
        setState(() {
          _usuario = usuario;
          _comprobandoSesion = false;
        });
      }
    } on ErrorApi catch (error) {
      // Sesión vencida o rechazada: se descarta y se pide login de nuevo.
      if (error.codigo != CodigosError.sinConexion) {
        await _api.olvidarSesion();
      }
      if (mounted) {
        setState(() {
          _comprobandoSesion = false;
          _falloDeArranque = error.codigo == CodigosError.sinConexion
              ? error.mensaje
              : null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kim Gas',
      debugShowCheckedModeBanner: false,
      theme: construirTema(),
      home: _pantallaInicial(),
    );
  }

  Widget _pantallaInicial() {
    if (_comprobandoSesion) {
      return const Scaffold(
        body: CuerpoPantalla(
          children: <Widget>[PantallaCargando(mensaje: 'Comprobando tu sesión…')],
        ),
      );
    }

    final String? fallo = _falloDeArranque;
    if (fallo != null) {
      return Scaffold(
        body: CuerpoPantalla(
          children: <Widget>[
            PantallaError(mensaje: fallo, onReintentar: _reintentarArranque),
          ],
        ),
      );
    }

    final Usuario? usuario = _usuario;
    if (usuario == null) {
      return LoginScreen(api: _api, onSesionIniciada: _iniciarSesion);
    }
    return PantallaCamionero(
      api: _api,
      entregas: _entregas,
      usuario: usuario,
      onSesionCerrada: _cerrarSesion,
    );
  }

  void _reintentarArranque() {
    setState(() {
      _falloDeArranque = null;
      _comprobandoSesion = true;
    });
    _recuperarSesion();
  }

  void _iniciarSesion(Usuario usuario) => setState(() => _usuario = usuario);

  void _cerrarSesion() {
    // Los pedidos son del camionero que se va: no pueden quedar a la vista del
    // siguiente que use el teléfono.
    _entregas.limpiar();
    setState(() => _usuario = null);
  }
}

/// Contenedor con la barra inferior de cuatro destinos.
///
/// Mismos destinos y mismo orden que la barra de `base.html`.
class PantallaCamionero extends StatefulWidget {
  const PantallaCamionero({
    super.key,
    required this.api,
    required this.entregas,
    required this.usuario,
    required this.onSesionCerrada,
  });

  final ApiCliente api;
  final ControladorEntregas entregas;
  final Usuario usuario;
  final VoidCallback onSesionCerrada;

  @override
  State<PantallaCamionero> createState() => _PantallaCamioneroState();
}

class _PantallaCamioneroState extends State<PantallaCamionero> with WidgetsBindingObserver {
  int _indice = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.entregas.cargar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Al volver del bloqueo o del segundo plano se recarga.
  ///
  /// Con la pantalla apagada Flutter deja de dibujar: la lista que se ve al
  /// desbloquear puede ser de antes.
  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) {
      widget.entregas.cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kim Gas'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Perfil',
            icon: const Icon(Icons.account_circle),
            onPressed: _mostrarPerfil,
          ),
        ],
      ),
      body: IndexedStack(
        index: _indice,
        children: <Widget>[
          InicioScreen(onIrAPestana: _cambiarPestana, nombreUsuario: widget.usuario.nombre),
          EntregasScreen(api: widget.api, controlador: widget.entregas),
          MisEntregasScreen(controlador: widget.entregas),
          const TarreoScreen(),
        ],
      ),
      bottomNavigationBar: BarraNavegacionCamionero(indice: _indice, onCambiar: _cambiarPestana),
    );
  }

  void _cambiarPestana(int nuevoIndice) {
    setState(() => _indice = nuevoIndice);

    // Las dos pestañas que muestran pedidos se recargan al entrar: si no, al
    // volver a una de ellas se vería la lista de la última vez que se cargó.
    if (nuevoIndice == 1 || nuevoIndice == 2) {
      widget.entregas.cargar();
    }
  }

  /// Confirma y cierra la sesión. El servidor es la fuente de verdad, pero si
  /// no responde se cierra igual en el teléfono: el camionero no puede quedar
  /// atrapado dentro de la app.
  Future<void> _mostrarPerfil() async {
    final bool salir = await confirmarAccion(
      context,
      titulo: 'Cerrar sesión',
      cuerpo:
          '${widget.usuario.nombre} · ${widget.usuario.rolEtiqueta}\n\n'
          '¿Quieres cerrar la sesión?',
      color: ColoresApp.peligro,
      textoConfirmar: 'Sí, cerrar sesión',
    );
    if (!salir || !mounted) {
      return;
    }

    try {
      await widget.api.cerrarSesion();
    } on ErrorApi catch (error) {
      debugPrint('LOGOUT_API_FALLIDO | ${error.codigo} | ${error.detalle ?? ''}');
    }
    if (!mounted) {
      return;
    }
    widget.onSesionCerrada();
  }
}
