import 'package:flutter/material.dart';

import 'screens/entregas_screen.dart';
import 'screens/inicio_screen.dart';
import 'screens/mis_entregas_screen.dart';
import 'screens/tarreo_screen.dart';
import 'theme/app_theme.dart';
import 'widgets/barra_navegacion.dart';

/// Aplicación Kim Gas para el camionero.
///
/// Extensión del sistema web existente: replica su interfaz y flujo, y no
/// agrega pantallas ni funciones que la web no tenga.
/// Ver docs/PLAN_APP_CAMIONERO.md, secciones 2.1 y 15.
class AppGasFacil extends StatelessWidget {
  const AppGasFacil({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kim Gas',
      debugShowCheckedModeBanner: false,
      theme: construirTema(),
      home: const PantallaCamionero(),
    );
  }
}

/// Contenedor con la barra inferior de cuatro destinos.
///
/// Mismos destinos y mismo orden que la barra de `base.html`.
class PantallaCamionero extends StatefulWidget {
  const PantallaCamionero({super.key});

  @override
  State<PantallaCamionero> createState() => _PantallaCamioneroState();
}

class _PantallaCamioneroState extends State<PantallaCamionero> {
  int _indice = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kim Gas'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Perfil',
            icon: const Icon(Icons.account_circle),
            onPressed: () {
              // TODO(api): "Mi perfil" y "Cerrar sesión" llegan con la API (F1).
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Mi perfil llega con la API (F1).',
                      style: TextStyle(fontSize: 16)),
                ),
              );
            },
          ),
        ],
      ),
      body: IndexedStack(
        index: _indice,
        children: <Widget>[
          InicioScreen(onIrAPestana: _cambiarPestana),
          const EntregasScreen(),
          const MisEntregasScreen(),
          const TarreoScreen(),
        ],
      ),
      bottomNavigationBar: BarraNavegacionCamionero(
        indice: _indice,
        onCambiar: _cambiarPestana,
      ),
    );
  }

  void _cambiarPestana(int nuevoIndice) {
    setState(() => _indice = nuevoIndice);
  }
}
