import 'package:flutter/material.dart';

/// Palette "Stabilo Boss × Paper Mate Flair" — 100 couleurs en 10 familles × 10 nuances.
/// Néon → Fluo → Acidulé → Vif → Medium → Doux → Pastel → Pastel doux → Pâle → Glacé.
class AppColors {
  // ══════════════════════════════════════════════════════════════
  //  PALETTE 100 COULEURS — Stabilo Boss + Paper Mate Flair
  //  10 familles × 10 nuances
  //  Néon → Fluo → Acidulé → Vif → Medium → Doux → Pastel → Pastel doux → Pâle → Glacé
  // ══════════════════════════════════════════════════════════════

  // ── 1. ROUGE ──────────────────────────────────────────────
  static const Color redNeon = Color(0xFFFF002B); // Néon électrique
  static const Color redFluo = Color(0xFFFF1744); // Paper Mate Red Flair
  static const Color redAcidule = Color(0xFFFF4D6A); // Bonbon pastèque
  static const Color redVif = Color(0xFFE53935); // Stabilo Original 40
  static const Color redMedium = Color(0xFFEF5350); // Cerise medium
  static const Color redDoux = Color(0xFFE57373); // Corail doux
  static const Color redPastel =
      Color(0xFFF2A5A5); // Stabilo Pastel cerise givrée
  static const Color redPastelDoux = Color(0xFFF5C4C4); // Rose-rouge muté
  static const Color redPale = Color(0xFFFCE4E4); // Blush
  static const Color redGlace = Color(0xFFFFF5F5); // Quasi-blanc rosé

  // ── 2. ROSE ───────────────────────────────────────────────
  static const Color pinkNeon = Color(0xFFFF0080); // Néon shocking pink
  static const Color pinkFluo = Color(0xFFFF4081); // Paper Mate Fuchsia
  static const Color pinkAcidule = Color(0xFFFF6BA0); // Bubblegum
  static const Color pinkVif = Color(0xFFEC407A); // Stabilo Original 56
  static const Color pinkMedium = Color(0xFFF06292); // Magenta doux
  static const Color pinkDoux = Color(0xFFF48FB1); // Rose tendre
  static const Color pinkPastel = Color(0xFFF2A5B8); // Stabilo Pastel rosé
  static const Color pinkPastelDoux = Color(0xFFF8C8D4); // Baby pink muté
  static const Color pinkPale = Color(0xFFFCE4EC); // Rose pâle
  static const Color pinkGlace = Color(0xFFFFF5F8); // Quasi-blanc rosé

  // ── 3. VIOLET ─────────────────────────────────────────────
  static const Color violetNeon = Color(0xFFEA00FF); // Néon ultraviolet
  static const Color violetFluo = Color(0xFFD500F9); // Paper Mate Purple Pop
  static const Color violetAcidule = Color(0xFFBF40FF); // Raisin acidulé
  static const Color violetVif = Color(0xFF9C27B0); // Stabilo Original 55
  static const Color violetMedium = Color(0xFFAB47BC); // Orchidée
  static const Color violetDoux = Color(0xFFBA68C8); // Glycine douce
  static const Color violetPastel = Color(0xFFCCA0DC); // Stabilo Pastel lilas
  static const Color violetPastelDoux = Color(0xFFDFC4EB); // Lavande mutée
  static const Color violetPale = Color(0xFFF3E5F5); // Lavande pâle
  static const Color violetGlace = Color(0xFFFBF5FE); // Quasi-blanc lilas

