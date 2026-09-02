class Vaca {
  final int? id;
  final String numero;
  final String nombre;
  final String raza;

  Vaca({
    this.id,
    required this.numero,
    required this.nombre,
    required this.raza,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'numero': numero,
      'nombre': nombre,
      'raza': raza,
    };
  }

  factory Vaca.fromMap(Map<String, dynamic> map) {
    return Vaca(
      id: map['id'] != null ? map['id'] as int : null,
      numero: map['numero'] as String,
      nombre: map['nombre'] as String,
      raza: map['raza'] as String,
    );
  }
}
