class EscaleModel {
  final int id;
  final String nom;
  final double? lat;
  final double? lng;
  final int ordre;
  final String? heurePrevue;
  final String? heureReelle;
  final String statut;

  const EscaleModel({
    required this.id,
    required this.nom,
    this.lat,
    this.lng,
    required this.ordre,
    this.heurePrevue,
    this.heureReelle,
    this.statut = 'en_attente',
  });

  factory EscaleModel.fromJson(Map<String, dynamic> json) {
    return EscaleModel(
      id: json['id'] as int,
      nom: json['nom'] as String? ?? '',
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      ordre: json['ordre'] as int? ?? 0,
      heurePrevue: json['heure_prevue'] as String?,
      heureReelle: json['heure_reelle'] as String?,
      statut: json['statut'] as String? ?? 'en_attente',
    );
  }

  bool get isArrive => statut == 'arrive';
  bool get isParti => statut == 'parti';
}
