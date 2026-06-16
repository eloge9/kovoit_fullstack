import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'colors.dart';
import 'app_radius.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get lightTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: KColors.primary,
      onPrimary: KColors.primaryContent,
      primaryContainer: Color(0xFFDCEEFF),
      onPrimaryContainer: KColors.primaryDark,
      secondary: KColors.secondary,
      onSecondary: KColors.secondaryContent,
      secondaryContainer: Color(0xFFE8E5F7),
      onSecondaryContainer: KColors.secondary,
      tertiary: KColors.accent,
      onTertiary: KColors.accentContent,
      error: KColors.error,
      onError: KColors.errorContent,
      surface: KColors.base100,
      onSurface: KColors.baseContent,
      surfaceContainerHighest: KColors.base200,
      outline: KColors.border,
      outlineVariant: KColors.base300,
      shadow: KColors.neutral,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Roboto',
      scaffoldBackgroundColor: KColors.base200,

      // AppBar — reprend l'en-tête blanc du Web avec bordure inférieure
      appBarTheme: AppBarTheme(
        backgroundColor: KColors.base100,
        foregroundColor: KColors.baseContent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: KColors.baseContent,
          letterSpacing: -0.2,
        ),
        iconTheme: const IconThemeData(color: KColors.baseContent),
        actionsIconTheme: const IconThemeData(color: KColors.baseContentMid),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        shape: const Border(
          bottom: BorderSide(color: KColors.border, width: 1),
        ),
      ),

      // Card — bg-base-100 rounded-2xl border border-base-200 (pas d'ombre sur le Web)
      cardTheme: CardThemeData(
        elevation: 0,
        color: KColors.base100,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: KRadius.borderLg,
          side: const BorderSide(color: KColors.border),
        ),
        margin: EdgeInsets.zero,
      ),

      // ElevatedButton — btn btn-primary rounded-full
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: KColors.primary,
          foregroundColor: KColors.primaryContent,
          disabledBackgroundColor: KColors.base300,
          disabledForegroundColor: KColors.baseContentMid,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: KRadius.borderFull),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      // OutlinedButton — btn btn-outline rounded-full
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: KColors.primary,
          side: const BorderSide(color: KColors.primary, width: 1.5),
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(borderRadius: KRadius.borderFull),
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),

      // TextButton — btn btn-ghost
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: KColors.primary,
          textStyle: const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(borderRadius: KRadius.borderMd),
        ),
      ),

      // Input — input input-bordered rounded-xl
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: KColors.base100,
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
        labelStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: KColors.baseContent,
        ),
        hintStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: KColors.baseContentLow,
        ),
        errorStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 12,
          color: KColors.error,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        floatingLabelBehavior: FloatingLabelBehavior.never,
      ),

      // Divider — border-base-200
      dividerTheme: const DividerThemeData(
        color: KColors.border,
        thickness: 1,
        space: 0,
      ),

      // Chip — badge DaisyUI
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: KRadius.borderFull),
        labelStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      // ListTile
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 24, vertical: 4),
        minLeadingWidth: 0,
        iconColor: KColors.baseContentMid,
        titleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: KColors.baseContent,
        ),
        subtitleTextStyle: TextStyle(
          fontFamily: 'Roboto',
          fontSize: 12,
          color: KColors.baseContentMid,
        ),
      ),

      // NavigationBar (bottom nav)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: KColors.base100,
        indicatorColor: KColors.primary.withValues(alpha: 0.12),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: KColors.primary, size: 24);
          }
          return const IconThemeData(color: KColors.baseContentMid, size: 24);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontFamily: 'Roboto',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: KColors.primary,
            );
          }
          return const TextStyle(
            fontFamily: 'Roboto',
            fontSize: 11,
            color: KColors.baseContentMid,
          );
        }),
        height: 64,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: KColors.border,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        indicatorShape: RoundedRectangleBorder(
          borderRadius: KRadius.borderFull,
        ),
      ),

      // SnackBar — style alert DaisyUI
      snackBarTheme: SnackBarThemeData(
        backgroundColor: KColors.neutral,
        contentTextStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 14,
          color: KColors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: KRadius.borderMd),
        behavior: SnackBarBehavior.floating,
        elevation: 4,
      ),

      // FloatingActionButton
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: KColors.primary,
        foregroundColor: KColors.primaryContent,
        elevation: 2,
        shape: CircleBorder(),
      ),

      // Progress indicator
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: KColors.primary,
        linearMinHeight: 4,
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return KColors.primary;
          return KColors.base300;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return KColors.primary.withValues(alpha: 0.3);
          }
          return KColors.base300;
        }),
      ),

      // TextSelectionTheme
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: KColors.primary,
        selectionColor: Color(0x40047AFF),
        selectionHandleColor: KColors.primary,
      ),
    );
  }
}
