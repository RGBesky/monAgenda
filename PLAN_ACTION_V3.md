# PLAN D'ACTION V3 — monAgenda
## Document de suivi d'exécution — 28/02/2026

> **Discipline de travail :**
> 1. Code la tâche
> 2. `flutter analyze` + `flutter build linux` → 0 erreur
> 3. Fix immédiat si bug détecté
> 4. `git commit` atomique avec message clair
> 5. Passe à la tâche suivante
>
> **Aucune tâche ne démarre tant que la précédente n'est pas commitée et validée.**

---

## PHASE 1 — Infrastructure & Bugfixes (Prompt 8 + Décision 7)
*Fondation obligatoire — tout le reste en dépend.*

### 1.1 — Versioning SQLite centralisé (db_migrations.dart) — Bug 9
- [ ] Terminé
- [ ] Testé (`flutter analyze` OK)
- [ ] Commité

**Fichiers impactés :** `lib/core/database/db_migrations.dart` (nouveau) + `lib/core/database/database_helper.dart`

<details>
<summary>PROMPT PRÉCIS</summary>

```
Tu dois corriger le Bug 9 du manifest : Versioning SQLite centralisé.

Fichier cible : lib/core/database/database_helper.dart + nouveau fichier lib/core/database/db_migrations.dart.

Problème : Les Prompts 4 (smart_attachments) et 8/Bug3 (FTS5) ajoutent chacun des DDL dans onUpgrade(). Sans versioning centralisé, deux sessions Opus séparées peuvent créer deux blocs onUpgrade() avec des numéros de version conflictuels → crash SQLite au premier upgrade.

Correction :
  1. Crée lib/core/database/db_migrations.dart avec :
     const int kCurrentDbVersion = 8;  // ATTENTION : le code actuel est à dbVersion=6. Reprendre à 7.
     final Map<int, List<String>> kMigrations = {
       7: ["ALTER TABLE events ADD COLUMN smart_attachments TEXT DEFAULT '[]'"],
       8: [
         "CREATE VIRTUAL TABLE IF NOT EXISTS events_fts USING fts5(title, description, location, content=events, content_rowid=id)",
         "CREATE TRIGGER events_ai AFTER INSERT ON events BEGIN INSERT INTO events_fts(rowid, title, description, location) VALUES (new.id, new.title, new.description, new.location); END",
         "CREATE TRIGGER events_au AFTER UPDATE ON events BEGIN INSERT INTO events_fts(events_fts, rowid, title, description, location) VALUES ('delete', old.id, old.title, old.description, old.location); INSERT INTO events_fts(rowid, title, description, location) VALUES (new.id, new.title, new.description, new.location); END",
         "CREATE TRIGGER events_ad AFTER DELETE ON events BEGIN INSERT INTO events_fts(events_fts, rowid, title, description, location) VALUES ('delete', old.id, old.title, old.description, old.location); END"
       ],
     };
  2. Dans DatabaseHelper.onUpgrade(db, oldVersion, newVersion) :
     for (int v = oldVersion + 1; v <= newVersion; v++) {
       for (final sql in kMigrations[v] ?? []) { await db.execute(sql); }
     }
  3. Dans openDatabase(), remplacer le numéro hardcodé par version: kCurrentDbVersion.

RÈGLE ABSOLUE : Toute future migration = incrémenter kCurrentDbVersion + ajouter entrée dans kMigrations. Ne jamais modifier une migration existante.
```

</details>

---

### 1.2 — sqflite → sqflite_sqlcipher (chiffrement DB at rest) — Décision 7
- [ ] Terminé
- [ ] Testé (`flutter analyze` OK)
- [ ] Commité

**Fichiers impactés :** `pubspec.yaml` + `lib/core/database/database_helper.dart`

<details>
<summary>PROMPT PRÉCIS</summary>

```
Tu dois appliquer la Décision 7 du manifest : SQLite chiffré au repos.

Décision : Remplacer sqflite par sqflite_sqlcipher. La base de données locale est chiffrée AES-256 at rest.

Implémentation :
  1. Dans pubspec.yaml : remplacer sqflite: par sqflite_sqlcipher: (même API, drop-in replacement).
  2. Dans DatabaseHelper.open() :
     final dbKey = await _secureStorage.read(key: 'db_encryption_key') ?? await _generateAndStoreKey();
     final db = await openDatabase(path, password: dbKey, version: kCurrentDbVersion, ...);
  3. _generateAndStoreKey() : générer 32 octets aléatoires (base64), stocker dans flutter_secure_storage clé 'db_encryption_key', retourner la valeur.
  4. Migration depuis une base non chiffrée (utilisateurs existants) : détecter si la base est lisible sans mot de passe → exporter, recréer chiffrée, réimporter.
  5. Ne jamais passer password: null à openDatabase().

Impact : pubspec.yaml uniquement + DatabaseHelper. Aucun autre changement d'API.
```

</details>

---

### 1.3 — ForceOfflineNotifier : StateNotifier → Notifier — Bug 7
- [ ] Terminé
- [ ] Testé (`flutter analyze` OK)
- [ ] Commité

**Fichiers impactés :** `lib/providers/sync_provider.dart`

<details>
<summary>PROMPT PRÉCIS</summary>

```
Tu dois corriger le Bug 7 du manifest : Migration ForceOfflineNotifier (StateNotifier → Notifier).

Fichier cible : lib/providers/sync_provider.dart — classe ForceOfflineNotifier.

Problème : ForceOfflineNotifier étend StateNotifier<bool> (API legacy Riverpod 2). Riverpod 3 déprécie StateNotifier.

Correction :
  1. Remplacer : class ForceOfflineNotifier extends StateNotifier<bool> { ForceOfflineNotifier() : super(false); ... }
     Par : class ForceOfflineNotifier extends Notifier<bool> { @override bool build() => false; ... }
  2. Remplacer la déclaration du provider :
     Avant : final forceOfflineProvider = StateNotifierProvider<ForceOfflineNotifier, bool>((ref) => ForceOfflineNotifier());
     Après : final forceOfflineProvider = NotifierProvider<ForceOfflineNotifier, bool>(ForceOfflineNotifier.new);
  3. L'accès en lecture (ref.watch/ref.read) reste identique — aucun changement côté consommateurs.
  4. Les mutations : remplacer state = x (identique, Notifier expose aussi state en lecture/écriture).
```

