class WeatherModel {
  final DateTime date;
  final double temperatureMin;
  final double temperatureMax;
  final double? temperatureCurrent;
  final int weatherCode; // WMO Weather interpretation codes
  final double? precipitationProbability;

  const WeatherModel({
    required this.date,
    required this.temperatureMin,
    required this.temperatureMax,
    this.temperatureCurrent,
    required this.weatherCode,
    this.precipitationProbability,
  });

  String get iconEmoji {
    if (weatherCode == 0) return '☀️';
    if (weatherCode <= 3) return '⛅';
    if (weatherCode <= 48) return '🌫️';
    if (weatherCode <= 67) return '🌧️';
    if (weatherCode <= 77) return '❄️';
    if (weatherCode <= 82) return '🌦️';
    if (weatherCode <= 86) return '🌨️';
    if (weatherCode <= 99) return '⛈️';
    return '🌡️';
  }

  String get description {
    if (weatherCode == 0) return 'Ensoleillé';
    if (weatherCode <= 2) return 'Partiellement nuageux';
    if (weatherCode == 3) return 'Couvert';
    if (weatherCode <= 48) return 'Brouillard';
    if (weatherCode <= 57) return 'Bruine';
    if (weatherCode <= 67) return 'Pluie';
    if (weatherCode <= 77) return 'Neige';
    if (weatherCode <= 82) return 'Averses';
    if (weatherCode <= 86) return 'Neige';
    if (weatherCode <= 99) return 'Orage';
    return 'Inconnu';
  }

  factory WeatherModel.fromJson(Map<String, dynamic> json, int index) {
    final daily = json['daily'] as Map<String, dynamic>;

    return WeatherModel(
      date: DateTime.parse((daily['time'] as List)[index] as String),
      temperatureMin:
          ((daily['temperature_2m_min'] as List)[index] as num).toDouble(),
      temperatureMax:
          ((daily['temperature_2m_max'] as List)[index] as num).toDouble(),
      weatherCode: ((daily['weathercode'] as List)[index] as num).toInt(),
      precipitationProbability: daily['precipitation_probability_max'] != null
          ? ((daily['precipitation_probability_max'] as List)[index] as num)
              .toDouble()
          : null,
    );
  }
}
