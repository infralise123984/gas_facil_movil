import 'package:flutter/material.dart';

/// Confirmación previa a una acción sobre un pedido.
///
/// Réplica del modal `#modalAccionEntrega` de la PWA (`camionero_entregas.html`),
/// que exige confirmar antes de tomar, entregar, cancelar o devolver.
Future<bool> confirmarAccion(
  BuildContext context, {
  required String titulo,
  required String cuerpo,
  required Color color,
  required String textoConfirmar,
}) async {
  final bool? resultado = await showDialog<bool>(
    context: context,
    builder: (BuildContext contextoDialogo) => AlertDialog(
      title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold)),
      content: Text(cuerpo, style: const TextStyle(fontSize: 17)),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(contextoDialogo).pop(false),
          child: const Text('Volver', style: TextStyle(fontSize: 16)),
        ),
        FilledButton(
          onPressed: () => Navigator.of(contextoDialogo).pop(true),
          style: FilledButton.styleFrom(backgroundColor: color),
          child: Text(textoConfirmar, style: const TextStyle(fontSize: 16)),
        ),
      ],
    ),
  );

  return resultado ?? false;
}

/// Aviso temporal. En la maqueta informa que la acción todavía no llama a la API.
void mostrarAviso(BuildContext context, String mensaje) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(mensaje, style: const TextStyle(fontSize: 16)),
      duration: const Duration(seconds: 3),
    ),
  );
}
