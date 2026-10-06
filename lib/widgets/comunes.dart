import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Contenedor base de todas las pantallas del camionero.
///
/// Reproduce el layout de la PWA: una sola columna, ancho máximo de 540 px,
/// con scroll y aire suficiente para dedos grandes.
class CuerpoPantalla extends StatelessWidget {
  const CuerpoPantalla({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      child: Center(
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: MedidasApp.anchoMaximoContenido),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Título de pantalla con ícono, igual que los `h2` de la PWA.
class TituloPantalla extends StatelessWidget {
  const TituloPantalla({
    super.key,
    required this.icono,
    required this.texto,
    this.color = ColoresApp.primario,
  });

  final IconData icono;
  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icono, size: 30, color: color),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              texto,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Encabezado de sección: "En Ruta (1)", "Pendientes (2)".
class EncabezadoSeccion extends StatelessWidget {
  const EncabezadoSeccion({super.key, required this.texto, required this.color});

  final String texto;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        texto,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}

/// Chip de contador: "2 pendientes • 1 en ruta".
class ContadorChip extends StatelessWidget {
  const ContadorChip({super.key, required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 14),
        decoration: BoxDecoration(
          color: ColoresApp.primario,
          borderRadius: BorderRadius.circular(40),
          boxShadow: const <BoxShadow>[
            BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
          ],
        ),
        child: Text(
          texto,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Estado vacío de la PWA: "Todo listo / No hay entregas pendientes…".
class EstadoVacio extends StatelessWidget {
  const EstadoVacio({
    super.key,
    this.titulo = 'Todo listo',
    this.mensaje = 'No hay entregas pendientes ni en ruta por ahora.',
  });

  final String titulo;
  final String mensaje;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        color: ColoresApp.grisClaro,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: <Widget>[
          const Icon(Icons.done_all, size: 54, color: ColoresApp.exito),
          const SizedBox(height: 14),
          Text(
            titulo,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, color: ColoresApp.secundario),
          ),
        ],
      ),
    );
  }
}

/// Aviso informativo, equivalente a los `alert` de Bootstrap.
class AvisoInfo extends StatelessWidget {
  const AvisoInfo({super.key, required this.texto, this.icono = Icons.info});

  final String texto;
  final IconData icono;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFCFE2FF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icono, color: ColoresApp.primario),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(fontSize: 16, color: Color(0xFF084298)),
            ),
          ),
        ],
      ),
    );
  }
}
