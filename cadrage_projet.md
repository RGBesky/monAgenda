# Cadrage Projet — monAgenda
## Calendrier Personnel Unifié · Infomaniak · Notion · Flutter

> **Date** : 2 mars 2026  
> **Auteur** : Robert (conception & dev) + Isabelle (audit IA)  
> **Branche** : `claude/save-agenda-github-bajxr` · HEAD `442e2e6`  
> **Statut** : Usage personnel · Open source GitHub envisagé

---

## 1. Contexte et problématique

Aucune application calendrier existante ne répond simultanément à ces besoins :

- **Souveraineté des données** : hébergement européen (Infomaniak), zéro cloud tiers américain
- **Unification** : rendez-vous Infomaniak (CalDAV) + tâches/projets Notion + abonnements .ics dans une seule app
- **Multi-plateforme** : Android (téléphone) + Linux Desktop (Ubuntu) dans le même codebase
- **IA locale** : saisie magique en langage naturel, zéro API cloud, modèle LLM embarqué sur l'appareil
- **Tags unifiés** : l'app est l'autorité absolue sur les catégories, couleurs et priorités

**monAgenda** remplace totalement Google Calendar et Outlook Calendar par une solution maîtrisée de bout en bout.

---

## 2. Vision produit

### 2.1 Principes fondateurs

1. **Offline-first absolu** — L'UI ne lit jamais que SQLite. Aucune attente HTTP.
2. **Zéro permission superflue** — Pas de READ_CONTACTS, pas de caméra, pas de micro. L'app est un frontend "dummy" ultra-rapide.
3. **IA 100% locale** — Inférence llama.cpp via FFI, modèle GGUF quantifié ~400-500 Mo, Isolate obligatoire.
4. **Souveraineté** — Données entre l'app et Infomaniak/Notion uniquement. Zéro serveur tiers.
5. **Desktop ≠ Mobile** — Desktop = usine à gaz (D&D, Time Blocking, PPT, PDF). Mobile = immédiateté tactile une main.

### 2.2 Philosophie design

Inspirée du **"Notion Way"** (Ivan Zhao) :
- Interface calme, espaces blancs généreux, frontières subtiles
- Élévation 0, border radius 3px, scrolledUnderElevation 0
- Typographie Inter (Google Fonts)
- Icônes exclusives HugeIcons Stroke Rounded
- Palette Stabilo Boss × Paper Mate Flair (100 couleurs, 10 familles × 10 nuances)

---

## 3. Plateformes et contraintes

| Plateforme | Cible | Spécificités |
|---|---|---|
| **Android** | API 26+ (Android 8) | Widget 7 jours, notifications exact alarm, WorkManager background, scan QR, home widget |
| **Linux Desktop** | Ubuntu 22+ | Process.run Python (PPT/CSV), Time Blocking D&D, Meeting Notes Notion, SQLCipher via system hooks |

### 3.1 Stack technique

| Composant | Technologie | Version |
|---|---|---|
| Langage | Dart | ≥ 3.0.0 |
| Framework | Flutter | ≥ 3.10.0 |
| State management | Riverpod | ^2.5.1 |
| Calendrier UI | SfCalendar (Syncfusion) | ^32.0.0 |
| HTTP | Dio | ^5.7.0 |
| BDD locale | SQLCipher (sqflite_sqlcipher) | ^3.1.0 |
| Chiffrement | AES-256-CBC (encrypt + pointycastle) | ^5.0.3 |
| Secrets | flutter_secure_storage | ^9.2.2 |
| Notifications | flutter_local_notifications | ^18.0.0 |
| Background | WorkManager | ^0.6.0 |
| IA locale | llama_cpp_dart (FFI) | ^0.2.2 |
| Widget Android | home_widget | ^0.7.0 |
| QR | qr_flutter + mobile_scanner | ^4.1.0 / ^6.0.2 |

---

## 4. Sources de données

| Source | Contenu | Sync | Protocole |
|---|---|---|---|
| **Infomaniak Calendar** | Rendez-vous | Bidirectionnel (app = source de vérité) | CalDAV (PROPFIND / REPORT / PUT / DELETE) via Basic Auth |
| **Notion** (multi-BDD) | Tâches et projets | Bidirectionnel | API REST Notion v2022-06-28 |
| **Calendriers .ics** | Vacances, paroisses… | Lecture seule (refresh périodique) | HTTP GET URL publique |
| **Open-Meteo** | Météo | Lecture seule | API REST (sans clé) |

### 4.1 Séparation des responsabilités

> **Règle clé** : les rendez-vous sont gérés par Infomaniak, les tâches et projets par Notion. Cette séparation est au cœur de l'architecture.

---

## 5. Architecture

### 5.1 Couches