</details>

---

### 1.4 — ProviderObserver + FlutterError.onError — Bug 10
- [ ] Terminé
- [ ] Testé (`flutter analyze` OK)
- [ ] Commité

**Fichiers impactés :** `lib/main.dart`

<details>
<summary>PROMPT PRÉCIS</summary>

```
Tu dois corriger le Bug 10 du manifest : ProviderObserver global + FlutterError.onError.

Fichier cible : lib/main.dart.

Problème : Rien ne capture les erreurs non attrapées. La table system_logs reste vide en prod.

Correction :
  1. Crée class AppProviderObserver extends ProviderObserver avec :
     @override void providerDidFail(provider, error, stackTrace, container) {
       AppLogger.error('Provider ${provider.name} failed', error: error, stackTrace: stackTrace);
     }
  2. Dans main(), wrape runApp avec :
     FlutterError.onError = (details) => AppLogger.error('Flutter error', error: details.exception, stackTrace: details.stack);
     PlatformDispatcher.instance.onError = (error, stack) { AppLogger.error('Platform error', error: error, stackTrace: stack); return true; };
  3. Passe l'observer à ProviderScope :
     ProviderScope(observers: [AppProviderObserver()], child: MonAgendaApp())
```

</details>

---

### 1.5 — Déduplication sync_queue — Bug 1
- [ ] Terminé
- [ ] Testé (`flutter analyze` OK)
- [ ] Commité

**Fichiers impactés :** `lib/core/database/database_helper.dart`

<details>
<summary>PROMPT PRÉCIS</summary>

```
Tu dois corriger le Bug 1 du manifest : Déduplication sync_queue.

Fichier cible : lib/core/database/database_helper.dart — méthode enqueueSync() (ou équivalent d'insertion dans sync_queue).

Problème : Si un event est modifié N fois en mode offline, N lignes UPDATE sont insérées. Au retour réseau, N requêtes API partent inutilement.

Correction : Avant d'insérer une ligne action='UPDATE', exécute :
  await db.delete('sync_queue', where: 'event_id = ? AND action = ? AND status = ?', whereArgs: [eventId, 'UPDATE', 'pending']);
Cela écrase silencieusement les updates antérieurs non encore envoyés.
NE PAS faire ce DELETE pour les actions 'CREATE' ou 'DELETE'.
```

</details>

---

### 1.6 — deleteEvent indépendant de la pagination — Bug 2
- [ ] Terminé
- [ ] Testé (`flutter analyze` OK)
- [ ] Commité

**Fichiers impactés :** `lib/core/database/database_helper.dart`

<details>
<summary>PROMPT PRÉCIS</summary>

```
Tu dois corriger le Bug 2 du manifest : deleteEvent indépendant de la pagination.

Fichier cible : lib/core/database/database_helper.dart — méthode deleteEvent().

Problème : La suppression logique (is_deleted=1) et l'enqueue sync dépendent de l'event étant présent dans le state mémoire Riverpod. Si l'event a scrollé hors de la vue, il est introuvable → désync permanente.

Correction : La méthode deleteEvent(String eventId) doit exclusivement opérer via SQL :
  1. UPDATE events SET is_deleted = 1, updated_at = NOW() WHERE id = ? (ou remote_id)
  2. Appeler directement enqueueSync(eventId, action: 'DELETE') sans passer par le state Riverpod.
Le state Riverpod est invalidé (ref.invalidate) APRÈS l'opération SQL, jamais avant.
```

</details>

---

### 1.7 — Full Text Search (SQLite FTS5) — Bug 3
- [ ] Terminé
- [ ] Testé (`flutter analyze` OK)
- [ ] Commité

**Fichiers impactés :** `lib/core/database/database_helper.dart` + `lib/core/database/db_migrations.dart`

<details>
<summary>PROMPT PRÉCIS</summary>

```
Tu dois corriger le Bug 3 du manifest : Full Text Search (SQLite FTS5).

Fichier cible : lib/core/database/database_helper.dart.

Problème : Les recherches LIKE '%mot%' sur les colonnes description et participants (JSON sérialisé) sont lentes et retournent des faux positifs.

Correction en 3 étapes :
  Étape 1 — La table FTS5 et les triggers sont déjà dans kMigrations[8] (tâche 1.1). Vérifier leur présence.
  Étape 2 — Remplacer les requêtes de recherche LIKE par :
    SELECT * FROM events WHERE id IN (SELECT rowid FROM events_fts WHERE events_fts MATCH ?);
  Étape 3 — Dans onUpgrade(), les migrations sont déjà gérées par le système centralisé (tâche 1.1).

Note : La table events_fts couvre title, description, location. Les triggers AFTER INSERT/UPDATE/DELETE maintiennent la synchronisation.
```

</details>

---

### 1.8 — Bannière "serveur saturé" (serverSyncErrorProvider) — Bug 6
- [ ] Terminé
- [ ] Testé (`flutter analyze` OK)
- [ ] Commité

**Fichiers impactés :** `lib/providers/sync_provider.dart` + widget bannière

<details>
<summary>PROMPT PRÉCIS</summary>

