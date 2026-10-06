import 'package:flutter/material.dart';

/// Colores espejo de la PWA (Bootstrap 5 en `base.html`).
///
/// Ver docs/PLAN_APP_CAMIONERO.md, sección 2.1: la app replica la interfaz
/// existente, no diseña una nueva.
class ColoresApp {
  const ColoresApp._();

  static const Color primario = Color(0xFF0D6EFD);
  static const Color exito = Color(0xFF198754);
  static const Color peligro = Color(0xFFDC3545);
  static const Color advertencia = Color(0xFFFFC107);
  static const Color info = Color(0xFF0DCAF0);
  static const Color secundario = Color(0xFF6C757D);
  static const Color grisClaro = Color(0xFFF1F3F5);
}

/// Medidas pensadas para uso en la calle: texto grande y zonas táctiles amplias.
class MedidasApp {
  const MedidasApp._();

  /// Ancho máximo del contenido, igual que los templates de la PWA.
  static const double anchoMaximoContenido = 540;

  static const double alturaBotonGrande = 68;
  static const double tamanoTextoBoton = 18;
  static const double tamanoTextoPedido = 22;
  static const double alturaBarraInferior = 68;
}

ThemeData construirTema() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: ColoresApp.primario),
    scaffoldBackgroundColor: Colors.white,
  );

  return base.copyWith(
    textTheme: base.textTheme.apply(fontSizeFactor: 1.05),
    appBarTheme: const AppBarTheme(
      backgroundColor: ColoresApp.primario,
      foregroundColor: Colors.white,
      centerTitle: true,
      titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
    ),
  );
}
