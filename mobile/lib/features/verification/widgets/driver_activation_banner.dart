import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/verification_provider.dart';
import '../models/verification_model.dart';
import '../../../core/theme/text_styles.dart';

class DriverActivationBanner extends ConsumerWidget {
  const DriverActivationBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(verificationStatusProvider);

    return statusAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (status) {
        if (status.isActive) return const SizedBox.shrink();
        return _BannerContent(status: status);
      },
    );
  }
}

class _BannerContent extends StatelessWidget {
  final DriverVerificationStatus status;
  const _BannerContent({required this.status});

  Color get _bgColor {
    if (status.isRejected || status.isBlocked) return const Color(0xFFFEE2E2);
    if (status.isPending) return const Color(0xFFFFF9E6);
    return const Color(0xFFEFF6FF);
  }

  Color get _iconColor {
    if (status.isRejected || status.isBlocked) return const Color(0xFFEF4444);
    if (status.isPending) return const Color(0xFFF59E0B);
    return const Color(0xFF3B82F6);
  }

  IconData get _icon {
    if (status.isRejected) return Icons.cancel_rounded;
    if (status.isBlocked) return Icons.block_rounded;
    if (status.isPending) return Icons.hourglass_empty_rounded;
    return Icons.upload_file_rounded;
  }

  String get _message {
    if (status.isBlocked) return 'Compte suspendu — contactez le support';
    if (status.isRejected) return 'Documents rejetés — renvoyez votre dossier';
    if (status.isAiPending) return 'Analyse IA en cours…';
    if (status.isAdminPending) return 'En attente de validation admin';
    final pct = status.completionPercentage;
    return 'Dossier à $pct% — complétez pour activer votre compte';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/conducteur/statut'),
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _iconColor.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(_icon, color: _iconColor, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _message,
                style: KTextStyles.caption.copyWith(
                  color: _iconColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!status.isBlocked && !status.isPending)
              Icon(Icons.arrow_forward_ios_rounded,
                  size: 12, color: _iconColor.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }
}