```
Tu dois corriger le Bug 6 du manifest : Bannière "serveur saturé".

Fichier cible : lib/providers/sync_provider.dart + widget bannière existant.

Problème : La bannière pending ne s'affiche qu'en mode offline forcé. Si le serveur est en ligne mais sature (503, 429, timeout), retry_count croît silencieusement.

Correction :
  1. Dans SyncQueueWorker, si une tentative de dépilage retourne statusCode 429/500/503 ou throw TimeoutException : émettre un événement dans un nouveau provider serverSyncErrorProvider (StateProvider<String?> — null = pas d'erreur, String = message d'erreur).
  2. Dans le widget bannière (ou dans app.dart), watch serverSyncErrorProvider. Si non null : afficher une SnackBar persistante orange "⚠️ Synchronisation en erreur (serveur)" avec un bouton "Réessayer" qui appelle ref.read(syncNotifierProvider.notifier).flushQueue().
  3. Réinitialiser serverSyncErrorProvider à null après un flush réussi ou après que l'utilisateur ferme la bannière.
```

</details>

---

### 1.9 — Conflits ETag (last-remote-wins) — Bug 8
- [ ] Terminé
- [ ] Testé (`flutter analyze` OK)
- [ ] Commité

**Fichiers impactés :** `lib/services/infomaniak_service.dart`

<details>
<summary>PROMPT PRÉCIS</summary>

```
Tu dois corriger le Bug 8 du manifest : Conflits ETag (modification simultanée offline + serveur).

Fichier cible : lib/services/infomaniak_service.dart — méthode pushEvent() ou équivalent.

Problème : Si un événement est modifié offline ET modifié côté CalDAV, le PROPATCH retourne 412 Precondition Failed. Comportement actuel : non géré.

Stratégie : Last-remote-wins + notification non-bloquante (comme Google Calendar).

Correction :
  1. Dans InfomaniakService.pushEvent(), si la réponse HTTP est 412 :
     a. Faire un GET immédiat pour récupérer la version serveur de l'event (avec son nouvel ETag).
     b. Mettre à jour SQLite avec la version serveur (override local).
     c. Supprimer l'entrée correspondante de sync_queue.
     d. Émettre via etagConflictProvider (StateProvider<EventModel?>) l'event overridé.
  2. Dans le widget principal, watch etagConflictProvider. Si non null : afficher SnackBar orange persistante "Cet événement a été modifié à distance — version serveur appliquée" avec bouton "Voir".
  3. Réinitialiser etagConflictProvider à null après affichage ou navigation.

INTERDICTION : Ne pas implémenter de merge 3-way — trop complexe pour V3. Last-remote-wins uniquement.
```

</details>

---

### 1.10 — Certificate pinning CalDAV + Notion — Bug 11
- [ ] Terminé
- [ ] Testé (`flutter analyze` OK)
- [ ] Commité

**Fichiers impactés :** `lib/services/infomaniak_service.dart` + `lib/services/notion_service.dart` + `lib/core/security/cert_pins.dart` (nouveau)

<details>
<summary>PROMPT PRÉCIS</summary>

```
Tu dois corriger le Bug 11 du manifest : Certificate pinning CalDAV + Notion.

Fichiers cibles : lib/services/infomaniak_service.dart + lib/services/notion_service.dart.

Problème : Les appels HTTP utilisent la chaîne TLS système sans vérification du certificat. Vulnérable à MitM sur WiFi public.

Correction :
  1. Dans InfomaniakService (dio), configurer un BadCertificateCallback strict :
     (_dio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate = (client) {
       client.badCertificateCallback = (cert, host, port) {
         final sha256 = sha256.convert(cert.der).toString();
         if (!kInfomaniakCertPins.contains(sha256)) {
           AppLogger.error('Certificate pinning FAIL on $host : $sha256');
           throw CertificatePinningException('Certificat non reconnu pour $host');
         }
         return false;
       };
     };
  2. Faire de même dans NotionService pour les domaines *.notion.so.
  3. Définir les constantes dans lib/core/security/cert_pins.dart :
     const Set<String> kInfomaniakCertPins = { '<sha256_infomaniak_leaf_cert>', '<sha256_infomaniak_intermediate>' };
     const Set<String> kNotionCertPins = { '<sha256_notion_leaf_cert>' };
     Note : Ces valeurs SHA-256 doivent être extraites au moment du build via :
     openssl s_client -connect sync.infomaniak.com:443 | openssl x509 -fingerprint -sha256 -noout
  4. En cas de CertificatePinningException : SnackBar rouge persistante + log AppLogger.critical.
  5. INTERDICTION : Ne jamais passer badCertificateCallback = (_, __, ___) => true en production.
```

</details>

---

### 1.11 — kDrive backup endpoint — Bug 5
- [ ] Terminé
- [ ] Testé (`flutter analyze` OK)
- [ ] Commité

**Fichiers impactés :** `lib/services/backup_service.dart` + `lib/features/settings/screens/settings_screen.dart`

<details>
<summary>PROMPT PRÉCIS</summary>

```
Tu dois corriger le Bug 5 du manifest : Endpoint kDrive backup.

Fichier cible : lib/services/infomaniak_service.dart (ou backup_service.dart).

Problème : L'endpoint de dépôt du backup vers kDrive retourne une erreur (non trouvé) signalée dans l'audit V2.

Actions :
  1. Localise l'URL d'upload kDrive dans InfomaniakService. Valide qu'elle correspond au format WebDAV kDrive actuel : https://connect.infomaniak.com/WebDAV/<username>/.
  2. Ajoute une méthode testKDriveConnection() → Future<bool> qui fait un OPTIONS ou un PROPFIND sur la racine et retourne true si 200/207.
  3. Dans l'écran de réglages (settings_screen.dart), ajoute un bouton "Tester la connexion kDrive" qui appelle cette méthode et affiche une SnackBar verte ("✓ kDrive accessible") ou rouge ("✗ Erreur : <statusCode>").
  4. Utilise les credentials depuis ref.read(settingsProvider) uniquement. Ne jamais hardcoder l'URL.
```

</details>

---

### 1.12 — Supprimer flex_color_scheme (dépendance fantôme)
- [ ] Terminé
- [ ] Testé (`flutter analyze` OK)
- [ ] Commité

