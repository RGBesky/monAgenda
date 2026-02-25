import 'package:dio/dio.dart';
import '../core/constants/app_constants.dart';
import '../core/models/weather_model.dart';

/// Service météo basé sur Open-Meteo (open source, sans clé API).
class WeatherService {
  final Dio _dio;
  double? _latitude;
  double? _longitude;

  WeatherService()
      : _dio = Dio(BaseOptions(
          baseUrl: AppConstants.openMeteoApiBase,
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 15),
        ));

  void setLocation({required double latitude, required double longitude}) {
    _latitude = latitude;
    _longitude = longitude;
  }

  /// Récupère les prévisions sur 7 jours.
  Future<List<WeatherModel>> fetchWeekForecast() async {
    if (_latitude == null || _longitude == null) return [];

    try {
      final response = await _dio.get(
        '/forecast',
        queryParameters: {
          'latitude': _latitude,
          'longitude': _longitude,
          'daily': [
            'weathercode',
            'temperature_2m_max',
            'temperature_2m_min',
            'precipitation_probability_max',
          ].join(','),
          'timezone': 'auto',
          'forecast_days': 7,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final daily = data['daily'] as Map<String, dynamic>;
      final times = daily['time'] as List;

      return List.generate(times.length, (i) {
        return WeatherModel.fromJson(data, i);
      });
    } catch (e) {
      // Météo non critique, retourne liste vide en cas d'erreur
      return [];
    }
  }

  /// Récupère la météo pour un jour précis.
  Future<WeatherModel?> fetchDayWeather(DateTime date) async {
    if (_latitude == null || _longitude == null) return null;

    try {
      final dateStr = date.toIso8601String().split('T').first;

      final response = await _dio.get(
        '/forecast',
        queryParameters: {
          'latitude': _latitude,
          'longitude': _longitude,
          'daily': [
            'weathercode',
            'temperature_2m_max',
            'temperature_2m_min',
          ].join(','),
          'hourly': 'temperature_2m',
          'timezone': 'auto',
          'start_date': dateStr,
          'end_date': dateStr,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final times = (data['daily']?['time'] as List?) ?? [];
      if (times.isEmpty) return null;

      return WeatherModel.fromJson(data, 0);
    } catch (e) {
      return null;
    }
  }
}
