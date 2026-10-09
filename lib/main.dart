import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    // En Android la configuración viene de android/app/google-services.json, que
    // aplica el plugin de Gradle: no hay opciones que pasar acá.
    await Firebase.initializeApp();
  } catch (error) {
    // Sin Firebase la app funciona igual: lo único que se pierde es el aviso con
    // la app cerrada. Un problema de notificaciones no puede dejar al camionero
    // sin ver sus pedidos.
    debugPrint('FIREBASE_INIT_FALLIDO | $error');
  }
  runApp(const AppGasFacil());
}
