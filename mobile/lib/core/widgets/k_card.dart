import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/app_radius.dart';
import '../theme/app_shadows.dart';
import '../theme/text_styles.dart';
import '../theme/app_spacing.dart';

/// Card KoVoit — bg-base-100 rounded-2xl border border-base-200
/// Reproduit exactement le style des cartes du Web (pas d'ombre, juste une bordure)
class KCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final bool hasShadow;
  final Color? backgroundColor;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;

  const KCard({
    super.key,
    required this.child,
    this.padding,
    this.hasShadow = false,
    this.backgroundColor,
    this.onTap,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? KColors.base100,
        borderRadius: borderRadius ?? KRadius.borderLg,
        border: Border.all(color: KColors.border),
        boxShadow: hasShadow ? KShadows.xl : KShadows.none,
      ),
      child: ClipRRect(
        borderRadius: borderRadius ?? KRadius.borderLg,
        child: child,
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}

/// En-tête de section à l'intérieur d'une KCard
/// Reproduit : px-6 py-4 border-b border-base-200
class KCardHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const KCardHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: KSpacing.cardHeaderH,
        vertical: KSpacing.cardHeaderV,
      ),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: KColors.border)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(title.toUpperCase(), style: KTextStyles.label)),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                action!,
                style: KTextStyles.caption.copyWith(color: KColors.primary),
              ),
            ),
        ],
      ),
    );
  }
}

/// Ligne de données (key/value) — reproduce le pattern "flex justify-between"
class KDataRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  final Widget? valueWidget;

  const KDataRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.valueWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: KSpacing.rowH,
        vertical: KSpacing.rowCompactV,
      ),
      child: Row(
        children: [
          Expanded(child: Text(label.toUpperCase(), style: KTextStyles.label)),
          const SizedBox(width: 8),
          valueWidget ??
              Text(
                value,
                style: KTextStyles.bodySmBold.copyWith(
                  color: valueColor ?? KColors.baseContent,
                ),
              ),
        ],
      ),
    );
  }
}

/// Stat card — bg-base-100 rounded-2xl border p-6
class KStatCard extends StatelessWidget {
  final String value;
  final String label;
  final String? sub;

  const KStatCard({
    super.key,
    required this.value,
    required this.label,
    this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return KCard(
      padding: const EdgeInsets.all(KSpacing.cardPadding),
      child: Padding(
        padding: const EdgeInsets.all(KSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: KTextStyles.statValue),
            const SizedBox(height: 6),
            Text(label, style: KTextStyles.bodySm),
            if (sub != null) ...[
              const SizedBox(height: 2),
              Text(sub!, style: KTextStyles.meta),
            ],
          ],
        ),
      ),
    );
  }
}

/// Skeleton shimmer loading — animate-pulse du Web
class KSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final double borderRadius;

  const KSkeleton({
    super.key,
    this.width = double.infinity,
    this.height = 16,
    this.borderRadius = 8,
  });

  @override
  State<KSkeleton> createState() => _KSkeletonState();
}

class _KSkeletonState extends State<KSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.4,
      end: 0.9,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Opacity(
        opacity: _anim.value,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: KColors.base300,
            borderRadius: BorderRadius.circular(widget.borderRadius),
          ),
        ),
      ),
    );
  }
}
