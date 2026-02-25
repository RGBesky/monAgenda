import 'package:flutter/material.dart';

/// Palette vivante Apple Calendar / TeamUp — couleurs vives, lisibles, joyeuses.
class AppColors {
  // ── Palette vivante (Apple Calendar) ──────────────────────
  static const Color categoryRed = Color(0xFFFF3B30);
  static const Color categoryOrange = Color(0xFFFF9500);
  static const Color categoryYellow = Color(0xFFFFCC00);
  static const Color categoryGreen = Color(0xFF34C759);
  static const Color categoryMint = Color(0xFF00C7BE);
  static const Color categoryTeal = Color(0xFF30B0C7);
  static const Color categoryBlue = Color(0xFF007AFF);
  static const Color categoryIndigo = Color(0xFF5856D6);
  static const Color categoryPurple = Color(0xFFAF52DE);
  static const Color categoryPink = Color(0xFFFF2D55);
  static const Color categoryBrown = Color(0xFFA2845E);
  static const Color categoryGray = Color(0xFF8E8E93);

  // Aliases sémantiques (pour compat)
  static const Color categoryWork = categoryBlue;
  static const Color categoryPersonal = categoryGreen;
  static const Color categoryHealth = categoryRed;
  static const Color categoryFamily = categoryOrange;
  static const Color categorySport = categoryTeal;
  static const Color categorySocial = categoryPurple;
  static const Color categoryTraining = categoryYellow;
  static const Color categoryAdmin = categoryGray;

  // ── Priorités ─────────────────────────────────────────────
  static const Color priorityUrgent = Color(0xFFFF3B30);
  static const Color priorityHigh = Color(0xFFFF9500);
  static const Color priorityNormal = Color(0xFF34C759);
  static const Color priorityLow = Color(0xFF8E8E93);

  // ── Sources ───────────────────────────────────────────────
  static const Color sourceInfomaniak = Color(0xFF0098FF);
  static const Color sourceNotion = Color(0xFF000000);
  static const Color sourceIcs = Color(0xFF8E8E93);

  // ── Hors ligne ────────────────────────────────────────────
  static const Color offlineBanner = Color(0xFFFF6D00);

  // ── Météo ─────────────────────────────────────────────────
  static const Color weatherSunny = Color(0xFFFAC515);
  static const Color weatherCloudy = Color(0xFF90A4AE);
  static const Color weatherRainy = Color(0xFF42A5F5);

  // ── Thème clair ───────────────────────────────────────────
  static const Color lightBackground = Color(0xFFF7F6F3);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceDim = Color(0xFFF1F0ED);
  static const Color lightPrimary = Color(0xFF007AFF);
  static const Color lightOutline = Color(0xFFE3E2DE);
  static const Color lightText = Color(0xFF37352F);
  static const Color lightTextSecondary = Color(0xFF787774);
  static const Color lightTextTertiary = Color(0xFF9B9A97);

  // ── Thème sombre ──────────────────────────────────────────
  static const Color darkBackground = Color(0xFF191919);
  static const Color darkSurface = Color(0xFF202020);
  static const Color darkSurfaceDim = Color(0xFF2D2D2D);
  static const Color darkPrimary = Color(0xFF0A84FF);
  static const Color darkOutline = Color(0xFF373737);
  static const Color darkText = Color(0xFFE8E7E4);
  static const Color darkTextSecondary = Color(0xFF9B9A97);
  static const Color darkTextTertiary = Color(0xFF6B6B6B);

  // ── Mapping couleurs Notion → palette vivante ─────────────
  static const Map<String, Color> notionColorMap = {
    'default': categoryBlue,
    'gray': categoryGray,
    'brown': categoryBrown,
    'orange': categoryOrange,
    'yellow': categoryYellow,
    'green': categoryGreen,
    'blue': categoryBlue,
    'purple': categoryPurple,
    'pink': categoryPink,
    'red': categoryRed,
    'light gray': Color(0xFFC7C7CC),
  };

  /// Convertit un nom de couleur Notion en Color vivante.
  static Color fromNotionColor(String notionColor) {
    return notionColorMap[notionColor.toLowerCase()] ?? categoryBlue;
  }

  /// Fond pastel Apple Calendar — doux mais coloré.
  static Color pastelBg(Color accent, {bool isDark = false}) {
    return isDark
        ? Color.lerp(accent, const Color(0xFF202020), 0.75)!
        : Color.lerp(accent, Colors.white, 0.72)!;
  }

  /// Texte sur fond pastel — assombri pour la lisibilité.
  static Color textOnPastel(Color accent, {bool isDark = false}) {
    if (isDark) {
      return Color.lerp(accent, Colors.white, 0.4)!;
    }
    final luminance = accent.computeLuminance();
    if (luminance > 0.45) {
      return Color.lerp(accent, const Color(0xFF37352F), 0.6)!;
    }
    return Color.lerp(accent, const Color(0xFF37352F), 0.18)!;
  }

  /// Fond rempli (style TeamUp) — pas trop agressif.
  static Color filledBg(Color accent, {bool isDark = false}) {
    return isDark
        ? Color.lerp(accent, const Color(0xFF202020), 0.45)!
        : Color.lerp(accent, Colors.white, 0.18)!;
  }

  /// Texte sur fond filledBg — blanc ou noir selon contraste.
  static Color textOnFilled(Color accent, {bool isDark = false}) {
    final bg = filledBg(accent, isDark: isDark);
    return ThemeData.estimateBrightnessForColor(bg) == Brightness.dark
        ? Colors.white
        : const Color(0xFF37352F);
  }

  static Color fromHex(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  static String toHex(Color color) {
    final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#$r$g$b'.toUpperCase();
  }

  static Color withOpacity(Color color, double opacity) {
    return color.withValues(alpha: opacity);
  }
}
