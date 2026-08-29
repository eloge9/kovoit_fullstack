class LatestVerificationReport {
  final String id;
  final String? decision;
  final double overallScore;
  final double fraudScore;
  final double confidenceScore;
  final String? completedAt;
  final String createdAt;

  const LatestVerificationReport({
    required this.id,
    this.decision,
    required this.overallScore,
    required this.fraudScore,
    required this.confidenceScore,
    this.completedAt,
    required this.createdAt,
  });

  factory LatestVerificationReport.fromJson(Map<String, dynamic> j) =>
      LatestVerificationReport(
        id:              j['id']?.toString() ?? '',
        decision:        j['decision'] as String?,
        overallScore:    (j['overall_score'] as num?)?.toDouble() ?? 0,
        fraudScore:      (j['fraud_score'] as num?)?.toDouble() ?? 0,
        confidenceScore: (j['confidence_score'] as num?)?.toDouble() ?? 0,
        completedAt:     j['completed_at'] as String?,
        createdAt:       j['created_at']?.toString() ?? '',
      );
}

class DriverVerificationStatus {
  final String status;
  final bool isVerified;
  final int completionPercentage;
  final bool canPublishTrip;
  final List<String> requiredDocuments;
  final List<String> uploadedDocuments;
  final List<String> missingDocuments;
  final String motifRejet;
  final String motifSuspension;
  final LatestVerificationReport? latestReport;

  const DriverVerificationStatus({
    required this.status,
    required this.isVerified,
    required this.completionPercentage,
    required this.canPublishTrip,
    required this.requiredDocuments,
    required this.uploadedDocuments,
    required this.missingDocuments,
    required this.motifRejet,
    required this.motifSuspension,
    this.latestReport,
  });

  factory DriverVerificationStatus.fromJson(Map<String, dynamic> j) =>
      DriverVerificationStatus(
        status:               j['status']?.toString() ?? 'DOCUMENTS_MISSING',
        isVerified:           j['is_verified'] as bool? ?? false,
        completionPercentage: (j['completion_percentage'] as num?)?.toInt() ?? 0,
        canPublishTrip:       j['can_publish_trip'] as bool? ?? false,
        requiredDocuments:    _strList(j['required_documents']),
        uploadedDocuments:    _strList(j['uploaded_documents']),
        missingDocuments:     _strList(j['missing_documents']),
        motifRejet:           j['motif_rejet']?.toString() ?? '',
        motifSuspension:      j['motif_suspension']?.toString() ?? '',
        latestReport:         j['latest_report'] is Map
            ? LatestVerificationReport.fromJson(
                j['latest_report'] as Map<String, dynamic>)
            : null,
      );

  static List<String> _strList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return [];
  }

  bool get isActive        => status == 'ACTIVE';
  bool get isPending       => status == 'PENDING_AI_REVIEW' || status == 'PENDING_ADMIN_REVIEW';
  bool get isAiPending     => status == 'PENDING_AI_REVIEW';
  bool get isAdminPending  => status == 'PENDING_ADMIN_REVIEW';
  bool get needsDocuments  => status == 'DOCUMENTS_MISSING' || status == 'DRAFT';
  bool get isRejected      => status == 'AI_REJECTED' || status == 'REJECTED';
  bool get isBlocked       => status == 'BLOCKED' || status == 'SUSPENDED';
  bool get canUpload       => !isBlocked;
}

class DriverDocumentModel {
  final String id;
  final String documentType;
  final String status;
  final String? fileUrl;
  final String fileName;
  final String? dateExpiration;
  final String rejectionReason;
  final String uploadedAt;
  final bool isExpired;

  const DriverDocumentModel({
    required this.id,
    required this.documentType,
    required this.status,
    this.fileUrl,
    required this.fileName,
    this.dateExpiration,
    required this.rejectionReason,
    required this.uploadedAt,
    required this.isExpired,
  });

  factory DriverDocumentModel.fromJson(Map<String, dynamic> j) =>
      DriverDocumentModel(
        id:              j['id']?.toString() ?? '',
        documentType:    j['document_type']?.toString() ?? '',
        status:          j['status']?.toString() ?? 'PENDING',
        fileUrl:         j['file_url'] as String?,
        fileName:        j['file_name']?.toString() ?? '',
        dateExpiration:  j['date_expiration'] as String?,
        rejectionReason: j['rejection_reason']?.toString() ?? '',
        uploadedAt:      j['uploaded_at']?.toString() ?? '',
        isExpired:       j['is_expired'] as bool? ?? false,
      );

