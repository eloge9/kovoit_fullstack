class EvaluationModel {
  final int id;
  final int trajetId;
  final String auteurId;
  final String auteurNom;
  final String? auteurPhoto;
  final String cibleId;
  final String cibleNom;
  final int note;
  final String? commentaire;
  final bool signalement;
  final String? motifSignalement;
  final DateTime dateEvaluation;

  const EvaluationModel({
    required this.id,
    required this.trajetId,
    required this.auteurId,
    required this.auteurNom,
    this.auteurPhoto,
    required this.cibleId,
    required this.cibleNom,
    required this.note,
    this.commentaire,
    this.signalement = false,
    this.motifSignalement,
    required this.dateEvaluation,
  });

  factory EvaluationModel.fromJson(Map<String, dynamic> json) {
    // Backend retourne 'trajet' (int), 'auteur' (UUID), 'cible' (UUID)
    // On supporte les deux formes pour la compatibilité
    return EvaluationModel(
      id: json['id'] as int,
      trajetId: json['trajet_id'] as int?
          ?? (json['trajet'] is int ? json['trajet'] as int : null)
          ?? 0,
      auteurId: json['auteur_id']?.toString()
          ?? json['auteur']?.toString()
          ?? '',
      auteurNom: json['auteur_nom']?.toString() ?? '',
      auteurPhoto: json['auteur_photo']?.toString(),
      cibleId: json['cible_id']?.toString()
          ?? json['cible']?.toString()
          ?? '',
      cibleNom: json['cible_nom']?.toString() ?? '',
      note: json['note'] as int? ?? 0,
      commentaire: json['commentaire']?.toString(),
      signalement: json['signalement'] as bool? ?? false,
      motifSignalement: json['motif_signalement']?.toString(),
      dateEvaluation: DateTime.tryParse(json['date_evaluation']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
