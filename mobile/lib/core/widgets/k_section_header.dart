import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../theme/app_spacing.dart';

/// En-tête de section — text-xs uppercase tracking-widest du Web
class KSectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const KSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: KTextStyles.label,
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: KTextStyles.meta),
        ],
      ],
    );
  }
}

/// Divider avec texte — reproduit le divider "ou" de DaisyUI
class KDividerText extends StatelessWidget {
  final String text;

  const KDividerText({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: KColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: KSpacing.md),
          child: Text(text, style: KTextStyles.caption),
        ),
        const Expanded(child: Divider(color: KColors.border)),
      ],
    );
  }
}
