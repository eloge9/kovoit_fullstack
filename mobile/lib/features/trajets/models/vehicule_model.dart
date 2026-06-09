class VehiculeModel {
  final int id;
  final String typeVehicule;
  final String marque;
  final String modele;
  final String couleur;
  final String plaque;
  final int placesMax;
  final bool actif;
  final String? photo;

  const VehiculeModel({
    required this.id,
    required this.typeVehicule,
    required this.marque,
    required this.modele,
    required this.couleur,
    required this.plaque,
    required this.placesMax,
    this.actif = true,
    this.photo,
  });

  factory VehiculeModel.fromJson(Map<String, dynamic> json) {
    return VehiculeModel(
      id: json['id'] as int,
      typeVehicule: json['type_vehicule'] ?? 'voiture',
      marque: json['marque'] ?? '',
      modele: json['modele'] ?? '',
      couleur: json['couleur'] ?? '',
      plaque: json['plaque'] ?? '',
      placesMax: json['places_max'] as int? ?? 4,
      actif: json['actif'] ?? true,
      photo: json['photo'],
    );
  }

  Map<String, dynamic> toJson() => {
        'type_vehicule': typeVehicule,
        'marque': marque,
        'modele': modele,
        'couleur': couleur,
        'plaque': plaque,
        'places_max': placesMax,
      };

  VehiculeModel copyWith({
    int? id,
    String? typeVehicule,
    String? marque,
    String? modele,
    String? couleur,
    String? plaque,
    int? placesMax,
    bool? actif,
    String? photo,
  }) {
    return VehiculeModel(
      id: id ?? this.id,
      typeVehicule: typeVehicule ?? this.typeVehicule,
      marque: marque ?? this.marque,
      modele: modele ?? this.modele,
      couleur: couleur ?? this.couleur,
      plaque: plaque ?? this.plaque,
      placesMax: placesMax ?? this.placesMax,
      actif: actif ?? this.actif,
      photo: photo ?? this.photo,
    );
  }

  String get displayName => '$marque $modele ($plaque)';
}