  // ── 4. BLEU ───────────────────────────────────────────────
  static const Color blueNeon = Color(0xFF0052FF); // Cobalt néon
  static const Color blueFluo = Color(0xFF2979FF); // Paper Mate Blue Flair
  static const Color blueAcidule = Color(0xFF448AFF); // Azur acidulé
  static const Color blueVif = Color(0xFF1E88E5); // Stabilo Original 31
  static const Color blueMedium = Color(0xFF42A5F5); // Ciel d'été
  static const Color blueDoux = Color(0xFF64B5F6); // Bleuet doux
  static const Color bluePastel = Color(0xFF8ABBE6); // Stabilo Pastel brume
  static const Color bluePastelDoux = Color(0xFFBBDEFB); // Baby blue
  static const Color bluePale = Color(0xFFE3F2FD); // Brouillard bleu
  static const Color blueGlace = Color(0xFFF5F9FF); // Quasi-blanc bleuté

  // ── 5. CYAN / TURQUOISE ───────────────────────────────────
  static const Color cyanNeon = Color(0xFF00FFDD); // Turquoise néon
  static const Color cyanFluo = Color(0xFF00E5FF); // Paper Mate Aqua Pop
  static const Color cyanAcidule = Color(0xFF18FFFF); // Cyan acidulé
  static const Color cyanVif = Color(0xFF00ACC1); // Stabilo Original 51
  static const Color cyanMedium = Color(0xFF26C6DA); // Lagon
  static const Color cyanDoux = Color(0xFF4DD0E1); // Aigue-marine douce
  static const Color cyanPastel = Color(0xFF82D2CC); // Stabilo Pastel menthe
  static const Color cyanPastelDoux = Color(0xFFB2EBF2); // Écume mutée
  static const Color cyanPale = Color(0xFFE0F7FA); // Eau glacée
  static const Color cyanGlace = Color(0xFFF3FFFE); // Quasi-blanc aqua

  // ── 6. VERT ───────────────────────────────────────────────
  static const Color greenNeon = Color(0xFF00FF66); // Vert néon électrique
  static const Color greenFluo = Color(0xFF00E676); // Paper Mate Green Flash
  static const Color greenAcidule = Color(0xFF69F0AE); // Menthe acidulée
  static const Color greenVif = Color(0xFF43A047); // Stabilo Original 33
  static const Color greenMedium = Color(0xFF66BB6A); // Prairie
  static const Color greenDoux = Color(0xFF81C784); // Sauge douce
  static const Color greenPastel = Color(0xFF9CD8A8); // Stabilo Pastel sauge
  static const Color greenPastelDoux = Color(0xFFC8E6C9); // Vert muté
  static const Color greenPale = Color(0xFFE8F5E9); // Rosée verte
  static const Color greenGlace = Color(0xFFF5FFF6); // Quasi-blanc vert

  // ── 7. LIME / ANIS ────────────────────────────────────────
  static const Color limeNeon = Color(0xFFB2FF00); // Lime néon
  static const Color limeFluo = Color(0xFFC6FF00); // Paper Mate Lime Flair
  static const Color limeAcidule = Color(0xFFD4E157); // Citron acidulé
  static const Color limeVif = Color(0xFF8BC34A); // Stabilo Original 33/5
  static const Color limeMedium = Color(0xFFA5D645); // Tilleul
  static const Color limeDoux = Color(0xFFAED581); // Lime douce
  static const Color limePastel = Color(0xFFC2DC8C); // Stabilo Pastel anis
  static const Color limePastelDoux = Color(0xFFDCEDC8); // Chartreuse mutée
  static const Color limePale = Color(0xFFF1F8E9); // Chartreuse pâle
  static const Color limeGlace = Color(0xFFFAFFF0); // Quasi-blanc lime

  // ── 8. JAUNE ──────────────────────────────────────────────
  static const Color yellowNeon = Color(0xFFFFFF00); // Jaune néon pur
  static const Color yellowFluo = Color(0xFFFFEA00); // Paper Mate Yellow Flair
  static const Color yellowAcidule = Color(0xFFFFD740); // Or acidulé
  static const Color yellowVif = Color(0xFFFFD600); // Stabilo Original 24
  static const Color yellowMedium = Color(0xFFFFEE58); // Citron doux
  static const Color yellowDoux = Color(0xFFFFF176); // Jaune tendre
  static const Color yellowPastel = Color(0xFFEAE08C); // Stabilo Pastel vanille
  static const Color yellowPastelDoux = Color(0xFFFFF9C4); // Crème mutée
  static const Color yellowPale = Color(0xFFFFFDE7); // Crème solaire
  static const Color yellowGlace = Color(0xFFFFFFF5); // Quasi-blanc jaune

