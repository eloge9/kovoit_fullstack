import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../theme/app_spacing.dart';

/// En-tête de page — reproduit le bloc h1 / sous-titre / date du Web
class KPageHeader extends StatelessWidget {
  final String prefix;
  final String title;
  final String? date;
  final Widget? action;

  const KPageHeader({
    super.key,
    required this.prefix,
    required this.title,
    this.date,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(prefix.toUpperCase(), style: KTextStyles.label),
                  const SizedBox(height: 4),
                  Text(title, style: KTextStyles.h1),
                  if (date != null) ...[
                    const SizedBox(height: 4),
                    Text(date!, style: KTextStyles.meta),
                  ],
                ],
              ),
            ),
            ?action,
          ],
        ),
        const SizedBox(height: KSpacing.xl),
        const Divider(color: KColors.border),
      ],
    );
  }
}
