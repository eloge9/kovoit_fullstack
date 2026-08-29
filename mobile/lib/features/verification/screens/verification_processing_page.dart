import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/verification_provider.dart';
import '../models/verification_model.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/text_styles.dart';
import '../../../core/widgets/k_button.dart';
import '../../../core/widgets/k_error_screen.dart';

/// Écran affiché juste après la soumission des documents : suit en direct
/// (polling) l'avancement de l'analyse IA, sans aucune action de l'utilisateur.
class VerificationProcessingPage extends ConsumerStatefulWidget {
  const VerificationProcessingPage({super.key});

  @override
  ConsumerState<VerificationProcessingPage> createState() => _VerificationProcessingPageState();
}

class _VerificationProcessingPageState extends ConsumerState<VerificationProcessingPage> {
  Timer? _pollTimer;
  bool _showIssues = false;

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      ref.invalidate(verificationStatusProvider);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statusAsync = ref.watch(verificationStatusProvider);

    return Scaffold(
      backgroundColor: KColors.base200,
      body: SafeArea(
        child: statusAsync.when(
          loading: _buildProcessing,
          error: (e, _) => KErrorScreen(
            kind: KErrorKind.server,
            homeRoute: '/conducteur',
            onRetry: () => ref.invalidate(verificationStatusProvider),
          ),
          data: (status) {
            if (status.status == 'PENDING_AI_REVIEW') return _buildProcessing();
            if (status.isRejected) return _buildRejected(context, status);
            return _buildSuccess(context, status);
          },
        ),
      ),
    );
  }

  Widget _buildProcessing() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _PulsingIcon(),
            const SizedBox(height: 28),
            Text(
              'Analyse de vos documents en cours…',
              textAlign: TextAlign.center,
              style: KTextStyles.h3,
            ),
            const SizedBox(height: 10),
            Text(
              "Cela ne prend généralement que quelques minutes. "
              "Vous serez notifié dès que le résultat sera disponible — "
              "vous n'avez rien d'autre à faire.",
              textAlign: TextAlign.center,
              style: KTextStyles.caption,
            ),
            const SizedBox(height: 28),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const LinearProgressIndicator(
                minHeight: 5,
                backgroundColor: KColors.base300,
                valueColor: AlwaysStoppedAnimation<Color>(KColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess(BuildContext context, DriverVerificationStatus status) {
    final isActive = status.isActive;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF22C55E).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle_rounded, color: Color(0xFF22C55E), size: 40),
            ),
            const SizedBox(height: 20),
            Text(
              'Vos documents ont été vérifiés avec succès.',
              textAlign: TextAlign.center,
              style: KTextStyles.h3,
            ),
            const SizedBox(height: 8),
            Text(
              isActive
                  ? 'Votre compte conducteur est maintenant actif !'
                  : 'Votre demande est en attente de validation.',
              textAlign: TextAlign.center,
              style: KTextStyles.caption,
            ),
            const SizedBox(height: 28),
            KButton(
              label: isActive ? 'Aller au tableau de bord' : 'Voir mon statut',
              icon: isActive ? Icons.home_rounded : Icons.verified_user_rounded,
              onPressed: () => isActive
                  ? context.go('/conducteur')
                  : context.pushReplacement('/conducteur/statut'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRejected(BuildContext context, DriverVerificationStatus status) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color: KColors.error.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded, color: KColors.error, size: 38),
            ),
            const SizedBox(height: 20),
            Text('Certains documents sont invalides.', textAlign: TextAlign.center, style: KTextStyles.h3),
            if (_showIssues && status.motifRejet.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status.motifRejet,
                  style: const TextStyle(fontSize: 13, color: Color(0xFFEF4444), height: 1.4),
                ),
              ),
            ],
            const SizedBox(height: 24),
            if (!_showIssues)
              KButton(
                label: 'Voir les problèmes',
                variant: KButtonVariant.outline,
                icon: Icons.visibility_outlined,
                onPressed: () => setState(() => _showIssues = true),
              ),
            const SizedBox(height: 12),
            KButton(
              label: 'Corriger',
              icon: Icons.edit_rounded,
              onPressed: () => context.pushReplacement('/conducteur/dossier'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PulsingIcon extends StatefulWidget {
  const _PulsingIcon();
  @override
  State<_PulsingIcon> createState() => _PulsingIconState();
}

class _PulsingIconState extends State<_PulsingIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale = 1.0 + (_controller.value * 0.12);
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: KColors.primary.withValues(alpha: 0.12),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.smart_toy_rounded, color: KColors.primary, size: 42),
      ),
    );
  }
}
