/// Espacements KoVoit — extraits du Web (Tailwind spacing scale)
class KSpacing {
  KSpacing._();

  // Tailwind scale : gap-1=4, gap-2=8, gap-3=12, gap-4=16, gap-6=24, gap-8=32, p-6=24, px-6=24
  static const double xs   =  4.0;   // gap-1
  static const double sm   =  8.0;   // gap-2
  static const double md   = 12.0;   // gap-3
  static const double lg   = 16.0;   // gap-4
  static const double xl   = 24.0;   // gap-6 / p-6
  static const double xxl  = 32.0;   // gap-8
  static const double xxxl = 40.0;   // gap-10

  // Padding de page (px-4 mobile = 16, px-8 desktop = 32)
  static const double pagePaddingH = 16.0;
  static const double pagePaddingV = 16.0;

  // Padding de card (card-body = p-6)
  static const double cardPadding   = 24.0;

  // Padding header de card (px-6 py-4)
  static const double cardHeaderH   = 24.0;
  static const double cardHeaderV   = 16.0;

  // Padding row de liste (px-6 py-4)
  static const double rowH          = 24.0;
  static const double rowV          = 16.0;

  // Padding row compact (px-6 py-3)
  static const double rowCompactV   = 12.0;

  // Taille avatar
  static const double avatarSm      = 28.0;
  static const double avatarMd      = 36.0;
  static const double avatarLg      = 48.0;

  // Bottom nav height
  static const double bottomNavH    = 64.0;

  // AppBar height
  static const double appBarH       = 56.0;
}
