class Intervencion {
  final String fecha;
  final String numero;
  final double tasaEurBs;
  final DateTime updatedAt;

  const Intervencion({
    required this.fecha,
    required this.numero,
    required this.tasaEurBs,
    required this.updatedAt,
  });

  factory Intervencion.fromJson(Map<String, dynamic> json) {
    return Intervencion(
      fecha: json['fecha'] as String,
      numero: json['numero'] as String,
      tasaEurBs: (json['tasa_eur_bs'] as num).toDouble(),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'fecha': fecha,
        'numero': numero,
        'tasa_eur_bs': tasaEurBs,
        'updated_at': updatedAt.toIso8601String(),
      };
}
