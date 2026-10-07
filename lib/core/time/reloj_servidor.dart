/// Reloj del servidor.
///
/// La app **no** muestra la hora del teléfono: el camionero trabaja contra la
/// hora del servidor, y un teléfono con la zona mal puesta mostraría una jornada
/// que no es la suya (en este entorno llegaron a verse 3 horas de diferencia).
///
/// Cada respuesta del API trae `servidor_ahora` (docs/API_MOVIL.md §5.1). Se
/// guarda el desfase contra el reloj del teléfono y se sigue contando con él.
///
/// Se comparan **horas de pared**: se descarta el desfase del ISO y se resta
/// contra la hora local del teléfono. Así el resultado es correcto aunque el
/// teléfono esté configurado en otra zona horaria, que es justo el caso que
/// motivó esta clase.
class RelojServidor {
  Duration _desfase = Duration.zero;
  bool _sincronizado = false;

  /// `true` cuando ya llegó la hora de una respuesta del servidor.
  bool get sincronizado => _sincronizado;

  /// Hora del servidor, avanzada con el reloj del teléfono desde la última
  /// sincronización.
  DateTime get ahora => DateTime.now().add(_desfase);

  /// Toma la hora del servidor de una respuesta. Nunca lanza: si el formato no
  /// es el esperado, se sigue con el reloj del teléfono.
  void sincronizar(String servidorAhora) {
    final String horaDePared = servidorAhora.length > 19
        ? servidorAhora.substring(0, 19)
        : servidorAhora;

    final DateTime delServidor;
    try {
      delServidor = DateTime.parse(horaDePared);
    } on FormatException {
      return;
    }

    _desfase = delServidor.difference(DateTime.now());
    _sincronizado = true;
  }
}
