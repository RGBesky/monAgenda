import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/pointycastle.dart' as pc;

/// Utilitaires de chiffrement AES-256-CBC pour les exports de configuration.
/// Aucune donnée sensible ne transite en clair.
class CryptoUtils {
  CryptoUtils._();

  /// Dérive une clé AES-256 (32 bytes) à partir d'un mot de passe et d'un sel
  /// via PBKDF2 (100 000 itérations, SHA-256).
  static Key deriveKey(String password, Uint8List salt) {
    final pbkdf2 = pc.KeyDerivator('SHA-256/HMAC/PBKDF2')
      ..init(pc.Pbkdf2Parameters(salt, 100000, 32));
    final keyBytes = pbkdf2.process(Uint8List.fromList(utf8.encode(password)));
    return Key(keyBytes);
  }

  /// Chiffre un texte JSON en AES-256-CBC avec dérivation de clé PBKDF2.
  /// Format de sortie : [salt (16 bytes)] + [IV (16 bytes)] + [données chiffrées]
  /// Retourne un Uint8List prêt à être encodé en base64 pour QR code.
  static Uint8List encryptJson(String jsonString, String password) {
    final salt = SecureRandom(16).bytes;
    final iv = IV.fromSecureRandom(16);
    final key = deriveKey(password, salt);

    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));
    final encrypted = encrypter.encrypt(jsonString, iv: iv);

    // Format : [SALT 16] + [IV 16] + [CIPHERTEXT ...]
    final result = Uint8List(16 + 16 + encrypted.bytes.length);
    result.setAll(0, salt);
    result.setAll(16, iv.bytes);
    result.setAll(32, encrypted.bytes);
    return result;
  }

  /// Déchiffre des données AES-256-CBC avec dérivation PBKDF2.
  /// Attend le format : [salt (16 bytes)] + [IV (16 bytes)] + [données chiffrées]
  static String decryptJson(Uint8List data, String password) {
    if (data.length < 33) {
      throw const FormatException('Données chiffrées invalides (trop courtes)');
    }

    final salt = Uint8List.fromList(data.sublist(0, 16));
    final iv = IV(Uint8List.fromList(data.sublist(16, 32)));
    final ciphertext = data.sublist(32);

    final key = deriveKey(password, salt);
    final encrypter = Encrypter(AES(key, mode: AESMode.cbc));

    try {
      return encrypter.decrypt(Encrypted(ciphertext), iv: iv);
    } catch (_) {
      throw const FormatException(
        'Déchiffrement échoué — mot de passe incorrect ou données corrompues',
      );
    }
  }

  /// Chiffre les settings en string base64 compacte pour QR code.
  /// Le QR code ne contient AUCUNE donnée lisible.
  /// Pipeline : JSON → gzip → base64 → AES-256-CBC → base64
  static String encryptToExportString(String jsonString, String password) {
    final compressedBytes = gzip.encode(utf8.encode(jsonString));
    final compressedString = base64Encode(compressedBytes);
    final encrypted = encryptJson(compressedString, password);
    return base64Encode(encrypted);
  }

  /// Déchiffre un export string (base64 → AES-256 → gzip → JSON).
  static String decryptFromExportString(String encoded, String password) {
    final encrypted = base64Decode(encoded);
    final compressedString = decryptJson(encrypted, password);
    final compressedBytes = base64Decode(compressedString);
    final jsonString = utf8.decode(gzip.decode(compressedBytes));
    return jsonString;
  }
}
