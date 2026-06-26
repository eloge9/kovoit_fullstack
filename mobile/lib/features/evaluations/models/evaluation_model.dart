class EvaluationModel {
  final int id;
  final int trajetId;
  final String trajetLabel;
  final String auteurId;
  final String auteurNom;
  final String? auteurPhoto;
  final String cibleId;
  final String cibleNom;
  final String? ciblePhoto;
  final int note;
  final String? commentaire;
  final bool signalement;
  final String? motifSignalement;
  final DateTime dateEvaluation;

  const EvaluationModel({
    required this.id,
    required this.trajetId,
    this.trajetLabel = '',
    required this.auteurId,
    required this.auteurNom,
    this.auteurPhoto,
    required this.cibleId,
    required this.cibleNom,
    this.ciblePhoto,
    required this.note,
    this.commentaire,
    this.signalement = false,
    this.motifSignalement,
    required this.dateEvaluation,
  });

  factory EvaluationModel.fromJson(Map<String, dynamic> json) {
    // Backend retourne: auteur_id, auteur (nom), auteur_photo,
    //                   cible_id, cible (nom), cible_photo,
    //                   trajet (label string), trajet_id,
    //                   date (pas date_evaluation)
    return EvaluationModel(
      id: json['id'] as int,
      trajetId: json['trajet_id'] as int?
          ?? (json['trajet'] is int ? json['trajet'] as int : null)
          ?? 0,
      trajetLabel: json['trajet'] is String ? json['trajet'].toString() : '',
      auteurId: json['auteur_id']?.toString() ?? '',
      auteurNom: json['auteur_nom']?.toString()
          ?? json['auteur']?.toString()
          ?? '',
      auteurPhoto: json['auteur_photo']?.toString(),
      cibleId: json['cible_id']?.toString() ?? '',
      cibleNom: json['cible_nom']?.toString()
          ?? json['cible']?.toString()
          ?? '',
      ciblePhoto: json['cible_photo']?.toString(),
      note: json['note'] as int? ?? 0,
      commentaire: json['commentaire']?.toString(),
      signalement: json['signale'] as bool? ?? json['signalement'] as bool? ?? false,
      motifSignalement: json['motif_signalement']?.toString(),
      dateEvaluation: DateTime.tryParse(
              json['date_evaluation']?.toString()
              ?? json['date']?.toString()
              ?? '') ??
          DateTime.now(),
    );
  }
}
