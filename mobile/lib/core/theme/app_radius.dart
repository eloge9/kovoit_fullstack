import 'package:flutter/material.dart';

/// Rayons de bordure — fidèles au Web (DaisyUI/Tailwind)
class KRadius {
  KRadius._();

  // rounded-lg  = 8px
  static const double sm    = 8.0;
  // rounded-xl  = 12px  (input, tag, nav active)
  static const double md    = 12.0;
  // rounded-2xl = 16px  (cards, sections)
  static const double lg    = 16.0;
  // rounded-3xl = 24px
  static const double xl    = 24.0;
  // rounded-full = 9999px (badges, boutons CTA, avatar)
  static const double full  = 99.0;

  // BorderRadius helpers
  static BorderRadius get borderSm   => BorderRadius.circular(sm);
  static BorderRadius get borderMd   => BorderRadius.circular(md);
  static BorderRadius get borderLg   => BorderRadius.circular(lg);
  static BorderRadius get borderXl   => BorderRadius.circular(xl);
  static BorderRadius get borderFull => BorderRadius.circular(full);
}
