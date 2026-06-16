import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../theme/app_radius.dart';

/// Badge KoVoit — badge badge-success/warning/error/info badge-outline rounded-full
/// Reproduit exactement le style DaisyUI du Web
class KBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color bgColor;
  final bool outlined;

  const KBadge({
    super.key,
    required this.label,
    this.color = KColors.success,
    this.bgColor = KColors.successLight,
    this.outlined = true,
  });

  factory KBadge.success(String label) => KBadge(
        label: label,
        color: KColors.success,
        bgColor: KColors.successLight,
      );

  factory KBadge.warning(String label) => KBadge(
        label: label,
        color: KColors.warning,
        bgColor: KColors.warningLight,
      );

  factory KBadge.error(String label) => KBadge(
        label: label,
        color: KColors.error,
        bgColor: KColors.errorLight,
      );

  factory KBadge.info(String label) => KBadge(
        label: label,
        color: KColors.info,
        bgColor: KColors.infoLight,
      );

  factory KBadge.neutral(String label) => KBadge(
        label: label,
        color: KColors.baseContentMid,
        bgColor: KColors.base200,
      );

  factory KBadge.fromStatut(String statut) {
    final color = KColors.statusColor(statut);
    final bgColor = KColors.statusBgColor(statut);
    return KBadge(label: _label(statut), color: color, bgColor: bgColor);
  }

  static String _label(String statut) {
    switch (statut.toLowerCase()) {
      case 'confirmee': return 'confirmé';
      case 'en_attente': return 'en attente';
      case 'en_cours': return 'en cours';
      case 'annulee': return 'annulé';
      case 'terminee': return 'terminé';
      case 'ouvert': return 'actif';
      default: return statut;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: outlined ? Colors.transparent : bgColor,
        borderRadius: KRadius.borderFull,
        border: outlined ? Border.all(color: color, width: 1.5) : null,
      ),
      child: Text(
        label,
        style: KTextStyles.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}
