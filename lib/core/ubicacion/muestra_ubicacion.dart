/// Una posición del camión, tal como viaja al servidor.
///
/// El servidor valida todo de nuevo (`mockups/api/ubicacion.py`): acá solo se
/// arma el JSON. El teléfono no es autoridad sobre la jornada ni sobre lo que
/// significa una muestra válida.
class MuestraUbicacion {
  const MuestraUbicacion({
    required this.lat,
    required this.lng,
    required this.capturadoEl,
    this.precisionM,
    this.velocidad,
    this.bateria,
  });

  factory MuestraUbicacion.desdeJson(Map<String, dynamic> json) {
    return MuestraUbicacion(
      lat: (json['lat'] as num).toDouble(),
      lng: (json['lng'] as num).toDouble(),
      capturadoEl: DateTime.parse(json['capturado_el'] as String),
      precisionM: (json['precision_m'] as num?)?.toDouble(),
      velocidad: (json['velocidad'] as num?)?.toDouble(),
      bateria: (json['bateria'] as num?)?.toInt(),
    );
  }

  final double lat;
  final double lng;

  /// Cuándo se tomó la muestra, según el reloj del teléfono.
  final DateTime capturadoEl;

  /// Error estimado en metros. El servidor descarta las muestras malas con esto:
  /// una lectura de 500 m de error inventaría un movimiento que no ocurrió.
  final double? precisionM;

  final double? velocidad;

  /// Batería del teléfono (0-100). Sirve para distinguir "se quedó quieto" de
  /// "se le apagó el teléfono".
  final int? bateria;

  /// JSON con las claves que espera el contrato (§7.8).
  ///
  /// El momento va en UTC con `Z`: así el servidor no tiene que adivinar la zona
  /// del teléfono.
  Map<String, dynamic> aJson() {
    return <String, dynamic>{
      'lat': lat,
      'lng': lng,
      'capturado_el': capturadoEl.toUtc().toIso8601String(),
      if (precisionM != null) 'precision_m': precisionM,
      if (velocidad != null) 'velocidad': velocidad,
      if (bateria != null) 'bateria': bateria,
    };
  }
}
