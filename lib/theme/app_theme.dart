import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Brand colors — Pastel Palette matching reference design
  static const primary = Color(0xFF6C52EE); // Rich royal violet / purple
  static const primaryLight = Color(0xFFEBE6FA); // Soft active pill background
  static const primaryHover = Color(0xFF5B41DB);
  static const primaryDark = Color(0xFF4C35BA);

  // Pastel accent containers and text/icon colors
  static const pastelPink = Color(0xFFFCE8EF);
  static const pastelPinkText = Color(0xFFE0567A);

  static const pastelBlue = Color(0xFFE3F5FF);
  static const pastelBlueText = Color(0xFF2D9CDB);

  static const pastelMint = Color(0xFFE6F8F0);
  static const pastelMintText = Color(0xFF10B981);

  static const pastelOrange = Color(0xFFFFF3E6);
  static const pastelOrangeText = Color(0xFFF59E0B);

  static const pastelPurple = Color(0xFFF1EDFD);
  static const pastelPurpleText = Color(0xFF6C52EE);

  static const pastelYellow = Color(0xFFFEF9E7);
  static const pastelYellowText = Color(0xFFD97706);

  static const pastelTeal = Color(0xFFE6FAF8);
  static const pastelTealText = Color(0xFF0D9488);

  // Semantic & compatibility aliases
  static const secondary = Color(0xFF2D9CDB);
  static const secondaryLight = Color(0xFFE3F5FF);
  static const accent = Color(0xFF6C52EE);
  static const success = Color(0xFF10B981);
  static const successLight = Color(0xFFE6F8F0);
  static const warning = Color(0xFFF59E0B);
  static const warningLight = Color(0xFFFFF3E6);
  static const danger = Color(0xFFE0567A);
  static const dangerLight = Color(0xFFFCE8EF);

  // Surfaces & Backgrounds
  static const surfaceLight = Color(0xFFF5F3FB); // Soft lavender background
  static const cardLight = Color(0xFFFFFFFF); // Clean white card
  static const sidebarLight = Color(0xFFFAF9FD); // Soft pastel sidebar
  static const borderLight = Color(0xFFEAE5F5); // Ultra subtle border

  static const surfaceDark = Color(0xFF121124); // Deep slate-indigo
  static const cardDark = Color(0xFF1E1D36); // Dark card surface
  static const sidebarDark = Color(0xFF18172E); // Dark sidebar
  static const borderDark = Color(0xFF2C2A4D); // Dark border

  // Text
  static const textPrimaryLight = Color(0xFF1C1939); // Deep dark purple-grey
  static const textSecondaryLight = Color(0xFF7E79A8); // Soft purple-grey
  static const textMutedLight = Color(0xFFA5A1C8);

  static const textPrimaryDark = Color(0xFFF5F3FB);
  static const textSecondaryDark = Color(0xFFA5A1C8);
  static const textMutedDark = Color(0xFF7E79A8);

  // Soft shadows
  static List<BoxShadow> get softShadow => [
        const BoxShadow(
          color: Color(0x0A2B1D61),
          blurRadius: 18,
          offset: Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get cardHoverShadow => [
        const BoxShadow(
          color: Color(0x142B1D61),
          blurRadius: 24,
          offset: Offset(0, 6),
        ),
      ];

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C52EE), Color(0xFF8C75FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient heroGradient = LinearGradient(
    colors: [Color(0xFF6C52EE), Color(0xFF9E86FF), Color(0xFF2D9CDB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient pinkGradient = LinearGradient(
    colors: [Color(0xFFF77099), Color(0xFFE0567A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient blueGradient = LinearGradient(
    colors: [Color(0xFF56CCF2), Color(0xFF2D9CDB)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppIcons {
  // Generic subject icon mapping based on common keywords
  static final Map<String, IconData> keywordMap = {
    'math': Icons.functions_rounded,
    'calculus': Icons.functions_rounded,
    'algebra': Icons.calculate_rounded,
    'stat': Icons.analytics_rounded,
    'science': Icons.biotech_rounded,
    'physics': Icons.bolt_rounded,
    'chemistry': Icons.science_rounded,
    'biology': Icons.eco_rounded,
    'history': Icons.auto_stories_rounded,
    'geo': Icons.public_rounded,
    'law': Icons.gavel_rounded,
    'legal': Icons.gavel_rounded,
    'account': Icons.account_balance_wallet_rounded,
    'tax': Icons.receipt_long_rounded,
    'audit': Icons.fact_check_rounded,
    'finance': Icons.monetization_on_rounded,
    'economic': Icons.trending_up_rounded,
    'cost': Icons.pie_chart_rounded,
    'manage': Icons.business_center_rounded,
    'program': Icons.terminal_rounded,
    'code': Icons.code_rounded,
    'computer': Icons.computer_rounded,
    'data': Icons.dataset_rounded,
    'eng': Icons.translate_rounded,
    'literature': Icons.menu_book_rounded,
    'art': Icons.palette_rounded,
    'med': Icons.medical_services_rounded,
    'health': Icons.favorite_rounded,
    'psych': Icons.psychology_rounded,
    'exam': Icons.assignment_turned_in_rounded,
    'test': Icons.quiz_rounded,
  };

  static const List<IconData> defaultPalette = [
    Icons.menu_book_rounded,
    Icons.school_rounded,
    Icons.lightbulb_rounded,
    Icons.psychology_rounded,
    Icons.assignment_rounded,
    Icons.auto_stories_rounded,
    Icons.calculate_rounded,
    Icons.code_rounded,
    Icons.draw_rounded,
    Icons.science_rounded,
  ];

  // Harmonious pastel color pairs (Container Color, Foreground Color)
  static const List<(Color, Color)> pastelStylePairs = [
    (AppColors.pastelBlue, AppColors.pastelBlueText),
    (AppColors.pastelOrange, AppColors.pastelOrangeText),
    (AppColors.pastelMint, AppColors.pastelMintText),
    (AppColors.pastelPurple, AppColors.pastelPurpleText),
    (AppColors.pastelPink, AppColors.pastelPinkText),
    (AppColors.pastelTeal, AppColors.pastelTealText),
    (AppColors.pastelYellow, AppColors.pastelYellowText),
  ];

  static IconData getIconFromCode(int? codePoint) {
    if (codePoint == null) return Icons.menu_book_rounded;
    for (final icon in defaultPalette) {
      if (icon.codePoint == codePoint) return icon;
    }
    for (final icon in keywordMap.values) {
      if (icon.codePoint == codePoint) return icon;
    }
    return Icons.menu_book_rounded;
  }

  static (IconData, Color, Color) getStyleFor(String name, int index) {
    final lower = name.toLowerCase();
    final pair = pastelStylePairs[index % pastelStylePairs.length];

    for (final entry in keywordMap.entries) {
      if (lower.contains(entry.key)) {
        return (entry.value, pair.$1, pair.$2);
      }
    }
    final icon = defaultPalette[index % defaultPalette.length];
    return (icon, pair.$1, pair.$2);
  }
}

ThemeData buildAppTheme({required bool isDark}) {
  final baseScheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: isDark ? Brightness.dark : Brightness.light,
  );

  final colorScheme = baseScheme.copyWith(
    primary: AppColors.primary,
    secondary: const Color(0xFF8C75FF),
    surface: isDark ? AppColors.cardDark : AppColors.cardLight,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor:
        isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
    textTheme: GoogleFonts.poppinsTextTheme(
      isDark ? ThemeData.dark().textTheme : ThemeData.light().textTheme,
    ),
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor:
          isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      titleTextStyle: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
          width: 1,
        ),
      ),
      color: isDark ? AppColors.cardDark : AppColors.cardLight,
      surfaceTintColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF18172E) : const Color(0xFFFAF9FD),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: isDark ? AppColors.borderDark : AppColors.borderLight,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      hintStyle: GoogleFonts.poppins(
        color: isDark ? AppColors.textMutedDark : AppColors.textMutedLight,
        fontSize: 13,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        textStyle:
            GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: isDark ? const Color(0xFFA899FF) : AppColors.primary,
        side: BorderSide(
            color: isDark ? AppColors.borderDark : AppColors.borderLight,
            width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        textStyle:
            GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 13),
      ),
    ),
  );
}
