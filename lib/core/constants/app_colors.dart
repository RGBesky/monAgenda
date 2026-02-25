import 'package:flutter/material.dart';

class AppColors {
  // Priorités (bordures gauche)
  static const Color priorityUrgent = Color(0xFFE53935);
  static const Color priorityHigh = Color(0xFFFB8C00);
  static const Color priorityNormal = Color(0xFF43A047);
  static const Color priorityLow = Color(0xFF90A4AE);

  // Catégories par défaut (fonds)
  static const Color categoryWork = Color(0xFF1E88E5);
  static const Color categoryPersonal = Color(0xFF43A047);
  static const Color categoryHealth = Color(0xFFE53935);
  static const Color categoryFamily = Color(0xFFFB8C00);
  static const Color categorySport = Color(0xFF00ACC1);
  static const Color categorySocial = Color(0xFF8E24AA);
  static const Color categoryTraining = Color(0xFFF4511E);
  static const Color categoryAdmin = Color(0xFF6D4C41);

  // Hors ligne
  static const Color offlineBanner = Color(0xFFFF6D00);

  // Météo
  static const Color weatherSunny = Color(0xFFFFC107);
  static const Color weatherCloudy = Color(0xFF90A4AE);
  static const Color weatherRainy = Color(0xFF42A5F5);

  // Thème clair
  static const Color lightBackground = Color(0xFFF5F5F5);
  static const Color lightSurface = Colors.white;
  static const Color lightPrimary = Color(0xFF1565C0);

  // Thème sombre
  static const Color darkBackground = Color(0xFF121212);
  static const Color darkSurface = Color(0xFF1E1E1E);
  static const Color darkPrimary = Color(0xFF5C9CE6);

  static Color fromHex(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  static String toHex(Color color) {
    final r = color.red.toRadixString(16).padLeft(2, '0');
    final g = color.green.toRadixString(16).padLeft(2, '0');
    final b = color.blue.toRadixString(16).padLeft(2, '0');
    return '#$r$g$b'.toUpperCase();
  }

  static Color withOpacity(Color color, double opacity) {
    return color.withOpacity(opacity);
  }
}
