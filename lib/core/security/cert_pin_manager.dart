import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart' as crypto;
import '../database/database_helper.dart';
import '../../services/logger_service.dart';

/// Résultat de la vérification d'un pin certificat.
enum CertPinResult {
  /// Premier contact — pin stocké (Trust on First Use).
  trusted,

  /// Pin correspond au pin stocké.
  verified,

  /// Certificat renouvelé mais CA connue → auto-rotation.
  rotated,

  /// Tout a changé, CA inconnue → bloqué.
  rejected,

  /// Erreur réseau (hôte injoignable, etc.).
  networkError,
}

/// Gestionnaire automatique de certificate pinning.
///
/// Principe TOFU (Trust on First Use) + auto-rotation :
/// 1. Première connexion : on stocke le hash du certificat en BDD
/// 2. Connexions suivantes : on compare le hash avec celui stocké
/// 3. Si le hash a changé mais que la CA est connue → rotation automatique
/// 4. Si la CA est inconnue → bloqué + alerte utilisateur
///
/// La vérification TLS normale (chaîne de confiance) est faite par le système.
/// On ajoute un layer de pinning par-dessus.
class CertPinManager {
  static final CertPinManager instance = CertPinManager._();
  CertPinManager._();

  final _db = DatabaseHelper.instance;
  final _log = AppLogger.instance;

  /// Cache mémoire des pins vérifiés (host → hash + timestamp).
  /// Évite de reconnecter à chaque requête.
  final Map<String, _CachedPin> _cache = {};

  /// Durée de validité du cache (24h).
  static const _cacheTtl = Duration(hours: 24);

  /// CAs connues pour nos domaines. Si le cert est signé par une de ces CAs,
  /// on accepte la rotation automatique.
  static const _trustedIssuers = {
    // Infomaniak
    'CN=Sectigo',
    "CN=Let's Encrypt",
    'O=Let\'s Encrypt',
    'CN=R3',
    'CN=R10',
    'CN=R11',
    'CN=R12',
    'CN=E5',
    'CN=E6',
    // Notion
    'O=Google Trust Services',
    'CN=WE1',
    'CN=WR2',
    'CN=GTS CA',
  };

  /// Vérifie le certificat d'un hôte, avec auto-rotation.
  ///
  /// Retourne [CertPinResult] indiquant le résultat.
  /// En cas de [CertPinResult.rotated], le nouveau pin est déjà stocké.
  Future<CertPinResult> verifyHost(String host, {int port = 443}) async {
    // Check cache d'abord
    final cached = _cache[host];
    if (cached != null &&
        DateTime.now().difference(cached.verifiedAt) < _cacheTtl) {
      return CertPinResult.verified;
    }

    try {
      // Connexion TLS pour récupérer le certificat
      // Le système vérifie la chaîne de confiance normalement
      final socket = await SecureSocket.connect(
        host,
        port,
        timeout: const Duration(seconds: 10),
      );

      final cert = socket.peerCertificate;
      await socket.close();

      if (cert == null) {
        _log.warning('CertPin', 'No certificate received from $host');
        return CertPinResult.networkError;
      }

      // Hash SHA-256 du certificat DER complet
      final derHash = base64.encode(crypto.sha256.convert(cert.der).bytes);

      // Récupérer le pin stocké en BDD
      final storedPin = await _db.getCertPin(host);

      if (storedPin == null) {
        // ── TOFU : premier contact, on fait confiance ──
        await _db.upsertCertPin(
          host: host,
          derSha256: derHash,
          issuer: cert.issuer.toString(),
          subject: cert.subject.toString(),
          expiresAt: cert.endValidity,
        );
        _cache[host] = _CachedPin(derHash, DateTime.now());
        _log.info(
          'CertPin',
          'TOFU: Stored initial pin for $host',
          'Hash: $derHash\nIssuer: ${cert.issuer}\nExpires: ${cert.endValidity}',
        );
        return CertPinResult.trusted;
      }

      final storedHash = storedPin['der_sha256'] as String;

      if (storedHash == derHash) {
        // ── Pin identique — tout va bien ──
        await _db.touchCertPin(host);
        _cache[host] = _CachedPin(derHash, DateTime.now());
        return CertPinResult.verified;
      }

      // ── Le certificat a changé ! ──
      final issuer = cert.issuer.toString();
      final isTrustedCA = _trustedIssuers.any(
        (ca) => issuer.contains(ca),
      );

      if (isTrustedCA) {
        // CA connue → rotation automatique & transparente
        await _db.upsertCertPin(
          host: host,
          derSha256: derHash,
          issuer: issuer,
          subject: cert.subject.toString(),
          expiresAt: cert.endValidity,
        );
        _cache[host] = _CachedPin(derHash, DateTime.now());
        _log.info(
          'CertPin',
          'Auto-rotated pin for $host (CA: $issuer)',
          'Old: $storedHash\nNew: $derHash\nExpires: ${cert.endValidity}',
        );
        return CertPinResult.rotated;
      }

      // CA inconnue → BLOQUER
      _log.error(
        'CertPin',
        'REJECTED: Unknown CA for $host — possible MITM!',
        'Expected CA matching: $_trustedIssuers\n'
            'Got issuer: $issuer\n'
            'Old hash: $storedHash\n'
            'New hash: $derHash',
      );
      return CertPinResult.rejected;
    } on SocketException catch (e) {
      _log.warning('CertPin', 'Network error verifying $host', e.toString());
      return CertPinResult.networkError;
    } on HandshakeException catch (e) {
      _log.error('CertPin', 'TLS handshake failed for $host', e.toString());
      return CertPinResult.rejected;
    } catch (e) {
      _log.warning('CertPin', 'Cert check error for $host', e.toString());
      return CertPinResult.networkError;
    }
  }

  /// Vérifie tous les hôtes connus (Infomaniak + Notion si configurés).
  /// Appelé au démarrage de l'app.
  Future<Map<String, CertPinResult>> verifyAllKnown() async {
    final results = <String, CertPinResult>{};
    final pins = await _db.getAllCertPins();

    for (final pin in pins) {
      final host = pin['host'] as String;
      results[host] = await verifyHost(host);
    }
    return results;
  }

  /// Vérifie les hôtes Infomaniak (API + CalDAV).
  Future<bool> verifyInfomaniak() async {
    final r1 = await verifyHost('api.infomaniak.com');
    final r2 = await verifyHost('sync.infomaniak.com');
    return r1 != CertPinResult.rejected && r2 != CertPinResult.rejected;
  }

  /// Vérifie l'hôte Notion.
  Future<bool> verifyNotion() async {
    final r = await verifyHost('api.notion.com');
    return r != CertPinResult.rejected;
  }

  /// Force le renouvellement du pin pour un hôte (ex: après mise à jour manuelle).
  Future<void> resetPin(String host) async {
    await _db.deleteCertPin(host);
    _cache.remove(host);
    _log.info('CertPin', 'Pin reset for $host — next connection will TOFU');
  }

  /// Supprime tous les pins stockés.
  Future<void> resetAll() async {
    await _db.clearAllCertPins();
    _cache.clear();
    _log.info('CertPin', 'All pins reset');
  }

  /// Invalide le cache mémoire (utile après un long idle).
  void invalidateCache() {
    _cache.clear();
  }
}

class _CachedPin {
  final String hash;
  final DateTime verifiedAt;
  _CachedPin(this.hash, this.verifiedAt);
}
