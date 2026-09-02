class RegistroOrdeno {
  final int? id;
  final int vacaId;
  final String fecha;
  final String hora;
  final double litros;
  final int sincronizado;

  RegistroOrdeno({
    this.id,
    required this.vacaId,
    required this.fecha,
    required this.hora,
    required this.litros,
    required this.sincronizado,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vacaId': vacaId,
      'fecha': fecha,
      'hora': hora,
      'litros': litros,
      'sincronizado': sincronizado,
    };
  }

  factory RegistroOrdeno.fromMap(Map<String, dynamic> map) {
    return RegistroOrdeno(
      id: map['id'] != null ? map['id'] as int : null,
      vacaId: map['vacaId'] as int,
      fecha: map['fecha'] as String,
      hora: map['hora'] as String,
      litros: map['litros'] as double,
      sincronizado: map['sincronizado'] as int,
    );
  }
}