```
┌──────────────────────────────────────────┐
│              UI Layer (Screens)           │
│   calendar · agenda · events · settings  │
├──────────────────────────────────────────┤
│           Providers (Riverpod)           │
│  events · settings · sync · tags         │
├──────────────────────────────────────────┤
│              Services                    │
│  InfomaniakService · NotionService       │
│  IcsService · SyncEngine · SyncQueue     │
│  MagicEntryService · LlamaService        │
│  WeatherService · NotificationService    │
│  BackupService · WidgetService           │
│  ModelDownloadService · LoggerService    │
├──────────────────────────────────────────┤
│            Data Layer                    │
│  DatabaseHelper (SQLCipher, WAL mode)    │
│  FlutterSecureStorage (5 clés)           │
│  SharedPreferences (UI prefs)            │
└──────────────────────────────────────────┘
```

### 5.2 Architecture CalDAV (3 couches)

```
InfomaniakService (HTTP CalDAV brut : PROPFIND, REPORT, PUT, DELETE)
       ↓
SyncEngine + SyncQueueWorker (cache SQLite + queue + conflit ETag 412)
       ↓
syncNotifierProvider (état Riverpod → UI)
```

### 5.3 Base de données (SQLCipher, chiffrée AES-256)

**Version de schéma** : 14  
**Mode journal** : WAL + busy_timeout=5000

| Table | Rôle |
|---|---|
| `events` | Cache unifié de tous les événements (toutes sources) |
| `tags` | Tags unifiés (type, nom, couleur, mapping Infomaniak, mapping Notion) |
| `event_tags` | Liaison N:N événements ↔ tags |
| `notion_databases` | BDD Notion configurées + mapping propriétés |
| `ics_subscriptions` | Abonnements .ics publics |
| `sync_state` | État de synchronisation par source (getctag, syncToken) |
| `sync_queue` | Actions en attente de sync (action, source, event_id, payload, retry_count, status) |
| `system_logs` | Logs techniques (cap 1000, purge 7j) |
| `events_fts` | Table virtuelle FTS5 (title, description, location) pour recherche full-text |
| `cert_pins` | Certificate pinning TOFU (sha256, previous_sha256, auto-rotation) |
| `magic_feedback` | Feedbacks correction IA (export CSV) |
| `magic_habits` | Habitudes apprises par l'IA (keyword → tag, durée, lieu) |

**5 clés flutter_secure_storage** : `infomaniak_username`, `infomaniak_app_password`, `infomaniak_calendar_url`, `notion_api_key`, `db_encryption_key`

**Index** : `idx_events_start_date`, `idx_events_source`, `idx_events_deleted`, `idx_sync_queue_status`, `idx_system_logs_level`

### 5.4 Sécurité

| Aspect | Implémentation |
|---|---|
| BDD chiffrée | SQLCipher, clé AES-256 auto-générée dans flutter_secure_storage |
| Desktop hooks | `hooks: user_defines: sqlite3: source: system, name: sqlcipher` |
| Migration transparent | `_migrateToEncryptedIfNeeded()` via `sqlcipher_export` |
| Backup chiffré | PBKDF2-HMAC-SHA256 (100k itérations + salt 32B) + AES-256-CBC |
| Export QR | AES-256-CBC avec mot de passe utilisateur, `QrErrorCorrectLevel.L` |
| Rétro-compatibilité | Détection magic header `MAP2` (PBKDF2) sinon fallback legacy |
| Cert pinning | TOFU + auto-rotation si CA connu |
| Zero print prod | AppLogger écrit en BDD, `print()` uniquement dans `assert()` |

---

## 6. Fonctionnalités

### 6.1 Vues calendrier

| Vue | Description |
|---|---|
| **Mois** | Aperçu mensuel avec indicateurs d'événements |
| **Semaine** | Créneaux horaires style Outlook, D&D, resize handles |
| **Jour** | Détail complet de la journée |
| **Agenda** | Liste chronologique avec sticky headers ("Aujourd'hui", "Demain"), météo/jour |

### 6.2 Représentation visuelle des événements

Chaque carte combine **trois informations visuelles simultanées** :

| Élément | Information |
|---|---|
| Bordure gauche colorée (4px) | Priorité (rouge=Urgent, orange=Haute…) |
| Chip catégorie coloré Stabilo | Catégorie (Travail, Perso, Santé…) |
| Logo source 16px | Infomaniak (PNG) ou Notion (PNG ClipRRect) |

Cartes Notion-like : élévation 0, border subtile 0.5px, borderRadius 3px.

### 6.3 Types d'événements