  // ── 9. ORANGE ─────────────────────────────────────────────
  static const Color orangeNeon = Color(0xFFFF6D00); // Orange néon intense
  static const Color orangeFluo = Color(0xFFFF9100); // Paper Mate Orange Flair
  static const Color orangeAcidule = Color(0xFFFFAB40); // Mandarine acidulée
  static const Color orangeVif = Color(0xFFFB8C00); // Stabilo Original 54
  static const Color orangeMedium = Color(0xFFFFA726); // Abricot
  static const Color orangeDoux = Color(0xFFFFB74D); // Ambre doux
  static const Color orangePastel = Color(0xFFFFBD98); // Stabilo Pastel pêche
  static const Color orangePastelDoux = Color(0xFFFFE0B2); // Pêche mutée
  static const Color orangePale = Color(0xFFFFF3E0); // Noisette pâle
  static const Color orangeGlace = Color(0xFFFFFAF5); // Quasi-blanc abricot

  // ── 10. NEUTRE / TERRE ────────────────────────────────────
  static const Color neutralNeon = Color(0xFF546E7A); // Acier sombre
  static const Color neutralFluo = Color(0xFF795548); // Brun profond
  static const Color neutralAcidule = Color(0xFF8D6E63); // Taupe
  static const Color neutralVif = Color(0xFF78909C); // Ardoise bleutée
  static const Color neutralMedium = Color(0xFFA1887F); // Terre chaude
  static const Color neutralDoux = Color(0xFFB0BEC5); // Argent bleuté
  static const Color neutralPastel = Color(0xFFC5B99A); // Sable
  static const Color neutralPastelDoux = Color(0xFFD7CFC0); // Perle
  static const Color neutralPale = Color(0xFFE6D2A8); // Beige
  static const Color neutralGlace = Color(0xFFFAF5EB); // Ivoire

  // ══════════════════════════════════════════════════════════════
  //  LISTE ORDONNÉE pour le color picker (10×10 grille)
  // ══════════════════════════════════════════════════════════════
  static const List<Color> palette100 = [
    // Row 0 – Néon (ultra-fluo criard)
    redNeon, pinkNeon, violetNeon, blueNeon, cyanNeon,
    greenNeon, limeNeon, yellowNeon, orangeNeon, neutralNeon,
    // Row 1 – Fluo (Paper Mate Flair)
    redFluo, pinkFluo, violetFluo, blueFluo, cyanFluo,
    greenFluo, limeFluo, yellowFluo, orangeFluo, neutralFluo,
    // Row 2 – Acidulé (bonbon électrique)
    redAcidule, pinkAcidule, violetAcidule, blueAcidule, cyanAcidule,
    greenAcidule, limeAcidule, yellowAcidule, orangeAcidule, neutralAcidule,
    // Row 3 – Vif (Stabilo Original)
    redVif, pinkVif, violetVif, blueVif, cyanVif,
    greenVif, limeVif, yellowVif, orangeVif, neutralVif,
    // Row 4 – Medium
    redMedium, pinkMedium, violetMedium, blueMedium, cyanMedium,
    greenMedium, limeMedium, yellowMedium, orangeMedium, neutralMedium,
    // Row 5 – Doux
    redDoux, pinkDoux, violetDoux, blueDoux, cyanDoux,
    greenDoux, limeDoux, yellowDoux, orangeDoux, neutralDoux,
    // Row 6 – Pastel (Stabilo Boss Pastel)
    redPastel, pinkPastel, violetPastel, bluePastel, cyanPastel,
    greenPastel, limePastel, yellowPastel, orangePastel, neutralPastel,
    // Row 7 – Pastel doux
    redPastelDoux, pinkPastelDoux, violetPastelDoux, bluePastelDoux,
    cyanPastelDoux,
    greenPastelDoux, limePastelDoux, yellowPastelDoux, orangePastelDoux,
    neutralPastelDoux,
    // Row 8 – Pâle (fond subtil)
    redPale, pinkPale, violetPale, bluePale, cyanPale,
    greenPale, limePale, yellowPale, orangePale, neutralPale,
    // Row 9 – Glacé (quasi-blanc)
    redGlace, pinkGlace, violetGlace, blueGlace, cyanGlace,
    greenGlace, limeGlace, yellowGlace, orangeGlace, neutralGlace,
  ];

