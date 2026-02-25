import 'package:flutter/material.dart';
import 'package:collection/collection.dart';
import '../../../core/models/weather_model.dart';

class WeatherHeader extends StatelessWidget {
  final List<WeatherModel> forecasts;
  final DateTime displayedDate;

  const WeatherHeader({
    super.key,
    required this.forecasts,
    required this.displayedDate,
  });

  @override
  Widget build(BuildContext context) {
    if (forecasts.isEmpty) return const SizedBox.shrink();

    final today = forecasts.firstWhere(
      (f) => _isSameDay(f.date, displayedDate),
      orElse: () => forecasts.first,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            today.iconEmoji,
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 8),
          Text(
            '${today.temperatureMax.round()}° / ${today.temperatureMin.round()}°',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          const SizedBox(width: 8),
          Text(
            today.description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  /// Prévision pour une semaine (vue semaine).
  static Widget buildWeekRow(
    BuildContext context,
    List<WeatherModel> forecasts,
    DateTime weekStart,
  ) {
    if (forecasts.isEmpty) return const SizedBox.shrink();

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
                Text(forecast.iconEmoji, style: const TextStyle(fontSize: 14)),
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
