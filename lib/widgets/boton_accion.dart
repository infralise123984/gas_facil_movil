import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum EstiloBoton { primario, exito, peligro, advertencia, secundario, contorno }

/// Botón de acción a ancho completo.
///
/// Espeja los `btn btn-lg w-100 py-4` de la PWA: alto, texto en mayúsculas
/// y pensado para tocarse con guantes o a pleno sol.
class BotonAccion extends StatelessWidget {
  const BotonAccion({
    super.key,
    required this.etiqueta,
    required this.icono,
    required this.onPressed,
    this.estilo = EstiloBoton.primario,
  });

  final String etiqueta;
  final IconData icono;
  final VoidCallback onPressed;
  final EstiloBoton estilo;

  Color get _color => switch (estilo) {
    EstiloBoton.primario => ColoresApp.primario,
    EstiloBoton.exito => ColoresApp.exito,
    EstiloBoton.peligro => ColoresApp.peligro,
    EstiloBoton.advertencia => ColoresApp.advertencia,
    EstiloBoton.secundario => ColoresApp.secundario,
    EstiloBoton.contorno => ColoresApp.secundario,
  };

  Color get _colorTexto {
    if (estilo == EstiloBoton.contorno) {
      return ColoresApp.secundario;
    }
    return estilo == EstiloBoton.advertencia ? Colors.black87 : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle estiloTexto = TextStyle(
      fontSize: MedidasApp.tamanoTextoBoton,
      fontWeight: FontWeight.bold,
      color: _colorTexto,
    );

    final Widget contenido = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Icon(icono, size: 28, color: _colorTexto),
        const SizedBox(width: 10),
        Flexible(
          child: Text(etiqueta, textAlign: TextAlign.center, style: estiloTexto),
        ),
      ],
    );

    return SizedBox(
      width: double.infinity,
      height: MedidasApp.alturaBotonGrande,
      child: estilo == EstiloBoton.contorno
          ? OutlinedButton(
              onPressed: onPressed,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: ColoresApp.secundario, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: contenido,
            )
          : FilledButton(
              onPressed: onPressed,
              style: FilledButton.styleFrom(
                backgroundColor: _color,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: contenido,
            ),
    );
  }
}