**Fichiers impactés :** `pubspec.yaml`

<details>
<summary>PROMPT PRÉCIS</summary>

```
Supprimer flex_color_scheme de pubspec.yaml.
Cette dépendance est déclarée mais n'est importée NULLE PART dans lib/.
C'est une dépendance fantôme identifiée lors de l'audit du 28/02/2026.
Exécuter flutter pub get après suppression pour valider.
```

</details>

---

## PHASE 2 — Optimisation Build & Documentation

### 2.1 — Réduction APK 95Mo → <40Mo — Prompt 7
- [ ] Terminé
- [ ] Testé (`flutter analyze` OK + build APK)
- [ ] Commité

**Fichiers impactés :** `android/app/build.gradle` + `pubspec.yaml` + fichiers Dart (const widgets)

<details>
<summary>PROMPT PRÉCIS</summary>

```
Tu dois appliquer les optimisations de build pour réduire l'APK de monAgenda de 95 Mo à moins de 40 Mo.

ANDROID (android/app/build.gradle) :
1. Dans buildTypes.release, ajoute :
   minifyEnabled true
   shrinkResources true
   proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
2. Compile avec : flutter build apk --split-per-abi
   Cela génère 3 APKs distincts (armeabi-v7a, arm64-v8a, x86_64) au lieu d'un seul "fat APK".

FLUTTER (pubspec.yaml) :
1. Vérifie que flutter.asset ne contient que les assets réellement utilisés.
2. Supprime tout tree-shaking de fonts non utilisées.

DART (code) :
1. Remplace tous les widgets qui peuvent être const par leurs équivalents const.
2. Ajoute @pragma('vm:prefer-inline') aux méthodes utilitaires très courtes.
3. Vérifie que chaque Widget Stateful dispose bien de son AnimationController, TextEditingController et StreamSubscription dans le dispose().

NOTE : Le modèle IA (fichier .gguf ~400Mo) ne sera jamais inclus dans l'APK. Il est téléchargé on-demand dans getApplicationDocumentsDirectory().
```

</details>

---

### 2.2 — Corrections V3GK.md — Prompt 6
- [ ] Terminé
- [ ] Testé (relecture)
- [ ] Commité

**Fichiers impactés :** `archive/V3GK.md`

<details>
<summary>PROMPT PRÉCIS</summary>

```
Tu dois mettre à jour le fichier V3GK.md pour corriger deux erreurs factuelles bloquantes.

ERREUR 1 — Section 7 (QR Code) : Le prompt actuel décrit zlib+base64. C'est obsolète.
Remplace entièrement le bloc "Contrainte algorithmique" par :
"Pipeline réel : JSON → jsonEncode → CryptoUtils.encryptToExportString(json, password) → String AES-256 → QrImageView(errorCorrectionLevel: QrErrorCorrectLevel.L). Import : String AES-256 → UI demande password → CryptoUtils.decryptFromExportString(encoded, password) → jsonDecode. La méthode gzip+base64 est @Deprecated dans settings_provider.dart et ne doit JAMAIS être réutilisée."

ERREUR 2 — Section 9 (CalDAV) : Nomenclature erronée.
Remplace toutes les occurrences de :
- CalDAVClient → InfomaniakService
- CalDAVRepository → SyncEngine / SyncQueueWorker
- events_cache → events
- sync_queue (colonnes minimales) → sync_queue réelle (id, action, source, event_id, payload, created_at, retry_count, last_error, status)
- CalendarProvider → syncNotifierProvider (NotifierProvider<SyncNotifier, SyncState>)

AJOUTS REQUIS :
Ajoute une section "État du Code Référence" documentant :
1. Les 8 tables SQLite réelles avec leurs colonnes
2. Les 4 clés flutter_secure_storage nommées
3. La hiérarchie Riverpod complète
```

</details>

---

## PHASE 3 — Features Core V3

### 3.1 — Smart Context PDF + migration v7 (smart_attachments) — Prompt 4
- [ ] Terminé
- [ ] Testé (`flutter analyze` OK)
- [ ] Commité

**Fichiers impactés :** `lib/core/models/event_model.dart` + `lib/features/events/screens/event_detail_screen.dart` + `lib/core/database/db_migrations.dart`

**Dépend de :** Phase 1.1 (db_migrations)

<details>
<summary>PROMPT PRÉCIS</summary>

```
Tu dois implémenter le "Smart Context" de monAgenda : association de fichiers locaux à un événement, analysée sur Desktop, affichée sur Mobile.

CONTEXTE :
- Sur Desktop, l'utilisateur peut associer à un événement des fichiers locaux (PDF, DOCX, etc.) via un file picker.
- Les chemins sont stockés dans EventModel.smartAttachments (List<String>).
- Sur Mobile, un clic ouvre le fichier via open_filex (si le chemin local existe sur cet appareil).

MIGRATION SQLITE REQUISE (déjà dans kMigrations[7]) :
   ALTER TABLE events ADD COLUMN smart_attachments TEXT DEFAULT '[]';
   Dans EventModel : ajoute le champ final List<String> smartAttachments.
   Dans toMap() : ajoute 'smart_attachments': jsonEncode(smartAttachments).
   Dans fromMap() : ajoute smartAttachments: jsonDecode(map['smart_attachments'] ?? '[]').cast<String>().

CONTRAINTES TECHNIQUES DESKTOP :
1. Crée dans EventDetailView_Desktop un bouton "+ Attacher un fichier" qui ouvre file_picker (FilePicker.platform.pickFiles).
2. Le chemin sélectionné est ajouté à EventModel.smartAttachments via ref.read(eventsProvider.notifier).addAttachment(event.id, path).
3. Ce changement est persisté en SQLite ET poussé dans la sync_queue.

CONTRAINTES TECHNIQUES MOBILE :
1. Pour chaque chemin dans smartAttachments, affiche un bouton avec le nom du fichier.
2. Au clic : vérifier File(path).exists(). Si true → OpenFilex.open(path). Si false → SnackBar orange.
3. INTERDICTION : Aucun moteur ML/NLP/PDF parser sur Mobile.
```