  bool get isVerified   => status == 'VERIFIED';
  bool get isPending    => status == 'PENDING';
  bool get isProcessing => status == 'PROCESSING';
  bool get isRejected   => status == 'REJECTED';
}

// ── Constantes documents ───────────────────────────────────────────────────────

const kRequiredDocTypes = [
  'CNI', 'SELFIE_ID', 'PORTRAIT',
  'DRIVING_LICENSE', 'VEHICLE_REGISTRATION',
  'INSURANCE', 'TECHNICAL_INSPECTION',
  'VEHICLE_FRONT', 'VEHICLE_REAR',
  'VEHICLE_LEFT', 'VEHICLE_RIGHT',
  'VEHICLE_INTERIOR_FRONT', 'VEHICLE_INTERIOR_REAR',
];

const kDocTypeLabels = <String, String>{
  'CNI':                    "Carte nationale d'identité",
  'PASSPORT':               'Passeport',
  'SELFIE_ID':              "Selfie avec pièce d'identité",
  'PORTRAIT':               'Photo portrait récente',
  'DRIVING_LICENSE':        'Permis de conduire',
  'VEHICLE_REGISTRATION':   'Carte grise',
  'INSURANCE':              "Attestation d'assurance",
  'TECHNICAL_INSPECTION':   'Contrôle technique',
  'VEHICLE_FRONT':          'Véhicule — Face avant',
  'VEHICLE_REAR':           'Véhicule — Face arrière',
  'VEHICLE_LEFT':           'Véhicule — Côté gauche',
  'VEHICLE_RIGHT':          'Véhicule — Côté droit',
  'VEHICLE_INTERIOR_FRONT': 'Véhicule — Intérieur avant',
  'VEHICLE_INTERIOR_REAR':  'Véhicule — Intérieur arrière',
  'PROOF_OF_ADDRESS':       'Justificatif de domicile',
  'TRANSFER_CERTIFICATE':   'Certificat de cession',
  'OWNER_AUTHORIZATION':    'Autorisation propriétaire',
};

// ── Regroupement des documents par étape du wizard ────────────────────────────
// Le statut backend (DriverStatus) reste la seule source de vérité ; ce
// regroupement ne sert qu'à structurer l'UI de soumission en étapes.
class DocStep {
  final String title;
  final IconIndex icon;
  final List<String> docTypes;
  const DocStep({required this.title, required this.icon, required this.docTypes});
}

enum IconIndex { identite, permis, vehiculePapiers, vehiculePhotos }

const kDocSteps = <DocStep>[
  DocStep(
    title: "Pièce d'identité",
    icon: IconIndex.identite,
    docTypes: ['CNI', 'SELFIE_ID', 'PORTRAIT'],
  ),
  DocStep(
    title: 'Permis de conduire',
    icon: IconIndex.permis,
    docTypes: ['DRIVING_LICENSE'],
  ),
  DocStep(
    title: 'Documents du véhicule',
    icon: IconIndex.vehiculePapiers,
    docTypes: ['VEHICLE_REGISTRATION', 'INSURANCE', 'TECHNICAL_INSPECTION'],
  ),
  DocStep(
    title: 'Photos du véhicule',
    icon: IconIndex.vehiculePhotos,
    docTypes: [
      'VEHICLE_FRONT', 'VEHICLE_REAR', 'VEHICLE_LEFT', 'VEHICLE_RIGHT',
      'VEHICLE_INTERIOR_FRONT', 'VEHICLE_INTERIOR_REAR',
    ],
  ),
];

const kDriverStatusLabels = <String, String>{
  'DRAFT':                'Brouillon',
  'DOCUMENTS_MISSING':    'Documents manquants',
  'PENDING_AI_REVIEW':    'Vérification IA en cours',
  'AI_APPROVED':          'Approuvé par IA',
  'AI_REJECTED':          'Rejeté par IA',
  'PENDING_ADMIN_REVIEW': 'En attente admin',
  'ACTIVE':               'Compte activé',
  'SUSPENDED':            'Suspendu',
  'BLOCKED':              'Bloqué',
  'REJECTED':             'Rejeté',
};
