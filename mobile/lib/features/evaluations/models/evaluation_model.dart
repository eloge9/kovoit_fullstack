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
    return EvaluationModel(
      id: json['id'] as int,
      trajetId: json['trajet_id'] as int? ?? json['trajet'] as int? ?? 0,
      auteurId: json['auteur_id']?.toString() ?? '',
      auteurNom: json['auteur_nom'] ?? '',
      auteurPhoto: json['auteur_photo'],
      cibleId: json['cible_id']?.toString() ?? '',
      cibleNom: json['cible_nom'] ?? '',
      note: json['note'] as int? ?? 0,
      commentaire: json['commentaire'],
      signalement: json['signalement'] ?? false,
      motifSignalement: json['motif_signalement'],
      dateEvaluation: DateTime.parse(json['date_evaluation'] as String),
    );
  }
}
