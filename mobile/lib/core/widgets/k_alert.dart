import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../theme/app_radius.dart';

enum KAlertType { error, success, warning, info }

/// Alert KoVoit — reproduit alert alert-error / alert-success du Web DaisyUI
class KAlert extends StatelessWidget {
  final String message;
  final KAlertType type;
  final VoidCallback? onDismiss;

  const KAlert({
    super.key,
    required this.message,
    this.type = KAlertType.error,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final (bg, border, icon, textColor) = _style;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: KRadius.borderMd,
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: textColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: KTextStyles.bodySm.copyWith(color: textColor),
            ),
          ),
          if (onDismiss != null) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onDismiss,
              child: Icon(Icons.close, color: textColor, size: 16),
            ),
          ],
        ],
      ),
    );
  }

  (Color bg, Color border, IconData icon, Color textColor) get _style {
    switch (type) {
      case KAlertType.error:
        return (
          KColors.errorLight,
          KColors.error.withValues(alpha: 0.3),
          Icons.error_outline,
          KColors.error,
        );
      case KAlertType.success:
        return (
          KColors.successLight,
          KColors.success.withValues(alpha: 0.3),
          Icons.check_circle_outline,
          KColors.success,
        );
      case KAlertType.warning:
        return (
          KColors.warningLight,
          KColors.warning.withValues(alpha: 0.3),
          Icons.warning_amber_outlined,
          KColors.warningContent,
        );
      case KAlertType.info:
        return (
          KColors.infoLight,
          KColors.info.withValues(alpha: 0.3),
          Icons.info_outline,
          KColors.info,
        );
    }
  }
}
