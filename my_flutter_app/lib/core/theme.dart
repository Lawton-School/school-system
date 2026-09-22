import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ── Shared brand colours ─────────────────────────────────────────
  static const Color primary      = Color(0xFF6557F5); // Stitch Primary
  static const Color primaryLight = Color(0xFF818CF8);
  static const Color primaryDark  = Color(0xFF4C3ADB);
  static const Color primarySoft  = Color(0xFFF0EEFF);
  static const Color secondary    = Color(0xFF10B981); // Emerald
  static const Color accent       = Color(0xFFF59E0B); // Amber
  static const Color danger       = Color(0xFFEF4444);
  static const Color success      = Color(0xFF10B981);
  static const Color warning      = Color(0xFFF59E0B);
  static const Color info         = Color(0xFF2563EB);

  // ── Stitch Design Tokens ─────────────────────────────────────────
  static const Color stitchHeading     = Color(0xFF172033);
  static const Color stitchMuted       = Color(0xFF74809A);
  static const Color stitchBorder      = Color(0xFFE2E8F0);
  static const Color stitchBg          = Color(0xFFF6F7FB);
  static const Color stitchSurface     = Color(0xFFFFFFFF);
  static const Color stitchSuccessSoft = Color(0xFFECFDF5);
  static const Color stitchSuccessText = Color(0xFF047857);
  static const Color stitchWarnSoft    = Color(0xFFFFFBEB);
  static const Color stitchWarnText    = Color(0xFFB45309);
  static const Color stitchDangerSoft  = Color(0xFFFEF2F2);
  static const Color stitchDangerText  = Color(0xFFB91C1C);
  static const Color stitchInfoSoft    = Color(0xFFEFF6FF);
  static const Color stitchInfoText    = Color(0xFF185BBC);

  // ── Dark palette ─────────────────────────────────────────────────
  static const Color backgroundDark = Color(0xFF0A0E1A);
  static const Color surfaceDark    = Color(0xFF111827);
  static const Color cardDark       = Color(0xFF1A2236);
  static const Color borderDark     = Color(0xFF1F2D45);
  static const Color textPrimary    = Color(0xFFF8FAFC);
  static const Color textSecondary  = Color(0xFF94A3B8);
  static const Color textMuted      = Color(0xFF475569);

  // ── Light palette ────────────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFF8F9FB);
  static const Color surfaceLight    = Color(0xFFFFFFFF);
  static const Color cardLight       = Color(0xFFFFFFFF);
  static const Color borderLight     = Color(0xFFE8ECF0);
  static const Color textPrimaryL    = Color(0xFF0F172A);
  static const Color textSecondaryL  = Color(0xFF64748B);
  static const Color textMutedL      = Color(0xFFADB5C0);

  // ── DARK THEME ───────────────────────────────────────────────────
  static ThemeData get darkTheme => _build(dark: true);

  // ── LIGHT THEME ──────────────────────────────────────────────────
  static ThemeData get lightTheme => _build(dark: false);

  static ThemeData _build({required bool dark}) {
    final bg     = dark ? backgroundDark : backgroundLight;
    final card   = dark ? cardDark       : cardLight;
    final border = dark ? borderDark     : borderLight;
    final tp     = dark ? textPrimary    : textPrimaryL;
    final ts     = dark ? textSecondary  : textSecondaryL;
    final tm     = dark ? textMuted      : textMutedL;
    final base   = dark ? ThemeData.dark() : ThemeData.light();

    return ThemeData(
      useMaterial3: true,
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bg,
      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge:  GoogleFonts.inter(color: tp, fontWeight: FontWeight.w700, fontSize: 32, letterSpacing: -1.0),
        displayMedium: GoogleFonts.inter(color: tp, fontWeight: FontWeight.w700, fontSize: 28, letterSpacing: -0.75),
        headlineLarge: GoogleFonts.inter(color: tp, fontWeight: FontWeight.w700, fontSize: 24, letterSpacing: -0.5),
        headlineMedium:GoogleFonts.inter(color: tp, fontWeight: FontWeight.w600, fontSize: 20),
        titleLarge:    GoogleFonts.inter(color: tp, fontWeight: FontWeight.w600, fontSize: 18),
        titleMedium:   GoogleFonts.inter(color: tp, fontWeight: FontWeight.w500, fontSize: 16),
        bodyLarge:     GoogleFonts.inter(color: tp, fontSize: 16),
        bodyMedium:    GoogleFonts.inter(color: ts, fontSize: 14),
        bodySmall:     GoogleFonts.inter(color: tm, fontSize: 12),
      ),
      colorScheme: dark
          ? const ColorScheme.dark(
              primary: primary, onPrimary: Colors.white,
              secondary: secondary, onSecondary: Colors.white,
              surface: surfaceDark, onSurface: textPrimary,
              error: danger, onError: Colors.white,
            )
          : ColorScheme.light(
              primary: primary, onPrimary: Colors.white,
              secondary: secondary, onSecondary: Colors.white,
              surface: surfaceLight, onSurface: textPrimaryL,
              error: danger, onError: Colors.white,
              outline: borderLight,
              surfaceContainerHighest: const Color(0xFFF1F5F9),
            ),
      appBarTheme: AppBarTheme(
        backgroundColor: dark ? backgroundDark : surfaceLight,
        elevation: 0,
        scrolledUnderElevation: dark ? 0 : 1,
        shadowColor: dark ? Colors.transparent : borderLight,
        centerTitle: false,
        titleTextStyle: GoogleFonts.inter(color: tp, fontWeight: FontWeight.w700, fontSize: 20),
        iconTheme: IconThemeData(color: tp),
      ),
      cardTheme: CardThemeData(
        color: card,
        elevation: dark ? 0 : 0,
        shadowColor: dark ? Colors.transparent : const Color(0x0A000000),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? surfaceDark : const Color(0xFFF8F9FB),
        hintStyle: GoogleFonts.inter(color: tm, fontSize: 14),
        labelStyle: GoogleFonts.inter(color: ts, fontSize: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: danger),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: dark ? surfaceDark : surfaceLight,
        selectedItemColor: primary,
        unselectedItemColor: tm,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? surfaceDark : surfaceLight,
        indicatorColor: primary.withAlpha(40),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return GoogleFonts.inter(color: primary, fontSize: 11, fontWeight: FontWeight.w600);
          }
          return GoogleFonts.inter(color: tm, fontSize: 11);
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: primary, size: 22);
          }
          return IconThemeData(color: tm, size: 22);
        }),
      ),
    );
  }
}