| Type | Source | Stockage |
|---|---|---|
| Rendez-vous | Infomaniak | CalDAV |
| Journée entière | Infomaniak | CalDAV (format DATE) |
| Récurrent | Infomaniak | CalDAV (RRULE DAILY/WEEKLY/MONTHLY) |
| Tâche | Notion | Notion API (checkbox, statut) |
| Projet multi-jours | Notion | Notion API (barre horizontale) |
| Abonnement | URL .ics | Lecture seule |

### 6.4 Système de tags

L'app est **l'autorité absolue** sur les tags. Elle définit les noms, couleurs et pousse vers Infomaniak (`CATEGORIES:`) et Notion (propriété Select/Multi-select).

| Dimension | Mapping Infomaniak | Mapping Notion |
|---|---|---|
| **Catégorie** (multi-select) | `CATEGORIES:Travail` | Propriété Multi-select |
| **Priorité** (select unique) | `PRIORITY:1-9` | Propriété Select |
| **Couleur** | Définie par l'app | Best effort Notion |

Palette : 100 couleurs Stabilo Boss × Paper Mate Flair (10 familles × 10 nuances), grille 10×10 dans le color picker.

### 6.5 Saisie Magique (IA locale)

**Entrée** : `"Dîner avec @Marc vendredi 20h au Resto #Perso"` → **Sortie** : EventModel complet

