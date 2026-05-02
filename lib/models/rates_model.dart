class Rates {
  final double bcv;
  final double usdt;
  final double eur;
  final DateTime updatedAt;
  final Map<String, String> sources;

  const Rates({
    required this.bcv,
    required this.usdt,
    required this.eur,
    required this.updatedAt,
    required this.sources,
  });

  factory Rates.fromJson(Map<String, dynamic> json) {
    return Rates(
      bcv: (json['bcv'] as num).toDouble(),
      usdt: (json['usdt'] as num).toDouble(),
      eur: (json['eur'] as num).toDouble(),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      sources: Map<String, String>.from(json['sources'] as Map),
    );
  }

  Map<String, dynamic> toJson() => {
        'bcv': bcv,
        'usdt': usdt,
        'eur': eur,
        'updated_at': updatedAt.toIso8601String(),
        'sources': sources,
      };

  // Edad de los datos en minutos
  int get ageMinutes => DateTime.now().difference(updatedAt).inMinutes;

  // Estado para el dot de la UI
  DataStatus get status {
    if (ageMinutes < 15) return DataStatus.fresh;
    if (ageMinutes < 360) return DataStatus.stale;
    return DataStatus.old;
  }
}

enum DataStatus { fresh, stale, old }
