import '../core/database/database_helper.dart';

/// Niveaux de log.
enum LogLevel { debug, info, warning, error }

/// Logger centralisé V2 — écrit en BDD au lieu de print().
/// Permet l'affichage d'un indicateur d'erreur dans les paramètres.
class AppLogger {
  static final AppLogger instance = AppLogger._internal();
  final DatabaseHelper _db = DatabaseHelper.instance;

  AppLogger._internal();

  /// Log de debug (non persisté en prod, juste pour développement).
  void debug(String source, String message, [String? details]) {
    // En debug, on peut activer le print si besoin
    assert(() {
      // ignore: avoid_print
      print('🐛 [$source] $message');
      return true;
    }());
  }

  /// Log d'information.
  void info(String source, String message, [String? details]) {
    _db.insertSystemLog(
      level: 'info',
      source: source,
      message: message,
      details: details,
    );
  }

  /// Log d'avertissement.
  void warning(String source, String message, [String? details]) {
    _db.insertSystemLog(
      level: 'warning',
      source: source,
      message: message,
      details: details,
    );
  }

  /// Log d'erreur.
  void error(String source, String message, [Object? error]) {
    _db.insertSystemLog(
      level: 'error',
      source: source,
      message: message,
      details: error?.toString(),
    );
  }
}
