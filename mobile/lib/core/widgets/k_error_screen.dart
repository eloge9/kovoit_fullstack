import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/colors.dart';
import '../theme/text_styles.dart';
import 'k_button.dart';

/// Types d'erreurs "pleine page" reconnus par [KErrorScreen].
enum KErrorKind { network, driverNotActivated, permission, server, notFound, unexpected }

/// Écran d'erreur générique KoVoit — remplace toute page rouge / erreur brute
/// par une page cohérente avec le design de l'app, avec des actions claires.
///
/// Utilisation typique : `.when(error: (e, _) => KErrorScreen(kind: KErrorKind.server, onRetry: ...))`
/// dans un provider Riverpod, ou directement comme écran plein (routes cassées,
/// permission refusée, compte non activé...).
class KErrorScreen extends StatelessWidget {
  final KErrorKind kind;
  final String? message;
  final VoidCallback? onRetry;
  final String homeRoute;

  const KErrorScreen({
    super.key,
    required this.kind,
    this.message,
    this.onRetry,
    this.homeRoute = '/passager',
  });

  (IconData, String, String) get _content {
    switch (kind) {
      case KErrorKind.network:
        return (
          Icons.wifi_off_rounded,
          'Connexion impossible',
          message ?? 'Vérifiez votre connexion internet puis réessayez.',
        );
      case KErrorKind.driverNotActivated:
        return (
          Icons.verified_user_rounded,
          'Compte conducteur non activé',
          message ?? "Votre compte conducteur n'est pas encore activé.",
        );
      case KErrorKind.permission:
        return (
          Icons.lock_outline_rounded,
          'Autorisation requise',
          message ?? 'Cette fonctionnalité nécessite une autorisation.',
        );
      case KErrorKind.server:
        return (
          Icons.cloud_off_rounded,
          'Une erreur est survenue',
          message ?? 'Le serveur ne répond pas correctement. Réessayez dans un instant.',
        );
      case KErrorKind.notFound:
        return (
          Icons.search_off_rounded,
          'Page introuvable',
          message ?? "Cette page n'existe pas ou n'est plus disponible.",
        );
      case KErrorKind.unexpected:
        return (
          Icons.error_outline_rounded,
          'Erreur inattendue',
          message ?? "Une erreur imprévue s'est produite. Nos équipes en ont été informées.",
        );
    }
  }

  void _goBack(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go(homeRoute);
    }
  }

  List<Widget> _actions(BuildContext context) {
    switch (kind) {
      case KErrorKind.network:
        return [
          KButton(
            label: 'Réessayer',
            icon: Icons.refresh_rounded,
            onPressed: onRetry ?? () => _goBack(context),
          ),
        ];
      case KErrorKind.driverNotActivated:
        return [
          KButton(
            label: 'Envoyer mes documents',
            icon: Icons.upload_file_rounded,
            onPressed: () => context.push('/conducteur/dossier'),
          ),
          const SizedBox(height: 12),
          KButton(
            label: 'Voir mes documents',
            icon: Icons.description_outlined,
            variant: KButtonVariant.outline,
            onPressed: () => context.push('/conducteur/documents'),
          ),
          const SizedBox(height: 12),
          KButton(
            label: 'Retour',
            variant: KButtonVariant.ghost,
            onPressed: () => _goBack(context),
          ),
        ];
      case KErrorKind.permission:
        return [
          KButton(
            label: 'Ouvrir les paramètres',
            icon: Icons.settings_rounded,
            onPressed: () => openAppSettings(),
          ),
          const SizedBox(height: 12),
          KButton(
            label: 'Retour',
            variant: KButtonVariant.ghost,
            onPressed: () => _goBack(context),
          ),
        ];
      case KErrorKind.server:
        return [
          KButton(
            label: 'Réessayer',
            icon: Icons.refresh_rounded,
            onPressed: onRetry ?? () => _goBack(context),
          ),
        ];
      case KErrorKind.notFound:
        return [
          KButton(
            label: "Retour à l'accueil",
            icon: Icons.home_rounded,
            onPressed: () => context.go(homeRoute),
          ),
        ];
      case KErrorKind.unexpected:
        return [
          KButton(
            label: 'Retour',
            variant: KButtonVariant.outline,
            onPressed: () => _goBack(context),
          ),
          const SizedBox(height: 12),
          KButton(
            label: "Accueil",
            icon: Icons.home_rounded,
            onPressed: () => context.go(homeRoute),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            KButton(
              label: 'Réessayer',
              icon: Icons.refresh_rounded,
              onPressed: onRetry,
            ),
          ],
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, title, desc) = _content;

    return Scaffold(
      backgroundColor: KColors.base200,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: KColors.errorLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: KColors.error, size: 34),
                ),
                const SizedBox(height: 20),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: KTextStyles.h2,
                ),
                const SizedBox(height: 8),
                Text(
                  desc,
                  textAlign: TextAlign.center,
                  style: KTextStyles.caption,
                ),
                const SizedBox(height: 28),
                ..._actions(context),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
