// Certificate pins (SPKI SHA-256 base64) pour les domaines critiques.
//
// Méthode : pin de la clé publique SPKI (Subject Public Key Info),
// pas du certificat entier. Plus résistant aux renouvellements tant
// que la clé privée du serveur ne change pas.
//
// Pour extraire / vérifier un pin :
//   echo | openssl s_client -connect HOST:443 2>/dev/null \
//     | openssl x509 -pubkey -noout \
//     | openssl pkey -pubin -outform DER \
//     | openssl dgst -sha256 -binary | base64
//
// ATTENTION : Mettre à jour ces pins si un domaine change de clé privée.
// On garde leaf + intermediate pour survivre à un renouvellement simple.
//
// Dernière extraction : 01/03/2026.

// Pins SPKI SHA-256 pour Infomaniak (API REST + CalDAV sync).
// - api.infomaniak.com  : leaf *.infomaniak.com (Sectigo, exp 25/02/2027)
// - sync.infomaniak.com : leaf sync.infomaniak.com (Let's Encrypt R12, exp 25/04/2026)
// - Intermediate commun Infomaniak (Sectigo Public Server Auth CA DV R36)
const Set<String> kInfomaniakCertPins = {
  // api.infomaniak.com — leaf SPKI pin (CN=*.infomaniak.com, Sectigo)
  'Ssd/jHGJ3OqEg6/K6iY1iEn201FKSH67WWHL5idnYp8=',
  // sync.infomaniak.com — leaf SPKI pin (CN=sync.infomaniak.com, Let's Encrypt R12)
  'xCow0zf72ea3k4uL7eNlmHKyUK3110jHkWwr4ftfxm4=',
  // Infomaniak intermediate — Sectigo Public Server Auth CA DV R36
  'a9khLOZJxlnJyrxstg/P+seiDCm+Yf3OsrXyFocBaI0=',
};

// Pins SPKI SHA-256 pour Notion (API REST).
// - api.notion.com : leaf (CN=notion.com, Google Trust Services WE1, exp 18/04/2026)
// - Intermediate Google Trust Services WE1
const Set<String> kNotionCertPins = {
  // api.notion.com — leaf SPKI pin (CN=notion.com)
  '6ChH0NMiOiR0QXe/gYrm3bQwIuVGxV/wLQsdJN9WgT0=',
  // Google Trust Services WE1 — intermediate
  'kIdp6NNEd8wsugYyyIYFsi1ylMCED3hZbSR8ZFsa/A4=',
};

/// Exception levée quand un certificat ne correspond à aucun pin connu.
class CertificatePinningException implements Exception {
  final String message;
  const CertificatePinningException(this.message);

  @override
  String toString() => 'CertificatePinningException: $message';
}
