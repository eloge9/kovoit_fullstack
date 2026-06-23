import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/verification_model.dart';
import '../repositories/verification_repository.dart';

final verificationRepositoryProvider =
    Provider<VerificationRepository>((ref) => VerificationRepository());

// ── Statut de vérification (chargé seulement pour les conducteurs) ─────────────

final verificationStatusProvider =
    FutureProvider.autoDispose<DriverVerificationStatus>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null || (user.role != 'conducteur' && !user.peutConduire)) {
    return DriverVerificationStatus(
      status: user?.driverStatus ?? 'DOCUMENTS_MISSING',
      isVerified: false,
      completionPercentage: 0,
      canPublishTrip: false,
      requiredDocuments: kRequiredDocTypes,
      uploadedDocuments: const [],
      missingDocuments: kRequiredDocTypes,
      motifRejet: '',
      motifSuspension: '',
    );
  }
  final repo = ref.watch(verificationRepositoryProvider);
  return repo.getStatus();
});

// ── Documents du conducteur ────────────────────────────────────────────────────

final verificationDocumentsProvider =
    FutureProvider.autoDispose<List<DriverDocumentModel>>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null || (user.role != 'conducteur' && !user.peutConduire)) {
    return Future.value([]);
  }
  final repo = ref.watch(verificationRepositoryProvider);
  return repo.getDocuments();
});

// ── Peut publier un trajet ? ───────────────────────────────────────────────────

final canPublishTripProvider = Provider.autoDispose<bool>((ref) {
  return ref.watch(verificationStatusProvider).value?.canPublishTrip ?? false;
});

// ── Statut string pour affichage ──────────────────────────────────────────────

final driverVerifStatusStringProvider = Provider.autoDispose<String>((ref) {
  final user = ref.watch(currentUserProvider);
  return ref.watch(verificationStatusProvider).value?.status
      ?? user?.driverStatus
      ?? 'DOCUMENTS_MISSING';
});
