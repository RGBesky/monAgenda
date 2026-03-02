# MANIFEST monAgenda — Mars 2026
## Document de référence unique · Philosophie · Historique · Architecture · Roadmap

> **Auteur :** RGBesky  
> **Dépôt :** https://github.com/RGBesky/monAgenda  
> **Date :** 02/03/2026  
> **HEAD :** `2488295` · 62 fichiers Dart · ~26 500 lignes  
> **Documents archivés :** Tous les anciens documents de référence sont dans `archive/`

---

## TABLE DES MATIÈRES

1. [Philosophie du projet](#1--philosophie-du-projet)
2. [Historique des versions](#2--historique-des-versions)
3. [Architecture technique](#3--architecture-technique)
4. [Matrice des fonctionnalités](#4--matrice-des-fonctionnalités)
5. [Décisions architecturales](#5--décisions-architecturales)
6. [État du code de référence](#6--état-du-code-de-référence)
7. [Règles absolues pour l'IA de production](#7--règles-absolues-pour-lia-de-production)
8. [Leçons apprises](#8--leçons-apprises--erreurs-interdites)
9. [Roadmap](#9--roadmap)
10. [Documents archivés](#10--documents-archivés)

---

## 1 — PHILOSOPHIE DU PROJET

### Vision

**monAgenda** est né d'un constat simple : aucune application existante ne combine nativement Infomaniak Calendar (souveraineté européenne des données), Notion (gestion des tâches et projets) et les calendriers .ics publics dans une interface unifiée, fonctionnant à la fois sur Android et Linux Desktop.

L'objectif est de **remplacer totalement Outlook Calendar et Google Calendar** par une solution personnelle, souveraine et unifiée.

### Principes fondamentaux

1. **Souveraineté des données** — Aucun serveur tiers. Les données transitent uniquement entre l'application et Infomaniak/Notion. Pas de tracking, pas d'analytics, pas de Cloud IA. L'IA est 100% locale (llama.cpp + GGUF).

2. **Offline-first** — L'application fonctionne sans connexion. Les modifications sont mises en queue (`sync_queue`) et synchronisées au retour réseau. L'utilisateur n'est jamais bloqué.

3. **Timeline unifiée** — Pas de séparation "Pro" / "Perso", ni "Tâches" / "Rendez-vous". Tout est sur une seule timeline fluide. Les sources (Infomaniak, Notion, ICS) sont identifiées visuellement mais cohabitent dans les mêmes vues.

4. **L'app est l'autorité** — monAgenda est la source de vérité pour les tags (noms, couleurs, mappings). Elle impose sa structure vers Infomaniak (CATEGORIES/PRIORITY iCalendar) et Notion (Multi-select/Select).

5. **Design "The Notion Way"** — Inspiré de la philosophie d'Ivan Zhao : *"Software should be tool-making."* L'interface s'efface pour laisser place au contenu. Design calme, structuré, espaces blancs généreux, frontières subtiles. Pas de dégradés agressifs ni d'ombres lourdes. Palette Stabilo Boss × Paper Mate Flair (10 familles × 10 nuances).

6. **Séparation Desktop / Mobile** — Le mobile sert à la consultation éclair et la création rapide. Le Desktop est l'usine à planification : Time Blocking, drag & drop, Meeting Notes, exports lourds (PPT, CSV).

7. **Zéro permission intrusive** — Pas d'accès aux contacts téléphoniques. Pas de partage natif OS. Les participants et le partage sont délégués à CalDAV/Notion. RGPD respectée nativement.

8. **Sécurité par défaut** — Base SQLite chiffrée (SQLCipher), credentials dans flutter_secure_storage (Android Keystore / libsecret), backup AES-256, certificate pinning TOFU, zéro `print()` en production.

---

## 2 — HISTORIQUE DES VERSIONS

### V0 — Prototype initial (25/02/2026)

**Commit :** `f2eb2b0` → `cf04d3f`

Le tout premier commit. Une application Flutter multi-plateforme fonctionnelle posant les fondations :
- Synchronisation CalDAV Infomaniak (lecture/écriture via Bearer Token)
- Intégration Notion multi-BDD bidirectionnelle
- Calendrier Syncfusion (vues Mois/Semaine/Jour/Agenda)
- Cache SQLite local (6 tables : `events`, `tags`, `event_tags`, `notion_databases`, `ics_subscriptions`, `sync_state`)
- Gestion d'état 100% Riverpod
- Abonnements .ics publics (lecture seule)
- Notifications locales (flutter_local_notifications)
- Recherche avancée avec filtres combinables
- Export .ics, .csv, .pptx (Linux via script Python)
- Météo Open-Meteo
- Thème clair/sombre avec bascule manuelle

**Stack initiale :** Flutter 3.x, Dart 3.x, Riverpod, sqflite, dio, Syncfusion, flutter_secure_storage, flutter_contacts, share_plus.

---

### V1 — Release initiale (26/02/2026)

**Tag :** `cf04d3f` — *v1.0.0 — Release monAgenda*

Première version stable. Ajouts par rapport à V0 :
- Tri personnalisable par calendrier
- Filtre Todo par source
- Fix tags et rattachements

---

### V2 — Refonte UX + Offline-first (27/02/2026)

**Commits :** `272276b` → `a5d8a13`

Session intensive de consolidation UX et implémentation du mode offline complet :
- **Sync Queue offline-first** : table `sync_queue` (9 colonnes), `SyncQueueWorker` (210 lignes), Optimistic UI dans `EventsNotifier`
- **System logs** : table `system_logs`, `AppLogger` silencieux (zéro `print()`), vue `SystemLogsScreen`
- **46 SnackBars persistants** — clé globale `scaffoldMessengerKey`, remplacement des dialogs bloquants
- **Dark mode corrigé** — 8 corrections contraste (icônes, texte, tags, chips, error banner)
- **Logos Infomaniak/Notion** — intégrés dans sidebar, event cards, settings
- **Notion multi-description** — `descriptionProperties` = `List<String>` (JSON en SQLite)
- **kDrive backup** — `BackupService` AES-256 via lien de dépôt (local OK, upload endpoint KO)
- **workmanager 0.6.0** — tâches périodiques 6h + reschedule immédiat
- **Locale fr_FR + Europe/Paris** hardcodées
- **Auto-sync debounce 5s** au retour réseau + fallback Timer 60s pour Linux
- **FAB 3 états** (vert/orange/rouge) toggle mode avion app
- **Build APK** : 95 Mo · **Build .deb** : 18 Mo

**Audit :** `bilan27022026.md` (commit `a5d8a13` — 107 fichiers, +6 388 / −1 069 lignes)

---

### V2.5 — Décisions architecturales + IA embarquée (28/02/2026)

**Commits :** `1697934` → `f4cc6bb`

Session de décisions structurantes documentée dans `manifest28022026.md` :

**Décisions prises :**
1. **Suppression `flutter_contacts` + `share_plus`** — participants délégués à CalDAV/Notion
2. **IA 100% locale** — llama.cpp FFI + H2O Danube 3 500M (q4_k_m, ~400 Mo, GGUF)
3. **Séparation stricte Desktop/Mobile** — matrice 18 features avec répartition
4. **Pipeline QR = AES-256** (CryptoUtils) — méthode gzip+base64 = `@Deprecated`
5. **sqflite → sqflite_sqlcipher** — chiffrement AES-256 at rest
6. **Versioning SQLite centralisé** — `db_migrations.dart` + `kMigrations`

**Implémentation IA Saisie Magique :**
- Intégration Danube 3 LLM comme parser principal (`6f8a142`)
- Mode LLM-first, regex fallback si modèle indisponible (`b86cd92`)
- Title generation + magic_habits auto-learning (`8f3c451`)
- Fix dates relatives, descriptions, mapping matin/soir (`119be65`, `9dc7003`, `f4cc6bb`)

---

### V3 — Sécurité + Refonte UX (01-02/03/2026)

**Commits :** `98f9b7f` → `d300ca8` (HEAD actuel)

Session de hardening sécurité puis refonte UX complète :

**Phase 0 — Sécurité (complète ✅) :**
- Certificate pinning TOFU auto-rotation (zéro mise à jour manuelle des certs) (`5d88c76`)
- Chiffrement desktop SQLCipher (`a835d35`)
- Backup PBKDF2-HMAC-SHA256 100k iter + salt 32B — remplace `padRight(32, '0')` (`5a27b7d`)
- Suppression méthodes @Deprecated (secrets en base64 clair)
- Fix `DatabaseHelper.close()` (singleton fermé)
- `FlutterError.onError` + `PlatformDispatcher.instance.onError` + `ProviderObserver`
- Gestion logs BDD : auto-trim 1000 entrées, purge 7j, filtrage par niveau (`7ed0bcd`)

**Phase 1 — Bugs critiques (complète ✅) :**
- SearchScreen connecté au bouton + Ctrl+F (`e47f332`)
- `copyWith` NotionTaskModel : tous les champs (`c9ff093`)
- `EventModel.props` Equatable : 27 champs (`c9ff093`)
- Source magic entry dynamique, WidgetService post-CRUD, deleteEvent SQL direct
- Versioning SQLite centralisé `kCurrentDbVersion=12` + `kMigrations`
- Timer leaks corrigés (dispose), N+1 queries → batch JOIN
- FTS5 migration V8 + fallback LIKE
- Déduplication `sync_queue` (DELETE UPDATE pending avant INSERT)

**Phase 2 — UX/Ergonomie (en cours) :**
- Boutons "Ouvrir Notion" / "Ouvrir Infomaniak" dans sidebar (`7d45657`)
- Vrais logos PNG partout — tailles optimisées 14-28px (`ebf27fb`, `7d45657`)
- Mode AMOLED true black #000000 (`ebf27fb`)
- Fix 18 overflow issues (`ebf27fb`)
- Palette 100 couleurs Stabilo Boss × Paper Mate Flair (10×10) (`1ede402`)
- Cards Notion-like (elevation 0, border subtile, borderRadius 3px)
- TextFields harmonisés (filled, fond Notion, borderRadius 8)
- Police Inter appliquée partout via Google Fonts

**Meeting Note Notion + Smart Context PDF** déjà en place (desktop only).

---

## 3 — ARCHITECTURE TECHNIQUE

### Stack

| Composant | Technologie |
|---|---|
| Langage | Dart 3.x |
| Framework UI | Flutter 3.x |
| Calendrier | `syncfusion_flutter_calendar` (Community License) |
| HTTP | `dio` |
| Cache local | `sqflite_sqlcipher` (chiffré AES-256) |
| Secrets | `flutter_secure_storage` (Android Keystore / libsecret) |
| State Management | `flutter_riverpod` (100% — zéro `provider.dart`) |
| Notifications | `flutter_local_notifications` |
| Background | `workmanager` (Android), Timer natif (Linux) |
| Météo | Open-Meteo (HTTP direct, sans clé API) |
| Widget Android | `home_widget` |
| IA locale | `llama.cpp` via FFI + GGUF + GBNF |
| QR Code | `qr_flutter` (export) + `mobile_scanner` (import) |
| Icônes | `hugeicons` (Stroke Rounded) |
| Typographie | `google_fonts` (Inter) |

### Plateformes

| Plateforme | Statut | Build |
|---|---|---|
| Android (API 26+) | ✅ | APK ~95 Mo (cible <40 Mo) |
| Linux Desktop (Ubuntu 22+) | ✅ | .deb ~18 Mo |
| iOS / Windows / macOS / Web | ❌ Non ciblés | — |

### Architecture des services

```
Flutter App (Android + Linux)
│
├── InfomaniakService     → CalDAV Bearer Token, CRUD événements
├── NotionService         → API Notion v1, lecture/écriture multi-BDD
├── IcsService            → Parse/export .ics publics
├── SyncEngine            → Orchestrateur (last-write-wins)
├── SyncQueueWorker       → Dépilage offline → API
├── WeatherService        → Open-Meteo
├── NotificationService   → Programmation alertes locales
├── BackupService         → Export/import AES-256 + kDrive
├── WidgetService         → Widget Android 7 jours (home_widget)
├── MagicEntryService     → Saisie Magique NLP (llama.cpp + Danube 3)
├── ModelDownloadService  → Téléchargement on-demand du .gguf
├── NotionMeetingService  → Création auto de Meeting Notes Notion
└── LoggerService         → AppLogger → table system_logs
```

### Structure du code

```
lib/
├── main.dart                          # Entrée + error observers
├── app.dart                           # Shell + navigation + thèmes M3
├── core/
│   ├── constants/                     # AppConstants, AppColors
│   ├── database/                      # DatabaseHelper, db_migrations
│   ├── models/                        # EventModel, TagModel, NotionTaskModel
│   ├── security/                      # CryptoUtils, CertPinManager
│   ├── utils/                         # DateUtils, PlatformUtils
│   └── widgets/                       # Composants réutilisables
├── services/                          # 14 services métier
├── providers/                         # Riverpod providers (4 fichiers)
│   ├── settings_provider.dart
│   ├── events_provider.dart
│   ├── tags_provider.dart
│   └── sync_provider.dart
└── features/
    ├── calendar/                      # Vues calendrier + agenda
    ├── events/                        # Formulaire + détail + popup
    ├── import/                        # Import QR/ICS
    ├── magic/                         # Saisie Magique NLP
    ├── project/                       # Vue Projet (Desktop)
    ├── search/                        # Recherche avancée
    ├── settings/                      # 7 sous-écrans paramètres
    └── setup/                         # Onboarding 3 étapes
```

---

## 4 — MATRICE DES FONCTIONNALITÉS

### Légende
- 📱 Téléphone uniquement · 💻 Bureau uniquement · 🔁 Les deux
- ✅ Implémenté · ⚠️ Partiel · 🔴 À implémenter

### Core — Base de données & Architecture

| Feature | Plateforme | Statut |
|---|---|---|
| Base SQLite chiffrée (SQLCipher, 8+ tables, dbVersion=12) | 🔁 | ✅ |
| EventModel complet (27 champs, etag, participants, smart_attachments) | 🔁 | ✅ |
| State Management 100% Riverpod (AsyncNotifier, StreamProvider, FutureProvider.family) | 🔁 | ✅ |
| Mode Offline forcé manuellement (forceOfflineProvider) | 🔁 | ✅ |
| Auto-sync debounce 5s au retour réseau | 🔁 | ✅ |
| Fallback sync périodique 60s (Linux) | 💻 | ✅ |
| Versioning SQLite centralisé (db_migrations.dart) | 🔁 | ✅ |
| Purge auto logs > 7j + cap 1000 entrées | 🔁 | ✅ |
| Locale fr_FR + Timezone Europe/Paris | 🔁 | ✅ |
| AppLogger silencieux (zéro print(), badge dans réglages) | 🔁 | ✅ |
| FlutterError.onError + ProviderObserver | 🔁 | ✅ |
| FTS5 (Full Text Search) avec fallback LIKE | 🔁 | ✅ |

### Synchronisation Cloud

| Feature | Plateforme | Statut |
|---|---|---|
| Sync CalDAV Infomaniak (lecture/écriture) | 🔁 | ✅ |
| Sync Queue offline-first (Optimistic UI) | 🔁 | ✅ |
| Déduplication sync_queue (écrasement UPDATE pending) | 🔁 | ✅ |
| Sync Notion API (lecture/écriture multi-bases) | 🔁 | ✅ |
| Validation Schéma Notion au démarrage | 🔁 | ✅ |
| Abonnements ICS externes | 🔁 | ✅ |
| Bannière "X actions en attente" | 🔁 | ✅ |
| FAB 3 états (vert/orange/rouge) | 🔁 | ✅ |
| Conflits ETag (HTTP 412) — last-remote-wins | 🔁 | ✅ |
| Bannière serveur saturé (429/500/503) | 🔁 | ✅ |

### Sécurité

| Feature | Plateforme | Statut |
|---|---|---|
| flutter_secure_storage (AES-256 Android, libsecret Linux) | 🔁 | ✅ |
| Export QR chiffré AES-256 avec password | 🔁 | ✅ |
| Import QR par scan (mobile_scanner) | 📱 | ✅ |
| clearAllCredentials() | 🔁 | ✅ |
| Certificate pinning TOFU auto-rotation | 🔁 | ✅ |
| SQLite chiffré at rest (SQLCipher) | 🔁 | ✅ |
| Backup PBKDF2-HMAC-SHA256 (100k iter + salt 32B) | 🔁 | ✅ |

### Interface Utilisateur

| Feature | Plateforme | Statut |
|---|---|---|
| Thème Dark + AMOLED (#000000) + Light (Material 3) | 🔁 | ✅ |
| Palette 100 couleurs Stabilo (10×10 grille) | 🔁 | ✅ |
| Police Inter (Google Fonts) | 🔁 | ✅ |
| Vue Mensuelle / Hebdomadaire / Jour / Agenda | 🔁 | ✅ |
| Drag & drop calendrier (snap 15min, undo SnackBar) | 🔁 | ✅ |
| Resize événement (snap 15min, min 15min) | 🔁 | ✅ |
| Formulaire complet (pickers, chips, tags, récurrence) | 🔁 | ✅ |
| SnackBars persistants sans blocage navigation | 🔁 | ✅ |
| Logos PNG Infomaniak/Notion partout | 🔁 | ✅ |
| Empty states (agenda, search, logs) | 🔁 | ✅ |
| Météo Open-Meteo (vue jour/semaine) | 🔁 | ✅ |

### Fonctionnalités Natives OS

| Feature | Plateforme | Statut |
|---|---|---|
| Notifications push (15 min avant) | 🔁 | ✅ |
| Background sync via workmanager / Timer Linux | 🔁 | ✅ |
| QR Code export/import paramètres | 🔁 | ✅ |
| Home Widget Android (7 jours) — Service Dart | 📱 | ⚠️ |
| Home Widget Android — Côté natif Kotlin/XML | 📱 | 🔴 |

### Import / Export

| Feature | Plateforme | Statut |
|---|---|---|
| Import ICS direct (file picker) | 🔁 | ✅ |
| Export CSV | 💻 | ✅ |
| Export PPT (script Python) | 💻 | ✅ |
| Export QR Code | 🔁 | ✅ |
| Import QR d'événements (merge) | 🔁 | 🔴 |

### IA — Saisie Magique

| Feature | Plateforme | Statut |
|---|---|---|
| Saisie Magique NLP (llama.cpp + Danube 3 + Isolate) | 🔁 | ✅ |
| Regex-first hybride (~80% des cas sans LLM) | 🔁 | ✅ |
| Magic habits auto-learning | 🔁 | ✅ |
| Grammaire GBNF enforcement | 🔁 | 🔴 |
| Validateur post-IA (title, dates, category) | 🔁 | 🔴 |
| Feedback loop (table magic_feedback) | 🔁 | 🔴 |
| Déchargement mémoire post-inférence | 🔁 | 🔴 |
| ModelDownloadService (SHA-256, progress, reprise) | 🔁 | 🔴 |

### Features Desktop Only

| Feature | Plateforme | Statut |
|---|---|---|
| Meeting Note Notion (créer/ouvrir compte-rendu) | 💻 | ✅ |
| Smart Context PDF (attachements fichiers) | 💻 | ✅ |
| Vue Projet + Time Blocking Drag & Drop | 💻 | ✅ |
| Raccourcis clavier (Ctrl+N/K/F/S/,, Échap) | 💻 | ✅ |
| Export PPT via Python Process.run | 💻 | ✅ |

---

## 5 — DÉCISIONS ARCHITECTURALES

### D1 — Suppression plugins sociaux natifs (28/02/2026)
`flutter_contacts` et `share_plus` supprimés. Participants et partage délégués à CalDAV (ATTENDEE) et Notion. Zéro permission OS superflue. Commité `1697934`.

### D2 — IA 100% locale — llama.cpp + H2O Danube 3 500M (28/02/2026)
Pas de TFLite (incompatible LLM). Pas d'API Cloud (viole la souveraineté). Modèle H2O Danube 3 500M q4_k_m (~400 Mo GGUF). Fine-tuné extraction info structurée. Meilleure conformité GBNF que Qwen2.5 à ce niveau. Gestion du français court sans drift anglais. Inférence obligatoirement dans un `Isolate.run()`. Modèle téléchargé on-demand (jamais dans l'APK).

### D3 — Séparation Desktop / Mobile (28/02/2026)
UI adaptative via `LayoutBuilder(constraints.maxWidth > 800)`. Features lourdes (Time Blocking, Meeting Note, Export PPT, Smart Context) = Desktop only. Mobile = consultation éclair + saisie rapide + scan QR. `Platform.isX` autorisé pour les processus OS (Python, file picker local).

### D4 — Pipeline QR = AES-256 (28/02/2026)
Export : `JSON → CryptoUtils.encryptToExportString(json, password) → QrImageView(Level.L)`. Import : `scan → password UI → CryptoUtils.decryptFromExportString → jsonDecode`. Méthode gzip+base64 V1 = `@Deprecated`, NE JAMAIS réutiliser.

### D5 — SQLite chiffré (sqflite_sqlcipher) (28/02/2026)
Drop-in replacement de sqflite. Clé AES-256 générée aléatoirement au premier lancement, stockée dans flutter_secure_storage clé `db_encryption_key`. Migration automatique des DB non chiffrées. Ne jamais passer `password: null` à `openDatabase()`.

### D6 — Certificate pinning TOFU (01/03/2026)
Auto-rotation sans mise à jour manuelle des certs. Implémenté dans `CertPinManager`. Trust on First Use : le premier certificat vu est stocké, les suivants sont comparés. Rotation automatique si le cert change mais la chaîne CA reste valide.

### D7 — Backup PBKDF2 (01/03/2026)
Remplace la dérivation faible `padRight(32, '0')` par PBKDF2-HMAC-SHA256 (100 000 itérations + salt 32 octets aléatoires). Rétrocompatibilité lecture legacy maintenue.

---

## 6 — ÉTAT DU CODE DE RÉFÉRENCE

### Tables SQLite (dbVersion=12)

```
events           : id, remote_id, source, type, title, start_date, end_date, is_all_day,
                   location, description, participants, tag_ids, rrule, recurrence_id,
                   calendar_id, notion_page_id, ics_subscription_id, status,
                   reminder_minutes, is_deleted, created_at, updated_at, synced_at, etag,
                   smart_attachments TEXT DEFAULT '[]'
                   UNIQUE(remote_id, source)

tags             : id, type, name, color_hex, infomaniak_mapping, notion_mapping, sort_order

event_tags       : event_id, tag_id (PK composite, FK cascade)

notion_databases : id, notion_id (UNIQUE), data_source_id, name, title_property,
                   start_date_property, end_date_property, category_property,
                   priority_property, description_property (TEXT JSON multi-props),
                   participants_property, status_property, location_property,
                   objective_property, material_property, is_enabled, last_synced_at

ics_subscriptions : id, name, url (UNIQUE), color_hex, is_enabled, last_synced_at

sync_state       : id, source (UNIQUE), last_synced_at, sync_token, status, error_message

sync_queue       : id, action, source, event_id, payload, created_at, retry_count,
                   last_error, status

system_logs      : id, level, source, message, details, created_at, is_read

events_fts       : VIRTUAL TABLE FTS5 (title, description, location, content=events)
                   + triggers AFTER INSERT/UPDATE/DELETE

magic_habits     : (table d'apprentissage auto des habitudes de saisie)

INEXISTANTES (mentionnées dans V3GK, absentes du code) : scheduled_notifications, app_config
```

### Clés flutter_secure_storage

```
infomaniak_username      → Nom d'utilisateur Infomaniak
infomaniak_app_password  → Mot de passe applicatif (pas le mdp compte)
infomaniak_calendar_url  → URL CalDAV complète du calendrier
notion_api_key           → Token Bearer Notion API
db_encryption_key        → Clé AES-256 de chiffrement SQLite (générée auto)
```

### Providers Riverpod clés

```
settingsProvider              → AsyncNotifierProvider<SettingsNotifier, AppSettings>
eventsProvider                → AsyncNotifierProvider<EventsNotifier, List<EventModel>>
eventsInRangeProvider         → FutureProvider.family<List<EventModel>, DateRange>
tagsProvider                  → AsyncNotifierProvider<TagsNotifier, List<TagModel>>
syncNotifierProvider          → NotifierProvider<SyncNotifier, SyncState>
connectivityStreamProvider    → StreamProvider<bool>
isOfflineProvider             → Provider<bool> (combiné forceOffline + connectivity)
forceOfflineProvider          → StateNotifierProvider<ForceOfflineNotifier, bool>
autoSyncOnConnectivityProvider → Provider<void> (debounce 5s)
periodicSyncRetryProvider     → Provider<void> (fallback Timer 60s Linux)
pendingSyncCountProvider      → FutureProvider<int>
```

---

## 7 — RÈGLES ABSOLUES POUR L'IA DE PRODUCTION

Ces règles s'appliquent à **toute contribution** au projet monAgenda :

1. **State Management :** Exclusivement `flutter_riverpod`. Jamais `provider`. Utiliser `AsyncNotifier` pour tout state asynchrone.
2. **Accès credentials :** Via `ref.read(settingsProvider)` uniquement. Jamais d'instanciation directe de `FlutterSecureStorage` ailleurs que dans `SettingsNotifier`.
3. **Réseau :** L'état offline est lu via `ref.watch(isOfflineProvider)`. Ne pas dupliquer la logique `connectivity_plus`.
4. **Thread safety IA :** Tout appel `llama.cpp` dans `Isolate.run(...)`. Jamais sur le thread principal.
5. **Plugins supprimés :** JAMAIS réinstaller `flutter_contacts` ou `share_plus`. JAMAIS `READ_CONTACTS` dans `AndroidManifest.xml`.
6. **QR Code :** Pipeline AES-256 via `CryptoUtils.encryptToExportString`. Jamais gzip+base64 (c'est `@Deprecated`).
7. **Nomenclature CalDAV :** La classe s'appelle `InfomaniakService`, pas `CalDAVClient`. La table `events`, pas `events_cache`.
8. **Desktop vs Mobile :** Time Blocking, Meeting Note, Export PPT, Smart Context Parser = **Desktop ONLY**. Utiliser `LayoutBuilder` ou `Platform.isLinux/isWindows`.
9. **Isolation des couches :** Les `Notifier` ne font pas d'appels UI. Les Widgets ne lisent pas SQLite directement.
10. **Logging :** `print()` interdit en production. Utiliser `AppLogger` → table `system_logs`.
11. **SQLite chiffré :** `sqflite_sqlcipher` obligatoire. Clé depuis `flutter_secure_storage` clé `db_encryption_key`. Jamais `password: null`.
12. **Navigation :** Le projet utilise **la navigation impérative** (`Navigator.push/pop`), PAS `go_router`.
13. **Commits atomiques :** Chaque fix = un commit dédié avec référence au finding. Jamais de commit monolithique "fix 30 bugs".

---

## 8 — LEÇONS APPRISES — ERREURS INTERDITES

*(Post-mortem session 01/03/2026)*

### 8.1 — Audit ≠ Fix aveugle
L'audit identifie les problèmes. La correction se fait **UN PAR UN**, avec vérification entre chaque. Un audit qui liste 30 bugs et les fixe tous en un seul commit géant est une bombe à régression.

### 8.2 — Ne JAMAIS déclarer "VERIFIED" sans preuve fonctionnelle
"Le code compile" ≠ "ça marche". Un fix n'est vérifié que quand l'application tourne ET l'utilisateur confirme le comportement attendu. `flutter analyze` = nécessaire mais pas suffisant. Il faut un test runtime.

### 8.3 — Traçabilité obligatoire des changements
Chaque finding corrigé = un commit dédié (ex: `fix: F-003 IntrinsicHeight overflow`). JAMAIS de commit "fix 30 bugs" monolithique.

### 8.4 — Cascade de bugs — détection et arrêt
Si la correction d'un finding en crée un nouveau → **STOP immédiat** : revert au commit précédent, réévaluer. Exemple vécu : supprimer `IntrinsicHeight` → cartes 0px → 25 000 erreurs Flutter → 582 Mo de logs → "database is locked" → écran vide. Un seul mauvais fix a créé 4 niveaux de cascade.

### 8.5 — Audit SQLite obligatoire
Toujours vérifier : WAL mode ? busy_timeout ? Nombre de connexions simultanées ? Singleton garanti ? N+1 queries ? Taille des tables de logs → rotation/purge automatique.

### 8.6 — Écouter les indices de l'utilisateur
"Ça marchait hier soir" = PREMIER RÉFLEXE : `git bisect`. "Je pense que c'est le filtre" = VÉRIFIER cette piste AVANT tes propres hypothèses. L'utilisateur est le meilleur capteur de régression.

### 8.7 — Gestion des processus
Avant chaque test, vérifier qu'aucune instance précédente ne tourne (`ps aux | grep`). Plusieurs instances = locks DB, corruption d'état, faux diagnostics. `flutter clean` peut détruire la DB locale : TOUJOURS backup avant.

---

## 9 — ROADMAP

> **Méthodologie :** Étape par étape. Chaque tâche = test + `flutter analyze` + commit atomique.  
> **Base de référence :** HEAD = `d300ca8`, 62 fichiers Dart, ~26 000 lignes.

### Récapitulatif de l'avancement

| Phase | Description | Tâches | Fait | Reste | Statut |
|-------|-------------|--------|------|-------|--------|
| **0** | Sécurité critique | 7 | 7 | 0 | ✅ Complète |
| **1** | Bugs bloquants & corrections | 18 | 17 | 1 | 🟠 94% |
| **2** | UX / Ergonomie | 18 | 11 | 7 | 🟡 61% |
| **3** | Stockage souverain | 5 | 0 | 5 | 🔴 0% |
| **4** | Widget Android natif | 5 | 1 | 4 | 🔴 20% |
| **5** | Intelligence Artificielle | 9 | 4 | 5 | 🟡 44% |
| **6** | Refonte graphique | 7 | 7 | 0 | ✅ Complète |
| **7** | Onboarding & finitions | 8 | 2 | 6 | 🟠 25% |
| **8** | Documentation & versioning | 4 | 0 | 4 | 🔴 0% |

---

### PHASE 1 — BUGS RESTANTS (3 tâches)

- [x] **1.15** — Bannière serveur saturé : `serverSyncErrorProvider` + `_buildServerErrorBanner()` orange + bouton "Réessayer" + dismiss ✅ (déjà implémenté)
- [x] **1.16** — Conflits ETag (HTTP 412) : GET version serveur → override local (last-remote-wins) + SnackBar "Conflit résolu" via `etagConflictProvider` ✅ (déjà implémenté)
- [ ] **1.19** — ICS import sans déduplication (double import = doublons) — ajouter check UID

### PHASE 2 — UX / ERGONOMIE (7 tâches restantes)

**Navigation & accès rapides :**
- [ ] **2.2** — Ctrl+F doit ouvrir SearchScreen (actuellement switch onglet seulement)
- [x] **2.3** — Raccourcis clavier : Ctrl+S (sync) + Ctrl+, (paramètres) + tooltips enrichis ✅ `f71b0fd`

**Fonctionnalités demandées :**
- [x] **2.5** — Import ICS direct depuis file picker + parsing + insertion en base ✅ `fa5d06a`
- [ ] **2.6** — Barre latérale Todo (tâches sans date) + glisser-déposer vers calendrier
- [ ] **2.7** — Redimensionnement d'événement par poignée (SfCalendar `allowAppointmentResize`)
- [ ] **2.8** — Logo dans le dock Ubuntu (fichier .desktop + icônes)

**États vides & feedback :**
- [x] **2.9** — Empty states calendrier SfCalendar (schedule: plein écran, week/month/day: bandeau flottant) ✅ `5818df7`
- [x] **2.11** — Bouton "Réinitialiser l'app" — zone danger + double confirmation + suppression DB/prefs/modèle ✅ `51380e6`
- [x] **2.12** — Bouton "Tester connexion kDrive" — BackupService.testKDriveConnection + feedback visuel ✅ `187a260`
- [x] **2.13** — Notification tap → navigatorKey global + getEventById + EventDetailScreen ✅ `e9c53db`
- [ ] **2.14** — Refonte paramètres en 5 sections (Comptes, Notifications, Apparence, IA, Avancé)

**Features V3 :**
- [ ] **2.17** — Import QR d'événements (pas juste config) — scan → déchiffrement → merge SQLite
- [ ] **2.18** — Logos SVG monAgenda (light, dark, splash) + flutter_svg

### PHASE 3 — STOCKAGE SOUVERAIN (zéro fichier local permanent)

- [ ] **3.1** — Audit de tous les fichiers locaux (backup, export, modèle IA)
- [ ] **3.2** — Upload direct WebDAV vers kDrive (remplacer copier-coller)
- [ ] **3.3** — Option "Envoyer vers kDrive" pour ICS/CSV
- [ ] **3.4** — ModelDownloadService complet (SHA-256, progress, reprise HTTP Range)
- [ ] **3.5** — `getDownloadsDirectory()` = fallback temporaire uniquement

### PHASE 4 — WIDGET ANDROID FONCTIONNEL

- [x] **4.1** — WidgetService.updateWidget() post-CRUD dans events_provider ✅
- [ ] **4.2** — WidgetService.updateWidget() post-sync dans sync_engine
- [ ] **4.3** — Vérifier/compléter layout XML du widget Android
- [ ] **4.4** — Vérifier receiver dans AndroidManifest.xml
- [ ] **4.5** — Tester le widget sur émulateur (7 jours affichés)

### PHASE 5 — INTELLIGENCE ARTIFICIELLE

- [x] **5.1** — Regex-first : mois en lettres ("15 mars", "3 avril 2025", "1er janvier") ajouté ✅ `2488295`
- [ ] **5.1b** — GBNF grammar enforcement (forcer JSON valide — sans elle, ~30% invalide)
- [ ] **5.1c** — Validateur post-IA : title non vide, date cohérente, startTime < endTime
- [ ] **5.2** — Feedback loop : table `magic_feedback`, export CSV, compteur dans Settings
- [ ] **5.4** — Suggestions contextuelles auto-complétion dans la barre magique
- [ ] **5.5** — Résumé matinal intelligent (Danube génère un texte du matin)
- [ ] **5.6** — Mode conversation libre (parser questions → intentions → query SQLite)
- [ ] **5.7** — Déchargement mémoire : cycle load → infer → unload (libérer ~1.2 Go RAM)

### PHASE 6 — REFONTE GRAPHIQUE ✅ (complète)

- [x] **6.6** — Micro-animations : SlideTransition fluide (320ms easeOut) sur tous les BottomSheets ✅ `ffff9bb`
- [x] **6.7** — disableAnimations global : BottomSheets + AnimatedSwitcher respectent WidgetsBinding.disableAnimations ✅ `fd3fe57`

### PHASE 7 — ONBOARDING & FINITIONS

- [x] **7.1** — SetupScreen onboarding 3 étapes ✅
- [ ] **7.2** — Guard de routage : credentials vides → `/setup`
- [ ] **7.3** — Migration ForceOfflineNotifier : StateNotifier → Notifier (Riverpod 3 ready)
- [ ] **7.4** — Mettre à jour `notionApiVersion` de `'2022-06-28'` vers version stable actuelle
- [ ] **7.5** — Supprimer `flex_color_scheme` (dans pubspec mais jamais importé)
- [ ] **7.6** — Remplacer `RadioListTile` deprecated par `Radio.adaptive` + `ListTile`
- [x] **7.7** — IntrinsicHeight supprimé dans search_screen.dart — remplacé par Border(left:) plus performant ✅ `bba1a9a`
- [ ] **7.8** — Optimisation APK : minifyEnabled, shrinkResources, --split-per-abi (cible <40 Mo)

### PHASE 8 — DOCUMENTATION & VERSIONING

- [ ] **8.1** — Mettre à jour README.md avec l'architecture V3 réelle
- [ ] **8.2** — Mettre à jour DESIGN_SYSTEM.md avec les tokens réellement appliqués
- [ ] **8.3** — Corriger V3GK.md (nomenclature CalDAV, pipeline QR)
- [ ] **8.4** — Tag Git `v3.0.0` quand toutes les phases sont complètes

---

### ORDRE D'EXÉCUTION

```
Phase 1 (bugs restants) → Phase 2 (UX + raccourcis) → Phase 5 (IA: GBNF + validateur)
→ Phase 4 (widget Android) → Phase 3 (stockage souverain)
→ Phase 6 (animations) → Phase 7 (finitions + optim APK)
→ Phase 8 (docs + tag v3.0.0)
```

Chaque tâche cochée = testée + `flutter analyze` clean + commit Git atomique.

---

## 10 — DOCUMENTS ARCHIVÉS

Tous les anciens documents de référence ont été déplacés dans `archive/` :

| Document | Date | Contenu |
|---|---|---|
| `cahier_des_charges-appagendaperso.md` | 25/02/2026 | Cahier des charges V0 — spécifications fonctionnelles initiales |
| `V3GK.md` | 28/02/2026 | Architecture Decision Record V3 — instructions de production pour Opus |
| `audit27022026.md` | 27/02/2026 | Audit technique V2 — analyse ligne par ligne |
| `bilan27022026.md` | 27/02/2026 | Bilan complet journée 27/02 — travaux réalisés + audit Phase 2 |
| `audit28022026.md` | 28/02/2026 | Audit delta V3GK.md ↔ code réel |
| `historiqueconv28022026.md` | 28/02/2026 | Historique de conversation du 28/02 |
| `manifest28022026.md` | 28/02/2026 | Manifest V3 complet (1073 lignes) — décisions + 15 prompts Opus |
| `PLAN_ACTION_V3.md` | 28/02/2026 | Plan d'action V3 — 26 tâches avec prompts précis |
| `roadmap01032026.md` | 01/03/2026 | Roadmap 81 tâches — état d'avancement au 02/03 |
| `AUDIT_UI_COMPLET.md` | 01/03/2026 | Audit UI complet — 22 fichiers Dart, 575 lignes |
| `DESIGN_SYSTEM.md` | 28/02/2026 | Design System — palette, typo, composants, mockups |
| `sauvegarde conversation 01032026.md` | 01/03/2026 | Sauvegarde de conversation |
| `Agenda des tâches *.csv` | — | Export Notion historique |
| `Calendrier garde *.csv` | — | Export Notion historique |

---

*Rédigé le 02/03/2026. HEAD = `d300ca8`. Ce document est le référentiel unique du projet — les documents archivés servent de trace historique.*
