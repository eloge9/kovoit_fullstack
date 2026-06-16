class UserModel {
  final String id;
  final String username;
  final String email;
  final String role;
  final String? firstName;
  final String? lastName;
  final String? phoneNumber;
  final String? photoProfile;
  final double note;
  final String? photoCNI;
  final String? photoPermis;
  final String statutValidation;
  final bool peutConduire;
  final String? contactUrgenceNom;
  final String? contactUrgenceTelephone;
  final String? modeCourant;
  final String? numeroPermis;
  final int? experienceAnnees;
  final String? driverStatus;

  const UserModel({
    required this.id,
    required this.username,
    required this.email,
    required this.role,
    this.firstName,
    this.lastName,
    this.phoneNumber,
    this.photoProfile,
    this.note = 0.0,
    this.photoCNI,
    this.photoPermis,
    this.statutValidation = 'non_soumis',
    this.peutConduire = false,
    this.contactUrgenceNom,
    this.contactUrgenceTelephone,
    this.modeCourant,
    this.numeroPermis,
    this.experienceAnnees,
    this.driverStatus,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id:                     json['id']?.toString() ?? '',
      username:               json['username'] ?? '',
      email:                  json['email'] ?? '',
      role:                   json['role'] ?? 'passager',
      firstName:              json['first_name'],
      lastName:               json['last_name'],
      phoneNumber:            json['numero_telephone'],
      photoProfile:           json['photo_profil'] ?? json['photo_profile'],
      note:                   (json['note'] as num?)?.toDouble() ?? 0.0,
      photoCNI:               json['photo_cni'],
      photoPermis:            json['photo_permis'],
      statutValidation:       json['statut_validation'] ?? 'non_soumis',
      peutConduire:           json['peut_conduire'] ?? false,
      contactUrgenceNom:      json['contact_urgence_nom'],
      contactUrgenceTelephone:json['contact_urgence_telephone'],
      modeCourant:            json['mode_courant'],
      numeroPermis:           json['numero_permis'],
      experienceAnnees:       json['experience_annees'],
      driverStatus:           json['driver_status'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id':                       id,
    'username':                 username,
    'email':                    email,
    'role':                     role,
    'first_name':               firstName,
    'last_name':                lastName,
    'numero_telephone':         phoneNumber,
    'photo_profil':             photoProfile,
    'note':                     note,
    'statut_validation':        statutValidation,
    'peut_conduire':            peutConduire,
    'contact_urgence_nom':      contactUrgenceNom,
    'contact_urgence_telephone':contactUrgenceTelephone,
    'mode_courant':             modeCourant,
  };

  UserModel copyWith({
    String? id, String? username, String? email, String? role,
    String? firstName, String? lastName, String? phoneNumber,
    String? photoProfile, double? note, String? photoCNI, String? photoPermis,
    String? statutValidation, bool? peutConduire,
    String? contactUrgenceNom, String? contactUrgenceTelephone,
    String? modeCourant, String? numeroPermis, int? experienceAnnees,
    String? driverStatus,
  }) {
    return UserModel(
      id:                     id ?? this.id,
      username:               username ?? this.username,
      email:                  email ?? this.email,
      role:                   role ?? this.role,
      firstName:              firstName ?? this.firstName,
      lastName:               lastName ?? this.lastName,
      phoneNumber:            phoneNumber ?? this.phoneNumber,
      photoProfile:           photoProfile ?? this.photoProfile,
      note:                   note ?? this.note,
      photoCNI:               photoCNI ?? this.photoCNI,
      photoPermis:            photoPermis ?? this.photoPermis,
      statutValidation:       statutValidation ?? this.statutValidation,
      peutConduire:           peutConduire ?? this.peutConduire,
      contactUrgenceNom:      contactUrgenceNom ?? this.contactUrgenceNom,
      contactUrgenceTelephone:contactUrgenceTelephone ?? this.contactUrgenceTelephone,
      modeCourant:            modeCourant ?? this.modeCourant,
      numeroPermis:           numeroPermis ?? this.numeroPermis,
      experienceAnnees:       experienceAnnees ?? this.experienceAnnees,
      driverStatus:           driverStatus ?? this.driverStatus,
    );
  }

  bool get isConducteur => role == 'conducteur' || peutConduire;
  bool get isPassager   => role == 'passager';
  bool get isAdmin      => role == 'admin';
  bool get isValidated  => statutValidation == 'valide';

  String get displayName =>
      (firstName?.isNotEmpty == true || lastName?.isNotEmpty == true)
          ? '${firstName ?? ''} ${lastName ?? ''}'.trim()
          : username;
}
