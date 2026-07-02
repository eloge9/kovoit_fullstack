import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/text_styles.dart';
import '../theme/app_radius.dart';

/// Champ texte KoVoit — input input-bordered rounded-xl du Web
class KTextField extends StatelessWidget {
  final TextEditingController? controller;
  final String label;
  final String? hint;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final int? maxLines;
  final bool enabled;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final void Function(String)? onSubmitted;
  final Iterable<String>? autofillHints;

  const KTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.obscureText = false,
    this.keyboardType,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.maxLines = 1,
    this.enabled = true,
    this.textInputAction,
    this.focusNode,
    this.onSubmitted,
    this.autofillHints,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: KTextStyles.bodySm.copyWith(fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          maxLines: obscureText ? 1 : maxLines,
          enabled: enabled,
          validator: validator,
          onChanged: onChanged,
          textInputAction: textInputAction,
          focusNode: focusNode,
          onFieldSubmitted: onSubmitted,
          autofillHints: autofillHints,
          style: KTextStyles.bodyLg.copyWith(color: KColors.baseContent),
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: prefixIcon != null
                ? IconTheme(
                    data: const IconThemeData(color: KColors.baseContentMid, size: 18),
                    child: prefixIcon!,
                  )
                : null,
            suffixIcon: suffixIcon,
            border: OutlineInputBorder(
              borderRadius: KRadius.borderMd,
              borderSide: const BorderSide(color: KColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: KRadius.borderMd,
              borderSide: const BorderSide(color: KColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: KRadius.borderMd,
              borderSide: const BorderSide(color: KColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: KRadius.borderMd,
              borderSide: const BorderSide(color: KColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: KRadius.borderMd,
              borderSide: const BorderSide(color: KColors.error, width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: KRadius.borderMd,
              borderSide: const BorderSide(color: KColors.base300),
            ),
            filled: true,
            fillColor: enabled ? KColors.base100 : KColors.base200,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            hintStyle: KTextStyles.bodyLg.copyWith(color: KColors.baseContentLow),
            errorStyle: KTextStyles.caption.copyWith(color: KColors.error),
          ),
        ),
      ],
    );
  }
}
