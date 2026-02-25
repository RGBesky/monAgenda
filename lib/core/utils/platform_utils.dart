import 'package:flutter/foundation.dart';
import 'dart:io';

class PlatformUtils {
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isLinux => !kIsWeb && Platform.isLinux;
  static bool get isWeb => kIsWeb;
  static bool get isDesktop =>
      !kIsWeb && (Platform.isLinux || Platform.isMacOS || Platform.isWindows);
  static bool get isMobile =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static bool get supportsPptExport => isLinux;
  static bool get supportsAndroidWidget => isAndroid;
  static bool get supportsContacts => isAndroid;

  static String get platformName {
    if (isAndroid) return 'Android';
    if (isLinux) return 'Linux';
    return 'Inconnu';
  }
}
