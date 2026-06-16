import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/app_radius.dart';
import '../theme/text_styles.dart';

enum KButtonVariant { primary, outline, ghost, warning, error, success }
enum KButtonSize { sm, md, lg }

/// Bouton KoVoit — reproduit btn, btn-primary, btn-outline, btn-ghost, btn-sm
/// du Web DaisyUI. Les boutons CTA sont toujours rounded-full.
class KButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final KButtonVariant variant;
  final KButtonSize size;
  final bool isLoading;
  final bool fullWidth;
  final IconData? icon;
  final Widget? child;

  const KButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = KButtonVariant.primary,
    this.size = KButtonSize.md,
    this.isLoading = false,
    this.fullWidth = true,
    this.icon,
    this.child,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;

    final (bg, fg, border) = _colors(disabled);
    final height = _height;
    final textStyle = _textStyle;
    final padding = _padding;

    Widget content = isLoading
        ? SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: size == KButtonSize.sm ? 14 : 16, color: fg),
                const SizedBox(width: 6),
              ],
              child ?? Text(label, style: textStyle.copyWith(color: fg)),
            ],
          );

    Widget button = GestureDetector(
      onTap: disabled ? null : onPressed,
      child: AnimatedOpacity(
        opacity: disabled ? 0.6 : 1.0,
        duration: const Duration(milliseconds: 150),
        child: Container(
          height: height,
          padding: padding,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: KRadius.borderFull,
            border: border != null
                ? Border.all(color: border, width: 1.5)
                : null,
          ),
          alignment: Alignment.center,
          child: content,
        ),
      ),
    );

    return fullWidth ? SizedBox(width: double.infinity, child: button) : button;
  }

  (Color bg, Color fg, Color? border) _colors(bool disabled) {
    if (disabled) {
      return (KColors.base300, KColors.baseContentMid, null);
    }
    switch (variant) {
      case KButtonVariant.primary:
        return (KColors.primary, KColors.white, null);
      case KButtonVariant.outline:
        return (Colors.transparent, KColors.primary, KColors.primary);
      case KButtonVariant.ghost:
        return (Colors.transparent, KColors.baseContent, KColors.border);
      case KButtonVariant.warning:
        return (KColors.warning, KColors.warningContent, null);
      case KButtonVariant.error:
        return (KColors.error, KColors.white, null);
      case KButtonVariant.success:
        return (KColors.success, KColors.white, null);
    }
  }

  double get _height {
    switch (size) {
      case KButtonSize.sm:  return 32;
      case KButtonSize.md:  return 48;
      case KButtonSize.lg:  return 56;
    }
  }

  EdgeInsets get _padding {
    switch (size) {
      case KButtonSize.sm:  return const EdgeInsets.symmetric(horizontal: 16, vertical: 6);
      case KButtonSize.md:  return const EdgeInsets.symmetric(horizontal: 24, vertical: 12);
      case KButtonSize.lg:  return const EdgeInsets.symmetric(horizontal: 32, vertical: 16);
    }
  }

  TextStyle get _textStyle {
    switch (size) {
      case KButtonSize.sm:  return KTextStyles.button.copyWith(fontSize: 13);
      case KButtonSize.md:  return KTextStyles.button;
      case KButtonSize.lg:  return KTextStyles.buttonLg;
    }
  }
}
