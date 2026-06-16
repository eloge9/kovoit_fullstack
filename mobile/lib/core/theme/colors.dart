import 'package:flutter/material.dart';

/// Palette KoVoit — extraite du thème DaisyUI "winter" du site Next.js
class KColors {
  KColors._();

  // ── Primary (bleu DaisyUI winter) ─────────────────────────────────────────
  // oklch(56.86% 0.255 257.57) → #1D6EEF
  static const Color primary        = Color(0xFF1D6EEF);
  static const Color primaryContent = Color(0xFFD6E8FF);   // oklch(91.372% 0.051 257.57)
  static const Color primaryLight   = Color(0xFF5B96F5);   // variante claire dérivée
  static const Color primaryDark    = Color(0xFF1455C0);   // variante foncée dérivée

  // ── Secondary (violet DaisyUI winter) ────────────────────────────────────
  // oklch(42.551% 0.161 282.339) → #4B3BAB
  static const Color secondary        = Color(0xFF4B3BAB);
  static const Color secondaryContent = Color(0xFFD5CEEA);  // oklch(88.51% 0.032 282.339)

  // ── Accent (rose DaisyUI winter) ─────────────────────────────────────────
  // oklch(59.939% 0.191 335.171) → #CC4899
  static const Color accent        = Color(0xFFCC4899);
  static const Color accentContent = Color(0xFF1A0012);     // oklch(11.988% 0.038 335.171)

  // ── Neutral (bleu marine DaisyUI winter) ─────────────────────────────────
  // oklch(19.616% 0.063 257.651) → #1A253A
  static const Color neutral        = Color(0xFF1A253A);
  static const Color neutralContent = Color(0xFFCACEDB);    // oklch(83.923% 0.012 257.651)

  // ── Base (fonds et textes) ────────────────────────────────────────────────
  static const Color base100        = Color(0xFFFFFFFF);   // oklch(100% 0 0) — Fond carte
  static const Color base200        = Color(0xFFF0F4F8);   // oklch(97.466% 0.011 259.822) — Fond page
  static const Color base300        = Color(0xFFDDE3ED);   // oklch(93.268% 0.016 262.751) — Divider
  static const Color baseContent    = Color(0xFF4A5568);   // oklch(41.886% 0.053 255.824) — Texte principal
  static const Color baseContentMid = Color(0xFF8896AA);   // ~60% opacity dérivé
  static const Color baseContentLow = Color(0xFFB0BAC8);   // ~40% opacity dérivé

  // ── Sémantique (DaisyUI winter = PASTELS, pas des couleurs vives) ─────────
  // oklch(80.494% 0.077 197.823) → #A8DDD6 (teal pastel)
  static const Color success        = Color(0xFFA8DDD6);
  static const Color successContent = Color(0xFF13201F);    // oklch(16.098% 0.015 197.823)
  static const Color successLight   = Color(0xFFE5F6F4);   // variante très claire

  // oklch(89.172% 0.045 71.47) → #F2DFBC (beige pastel)
  static const Color warning        = Color(0xFFF2DFBC);
  static const Color warningContent = Color(0xFF1C1810);    // oklch(17.834% 0.009 71.47)
  static const Color warningLight   = Color(0xFFFAF2E4);   // variante très claire

  // oklch(73.092% 0.11 20.076) → #D97A72 (rose muted)
  static const Color error          = Color(0xFFD97A72);
  static const Color errorContent   = Color(0xFF200F0E);    // oklch(14.618% 0.022 20.076)
  static const Color errorLight     = Color(0xFFF5E2E1);   // variante très claire

  // oklch(88.127% 0.085 214.515) → #B3E5F5 (bleu ciel pastel)
  static const Color info           = Color(0xFFB3E5F5);
  static const Color infoContent    = Color(0xFF1A2E35);    // oklch(17.625% 0.017 214.515)
  static const Color infoLight      = Color(0xFFE4F5FB);   // variante très claire

  // ── Bordures ──────────────────────────────────────────────────────────────
  static const Color border         = Color(0xFFDDE3ED);   // = base300

  // ── Overlay ───────────────────────────────────────────────────────────────
  static const Color overlay        = Color(0x801A253A);   // neutral à 50%

  // ── Blanc / Noir ─────────────────────────────────────────────────────────
  static const Color white          = Color(0xFFFFFFFF);
  static const Color black          = Color(0xFF000000);

  // ── Transparent ───────────────────────────────────────────────────────────
  static const Color transparent    = Color(0x00000000);

  // ── Statuts badge ────────────────────────────────────────────────────────
  static Color statusColor(String statut) {
    switch (statut.toLowerCase()) {
      case 'confirmee':
      case 'confirmé':
      case 'active':
      case 'actif':
      case 'ouvert':
      case 'approuve':
        return success;
      case 'en_attente':
      case 'en attente':
      case 'en_cours':
      case 'en cours':
      case 'pending':
        return warning;
      case 'annulee':
      case 'annulé':
      case 'rejete':
      case 'rejeté':
      case 'bloque':
      case 'blocked':
        return error;
      case 'termine':
      case 'terminé':
      case 'closed':
        return baseContentMid;
      default:
        return info;
    }
  }

  static Color statusBgColor(String statut) {
    switch (statut.toLowerCase()) {
      case 'confirmee':
      case 'confirmé':
      case 'active':
      case 'actif':
      case 'ouvert':
      case 'approuve':
        return successLight;
      case 'en_attente':
      case 'en attente':
      case 'en_cours':
      case 'en cours':
      case 'pending':
        return warningLight;
      case 'annulee':
      case 'annulé':
      case 'rejete':
      case 'rejeté':
      case 'bloque':
      case 'blocked':
        return errorLight;
      case 'termine':
      case 'terminé':
      case 'closed':
        return base200;
      default:
        return infoLight;
    }
  }
}
