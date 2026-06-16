import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../theme/app_spacing.dart';

/// Ligne de liste cliquable — reproduit le pattern div hover:bg-base-200/40 du Web
class KListTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final Color? titleColor;

  const KListTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron = true,
    this.titleColor,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: KSpacing.rowH,
          vertical: KSpacing.rowCompactV,
        ),
        child: Row(
          children: [
            if (leading != null) ...[leading!, const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: KTextStyles.bodySm.copyWith(
                      color: titleColor ?? KColors.baseContentMid,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!, style: KTextStyles.meta),
                  ],
                ],
              ),
            ),
            ?trailing,
            if (showChevron && trailing == null)
              const Text(
                '→',
                style: TextStyle(color: KColors.baseContentLow, fontSize: 12),
              ),
          ],
        ),
      ),
    );
  }
}
