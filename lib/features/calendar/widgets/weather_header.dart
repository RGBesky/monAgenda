import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/models/weather_model.dart';

class WeatherHeader extends StatelessWidget {
  final List<WeatherModel> forecasts;
  final DateTime displayedDate;
  final String cityName;

  const WeatherHeader({
    super.key,
    required this.forecasts,
    required this.displayedDate,
    this.cityName = 'Genève',
  });

  @override
  Widget build(BuildContext context) {
    if (forecasts.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final today = forecasts.firstWhere(
      (f) => _isSameDay(f.date, displayedDate),
      orElse: () => forecasts.first,
    );

    final bg = isDark ? AppColors.darkSurfaceDim : AppColors.lightSurfaceDim;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final subColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          // Icône météo
          _weatherIcon(today.weatherCode, isDark),
          const SizedBox(width: 10),
          // Températures
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${today.temperatureMax.round()}° / ${today.temperatureMin.round()}°',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                  height: 1.2,
                ),
              ),
              Text(
                today.description,
                style: TextStyle(
                  fontSize: 11,
                  color: subColor,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const Spacer(),
          // Ville
          HugeIcon(
            icon: HugeIcons.strokeRoundedLocation01,
            color: subColor,
            size: 13,
          ),
          const SizedBox(width: 3),
          Text(
            cityName,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: subColor,
            ),
          ),
        ],
      ),
    );
  }

  /// Icône matérielle pour le code météo WMO
  static Widget _weatherIcon(int code, bool isDark) {
    List<List<dynamic>> icon;
    Color color;
    if (code == 0) {
      icon = HugeIcons.strokeRoundedSun01;
      color = AppColors.weatherSunny;
    } else if (code <= 3) {
      icon = HugeIcons.strokeRoundedSunCloud02;
      color = AppColors.weatherCloudy;
    } else if (code <= 48) {
      icon = HugeIcons.strokeRoundedCloud;
      color = AppColors.weatherCloudy;
    } else if (code <= 67) {
      icon = HugeIcons.strokeRoundedCloudMidRain;
      color = AppColors.weatherRainy;
    } else if (code <= 77) {
      icon = HugeIcons.strokeRoundedSnow;
      color = isDark ? Colors.white70 : const Color(0xFF90CAF9);
    } else if (code <= 82) {
      icon = HugeIcons.strokeRoundedCloudBigRain;
      color = AppColors.weatherRainy;
    } else {
      icon = HugeIcons.strokeRoundedCloudAngledRainZap;
      color = const Color(0xFFFF9800);
    }
    return HugeIcon(icon: icon, color: color, size: 22);
  }

  /// Prévision pour une semaine (vue semaine).
  static Widget buildWeekRow(
    BuildContext context,
    List<WeatherModel> forecasts,
    DateTime weekStart,
  ) {
    if (forecasts.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: List.generate(7, (i) {
          final day = weekStart.add(Duration(days: i));
          final forecast = forecasts.firstWhereOrNull(
            (f) => _isSameDay(f.date, day),
          );
          if (forecast == null) return const Expanded(child: SizedBox());

          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _weatherIcon(forecast.weatherCode, isDark),
                const SizedBox(height: 2),
                Text(
                  '${forecast.temperatureMax.round()}°',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
