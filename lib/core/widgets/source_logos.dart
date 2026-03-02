import 'package:flutter/material.dart';

/// Logos officiels des sources (Infomaniak, Notion) — assets PNG.
class SourceLogos {
  SourceLogos._();

  /// Choisit le bon asset PNG en fonction de la taille demandée.
  /// Toujours prendre la résolution >= 2x la taille affichée pour la netteté HiDPI.
  static String _pickAsset(String prefix, double size) {
    // Sélectionne la résolution la plus adaptée (2x pour HiDPI)
    final needed = size * 2;
    if (needed <= 16) return 'assets/logos/${prefix}_16x16.png';
    if (needed <= 32) return 'assets/logos/${prefix}_32x32.png';
    if (needed <= 48) return 'assets/logos/${prefix}_48x48.png';
    if (needed <= 64) return 'assets/logos/${prefix}_64x64.png';
    if (needed <= 128) return 'assets/logos/${prefix}_128x128.png';
    if (needed <= 256) return 'assets/logos/${prefix}_256x256.png';
    return 'assets/logos/${prefix}_512x512.png';
  }

  /// Résolution adaptée pour les assets qui plafonnent à 128x128 (ex: Notion).
  static String _pickAssetMax128(String prefix, double size) {
    final needed = size * 2;
    if (needed <= 16) return 'assets/logos/${prefix}_16x16.png';
    if (needed <= 32) return 'assets/logos/${prefix}_32x32.png';
    if (needed <= 48) return 'assets/logos/${prefix}_48x48.png';
    if (needed <= 64) return 'assets/logos/${prefix}_64x64.png';
    return 'assets/logos/${prefix}_128x128.png';
  }

  /// Logo monAgenda (PNG couleur, toujours clair).
  /// Utilise les assets logo_packv3 copiés dans assets/logos/monagenda_*.
  static Widget appLogo({double size = 64}) {
    return Image.asset(
      _pickAsset('monagenda', size),
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => _appLogoFallback(size),
    );
  }

  /// Logo officiel Infomaniak (asset PNG, haute qualité).
  static Widget infomaniak({double size = 16}) {
    return Image.asset(
      _pickAsset('infomaniak', size),
      width: size,
      height: size,
      filterQuality: FilterQuality.high,
      errorBuilder: (_, __, ___) => _infomaniakFallback(size),
    );
  }

  /// Logo officiel Notion (asset PNG, haute qualité).
  /// Max asset disponible : 128x128.
  static Widget notion({double size = 16, bool isDark = false}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.18),
      child: Image.asset(
        _pickAssetMax128('notion', size),
        width: size,
        height: size,
        filterQuality: FilterQuality.high,
        errorBuilder: (_, __, ___) => _notionFallback(size, isDark),
      ),
    );
  }

  /// Badge source avec label (pour la vue détail).
  /// [subtitle] : nom de la BDD Notion (ex. "Agenda des tâches").
  static Widget badge({
    required String source,
    bool isDark = false,
    double logoSize = 14,
    String? subtitle,
  }) {
    String label;
    Color color;
    Widget logo;

    if (source == 'infomaniak') {
      label = 'Infomaniak';
      color = const Color(0xFF0098FF);
      logo = infomaniak(size: logoSize);
    } else if (source == 'notion') {
      label = 'Notion';
      color = isDark ? const Color(0xFF9B9A97) : const Color(0xFF37352F);
      logo = notion(size: logoSize, isDark: isDark);
    } else {
      label = '.ics';
      color = const Color(0xFF787774);
      logo = Icon(Icons.calendar_today, size: logoSize - 2, color: color);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          logo,
          const SizedBox(width: 5),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty)
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.7),
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Fallbacks (au cas où les assets ne sont pas trouvés) ──

  static Widget _appLogoFallback(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFE8505B),
        borderRadius: BorderRadius.circular(size * 0.2),
      ),
      child: Center(
        child: Text(
          'mA',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.38,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  static Widget _infomaniakFallback(double size) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0098FF), Color(0xFF006DD9)],
        ),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          'ik',
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.48,
            fontWeight: FontWeight.w900,
            fontStyle: FontStyle.italic,
            letterSpacing: -0.5,
            height: 1.0,
          ),
        ),
      ),
    );
  }

  static Widget _notionFallback(double size, bool isDark) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2F3437) : Colors.white,
        borderRadius: BorderRadius.circular(size * 0.18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.12),
          width: 0.5,
        ),
      ),
      child: Center(
        child: Text(
          'N',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontSize: size * 0.55,
            fontWeight: FontWeight.w900,
            height: 1.0,
          ),
        ),
      ),
    );
  }
}
