import 'package:flutter/material.dart';
import 'colors.dart';

/// Ombres KoVoit — DaisyUI shadow-xl / shadow-md
class KShadows {
  KShadows._();

  // shadow-xl de DaisyUI (utilisé sur les cards auth)
  static List<BoxShadow> get xl => [
    BoxShadow(
      color: KColors.neutral.withValues(alpha: 0.08),
      blurRadius: 24,
      spreadRadius: 0,
      offset: const Offset(0, 8),
    ),
    BoxShadow(
      color: KColors.neutral.withValues(alpha: 0.04),
      blurRadius: 8,
      spreadRadius: 0,
      offset: const Offset(0, 2),
    ),
  ];

  // shadow légère (élévation faible)
  static List<BoxShadow> get sm => [
    BoxShadow(
      color: KColors.neutral.withValues(alpha: 0.05),
      blurRadius: 8,
      spreadRadius: 0,
      offset: const Offset(0, 2),
    ),
  ];

  // Pas d'ombre — les cards du dashboard n'ont qu'une bordure sur le Web
  static List<BoxShadow> get none => [];
}