</details>

---

### 3.2 — Onboarding SetupScreen — Prompt 10
- [ ] Terminé
- [ ] Testé (`flutter analyze` OK)
- [ ] Commité

**Fichiers impactés :** `lib/features/setup/setup_screen.dart` (nouveau) + `lib/app.dart`

<details>
<summary>PROMPT PRÉCIS</summary>

```
Tu dois implémenter l'écran de configuration initiale de monAgenda (premier lancement ou credentials vides).

CONTEXTE :
- Au premier lancement, les 4 clés flutter_secure_storage sont toutes null.
- Si SettingsNotifier.isConfigured == false, l'app redirige vers SetupScreen.
- L'onboarding est en 3 étapes : (1) Infomaniak CalDAV, (2) Notion, (3) Test de sync.

CONTRAINTES TECHNIQUES :
1. Ajoute dans AppSettings un getter isConfigured → bool :
   bool get isConfigured => infomaniakUsername != null && infomaniakAppPassword != null && infomaniakCalendarUrl != null;
   (Notion est optionnel.)
2. ⚠️ Le projet n'utilise PAS go_router — navigation impérative (Navigator.push/pop). Le guard de routage :
   // Dans AppShell.initState() ou via addPostFrameCallback :
   final isConfigured = ref.read(settingsProvider).valueOrNull?.isConfigured ?? false;
   if (!isConfigured) {
     Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const SetupScreen()));
   }
3. SetupScreen (lib/features/setup/setup_screen.dart) :
   - PageView à 3 pages avec PageController. Indicateur de progression (3 dots).
   - Page 1 (Infomaniak) : 3 TextField (Username, App Password, Calendar URL) + bouton "Suivant".
   - Page 2 (Notion) : 1 TextField (API Key) + "Passer" (skippable) et "Connecter".
   - Page 3 (Test sync) : Bouton "Tester la connexion" → affiche ✓ ou ✗. Bouton "Commencer" activé si Infomaniak ✓.
4. URL CalDAV validée par RegExp(r'^https://.+/calendar/.+$').
5. INTERDICTION : Pas d'AlertDialog/BottomSheet. Écran à part entière.
6. TextFields de mots de passe : obscureText: true + IconButton œil pour toggle.
```

</details>

---

### 3.3 — Import QR complet (events) — Prompt 11
- [ ] Terminé
- [ ] Testé (`flutter analyze` OK)
- [ ] Commité

**Fichiers impactés :** `lib/features/import/import_qr_screen.dart` (nouveau) + providers

<details>
<summary>PROMPT PRÉCIS</summary>

```
Tu dois implémenter l'import des données via QR Code dans monAgenda. Le plugin mobile_scanner est déjà actif.

CONTEXTE :
- L'export QR produit une string AES-256 via CryptoUtils.encryptToExportString(json, password).
- L'import = scan QR → demande password → déchiffrement → merge SQLite.
- Mobile ET Desktop (Desktop via image QR importée depuis fichier).

CONTRAINTES TECHNIQUES :
1. ImportQrScreen (lib/features/import/import_qr_screen.dart) :
   - Sur Mobile : MobileScanner widget plein écran avec overlay. onDetect reçoit le contenu QR.
   - Sur Desktop : bouton "Importer une image QR" → FilePicker (jpg, png) → MobileScannerController.analyzeImage(path).
2. Après détection :
   a. AlertDialog avec TextField obscureText:true pour le mot de passe.
   b. CryptoUtils.decryptFromExportString(encoded, password) dans try/catch.
   c. Si exception → TextField en erreur rouge "Mot de passe incorrect".
   d. Si succès → jsonDecode → List<Map> d'events.
3. Logique de merge (ImportNotifier.mergeImport(List<Map> events)) :
   a. Pour chaque event : chercher dans SQLite par remote_id + source.
   b. Si existe ET imported.updatedAt > local.updatedAt → UPDATE.
   c. Si n'existe pas → INSERT.
   d. Si existe ET imported.updatedAt <= local.updatedAt → SKIP.
   e. Retourner ImportResult(inserted: int, updated: int, skipped: int).
4. Après merge : SnackBar vert "Import terminé : X ajoutés, Y mis à jour, Z ignorés" + ref.invalidate(eventsProvider).
5. RIVERPOD : ImportNotifier (AsyncNotifier<ImportResult?>) exposé via importProvider.
6. NE JAMAIS écraser un event local plus récent. updatedAt gagne toujours.
```

</details>

---

## PHASE 4 — Pipeline IA (Saisie Magique)

### 4.1 — ModelDownloadService (téléchargement on-demand) — Prompt 9
- [ ] Terminé
- [ ] Testé (`flutter analyze` OK)
- [ ] Commité

**Fichiers impactés :** `lib/services/model_download_service.dart` (nouveau) + providers

<details>
<summary>PROMPT PRÉCIS</summary>

```
Tu dois implémenter ModelDownloadService pour gérer le cycle de vie du fichier .gguf de la Saisie Magique.

CONTEXTE :
- Le fichier .gguf (~400Mo) N'EST PAS dans l'APK/DEB. Téléchargé au premier clic "✨ Magie".
- Stockage : getApplicationDocumentsDirectory()/models/magic_model.gguf
- Intégrité vérifiée par SHA-256 hardcodé.

CONTRAINTES TECHNIQUES :
1. ModelDownloadService.ensureModelReady() → Future<String> (retourne le chemin local) :
   a. Si File(localPath).existsSync() et SHA-256 OK → retourne localPath.
   b. Sinon : téléchargement via dio (StreamResponse) depuis l'URL kDrive stockée dans settingsProvider.
   c. Stream la progression dans StreamController<double> → modelDownloadProgressProvider (StreamProvider<double>).
   d. Après complétion : vérifie SHA-256. Si mismatch → supprimer fichier + throw ModelIntegrityException.
2. MODEL_SHA256_HARDCODED défini dans le code source (ancrage de sécurité).
3. UX dans MagicEntryScreen : LinearProgressIndicator pendant téléchargement + pourcentage.
4. Gestion reprise partielle : headers HTTP Range + FileMode.append sur fichier .part.
5. RIVERPOD : modelDownloadStatusProvider (AsyncNotifier<ModelStatus>) avec enum { notDownloaded, downloading, ready, error }.
6. Vérification SHA-256 du fichier 400Mo dans un Isolate.run().
```

