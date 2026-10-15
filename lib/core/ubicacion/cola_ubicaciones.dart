import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'muestra_ubicacion.dart';

/// Guarda las posiciones que todavía no llegaron al servidor.
///
/// Sin esto se pierden justo las muestras que importan: cuando el camión entra a
/// un pasaje sin señal no hay dónde acumular, y el hueco que queda en la
/// bitácora es precisamente el rato que se quiere revisar. Un pasaje sin señal
/// son unas pocas decenas de muestras, así que el volumen es trivial.
///
/// El tope evita que una app sin red durante días crezca sin límite. Al
/// desbordar se descartan las **más viejas**: si no se pudo enviar durante
/// tanto tiempo, lo reciente es lo que sirve.

class ColaUbicaciones {
  const ColaUbicaciones();

  static const String _clave = 'cola_ubicaciones';
  static const int tope = 240;

  Future<List<MuestraUbicacion>> leer() async {
    final prefs = await SharedPreferences.getInstance();
    return _decodificar(prefs.getStringList(_clave));
  }

  /// Agrega una muestra y devuelve el tamaño resultante de la cola.
  Future<int> agregar(MuestraUbicacion muestra) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> crudas = prefs.getStringList(_clave) ?? <String>[];
    crudas.add(jsonEncode(muestra.aJson()));

    final List<String> recortadas = crudas.length > tope
        ? crudas.sublist(crudas.length - tope)
        : crudas;

    await prefs.setStringList(_clave, recortadas);
    return recortadas.length;
  }

  /// Deja en la cola solo lo que no se pudo enviar.
  ///
  /// Se guarda lo pendiente en vez de vaciar: si el envío falló a medias, lo que
  /// no entró se reintenta en el próximo ciclo.
  Future<void> dejarPendientes(List<MuestraUbicacion> pendientes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _clave,
      pendientes.map((muestra) => jsonEncode(muestra.aJson())).toList(),
    );
  }

  /// Vacía la cola. Se usa al cerrar sesión: esas muestras pertenecen a una
  /// jornada que ya terminó y subirlas después sería reportar fuera de hora.
  Future<void> limpiar() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_clave);
  }

  List<MuestraUbicacion> _decodificar(List<String>? crudas) {
    if (crudas == null || crudas.isEmpty) {
      return <MuestraUbicacion>[];
    }
    final List<MuestraUbicacion> muestras = <MuestraUbicacion>[];
    for (final String cruda in crudas) {
      try {
        muestras.add(MuestraUbicacion.desdeJson(jsonDecode(cruda) as Map<String, dynamic>));
      } catch (error) {
        // Una entrada corrupta no puede tumbar la cola entera: se descarta sola.
        debugPrint('UBICACION_COLA_DESCARTE | $error');
      }
    }
    return muestras;
  }
}
