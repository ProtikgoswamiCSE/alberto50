import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ─── Horror After Dark Color Palette ──────────────────────────────────────
  static const Color bgDark     = Color(0xFF0A0A0A); // Jet black
  static const Color bgCard     = Color(0xFF111111); // Dark card
  static const Color bgElevated = Color(0xFF1A1212); // Dark red-tinted
  static const Color bgOverlay  = Color(0xCC000000); // Semi-transparent black

  static const Color accent      = Color(0xFFE31212); // Blood red (CTAs)
  static const Color accentDark  = Color(0xFF9B0000); // Dark crimson
  static const Color accentLight = Color(0xFFFF4444); // Lighter red

  static const Color gold      = Color(0xFFC4962A); // Crown gold
  static const Color goldLight = Color(0xFFDAA520); // Brighter gold

  static const Color purple      = Color(0xFF7B2FBE); // Pagination purple
  static const Color purpleLight = Color(0xFF9B59B6);

  static const Color success = Color(0xFF06D6A0);
  static const Color danger  = Color(0xFFFF1744);
  static const Color warning = Color(0xFFFFB703);

  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFCCCCCC);
  static const Color textMuted     = Color(0xFF888888);
  static const Color textDim       = Color(0xFF555555);

  static const Color divider     = Color(0xFF2A1A1A); // Dark red-black divider
  static const Color dividerRed  = Color(0xFF3D0000); // Featured section border

  // Section header left-border (like "FEATURED" on site)
  static const Color sectionBorder = accent;

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgDark,
      focusColor: gold.withValues(alpha: 0.28),
      highlightColor: gold.withValues(alpha: 0.16),
      colorScheme: const ColorScheme.dark(
        primary: accent,
        secondary: gold,
        surface: bgCard,
        error: danger,
        onPrimary: Colors.white,
        onSecondary: Colors.black,
        onSurface: textPrimary,
      ),
      textTheme: _buildTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.cinzel(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.5,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bgCard,
        selectedItemColor: accent,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: GoogleFonts.raleway(
            fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.raleway(fontSize: 11),
      ),
      cardTheme: CardThemeData(
        color: bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: divider, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1A1A1A),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: danger),
        ),
        hintStyle: GoogleFonts.raleway(color: textMuted, fontSize: 14),
        labelStyle:
            GoogleFonts.raleway(color: textSecondary, fontSize: 14),
        prefixIconColor: textMuted,
        suffixIconColor: textMuted,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30), // pill shape like site
          ),
          textStyle: GoogleFonts.raleway(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
          elevation: 0,
        ).copyWith(
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return const BorderSide(color: gold, width: 3);
            }
            return BorderSide.none;
          }),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return gold.withValues(alpha: 0.22);
            }
            return null;
          }),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          side: const BorderSide(color: accent, width: 1.5),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          textStyle: GoogleFonts.raleway(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ).copyWith(
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return const BorderSide(color: gold, width: 3);
            }
            return const BorderSide(color: accent, width: 1.5);
          }),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: textPrimary,
        ).copyWith(
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return accent.withValues(alpha: 0.35);
            }
            return null;
          }),
          side: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.focused)) {
              return const BorderSide(color: gold, width: 2);
            }
            return BorderSide.none;
          }),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: bgCard,
        contentTextStyle: GoogleFonts.raleway(color: textPrimary),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: dividerRed, width: 1),
        ),
      ),
    );
  }

  static TextTheme _buildTextTheme() {
    return TextTheme(
      // Large gothic headers — Cinzel (closest to site's horror font)
      displayLarge: GoogleFonts.cinzel(
        color: textPrimary,
        fontSize: 36,
        fontWeight: FontWeight.w900,
        letterSpacing: 2,
      ),
      displayMedium: GoogleFonts.cinzel(
        color: textPrimary,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.5,
      ),
      displaySmall: GoogleFonts.cinzel(
        color: textPrimary,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
      headlineMedium: GoogleFonts.cinzel(
        color: textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
      headlineSmall: GoogleFonts.cinzel(
        color: textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.5,
      ),
      // Body — Raleway (clean sans-serif, matches site nav/body)
      bodyLarge: GoogleFonts.raleway(
        color: textPrimary,
        fontSize: 15,
        fontWeight: FontWeight.w400,
      ),
      bodyMedium: GoogleFonts.raleway(
        color: textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      bodySmall: GoogleFonts.raleway(
        color: textMuted,
        fontSize: 12,
        fontWeight: FontWeight.w400,
      ),
      labelLarge: GoogleFonts.raleway(
        color: textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.5,
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  /// The hero background image asset path.
  static const String heroBg = 'assets/images/bg.png';

  /// Blood-red gradient used on hero/splash overlays.
  static const LinearGradient heroGradient = LinearGradient(
    colors: [
      Color(0xE6000000), // 90% black top
      Color(0x99000000), // 60% black middle
      Color(0xCC000000), // 80% black bottom
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.5, 1.0],
  );

  /// Gradient overlay for card thumbnails — keeps text readable.
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Colors.transparent, Color(0xDD000000)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.4, 1.0],
  );

  /// Featured section header decoration (red left-border like site).
  static BoxDecoration sectionHeaderDecoration(BuildContext context) {
    return const BoxDecoration(
      border: Border(left: BorderSide(color: accent, width: 4)),
    );
  }
}