</details>

---

### 4.2 — MagicEntryService (Saisie Magique NLP) — Prompt 1
- [ ] Terminé
- [ ] Testé (`flutter analyze` OK)
- [ ] Commité

**Fichiers impactés :** `lib/services/magic_entry_service.dart` (nouveau) + `lib/features/magic/magic_entry_screen.dart` (nouveau) + providers

**Dépend de :** 4.1 (ModelDownloadService)

<details>
<summary>PROMPT PRÉCIS</summary>

```
Tu dois implémenter le module MagicEntryService pour la "Saisie Magique" de monAgenda.

CONTEXTE :
- L'utilisateur tape en langage naturel : "Dîner avec Marc vendredi 20h au Resto #Perso"
- L'app extrait : title, startDate, startTime, endTime, location, category
- Inférence 100% locale via llama.cpp (GGUF 4-bit)
- Modèle : H2O Danube 3 (500M, q4_k_m, ~400Mo)

INTERDICTIONS :
- Ne pas utiliser tflite_flutter
- Ne pas faire d'appel HTTP vers une API Cloud
- Ne jamais appeler llama.cpp depuis le thread principal Flutter

CONTRAINTES TECHNIQUES :
1. Wrapper FFI : dart:ffi pour llama.cpp (.so Android / .dll Windows)
2. Isolate obligatoire : Isolate.run(() async { ... })
3. Grammaire GBNF obligatoire (texte exact fourni dans le manifest Prompt 1)
4. Sortie → jsonDecode() directement. Aucun post-traitement regex.
5. Mapping @mentions par le Controller Flutter, pas le service IA.
6. UX : bouton "✨ Magie" sur Mobile, Ctrl+K "Spotlight" sur Desktop. Animation shimmer pendant attente.
7. Le .gguf est téléchargé on-demand (via ModelDownloadService, tâche 4.1).
8. Stratégie Regex-first OBLIGATOIRE :
   - Patterns : #\w+ → category, @\w+ → participant, \d{1,2}[h:]\d{2} → heure, demain|lundi|... → date relative
   - Si title + date extraits par Regex → NE PAS appeler llama.cpp (~80% des cas)
9. Validateur post-IA : title.isNotEmpty, date pas absurde, startTime < endTime, category connue
10. System prompt exact (< 60 tokens, texte fourni dans manifest)
11. SLA : < 3s Android mid-range, timeout 8s, log durée via AppLogger

RIVERPOD : MagicEntryNotifier (AsyncNotifier<EventModel?>) via magicEntryProvider.
Méthode : parseText(String input) → Future<EventModel?>.
```

</details>

---

### 4.3 — Feedback Loop IA (magic_feedback) — Prompt 14
- [ ] Terminé
- [ ] Testé (`flutter analyze` OK)
- [ ] Commité

**Fichiers impactés :** `lib/core/database/magic_feedback_repository.dart` (nouveau) + `lib/core/database/db_migrations.dart` + settings screen

**Dépend de :** 4.2 + Phase 1.1

<details>
<summary>PROMPT PRÉCIS</summary>

```
Tu dois implémenter la boucle de feedback pour améliorer la Saisie Magique.

CONTEXTE :
- Chaque fois que l'IA parse un texte, l'utilisateur peut corriger le résultat manuellement.
- La paire (input_text, ia_output_corrigé) est stockée dans magic_feedback.
- 100% locale — aucun envoi Cloud.

MIGRATION SQLite (ajouter dans kMigrations, version suivante) :
  CREATE TABLE IF NOT EXISTS magic_feedback (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    input_text TEXT NOT NULL,
    ia_output_json TEXT NOT NULL,
    corrected_output_json TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (datetime('now'))
  );

CONTRAINTES TECHNIQUES :
1. Dans MagicEntryScreen, après validation :
   a. Si event modifié par rapport au JSON IA → MagicFeedbackRepository.record(input, iaJson, correctedJson).
   b. Si non modifié → NE PAS insérer.
2. Détection : comparer EventModel.toMap() avant et après édition. ≥ 1 champ différent = correction.
3. MagicFeedbackRepository (lib/core/database/magic_feedback_repository.dart) :
   - record(), getAll(), exportToCsv(), clear()
4. Dans SettingsScreen section "IA & Modèle" : compteur "X corrections", bouton "Exporter", bouton "Vider".
5. INTERDICTION : Ne jamais envoyer magic_feedback vers un serveur.

RIVERPOD : magicFeedbackCountProvider (FutureProvider<int>).
```

</details>

---

## PHASE 5 — Features Desktop Only

### 5.1 — Meeting Note Notion — Prompt 2
- [ ] Terminé
- [ ] Testé (`flutter analyze` OK)
- [ ] Commité

**Fichiers impactés :** `lib/services/notion_meeting_service.dart` (nouveau) + `lib/features/events/screens/event_detail_screen.dart`

<details>
<summary>PROMPT PRÉCIS</summary>

