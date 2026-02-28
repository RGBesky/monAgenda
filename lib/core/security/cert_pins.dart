/// Certificate pins pour les domaines critiques (CalDAV Infomaniak + Notion).
///
/// Ces SHA-256 des certificats leaf/intermediate sont utilisés pour le
/// certificate pinning afin de protéger contre les attaques MitM sur WiFi public.
///
/// Pour extraire les pins à jour :
///   openssl s_client -connect sync.infomaniak.com:443 < /dev/null 2>/dev/null | \
///     openssl x509 -fingerprint -sha256 -noout
///
/// ATTENTION : Ces pins doivent être mis à jour lors du renouvellement des
/// certificats. Inclure au moins le leaf ET l'intermediate pour survivre
/// à un renouvellement du leaf.

/// Pins SHA-256 pour sync.infomaniak.com (CalDAV).
/// Inclut le leaf et l'intermediate (Let's Encrypt / Sectigo).
const Set<String> kInfomaniakCertPins = {
  // Infomaniak leaf cert SHA-256 (à extraire au moment du build)
  // TODO: Extraire via openssl s_client -connect sync.infomaniak.com:443
  'placeholder_infomaniak_leaf_sha256',
  // Infomaniak intermediate cert SHA-256
  'placeholder_infomaniak_intermediate_sha256',
};

/// Pins SHA-256 pour api.notion.com (API Notion).
const Set<String> kNotionCertPins = {
  // Notion leaf cert SHA-256 (à extraire au moment du build)
  // TODO: Extraire via openssl s_client -connect api.notion.com:443
  'placeholder_notion_leaf_sha256',
};

/// Exception levée quand un certificat ne correspond à aucun pin connu.
class CertificatePinningException implements Exception {
  final String message;
  const CertificatePinningException(this.message);

  @override
  String toString() => 'CertificatePinningException: $message';
}
