import 'package:flutter/material.dart';
import 'colors.dart';

/// Typographie KoVoit — extraite du Web (Tailwind text-scale)
class KTextStyles {
  KTextStyles._();

  // Police système (identique au Web qui utilise la police système via Tailwind)
  static const String fontFamily = 'Roboto';

  // ── Titres ─────────────────────────────────────────────────────────────────
  // text-3xl font-bold tracking-tight (h1 dashboard)
  static TextStyle get h1 => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 28,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.5,
    color: KColors.baseContent,
    height: 1.2,
  );

  // text-2xl font-bold (sous-titre de page)
  static TextStyle get h2 => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: KColors.baseContent,
    height: 1.3,
  );

  // text-xl font-bold (titre de carte activation)
  static TextStyle get h3 => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: KColors.baseContent,
    height: 1.4,
  );

  // ── Body ───────────────────────────────────────────────────────────────────
  // text-base (16px)
  static TextStyle get bodyLg => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: KColors.baseContent,
    height: 1.5,
  );

  // text-sm font-medium (labels, nav items)
  static TextStyle get bodySm => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: KColors.baseContent,
    height: 1.4,
  );

  // text-sm font-semibold (valeur dans les lignes de données)
  static TextStyle get bodySmBold => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: KColors.baseContent,
    height: 1.4,
  );

  // ── Captions / Labels ─────────────────────────────────────────────────────
  // text-xs (12px) — standard
  static TextStyle get caption => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: KColors.baseContentMid,
    height: 1.4,
  );

  // text-xs uppercase tracking-widest font-medium (section headers)
  static TextStyle get label => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    color: KColors.baseContentLow,
    letterSpacing: 1.2,
    height: 1.2,
  );

  // text-xs text-base-content/40 (timestamp, meta)
  static TextStyle get meta => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: KColors.baseContentLow,
    height: 1.3,
  );

  // ── Stats ─────────────────────────────────────────────────────────────────
  // text-3xl font-bold (chiffre stat card)
  static TextStyle get statValue => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: KColors.baseContent,
    height: 1.1,
  );

  // ── Nav / Boutons ─────────────────────────────────────────────────────────
  // text-sm font-semibold (bouton)
  static TextStyle get button => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    height: 1.2,
  );

  // text-base font-semibold (bouton grand)
  static TextStyle get buttonLg => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
    height: 1.2,
  );

  // Lien primary (link link-primary)
  static TextStyle get link => const TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: KColors.primary,
    height: 1.4,
  );

  // ── Couleurs rapides ──────────────────────────────────────────────────────
  static TextStyle colored(TextStyle base, Color color) =>
      base.copyWith(color: color);

  static TextStyle primary(TextStyle base) =>
      base.copyWith(color: KColors.primary);

  static TextStyle muted(TextStyle base) =>
      base.copyWith(color: KColors.baseContentMid);

  static TextStyle faded(TextStyle base) =>
      base.copyWith(color: KColors.baseContentLow);
}