```
Tu dois implémenter NotionMeetingService + bouton conditionnel dans EventDetailView pour Desktop.

CONTEXTE :
- Sur Desktop, quand un événement est en cours ou a un tag "Réunion", un bouton "Ouvrir / Créer le compte-rendu" apparaît.
- Si une note liée existe dans Notion → l'ouvrir. Sinon → créer via API Notion.

INTERDICTIONS :
- Ne pas afficher ce bouton sur Mobile.
- Credentials Notion via ref.read(settingsProvider).notionApiKey uniquement.

CONTRAINTES TECHNIQUES :
1. NotionMeetingService.create(EventModel event) :
   - GET API Notion : vérifier si page avec titre de l'event existe dans la DB "Notes de réunion".
   - Si non : POST https://api.notion.com/v1/pages avec body approprié (Title, Date, Relation Agenda).
   - Headers : Authorization Bearer, Notion-Version 2022-06-28.
   - Retourne l'URL de la page.
2. Dans EventDetailView_Desktop :
   - Bouton → NotionMeetingService.create(). CircularProgressIndicator pendant l'appel.
   - Sur succès : launchUrl(notionPageUrl).
   - Sur erreur : SnackBar rouge.
3. L'ID de la DB "Notes de réunion" configurable dans SettingsNotifier.
```

</details>

---

### 5.2 — Vue Projet + Time Blocking Drag&Drop — Prompt 3
- [ ] Terminé
- [ ] Testé (`flutter analyze` OK)
- [ ] Commité

**Fichiers impactés :** `lib/features/project/project_view_screen.dart` (nouveau) + providers Notion tasks

<details>
<summary>PROMPT PRÉCIS</summary>

```
Tu dois implémenter la "Vue Projet" avec Drag & Drop pour le Time Blocking sur Desktop.

CONTEXTE :
- Mode "Time Blocking" activable sur Desktop.
- Vue divisée : Gauche (flex 3) = SfCalendar hebdomadaire, Droite (flex 1) = tâches Notion non datées.
- L'utilisateur glisse une tâche vers un créneau du calendrier → update Date dans Notion + SQLite.

INTERDICTIONS :
- JAMAIS sur Mobile. Condition : LayoutBuilder constraints.maxWidth > 800.

CONTRAINTES TECHNIQUES :
1. Tâches dans la liste droite = Draggable<NotionTaskModel>.
2. Créneaux du SfCalendar = DragTarget<NotionTaskModel>.
3. onAccept :
   a. OPTIMISTIC UI : injecter Appointment visuel immédiatement.
   b. Retirer tâche de la liste immédiatement.
   c. En arrière-plan : NotionRepository.updateTaskDate(). Si erreur → rollback + SnackBar rouge.
4. calendarController.getCalendarDetailsAtOffset(offset) pour extraire le DateTime du drop.
5. RIVERPOD : NotionProjectTasksNotifier (AsyncNotifier<List<NotionTaskModel>>). Méthode assignDate(taskId, date) avec Optimistic Update + rollback.
```

</details>

---

## PHASE 6 — UX & Polish

### 6.1 — Refonte UX Paramètres — Prompt 12
- [ ] Terminé
- [ ] Testé (`flutter analyze` OK)
- [ ] Commité

**Fichiers impactés :** `lib/features/settings/screens/settings_screen.dart` (refonte complète)

<details>
<summary>PROMPT PRÉCIS</summary>

```
Tu dois refondre l'écran des paramètres. Passer d'une liste plate à 5 sections thématiques.

CONTEXTE :
- Palette et typo de référence : DESIGN_SYSTEM.md.
- Desktop : NavigationRail latéral avec 5 sections. Contenu à droite.
- Mobile : ListView avec ExpansionTile collapsibles.

5 SECTIONS :
  🔗 Comptes       — Infomaniak (username + url + test) | Notion (API key + test) | indicateurs ✓/✗
  🔔 Notifications — Toggle rappels | délai Slider 5-60 min | toggle sync silencieuse
  🎨 Apparence     — Dark/Light/Auto | couleur accent (9 Stabilo) | Dense vs Comfortable
  🤖 IA & Modèle   — Statut modèle + taille + Télécharger/Supprimer | URL | toggle Regex-first only
  ⚙️ Avancé        — Export/Import QR | Vider sync_queue | Réinitialiser (double confirmation)

CONTRAINTES :
1. Tout via ref.watch(settingsProvider) / ref.read(settingsProvider.notifier).
2. Tests connexion Infomaniak/Notion : FutureBuilder avec cache 5 min.
3. Réinitialiser : DEUX AlertDialog successifs avant DatabaseHelper.dropAndRecreate() + deleteAll() + restart.
4. Desktop : NavigationRail labelType all. Mobile : ExpansionTile.
5. INTERDICTION : Aucun appel direct à FlutterSecureStorage dans le widget.
```

</details>

---

### 6.2 — Refonte Graphique M3 (harmonisation Design System) — Prompt 13
- [ ] Terminé
- [ ] Testé (`flutter analyze` OK)
- [ ] Commité

**Fichiers impactés :** `lib/app.dart` + tous les écrans + `assets/logos/`

<details>
<summary>PROMPT PRÉCIS</summary>

```
Tu dois appliquer la refonte graphique finale, en conformité totale avec DESIGN_SYSTEM.md.

OBJECTIF : Harmonisation des tokens sur toutes les screens. M3 et NavigationBar déjà actifs.

⚠️ useMaterial3: true DÉJÀ actif. ColorScheme explicite DÉJÀ construit (20+ tokens). NE PAS remplacer par ColorScheme.fromSeed().

ÉTAPE 1 — ThemeData dans app.dart :
  Garder le ColorScheme existant. Ajouter/harmoniser :
  fontFamily 'Inter', CardTheme(elevation: 0, borderRadius 12), DividerTheme, AppBarTheme(fond #F7F6F3, elevation 0).
  Thème dark : background #191919, surface #252525.

ÉTAPE 2 — Navigation : NavigationBar déjà M3. Harmoniser indicatorColor + labelBehavior.

ÉTAPE 3 — Composants : ElevatedButton borderRadius 10, Card sans elevation + border, TextField filled #F7F6F3, SnackBar floating borderRadius 8.

ÉTAPE 4 — Logos : 3 variantes SVG (light, dark, splash) dans assets/logos/. Icône calendrier + point accent Stabilo Orange #FFBD98.

ÉTAPE 5 — Typographie Inter : Display 24px Bold, Body 15px Regular, Caption 13px Medium.

ÉTAPE 6 — Empty states + micro-animations :
  - Agenda vide → IllustrationWidget + "Aucun événement ce jour" + bouton "+ Créer".
  - Search 0 résultat → suggestion terme plus court.
  - FadeTransition 200ms sur EventCards, SlideTransition 250ms sur BottomSheet.
  - Respecter MediaQuery.disableAnimations (accessibilité).

INTERDICTIONS : Zéro dégradé. Zéro ombre > elevation 2. Zéro couleur hardcodée hors DESIGN_SYSTEM.
```

