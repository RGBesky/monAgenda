import 'package:flutter/material.dart';

/// Palette "Stabilo Boss" — highlighters doux et vibrants pour les tags/catégories.
/// Inspiré du design system "Organic & Unified".
class AppColors {
  // ── Palette Stabilo Boss v2 (Tags & Catégories) ───────────
  // Teintes redistribuées tous les ~37° pour un contraste optimal
  static const Color stabiloBeige =
      Color(0xFFE6D2A8); // 40° Sable chaud – Admin / Autre
  static const Color stabiloLilac =
      Color(0xFFCCA0DC); // 285° Orchidée – Famille
  static const Color stabiloBlue =
      Color(0xFF8ABBE6); // 212° Ciel d'été – Travail
  static const Color stabiloMint =
      Color(0xFF82D2CC); // 172° Menthe glacée – Sport
  static const Color stabiloGreen =
      Color(0xFF9CD8A8); // 130° Sauge fraîche – Santé
  static const Color stabiloLime = Color(0xFFC2DC8C); // 82° Tilleul – Projets
  static const Color stabiloYellow =
      Color(0xFFEAE08C); // 55° Citron doux – Loisirs
  static const Color stabiloOrange =
      Color(0xFFFFBD98); // 22° Pêche douce – Important
  static const Color stabiloPink =
      Color(0xFFF2A5B8); // 350° Rose poudré – Urgent

  // ── Aliases catégories (Stabilo) ──────────────────────────
  static const Color categoryWork = stabiloBlue;
  static const Color categoryPersonal = stabiloGreen;
  static const Color categoryHealth = stabiloGreen;
  static const Color categoryFamily = stabiloLilac;
  static const Color categorySport = stabiloMint;
  static const Color categorySocial = stabiloPink;
  static const Color categoryTraining = stabiloYellow;
  static const Color categoryAdmin = stabiloBeige;
  static const Color categoryProjects = stabiloLime;
  static const Color categoryLeisure = stabiloYellow;

  // Palette vivante conservée pour les blocs calendrier (SfCalendar)
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

  // ── Priorités (bordure gauche carte événement) ────────────
  static const Color priorityUrgent = stabiloPink; // Rose vif
  static const Color priorityHigh = stabiloOrange; // Orange
  static const Color priorityNormal = stabiloBlue; // Bleu doux
  static const Color priorityLow = stabiloMint; // Vert menthe

  // Priorités vives pour les blocs calendrier
  static const Color priorityUrgentVivid = Color(0xFFFF3B30);
  static const Color priorityHighVivid = Color(0xFFFF9500);
  static const Color priorityNormalVivid = Color(0xFF34C759);
  static const Color priorityLowVivid = Color(0xFF8E8E93);

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

  // ── Mapping couleurs Notion → palette Stabilo ────────────
  static const Map<String, Color> notionColorMap = {
    'default': stabiloBlue,
    'gray': stabiloBeige,
    'brown': stabiloBeige,
    'orange': stabiloOrange,
    'yellow': stabiloYellow,
    'green': stabiloGreen,
    'blue': stabiloBlue,
    'purple': stabiloLilac,
    'pink': stabiloPink,
    'red': stabiloPink,
    'light gray': Color(0xFFE4E4E4),
  };

  /// Convertit un nom de couleur Notion en couleur Stabilo.
  static Color fromNotionColor(String notionColor) {
    return notionColorMap[notionColor.toLowerCase()] ?? stabiloBlue;
  }

  /// Couleur Stabilo pour un nom de tag.
  static Color stabiloForTag(String tagName) {
    final name = tagName.toLowerCase();
    if (name.contains('travail') ||
        name.contains('work') ||
        name.contains('pro')) return stabiloBlue;
    if (name.contains('famille') || name.contains('family'))
      return stabiloLilac;
    if (name.contains('sport')) return stabiloMint;
    if (name.contains('santé') || name.contains('health')) return stabiloGreen;
    if (name.contains('loisir') || name.contains('perso')) return stabiloYellow;
    if (name.contains('projet') || name.contains('dev')) return stabiloLime;
    if (name.contains('urgent')) return stabiloPink;
    if (name.contains('important')) return stabiloOrange;
    if (name.contains('admin')) return stabiloBeige;
    return stabiloBlue;
  }

  /// Texte foncé sur fond Stabilo (les couleurs Stabilo sont claires).
  static Color textOnStabilo(Color stabilo) {
    final luminance = stabilo.computeLuminance();
    return luminance > 0.3
        ? const Color(0xFF37352F) // Texte sombre
        : const Color(0xFF37352F); // Stabilo toujours clair => texte sombre
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