| Composant | Description |
|---|---|
| **Regex-first** | Pré-traitement regex couvrant ~80% des cas en ~1ms (#tag, @mention, heure, date, durée, lieu) |
| **LLM fallback** | Qwen2.5 0.5B/1.5B q4_k_m GGUF via llama.cpp FFI, Isolate obligatoire |
| **GBNF grammar** | Grammaire forcée pour JSON valide exclusif |
| **Post-validation** | Title non vide, date cohérente, startTime < endTime, catégorie connue |
| **Habits auto-learn** | Table `magic_habits` : apprend les patterns (keyword → tag, durée, lieu) |
| **Feedback** | Table `magic_feedback` pour corrections, export CSV |

**Desktop** : Barre "Spotlight" via Ctrl+K  
**Mobile** : Bouton "✨ Magie"

**Source dynamique** : Infomaniak prioritaire > Notion > fallback

**Historique modèle** : H2O Danube 3 testé et abandonné (résultats trop mauvais). Qwen2.5 retenu.

### 6.6 Fonctionnalités Desktop exclusives

- **Time Blocking** : Vue split-panel SfCalendar + inbox tâches Notion non datées, D&D croisé (`Draggable<NotionTaskModel>` → `DragTarget`), Optimistic UI + rollback
- **Meeting Notes** : Bouton "Créer/Ouvrir compte-rendu" → POST Notion /v1/pages (Title + Date + Relation Projet) → launchUrl
- **Export PPT** : Process.run Python (`generate_calendar_ppt.py`), check python3 sur PATH, résolution venv auto
- **Export CSV** : Tous les events, protection injection formules CSV (`=`, `+`, `-`, `@`, `\t`)
- **Raccourcis clavier** : Ctrl+K (Spotlight), Ctrl+F (recherche), Ctrl+N (new event), Ctrl+S (sync), Ctrl+, (settings), Escape (close)

### 6.7 Fonctionnalités Mobile exclusives

- **Widget Android** : 7 events par défaut (paramétrable), pipeline SQLite → HomeWidget.saveWidgetData → updateWidget
- **Scan QR** : mobile_scanner + déchiffrement AES-256 pour import config
- **Layout Android** : calendar_widget.xml + CalendarWidgetProvider.kt + receiver AndroidManifest

### 6.8 Sync & Offline

| Mécanisme | Description |
|---|---|
| **sync_queue** | Toute mutation locale → enqueue → worker async dédépile |
| **ETag conflict** | If-Match sur PUT/DELETE, 412 → GET serveur → last-remote-wins → SnackBar |
| **FAB 3 états** | Vert (connecté) / Orange (pas de réseau) / Rouge (force-offline) |
| **Bannière** | "X actions en attente" conditionnelle |
| **Auto-sync** | Debounce 30s au retour réseau |
| **Periodic Linux** | Timer 60s (fallback connectivity_plus silencieux sur Linux) |
| **Cert pinning** | TOFU + auto-rotation si CA connu |

### 6.9 Notifications

- Rappel configurable par événement
- Résumé matinal quotidien (heure configurable)
- POST_NOTIFICATIONS Android 13+ contextuel (pas au cold start)
- SCHEDULE_EXACT_ALARM Android 12+ avec fallback inexact
- zonedSchedule (TZDateTime) pour fuseaux horaires
- Tap → EventDetailScreen via payload `event:${event.id}`
- WorkManager periodic 6h reschedule (survit kill + reboot)
- BOOT_COMPLETED + MY_PACKAGE_REPLACED → reprogramme les notifications

### 6.10 Météo

- **Open-Meteo** (open source, sans clé API)
- Affichage sous chaque en-tête de jour dans la vue Agenda
- Géolocalisation : GPS prioritaire → IP (ipapi.co + Nominatim) → saisie manuelle → 8 villes suisses pré-configurées
- Non critique : si indisponible, l'app fonctionne normalement

### 6.11 Recherche

- FTS5 full-text (title, description, location) avec MATCH + fallback LIKE
- Ctrl+F ouvre SearchScreen
- Filtres combinables : mot-clé, tag, source, période

### 6.12 Paramètres

5 sections via NavigationRail (desktop) :

1. **Connexions** : Infomaniak (user + app password + calendar URL), Notion (API key + multi-BDD avec auto-discover), abonnements .ics
2. **Tags** : Catégories + priorités, grille 10×10 Stabilo, mapping bidirectionnel
3. **Notifications** : Délai rappel, résumé matinal (heure + toggle), permissions
4. **Apparence** : Thème (auto/clair/sombre/AMOLED), vue par défaut, premier jour semaine, tri calendriers
5. **Avancé** : Backup kDrive, export/import config (QR + JSON), export CSV/PPT, modèle IA, logs système, zone danger (reset)

### 6.13 Import / Export

| Format | Direction | Détails |
|---|---|---|
| `.ics` fichier | Import | Via FilePicker, parsing + dedup |
| `.ics` URL | Import | Abonnement lecture seule, refresh périodique |
| `.ics` global | Export | Sauvegarde complète |
| `.csv` | Export | Tous les events, protection injection |
| `.pptx` | Export | Planning de garde, Linux uniquement, Python |
| QR AES-256 | Export/Import | Config chiffrée cross-device |
| JSON | Export/Import | Config fichier (credentials strippés en fichier) |
| Backup kDrive | Export | AES-256 PBKDF2, lien de dépôt |

---

## 7. Thèmes et tokens design

### 7.1 Couleurs

| Token | Light | Dark | AMOLED |
|---|---|---|---|
| Background | `#F7F6F3` | `#191919` | `#000000` |
| Surface | `#FFFFFF` | `#252525` | `#0A0A0A` |
| Primary | `#007AFF` | `#0A84FF` | `#0A84FF` |
| Text | `#37352F` | `#FFFFFF` | `#FFFFFF` |

### 7.2 Typographie

Police globale : **Inter** via Google Fonts

### 7.3 Iconographie

Exclusivement **HugeIcons Stroke Rounded** pour navigation, actions, métadonnées.

### 7.4 Logos sources

PNG haute qualité, **toujours version claire**, intégrés partout (event card, calendrier, filtres, Quick Add, settings, sidebar). ClipRRect coins arrondis pour Notion.

---

## 8. Règles de développement

1. **Un fix = un commit** avec référence (ex: `fix: P1-3 invalidate pendingSyncCount`)
2. **Riverpod only** pour l'état global. `setState` interdit sauf cycle de vie widget.
3. **Notifiers ne font pas d'appels UI** directs. Widgets ne lisent pas SQLite directement.
4. **Accès credentials** toujours via `ref.read(settingsProvider)`, jamais FlutterSecureStorage direct.
5. **Zero `print()` en production** — tout passe par AppLogger → table system_logs.
6. **flutter analyze : 0 issues** avant chaque commit.
7. **Si un fix crée un nouveau problème** → STOP immédiat, revert, réévaluer.

---

## 9. Hors scope (décisions actées)

| Feature | Raison |
|---|---|
| SmartContextService (PDF Notion) | Pas dans la philosophie de l'app |
| Saisie vocale | NO-GO définitif |
| CardDAV contacts | Déporté côté CalDAV serveur |
| Multi-compte Infomaniak | V-FUTURE |
| iTIP/iMIP (invitations mail) | V-FUTURE |
| Couche Repository explicite | V-FUTURE (architecture actuelle suffisante) |
| Autocomplete magic bar | Pas prioritaire |

---

## 10. Roadmap résumée

| Phase | Contenu | Cf. |
|---|---|---|
| **Phase 0** | WAL mode, manifest, 9 items | ✅ Fait (442e2e6) |
| **Phase 1** | 9 quick fixes (logos, debugPrint, pending, purge, creds warning, long press, cleanup, snackbars, widget) | `feuille_de_route.md` |
| **Phase 2** | 8 features M (ATTENDEE parser, bg sync, table participants, LayoutBuilder, géoloc GPS, animations, Riverpod, résumé IA) | `feuille_de_route.md` |
| **Phase 3** | 3 features L (conversation IA, backup kDrive, A/B test prompt) | `feuille_de_route.md` |
| **Phase 4** | V-FUTURE (battery, export kDrive, architecture layers) | Reporté |