  // ══════════════════════════════════════════════════════════════
  //  ALIASES CATÉGORIES (colonne "medium" – la plus lisible)
  // ══════════════════════════════════════════════════════════════
  static const Color categoryWork = blueMedium; // Travail
  static const Color categoryPersonal = greenPastel; // Perso
  static const Color categoryHealth = greenMedium; // Santé
  static const Color categoryFamily = violetPastel; // Famille
  static const Color categorySport = cyanMedium; // Sport
  static const Color categorySocial = pinkMedium; // Social
  static const Color categoryTraining = yellowMedium; // Formation
  static const Color categoryAdmin = neutralPale; // Admin
  static const Color categoryProjects = limeMedium; // Projets
  static const Color categoryLeisure = orangeMedium; // Loisirs

  // ── Priorités (bordure gauche carte événement) ────────────
  static const Color priorityUrgent = redVif; // Rouge vif
  static const Color priorityHigh = orangeVif; // Orange vif
  static const Color priorityNormal = blueVif; // Bleu vif
  static const Color priorityLow = cyanPastel; // Menthe douce

  // Priorités vives pour les blocs calendrier
  static const Color priorityUrgentVivid = redFluo;
  static const Color priorityHighVivid = orangeFluo;
  static const Color priorityNormalVivid = greenFluo;
  static const Color priorityLowVivid = neutralVif;

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
  static const Color lightPrimary = Color(0xFF2383E2); // Notion blue
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

  // ── Mapping couleurs Notion → palette Stabilo/PaperMate ──
  static const Map<String, Color> notionColorMap = {
    'default': bluePastel,
    'gray': neutralPale,
    'brown': neutralAcidule,
    'orange': orangePastel,
    'yellow': yellowPastel,
    'green': greenPastel,
    'blue': bluePastel,
    'purple': violetPastel,
    'pink': pinkPastel,
    'red': redPastel,
    'light gray': neutralGlace,
  };

  /// Convertit un nom de couleur Notion en couleur Stabilo/PaperMate.
  static Color fromNotionColor(String notionColor) {
    return notionColorMap[notionColor.toLowerCase()] ?? bluePastel;
  }

  /// Couleur pour un nom de tag (basée sur la palette 100).
  static Color stabiloForTag(String tagName) {
    final name = tagName.toLowerCase();
    if (name.contains('travail') ||
        name.contains('work') ||
        name.contains('pro')) return blueMedium;
    if (name.contains('famille') || name.contains('family'))
      return violetPastel;
    if (name.contains('sport')) return cyanMedium;
    if (name.contains('santé') || name.contains('health')) return greenMedium;
    if (name.contains('loisir') || name.contains('perso')) return greenPastel;
    if (name.contains('projet') || name.contains('dev')) return limeMedium;
    if (name.contains('urgent')) return redVif;
    if (name.contains('important')) return orangeVif;
    if (name.contains('admin')) return neutralPale;
    if (name.contains('social')) return pinkMedium;
    if (name.contains('formation')) return yellowMedium;
    return bluePastel;
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
