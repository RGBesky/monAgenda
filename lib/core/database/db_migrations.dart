/// Versioning SQLite centralisé.
///
/// RÈGLE ABSOLUE : Toute future migration = incrémenter [kCurrentDbVersion]
/// + ajouter une entrée dans [kMigrations]. Ne jamais modifier une migration existante.
library;

const int kCurrentDbVersion = 14;

/// Chaque clé = numéro de version cible.
/// Chaque valeur = liste de DDL à exécuter pour passer de (version - 1) à version.
final Map<int, List<String>> kMigrations = {
  // --- V1 → V6 gérées par l'ancien _onUpgrade inline (conservé pour compat) ---
  // --- V7 : Smart Attachments (Prompt 4) ---
  7: [
    "ALTER TABLE events ADD COLUMN smart_attachments TEXT DEFAULT '[]'",
  ],
  // --- V8 : Full Text Search FTS5 (Bug 3) ---
  8: [
    "CREATE VIRTUAL TABLE IF NOT EXISTS events_fts USING fts5(title, description, location, content=events, content_rowid=id)",
    "CREATE TRIGGER IF NOT EXISTS events_ai AFTER INSERT ON events BEGIN INSERT INTO events_fts(rowid, title, description, location) VALUES (new.id, new.title, new.description, new.location); END",
    "CREATE TRIGGER IF NOT EXISTS events_au AFTER UPDATE ON events BEGIN INSERT INTO events_fts(events_fts, rowid, title, description, location) VALUES ('delete', old.id, old.title, old.description, old.location); INSERT INTO events_fts(rowid, title, description, location) VALUES (new.id, new.title, new.description, new.location); END",
    "CREATE TRIGGER IF NOT EXISTS events_ad AFTER DELETE ON events BEGIN INSERT INTO events_fts(events_fts, rowid, title, description, location) VALUES ('delete', old.id, old.title, old.description, old.location); END",
    // Remplissage initial de la table FTS à partir des données existantes
    "INSERT OR IGNORE INTO events_fts(rowid, title, description, location) SELECT id, title, COALESCE(description,''), COALESCE(location,'') FROM events WHERE is_deleted = 0",
  ],
  // --- V9 : Magic Feedback (Prompt 14) ---
  9: [
    "CREATE TABLE IF NOT EXISTS magic_feedback (id INTEGER PRIMARY KEY AUTOINCREMENT, input_text TEXT NOT NULL, ia_output_json TEXT NOT NULL, corrected_output_json TEXT NOT NULL, created_at TEXT NOT NULL DEFAULT (datetime('now')))",
  ],
  // --- V10 : Safety re-add smart_attachments (column may be missing if V9 was set before V7 migration ran) ---
  10: [
    "ALTER TABLE events ADD COLUMN smart_attachments TEXT DEFAULT '[]'",
  ],
  // --- V11 : Magic Habits — apprentissage des habitudes utilisateur (messe → Saint-Défendent) ---
  11: [
    """CREATE TABLE IF NOT EXISTS magic_habits (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      keyword TEXT NOT NULL,
      field_name TEXT NOT NULL,
      field_value TEXT NOT NULL,
      usage_count INTEGER DEFAULT 1,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    )""",
    "CREATE UNIQUE INDEX IF NOT EXISTS idx_magic_habits_keyword_field ON magic_habits(keyword, field_name)",
  ],
  // --- V12 : cert_pins — auto-rotation TOFU des certificats TLS ---
  12: [
    """CREATE TABLE IF NOT EXISTS cert_pins (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      host TEXT NOT NULL UNIQUE,
      der_sha256 TEXT NOT NULL,
      issuer TEXT,
      subject TEXT,
      expires_at TEXT,
      first_seen TEXT NOT NULL,
      last_verified TEXT NOT NULL
    )""",
    "CREATE UNIQUE INDEX IF NOT EXISTS idx_cert_pins_host ON cert_pins(host)",
  ],
  // --- V13 : Rattrapage — s'assurer que magic_habits existe (V11 pouvait être sautée) ---
  13: [
    """CREATE TABLE IF NOT EXISTS magic_habits (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      keyword TEXT NOT NULL,
      field_name TEXT NOT NULL,
      field_value TEXT NOT NULL,
      usage_count INTEGER DEFAULT 1,
      created_at TEXT NOT NULL DEFAULT (datetime('now')),
      updated_at TEXT NOT NULL DEFAULT (datetime('now'))
    )""",
    "CREATE UNIQUE INDEX IF NOT EXISTS idx_magic_habits_keyword_field ON magic_habits(keyword, field_name)",
  ],
  // --- V14 : Migration couleurs iOS → Stabilo Boss × Paper Mate Flair ---
  14: [
    // Catégories : iOS → Stabilo/PaperMate medium/pastel
    "UPDATE tags SET color_hex = '#42A5F5' WHERE color_hex = '#007AFF' AND type = 'category'",   // Travail
    "UPDATE tags SET color_hex = '#9CD8A8' WHERE color_hex = '#34C759' AND type = 'category'",   // Perso
    "UPDATE tags SET color_hex = '#66BB6A' WHERE color_hex = '#FF3B30' AND type = 'category'",   // Santé (was red)
    "UPDATE tags SET color_hex = '#CCA0DC' WHERE color_hex = '#FF9500' AND type = 'category'",   // Famille (was orange)
    "UPDATE tags SET color_hex = '#26C6DA' WHERE color_hex = '#30B0C7' AND type = 'category'",   // Sport
    "UPDATE tags SET color_hex = '#F06292' WHERE color_hex = '#AF52DE' AND type = 'category'",   // Social (was purple)
    "UPDATE tags SET color_hex = '#FFEE58' WHERE color_hex = '#FFCC00' AND type = 'category'",   // Formation
    "UPDATE tags SET color_hex = '#E6D2A8' WHERE color_hex = '#8E8E93' AND type = 'category'",   // Admin (was gray)
    // Priorités : iOS → Stabilo vif
    "UPDATE tags SET color_hex = '#E53935' WHERE color_hex = '#FF3B30' AND type = 'priority'",   // Urgent
    "UPDATE tags SET color_hex = '#FB8C00' WHERE color_hex = '#FF9500' AND type = 'priority'",   // Haute
    "UPDATE tags SET color_hex = '#1E88E5' WHERE color_hex = '#34C759' AND type = 'priority'",   // Normale (was green)
    "UPDATE tags SET color_hex = '#82D2CC' WHERE color_hex = '#8E8E93' AND type = 'priority'",   // Basse (was gray)
    // Statuts : rafraîchir les médium
    "UPDATE tags SET color_hex = '#FFEE58' WHERE color_hex = '#EAE08C' AND type = 'status'",    // En cours → yellowMedium
  ],
};
