import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import 'k_button.dart';

/// État vide — reproduit le pattern "px-6 py-8 text-center" du Web
class KEmptyState extends StatelessWidget {
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;
  final String? emoji;

  const KEmptyState({
    super.key,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.emoji,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (emoji != null)
            Text(emoji!, style: const TextStyle(fontSize: 36))
          else if (icon != null)
            Icon(icon, size: 36, color: KColors.baseContentLow),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: KTextStyles.bodySm.copyWith(color: KColors.baseContentMid),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            KButton(
              label: actionLabel!,
              onPressed: onAction,
              size: KButtonSize.sm,
              fullWidth: false,
            ),
          ],
        ],
      ),
    );
  }
}