</details>

---

### 6.3 — Home Widget Android — Prompt 5
- [ ] Terminé
- [ ] Testé (`flutter analyze` OK + build APK)
- [ ] Commité

**Fichiers impactés :** `lib/services/home_widget_service.dart` (nouveau) + `android/app/src/main/...` (Kotlin + XML)

<details>
<summary>PROMPT PRÉCIS</summary>

```
Tu dois implémenter le widget d'écran d'accueil Android via home_widget (^0.7.0).

CONTEXTE :
- Affiche les 7 prochains RDV (titre + date/heure) sur l'écran d'accueil.
- Mise à jour après chaque sync réussie + à l'ouverture de l'app.

CÔTÉ DART (lib/services/home_widget_service.dart) :
1. HomeWidgetService.update(List<EventModel> events) :
   - 7 prochains events triés par date.
   - Pour chaque : HomeWidget.saveWidgetData<String>('event_$i_title', event.title) + time.
   - HomeWidget.updateWidget(name: 'MonAgendaWidget').
2. Appeler après chaque sync réussie dans SyncNotifier.
3. Déduplication : ne mettre à jour que si la liste a changé.

CÔTÉ ANDROID :
1. res/layout/widget_agenda.xml : LinearLayout vertical, 7 TextViews.
2. res/xml/widget_agenda_info.xml : AppWidgetProviderInfo (250dp x 200dp, updatePeriod 30min).
3. kotlin/.../MonAgendaWidget.kt : AppWidgetProvider, lit via SharedPreferences (HomeWidget), peuple RemoteViews.
4. AndroidManifest.xml : <receiver> avec APPWIDGET_UPDATE + meta-data.
```

</details>

---

### 6.4 — Raccourcis clavier Desktop — Prompt 15
- [ ] Terminé
- [ ] Testé (`flutter analyze` OK)
- [ ] Commité

**Fichiers impactés :** `lib/app.dart` + `lib/features/settings/screens/settings_screen.dart`

<details>
<summary>PROMPT PRÉCIS</summary>

```
Tu dois implémenter les raccourcis clavier globaux pour Desktop.

RACCOURCIS :
  Ctrl+N → Ouvrir formulaire création d'événement
  Ctrl+F → Focus champ de recherche
  Ctrl+K → Ouvrir barre Saisie Magique (Spotlight)
  Escape → Fermer modal/BottomSheet (Navigator.maybePop)
  Espace → Toggle done/pending si focus sur EventCard tâche
  Delete → AlertDialog confirmation suppression si focus sur EventCard
  Tab    → Navigation entre champs (comportement natif — vérifier FocusNode)
  Ctrl+S → Sauvegarder formulaire en cours

CONTRAINTES :
1. Dans app.dart, wrapper le widget racine :
   if (Platform.isLinux || Platform.isWindows)
     CallbackShortcuts(bindings: {...}, child: Focus(autofocus: true, child: child))
2. Actions via Navigator.push() — le projet utilise la navigation impérative, pas go_router.
3. Tooltip d'aide sur boutons principaux : Tooltip(message: 'Ctrl+N', child: ...).
4. INTERDICTION : Ne pas installer CallbackShortcuts sur Mobile.
5. Dans SettingsScreen section "Avancé" : bouton "Voir les raccourcis" → SimpleDialog listant tous les shortcuts.
```

</details>

---

## MÉTRIQUES DE SUIVI

| Phase | Tâches | Terminées | % |
|-------|--------|-----------|---|
| Phase 1 — Infrastructure & Bugfixes | 12 | 0 | 0% |
| Phase 2 — Optimisation & Docs | 2 | 0 | 0% |
| Phase 3 — Features Core V3 | 3 | 0 | 0% |
| Phase 4 — Pipeline IA | 3 | 0 | 0% |
| Phase 5 — Features Desktop | 2 | 0 | 0% |
| Phase 6 — UX & Polish | 4 | 0 | 0% |
| **TOTAL** | **26** | **0** | **0%** |

---

## RÈGLES ABSOLUES (rappel — applicables à TOUTES les tâches)

1. State Management : Exclusivement `flutter_riverpod`. Jamais `provider`.
2. Credentials : Via `ref.read(settingsProvider)`. Jamais FlutterSecureStorage directement.
3. Réseau offline : Via `ref.watch(isOfflineProvider)`.
4. Thread IA : `Isolate.run(...)`. Jamais thread principal.
5. Plugins supprimés : JAMAIS réinstaller `flutter_contacts` ou `share_plus`.
6. QR Code : Pipeline AES-256 via `CryptoUtils`. Jamais gzip+base64.
7. CalDAV : `InfomaniakService`, pas `CalDAVClient`. Table `events`, pas `events_cache`.
8. Desktop/Mobile : Time Blocking, Meeting Note, Export PPT, Smart Context Parser = Desktop ONLY.
9. Couches : Notifiers ≠ UI. Widgets ≠ SQLite direct.
10. Logging : `AppLogger` uniquement. Zéro `print()`.
11. SQLite : `sqflite_sqlcipher` chiffré. Jamais `password: null`.

---

*Dernière mise à jour : 28/02/2026*
