# V3GK.md - ARCHITECTURE DECISION RECORD & INSTRUCTIONS DE PRODUCTION CIBLÉES

Ce document est le référentiel absolu de conception pour la V3 de l'application Mon Agenda. Il est destiné à Opus 4.6 (et tout agent IA) pour garantir une implémentation exacte, sans dérives, en respectant les choix d'architecture technique validés en amont.

---

## 1. GESTION DES DÉPENDANCES NATIVES ET DU PARTAGE (ÉCOSYSTÈME AGILE)

### 📝 Historique & Débat
Le dialogue a porté sur la lourdeur des intégrations natives pour la gestion des contacts et du partage. L'utilisation initiale de `flutter_contacts` et `share_plus` ajoutait un poids considérable à l'application et forçait la demande de permissions très intrusives (`android.permission.READ_CONTACTS`, équivalents iOS). Cela freinait l'adoption (peur pour la vie privée) et compliquait le code avec des états de permissions multiples.

### 🏗️ Choix Architectural Argumenté
**Suppression totale des dépendances natives sociales.** L'application subit une cure d'amincissement extrême ("Drop" des plugins `flutter_contacts`, `share_plus`, etc.).
*Argumentaire* : L'application n'a **pas** l'ambition de remplacer le carnet d'adresses de l'OS. Les notions de "Rendez-vous partagé", "Contacts" et "Collaboration" sont intégralement déléguées à **CalDAV (infrastructure backend via Infomaniak)** et à **Notion**. C'est le serveur qui s'occupe de résoudre les contacts et les invitations. Le Flutter de la V3 n'est qu'un frontend d'affichage "dummy" mais ultra-rapide. Cela garantit ZÉRO permission OS superflue et un respect total de la RGPD locale.

### 💻 To-Do Prompt Technique pour Opus 4.6
> **[PROMPT OPUS]**
> **Objectif :** Intégrer l'ajout de participants à un événement de l'agenda.
> **Contraintes Strictes :**
> - Ne JAMAIS réinstaller `flutter_contacts` ou `share_plus`.
> - Ne JAMAIS modifier `AndroidManifest.xml` ou `Info.plist` pour ajouter des requêtes de permissions de contacts.
> - Si tu dois lier une entité (@Marc), tu dois taper exclusivement dans `CalDAVService` ou `NotionRepository`. 
> - Côté UI, utilise une barre de recherche simple qui tape dans une liste issue d'une table SQLite locale pré-synchronisée (base infomaniak), jamais dans les adresses du téléphone. Rends l'UI légère et sans `PermissionHandler` pour ces requêtes.

---

## 2. SÉPARATION DES PARADIGMES : DESKTOP (USINE À GAZ) VS MOBILE (IMMÉDIATETÉ)

### 📝 Historique & Débat
L'application étant multi-plateforme, le besoin a émergé de ne pas offrir la "même" application sur un PC et sur un Smartphone, car les cas d'usages diffèrent. Le mobile sert à de la consultation éclair et de la création éclair. Le PC/Linux/Web sert à la planification complexe, la réorganisation (Time Blocking) et le traitement lourd de la donnée (génération de slides, exports).

### 🏗️ Choix Architectural Argumenté
Mise en place d'une architecture dichotomique via le routing et `LayoutBuilder` / `Platform.isX`.
**Desktop (Linux/Web) :** Destiné à l'interface "Usine à gaz". Conçue pour la souris et le clavier. Elle héberge la vue complète `syncfusion_flutter_calendar`, autorise le Drag & Drop hyper complexe, déclenche les processus d'application lourds via `Process.run` comme l'export PPT/CSV en attaquant des scripts Python natifs (`generate_calendar_ppt.py`), et est autorisée à faire du parsing profond sur des fichiers PDF.
**Mobile (Android/iOS) :** Focalisée à 100% sur le tactile, l'usage à une main et la conservation de batterie. Pas d'exports Python ni de traitements de fichiers massifs. On se concentre sur des vues minimalistes, l'appel aux flux natifs simplifiés, les `home_widget` (pour consultation depuis l'écran d'accueil de l'OS) et le scan de QR Code (`mobile_scanner` compressé via `zlib`).

### 💻 To-Do Prompt Technique pour Opus 4.6
> **[PROMPT OPUS]**
> **Objectif :** Créer la navigation globale et l'intégration des fonctionnalités lourdes vs légères.
> **Contraintes Strictes :**
> - Structure chaque `Screen` majeur avec un composant `ResponsiveBuilder`.
> - Sur le `DesktopScreenLayout` : Implémente obligatoirement les EventListeners pour le Drag & Drop. Intègre le bouton d'Export. Ce bouton doit instancier un `Process.run('python3', ['assets/calendar_export/generate_calendar_ppt.py'])` sans bloquer le thread principal.
> - Sur le `MobileScreenLayout` : Occulte l'Export PPT. Intègre des Floating Action Buttons ciblant exclusivement la "Saisie Magique" ou l'ouverture du scan de QR Code.
> - Pour la génération des QR codes d'export de paramétrages sur l'application globale, force la compression en encapsulant chaque payload dans un `zlib.encode()` et configure l'UI avec le niveau d'erreur `QrErrorCorrectLevel.L` pour maximiser la réactivité du `mobile_scanner`.

---

## 3. LA "SAISIE MAGIQUE" (MOTEUR NLP TOTALEMENT LOCAL)

### 📝 Historique & Débat
L'ajout manuel d'un rendez-vous sur mobile avec ses "Démarrages", "Fins", "Lieux", "Tags" est un enfer d'UX (DatePicker, TimePicker limitatifs). Une entrée libre : "Dîner avec @Marc vendredi 20h au Resto #Perso" est la solution "Google Killer". Le débat : quelle IA ? Les API Cloud posent d'énormes problèmes quant à la vie privée. TensorFlow Lite manque de souplesse sur les LLM modernes et manipuler des I/O strings de modèle est un cauchemar en Flutter.

### 🏗️ Choix Architectural Argumenté
**L'IA sera 100% locale, basée sur `llama.cpp` + FFI + Isolate + Quantification GGUF + Grammaire GBNF.**
*Argumentaire* : L'utilisation de `llama.cpp` via les wrappers FFI sur Dart offre une performance imbattable sur le natif (C++). On garantit l'empreinte de l'app en bloquant à un modèle de format 4-bit (GGUF, ~500Mo, famille Qwen2.5-0.5B ou H2O Danube). 
*La règle d'or* : La boucle d'inférence "llama_decode" va utiliser le CPU à 100%, elle DOIT ABSOLUMENT être isolée via `Isolate.run()` afin de ne pas paralyser le thread Flutter UI (60 FPS exigé).
De plus, aucune IA ne sera fiable à 100% en respect de JSON pur sans filet de sécurité. L'obligation technique est donc de passer le parser C++ sous contrainte **GBNF** afin de bloquer physiquement les tokens de l'IA aux limites syntaxiques de notre `EventModel`.

### 💻 To-Do Prompt Technique pour Opus 4.6
> **[PROMPT OPUS]**
> **Objectif :** Écrire le module `MagicEntryService` pour la génération en NLP (Natural Language Processing) de rendez-vous.
> **Contraintes Strictes :**
> - Tu as FORMELLEMENT L'INTERDICTION d'utiliser le plugin `tflite_flutter` ou de recourir à de l'API cloud tierce type OpenAI.
> - Implémente ou lie un wrapper `dart:ffi` exploitant les méthodes d'accès brut à `llama.cpp` (lib llama.so ou .dll).
> - Tout appel à la méthode de génération (ex: `generateTokens()`) de l'implémentation FFI doit IMPÉRATIVEMENT se produire dans un `Isolate.run(...)` séparé afin de certifier que Flutter ne subit aucun Event Loop Block. 
> - Lors de la création du contexte de l'IA applicative, alloue un fichier ou un format string spécifiant une syntaxe Grammaticale **GBNF pure JSON** imposant la production des clés `title`, `startTime`, `endTime`, `location` et `category`.
> - La string retournée est balancée dans un simple `jsonDecode()`. 
> - ATTENTION RÈGLE DB : L'IA ne doit jamais interroger SQLite. Si on écrit "Avec @Marc", l'IA répond juste avec la string "@Marc" dans l'attribut *title/location*. C'est le Controller Dart qui applique une expression régulière (RegExp) pour extraire ce token et mapper via DB l'UUID de l'utilisateur.

---

## 4. LA VISION "MEETING NOTE" : TRANSITION AGENDA -> CONTEXTE NOTION

### 📝 Historique & Débat
L'un des plus grands points de friction professionnels : la réunion se tient, mais les notes sont dispersées ou n'existent jamais, coupant le flow de productivité. Nous voulons transformer l'agenda en Hub génératif de contexte de travail, très fortement inspiré par le "Notion Calendar" spirité.

### 🏗️ Choix Architectural Argumenté
**L'Automatisation conditionnelle Parent Page vers Notion.** (Focus Interface Desktop)
Dès qu'un Event du calendrier arbore une logique formelle collaborative ("Réunion", "Update", "Call"), le panneau de détail injecte un appel d'action primaire ("Créer / Ouvrir le compte-rendu").
Si l'identifiant local rattaché à l'Event est caduc ou inexistant, l'agent applicatif effectue de manière silencieuse une méthode HTTP POST sur l'API Notion pour créer, au sein de la "Database Parent Réunions", une nouvelle page synchronisée (injectant Date + Title + Liaisons relations récupérés du CalDAV). Ensuite, il ouvre la note au format externe.

### 💻 To-Do Prompt Technique pour Opus 4.6
> **[PROMPT OPUS]**
> **Objectif :** Implémenter le composant `EventDetailView_Desktop` couplé au système de provisionning `NotionMeetingService`.
> **Contraintes Strictes :**
> - Insère conditionnellement un énorme bouton "Create/Open Meeting Note" si le paramètre category de l'Event ou les Tags dénotent d'une réunion.
> - La commande du bouton déclenche la création d'un Body Payload complet sur `https://api.notion.com/v1/pages` (headers: Notion-Version && Bearer Token de l'user).
> - Le JSON Notion doit inclure la propriété parente formatée en `database_id: "ID_MEETINGS"`, ainsi que l'injection des keys "Title" mappés au titre de l'Event, une propriété "Date" castée parfaitement au format ISO8601 depuis le startTime de l'Event, et lier la relation Projet parente si fournie.
> - Intègre expressément une gestion UI de transition : Remplacement du bouton Action par un `CircularProgressIndicator` durant le cycle HTTP, capture du statusCode (si 200), puis lancement de l'ouverture Web URL extraite du retour JSON Notion.

---

## 5. LA "VUE PROJET" & LE TIME BLOCKING (L'OUTLOOK KILLER)

### 📝 Historique & Débat
Sur Desktop (PC) : observer son temps n'est pas suffisant. On a le calendrier sur l'écran de gauche, et le suivi de tickets/tâches Notion sur le droit, obligeant à taper deux fois les données. La fusion de la gestion projet et du temps de calendrier (Time Blocking) devait être la "killer feature" de la V3.

### 🏗️ Choix Architectural Argumenté
**Architecture Split-Panel (Panneau double) interactif supportée par `SfCalendar` et état "Optimistic Ui".**
La racine de la page de planification Desktop expose un `Row`. À gauche : un massif module de rendu agenda basé sur `syncfusion_flutter_calendar`. À la droite : une barre Inbox listant les tâches Notion actuellement dépourvues de variables temporelles (`date_start == null`).
Le fonctionnement s'orchestre avec un Drag & Drop complet entre les deux environnements. 

### 💻 To-Do Prompt Technique pour Opus 4.6
> **[PROMPT OPUS]**
> **Objectif :** Développer le composant de Drag&Drop croisé (Time Blocking) sur l'expérience Desktop.
> **Contraintes Strictes :**
> - Au sein de la `DesktopCalendarScreen`, configure un `Row` principal doté d'éléments enfichables (`Expanded` de facteur 3 pour `SfCalendar`, et `Expanded` de facteur 1 pour la Vue Liste des tâches).
> - Enroule l'intégralité des UI Tuiles composant le bloc liste tâches Notion par un constructeur `Draggable<NotionTaskModel>`.
> - Active la permission implicite de destination sur le controleur d'agenda. Connecte l'événement d'Acceptation de Drag (`onDragOver` / Zone Drop) sur le composant grille.
> - Dans la fonction `onAccept`, extrais l'emplacement temporel via le widget pointant (utiliser la mathématique d'Offset Syncfusion : `calendarController.getCalendarDetailsAtOffset()`) afin d'obtenir un `DateTime` cible.
> - Code expressément la logique de l'**Optimistic UI Update** : Insère instantanément le render graphique de l'Appointment dans la state UI (sans attente !), et confie la méthode asynchrone API `NotionRepository.updateTaskDate(task.id, calcDate)` dans une exécution en arrière-plan (Future). Assure un block `.catchError` qui va faire un Rollback de la liste visuelle et envoyer une `SnackBar` de danger.

---

## 6. L'ENRICHISSEMENT INTELLIGENT (SMART CONTEXT PDF)

### 📝 Historique & Débat
La consultation du "Où ?" "Comment ?" à la dernière minute. Tenter de chercher un fichier (Billet de bus/train, Contrat) dans sa messagerie mobile est un lourd frein. La plateforme Desktop possède des facultés CPU/Idle capables d'anticiper la demande.

### 🏗️ Choix Architectural Argumenté
**Séparation pure du modèle d'Analyse (Desktop) VS Affichage (Mobile).** 
La routine Desktop/Backend (quand disponible) s'occupe de scrapper ou d'analyser le corps textuel et les pièces jointes des Notes Notion connectées aux prochains événements (heuristique simple : "Train", "Billet", Lien web dans le text payload). Il opère le téléchargement des PDF critiques sur le drive local et pousse le chemin local absolu dans le modèle BDD de l'Event concerné (`smartAttachments: List<String>`).
À l'inverse absolue : le Mobile n'embarque strictemet AUNCUN moteur de téléchargement lourd automatisé ni parsing (optimisation ultime de l'énergie et RAM). Il agit comme le terminal d'accès terminal.

### 💻 To-Do Prompt Technique pour Opus 4.6
> **[PROMPT OPUS]**
> **Objectif :** Implémenter l'extraction asynchrone Desktop / le visuel d'affichage fichier direct sur Mobile.
> **Contraintes Strictes :**
> - Conception de la classe logique `SmartContextService` (côté Desktop OS) : Parcourt le array block textuel Notion lié. Effectue des RegEx ciblant la classe URL des PDFs attachés ou des sources billets connues. Vérifie le système lourd `dart:io` et télécharge physiquement l'Asset dans un sub-folder. Modifie le payload SQL local en y ajoutant le chemin stocké vers cet Event.
> - Conception d'UI pour `MobileEventDetailScreen` : Lis simplement le pointeur liste fourni par `EventModel.smartAttachments`. Si `isNotEmpty`, injecte un "Massive Button Action" identifiant un document local (Icon PDF).
> - L'action du dit-bouton doit faire appel exclusif sur le plugin simple `open_filex`, passant le bloc path issu de la base en argument. S'il y a un plantage de fichier (File.exists() = false), active la roue de téléchargement fallback. Mais interdis sous tout prétexte l'inclusion de ML / Heavy Parsing / NLP PDF Scanner sur la codebase réservée à Android/iOS.

---

## 7. QR CODE DE SAUVEGARDE / IMPORT DE CONFIGURATION (CROSS-PLATEFORME)

### 📝 Historique & Débat
Le besoin : permettre à l'utilisateur de sauvegarder et de transférer sa configuration applicative (clés API Notion, URL CalDAV, catégories personnalisées, préférences d'affichage) d'un appareil à l'autre, ou simply de faire une sauvegarde locale rapide. La contrainte : les QR codes standards ont une capacité limitée (~3KB en UTF-8 brut) et les payloads JSON de configuration peuvent vite depasser cette limite. Un QR code dense devient illisible pour `mobile_scanner` (angle, luminosité insuffisante). Il fallait trouver une solution de compression maximale garantissant un QR lisible à la volée sur n'importe quel smartphone.

### 🏗️ Choix Architectural Argumenté
**Pipeline obligatoire : Sérialisation JSON → Chiffrement AES-256 → QR avec niveau d'erreur L.**
*Argumentaire* : La méthode V1 (gzip+base64) est @Deprecated dans settings_provider.dart et ne doit JAMAIS être réutilisée.
Pipeline réel V2/V3 : JSON → `jsonEncode` → `CryptoUtils.encryptToExportString(json, password)` → String AES-256 → `QrImageView(errorCorrectionLevel: QrErrorCorrectLevel.L)`.
Import : String AES-256 → UI demande password → `CryptoUtils.decryptFromExportString(encoded, password)` → `jsonDecode`.
Le niveau de correction d'erreur `QrErrorCorrectLevel.L` (7% de redondance) est volontairement choisi au lieu de `M`, `Q` ou `H` car il permet d'encoder un volume de données nettement plus important dans une surface de QR identique, produisant des QR "moins denses" (carrés plus gros) donc nettement plus faciles à scanner avec `mobile_scanner`.

### 💻 To-Do Prompt Technique pour Opus 4.6
> **[PROMPT OPUS]**
> **Objectif :** Implémenter les écrans `BackupExportScreen` (génération QR) et `BackupImportScreen` (scan + restauration).
> **Contraintes Strictes :**
> - **Export (génération QR) :**
>   - Récupère le modèle `AppSettings` depuis `ref.read(settingsProvider)`.
>   - Sérialise en JSON : `jsonEncode(settings.toMap())`.
>   - Chiffre via AES-256 : `CryptoUtils.encryptToExportString(jsonString, password)`.
>   - L'utilisateur saisit un mot de passe dans un TextField `obscureText: true`.
>   - Passe la string AES-256 chiffrée au widget `QrImageView` avec le paramètre OBLIGATOIRE `errorCorrectionLevel: QrErrorCorrectLevel.L`. Ne jamais utiliser M, Q ou H.
>   - Ajoute un bouton "Copier le backup" qui copie la string chiffrée dans le clipboard comme fallback.
> - **Import (scan QR) :**
>   - Ouvre `MobileScannerController` et expose un `MobileScanner` widget plein écran.
>   - Sur le callback `onDetect`, extrais la valeur `barcode.rawValue`.
>   - Demande le mot de passe via AlertDialog avec TextField `obscureText: true`.
>   - Déchiffre : `CryptoUtils.decryptFromExportString(rawValue, password)` dans un try/catch.
>   - Si exception → TextField en erreur rouge "Mot de passe incorrect".
>   - Parse : `jsonDecode(decryptedString)` → `AppSettings.fromMap(...)`.
>   - Propose une boîte de dialogue de confirmation "Remplacer la config actuelle ?" avant toute écriture.
>   - Gère les erreurs de déchiffrement (payload corrompu, mauvais password) avec un catch + SnackBar d'avertissement explicite.
> - **INTERDICTION :** Ne jamais utiliser gzip+base64 (pipeline V1 @Deprecated).

---

## 8. RÉDUCTION, OPTIMISATION DU CODE ET DETTE TECHNIQUE (EXIGENCES V3)

### 📝 Historique & Débat
Le projet a accumulé de la dette technique au fil du temps : des flags `supportsX` inutilisés depuis les suppressions de plugins, des imports résiduels, des services partiellement implémentés, et un `platform_utils.dart` qui contenait encore des références à `flutter_contacts`. L'objectif de la V3 est de partir sur une base propre, sans code mort, pour que chaque nouvelle fonctionnalité ajoutée par Opus soit intégrée dans un codebase sain et lisible. La règle : toute ligne de code présente doit avoir une raison d'être. La V3 est l'occasion d'un refactor global avant d'ajouter les features.

### 🏗️ Choix Architectural Argumenté
**Audit systématique avant tout nouveau développement.** La dette a déjà été partiellement soldée : `flutter_contacts`, `share_plus` ont été retirés de `pubspec.yaml`, la permission `READ_CONTACTS` a été supprimée de `AndroidManifest.xml`, et le flag `supportsContacts` a été retiré de `platform_utils.dart`. Mais un audit Opus est nécessaire pour identifier et purger tout ce qui reste : imports orphelins, widgets non utilisés, services jamais appelés, code conditionnel basé sur des features supprimées. L'architecture doit ensuite converger vers un modèle en couches strict : `UI Layer` -> `ViewModel/Provider` -> `Repository` -> `DataSource (SQLite / HTTP)`. Aucun appel HTTP direct depuis un Widget. Aucune logique métier dans un `Screen`.

### 💻 To-Do Prompt Technique pour Opus 4.6
> **[PROMPT OPUS]**
> **Objectif :** Effectuer un audit complet du codebase Flutter et éliminer toute dette technique avant de commencer les nouvelles features V3.
> **Étapes Obligatoires à Exécuter DANS CET ORDRE :**
> 1. **Scan des imports inutilisés** : Passe en revue chaque fichier `.dart` dans `lib/`. Supprime tout import qui n'est pas référencé dans le corps du fichier. Utilise l'analyse statique `dart analyze` pour identifier les warnings `unused_import`.
> 2. **Purge du code mort lié aux plugins supprimés** : Recherche (grep) dans tout `lib/` les occurrences de : `flutter_contacts`, `share_plus`, `supportsContacts`, `READ_CONTACTS`, `ContactService`, `ShareService`. Supprime intégralement toute classe, méthode, ou variable liée.
> 3. **Audit de `platform_utils.dart`** : Ce fichier doit uniquement exposer des getters booléens propres : `isDesktop`, `isMobile`, `isLinux`, `isAndroid`. Toute autre logique applicative doit en être extraite.
> 4. **Vérification de la séparation des couches** : Pour chaque `Screen` (`*_screen.dart`), vérifie qu'il ne contient aucun appel directe à `http`, `sqflite`, ou `dio`. Si c'est le cas, extrais la logique dans le `Repository` correspondant.
> 5. **`const` systématique** : Tout widget Flutter qui peut être déclaré `const` doit l'être. Cela réduit drastiquement les rebuilds superflus et améliore les performances de 60 FPS sur Mobile.
> 6. **Vérification des `dispose()`** : Chaque `TextEditingController`, `AnimationController`, `ScrollController`, `StreamSubscription` instancié dans un `State` doit avoir son `dispose()` correspondant. Les fuites mémoire sur Mobile sont critiques.
> 7. **Rapport final** : Génère un fichier `AUDIT_V3.md` listant chaque fichier modifié, les lignes supprimées, et les problèmes architecturaux résolus. Ce fichier servira de preuve de la santé du codebase au démarrage de la V3.

---

## 9. SYNCHRONISATION CALDAV / INFOMANIAK (CŒUR DU SYSTÈME)

### 📝 Historique & Débat
La suppression de `flutter_contacts` et `share_plus` a délégué 100% de la gestion des contacts, des participants et de la collaboration à CalDAV. CalDAV est donc devenu le système nerveux central de l'application — pas un simple "import/export". C'est lui qui gère les events multi-plateformes, les invitations, les rappels serveur, et la synchronisation bi-directionnelle entre tous les appareils de l'utilisateur. La question architecturale était : comment gérer les conflits ? Comment éviter de saturer l'API Infomaniak à chaque rebuild Flutter inutile ? On a opté pour une stratégie de `sync_queue` avec timestamp de dernière synchronisation et résolution de conflits "Last Write Wins" côté serveur.

### 🏗️ Choix Architectural Argumenté
**Architecture CalDAV à 3 couches : `InfomaniakService` (HTTP CalDAV brut) → `SyncEngine` / `SyncQueueWorker` (cache SQLite + queue) → `syncNotifierProvider` (état Riverpod).**
*Argumentaire* : `InfomaniakService` ne fait que parler le protocole CalDAV (REPORT, PROPFIND, PUT, DELETE) via des requêtes HTTP Dio. Il ne connaît pas la UI. `SyncEngine` et `SyncQueueWorker` maintiennent un cache SQLite local (table `events`) qui sert de "source de vérité" pour l'UI — l'application est 100% utilisable hors ligne, le cache SQLite étant toujours à jour. Une table `sync_queue` SQLite locale (colonnes : id, action, source, event_id, payload, created_at, retry_count, last_error, status) stocke toutes les mutations locales en attente de synchronisation. Un `WorkManager` (plugin `workmanager` présent dans le repo) déclenche la synchronisation en arrière-plan toutes les X minutes, même quand l'app est fermée sur Android. La résolution de conflit applique "Last-remote-wins" via ETag (réponse 412 → GET serveur → override local → notification non-bloquante via `etagConflictProvider`).

### 💻 To-Do Prompt Technique pour Opus 4.6
> **[PROMPT OPUS]**
> **Objectif :** Implémenter la couche de synchronisation CalDAV complète avec cache offline-first.
> **Contraintes Strictes :**
> - **`InfomaniakService`** : Implémente les 4 méthodes HTTP CalDAV de base avec `dio` :
>   - `REPORT` (récupération des events dans un intervalle de dates, body XML `calendar-query`).
>   - `PROPFIND` (discovery de la collection CalDAV de l'user).
>   - `PUT` (création ou mise à jour d'un event, body iCal `.ics` avec header `If-Match: <etag>`).
>   - `DELETE` (suppression par UID).
>   - Gestion des headers obligatoires : `Content-Type: text/calendar`, `Authorization: Basic base64(user:token)`.
>   - Certificate pinning via `cert_pins.dart` (SHA-256 du cert Infomaniak).
> - **`SyncEngine` / `SyncQueueWorker`** : Maintient la table SQLite `events` comme source de vérité (voir schéma complet ci-dessous). Le flag `is_deleted = 1` signifie suppression logique.
> - **`sync_queue`** : Table SQLite (colonnes : `id INTEGER PRIMARY KEY AUTOINCREMENT`, `action TEXT NOT NULL`, `source TEXT NOT NULL`, `event_id INTEGER`, `payload TEXT NOT NULL`, `created_at TEXT NOT NULL`, `retry_count INTEGER DEFAULT 0`, `last_error TEXT`, `status TEXT DEFAULT 'pending'`). Chaque mutation locale ajoute une entrée ici. `SyncQueueWorker` dépile la queue et exécute les appels HTTP correspondants. Déduplication : les UPDATE successifs pour le même event_id écrasent les précédents pending.
> - **`WorkManager`** : Enregistre une tâche périodique `caldav_sync` avec `Workmanager().registerPeriodicTask(...)` à l'init de l'app.
> - **Résolution de conflit** : Si une `PUT` renvoie HTTP 412 (Precondition Failed — ETag mismatch), effectue un GET immédiat pour récupérer la version serveur, met à jour SQLite avec la version serveur (last-remote-wins), supprime l'entrée sync_queue, notifie via `etagConflictProvider`. Ne jamais implémenter de merge 3-way.
> - **Serveur saturé** : Si 429/500/503/timeout détecté, émettre dans `serverSyncErrorProvider` (StateProvider<String?>) pour bannière orange.
> - **Offline-first absolu** : À aucun moment l'UI ne doit attendre une réponse HTTP. Toutes les lectures UI se font exclusivement depuis SQLite.
> - **Riverpod** : `syncNotifierProvider` (`NotifierProvider<SyncNotifier, SyncState>`), `forceOfflineProvider` (`NotifierProvider<ForceOfflineNotifier, bool>`), `isOfflineProvider` (Provider<bool>).

---

## 10. EXPORT PPT/CSV VIA SCRIPT PYTHON (DESKTOP UNIQUEMENT)

### 📝 Historique & Débat
Le script `assets/calendar_export/generate_calendar_ppt.py` existe physiquement dans le repo. C'est une fonctionnalité "Desktop only" car elle requiert Python3 installé sur le système, une librairie `python-pptx`, et peut prendre plusieurs secondes d'exécution (génération de slides). Sur mobile ce n'est pas possible (pas d'interpréteur Python embarqué, consommation CPU/batterie prohibitive). Le débat : passer les données comment ? Par fichier temporaire JSON ? Par stdin ? On a choisi stdin/stdout pour éviter toute pollution de fichiers temporaires sur le disque.

### 🏗️ Choix Architectural Argumenté
**`Process.run()` avec injection de données via stdin JSON + récupération résultat via stdout.**
*Argumentaire* : Flutter sur Desktop peut lancer des processus OS via `dart:io`. Le processus Python est déclenché en mode non-interactif : Flutter sérialise les events du mois courant en JSON et les passe au script via stdin (`process.stdin.write`). Le script Python lit `sys.stdin`, génère le PPT en mémoire, et retourne le chemin absolu du fichier `.pptx` généré via stdout. Flutter récupère ce path et déclenche l'ouverture du fichier via `open_filex`. Ce pattern évite tout couplage de fichiers intermédiaires et garantit que l'UI n'est jamais bloquée (`Process.run` est asynchrone dans un `Future`).

### 💻 To-Do Prompt Technique pour Opus 4.6
> **[PROMPT OPUS]**
> **Objectif :** Implémenter le bouton d'export PPT/CSV sur `DesktopCalendarScreen` et le pipeline de communication avec `generate_calendar_ppt.py`.
> **Contraintes Strictes :**
> - Ce bouton et toute la logique d'export NE DOIT EXISTER QUE sur `DesktopScreenLayout`. Protège avec `if (Platform.isLinux || Platform.isMacOS || Platform.isWindows)`. Sur Mobile, ce bouton est strictement absent, pas simplement grisé.
> - Implémente `ExportService.exportToPPT(List<EventModel> events)` :
>   - Sérialise les events en JSON : `jsonEncode(events.map((e) => e.toMap()).toList())`.
>   - Lance le processus : `await Process.run('python3', ['assets/calendar_export/generate_calendar_ppt.py'], stdinRaw: ...)`. Passe le JSON sur stdin.
>   - Récupère `result.stdout.trim()` pour obtenir le chemin du fichier généré.
>   - Si `result.exitCode != 0`, affiche `result.stderr` dans une `SnackBar` d'erreur.
>   - Si succès, appelle `OpenFilex.open(outputPath)` pour ouvrir le fichier directement.
> - Même logique pour l'export CSV : le script Python reçoit le même payload JSON et retourne le path d'un `.csv`.
> - Durant l'exécution du process (qui peut durer 2-5 secondes), affiche un `LinearProgressIndicator` dans l'AppBar Desktop pour signifier à l'user que la génération est en cours. Ne jamais bloquer le thread Flutter avec `await` dans un `build()`.
> - Vérifie que `python3` est disponible sur le PATH au premier lancement (`Process.run('which', ['python3'])`). Si absent, affiche un dialog explicatif "Python3 requis pour cette fonctionnalité. Installez-le via votre gestionnaire de paquets." au lieu du bouton.

---

## 11. HOME WIDGET ANDROID/iOS (CONSULTATION ÉCRAN D'ACCUEIL)

### 📝 Historique & Débat
Les `home_widget` figurent dans la matrice Mobile comme fonctionnalité d'interaction OS rapide. Le plugin `home_widget` est déjà présent dans le `pubspec.yaml` du projet. L'objectif est d'afficher les 3 prochains événements du jour directement sur l'écran d'accueil Android (AppWidget) ou iOS (WidgetKit), sans ouvrir l'application. L'enjeu architectural est la communication de données entre l'app Flutter et le processus natif du widget OS : ils ne partagent pas de mémoire. Le plugin `home_widget` résout ce problème via des `SharedPreferences` cross-process (Android) ou un `AppGroup` (iOS).

### 🏗️ Choix Architectural Argumenté
**Pipeline de mise à jour du widget : mutation SQLite locale -> `HomeWidgetUpdateService.push()` -> `HomeWidget.saveWidgetData()` -> `HomeWidget.updateWidget()`.**
*Argumentaire* : À chaque fois que le cache SQLite local est modifié (sync CalDAV terminée, création d'event par l'user), un `HomeWidgetUpdateService` est déclenché. Ce service lit les 3 prochains events depuis SQLite, les formate en JSON simplifié, les écrit dans les SharedPreferences cross-process via `HomeWidget.saveWidgetData<String>('next_events', jsonString)`, puis demande une mise à jour visuelle via `HomeWidget.updateWidget(name: 'MonAgendaWidget')`. Le widget natif Android (XML + RemoteViews) ou iOS (SwiftUI minimal) lit ces données et se re-render. Ce flux est 100% unilatéral (Flutter -> Widget OS), pas de callback retour.

### 💻 To-Do Prompt Technique pour Opus 4.6
> **[PROMPT OPUS]**
> **Objectif :** Implémenter le service de mise à jour du Home Widget et le layout natif Android.
> **Contraintes Strictes :**
> - **Côté Flutter (`HomeWidgetUpdateService`)** :
>   - Crée la méthode `static Future<void> push(List<EventModel> nextEvents)`.
>   - Prend les 3 premiers events dont `startTime.isAfter(DateTime.now())`, triés par date croissante.
>   - Formate en JSON léger : `[{"title": "...", "time": "14h30", "color": "#FF5733"}, ...]`.
>   - Appelle `HomeWidget.saveWidgetData<String>('next_events', jsonString)`.
>   - Appelle `HomeWidget.updateWidget(name: 'MonAgendaWidget', iOSName: 'MonAgendaWidget')`.
>   - Cette méthode doit être appelée systématiquement à la fin de `SyncEngine.applySync()` et après chaque `DatabaseHelper.insertOrUpdateEvent()`.
> - **Côté Android natif (`android/app/src/main/res/layout/`)** :
>   - Crée le layout XML `widget_agenda.xml` avec un `LinearLayout` vertical listant 3 `TextView` (titre + heure).
>   - Crée la classe Kotlin `MonAgendaWidget.kt` étendant `AppWidgetProvider`. Dans `onUpdate()`, lis les SharedPreferences cross-process via `HomeWidgetPlugin.getData(context, "next_events")`, parse le JSON, et injecte les textes dans les `RemoteViews`.
>   - Déclare le widget dans `AndroidManifest.xml` avec `<receiver android:name=".MonAgendaWidget">` et son `appwidget-provider` XML associé (taille 4x2 cellules minimum).
> - **NE PAS** tenter d'intégrer des images ou des RecyclerViews dans le widget : les RemoteViews Android sont strictement limités. Texte pur uniquement. Sur iOS, SwiftUI `VStack` minimal avec `Text` uniquement.
> - Ce composant est **Mobile uniquement**. Aucune référence à `home_widget` ne doit apparaître dans les layouts ou services Desktop.

---

## 12. NOTIFICATIONS LOCALES (RAPPELS D'ÉVÉNEMENTS)

### 📝 Historique & Débat
Les notifications de rappel sont listées dans la matrice Mobile comme feature de base. Le plugin `flutter_local_notifications` est présent dans le repo. La difficulté principale sur Android 13+ : la permission `POST_NOTIFICATIONS` est devenue une permission runtime (comme la caméra), non plus automatique. Sur Android 12+, les alarmes exactes (`setExactAndAllowWhileIdle`) requièrent une permission supplémentaire `SCHEDULE_EXACT_ALARM` ou `USE_EXACT_ALARM`. Il fallait donc implémenter un flow de demande de permission élégant (non bloquant) et gérer le cas où l'utilisateur refuse. Deuxième enjeu : éviter les doublons de notifications si la sync CalDAV ramène des events déjà planifiés.

### 🏗️ Choix Architectural Argumenté
**`NotificationService` singleton avec table de déduplication SQLite + demande de permission contextuelle (non-intrusive).**
*Argumentaire* : Une table SQLite `scheduled_notifications` (`event_uid TEXT PRIMARY KEY`, `notification_id INTEGER`, `scheduled_at INTEGER`) garantit qu'on n'enregistre jamais deux fois la même notification pour le même event. À chaque sync CalDAV, on compare les UIDs des events à venir contre cette table. Si l'UID est absent → on planifie et on insère dans la table. Si présent et que l'heure de l'event a changé → on annule l'ancienne notification (`cancel(id)`) et on replanifie. La permission `POST_NOTIFICATIONS` est demandée la première fois que l'user crée un event avec un rappel, avec un dialog explicatif contextuel ("Pour vous rappeler de votre rendez-vous, l'application a besoin...") — jamais au cold start de l'app.

### 💻 To-Do Prompt Technique pour Opus 4.6
> **[PROMPT OPUS]**
> **Objectif :** Implémenter `NotificationService` avec déduplication, gestion des permissions Android 13+ et iOS, et intégration avec `WorkManager`.
> **Contraintes Strictes :**
> - **Initialisation** : Dans `main.dart`, appelle `NotificationService.init()` qui configure `FlutterLocalNotificationsPlugin` avec les settings Android (`AndroidInitializationSettings('@mipmap/ic_launcher')`) et iOS (`DarwinInitializationSettings(requestAlertPermission: false)`). Ne jamais demander la permission iOS à l'init.
> - **Demande de permission Android 13+** : Avant de planifier une notification, vérifie `await flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.areNotificationsEnabled()`. Si `false`, affiche un `AlertDialog` contextuel explicatif puis appelle `.requestNotificationsPermission()`. Si l'user refuse, stocke le refus dans les prefs locales et ne redemande JAMAIS automatiquement.
> - **Permission alarms exactes Android 12+** : Vérifie et demande `SCHEDULE_EXACT_ALARM` via `permission_handler` (plugin déjà présent dans le repo). Fallback vers alarm inexacte si refusée.
> - **Planification** : Utilise `zonedSchedule()` avec `TZDateTime` (package `timezone`) pour garantir la correcte gestion des fuseaux horaires. Le délai du rappel doit être configurable par l'user (15min, 30min, 1h, 1j avant). Stocke le choix par défaut dans les prefs locales.
> - **Déduplication** : Avant tout `zonedSchedule()`, vérifie la table `scheduled_notifications`. Si l'`event_uid` existe et que `scheduled_at` est identique, ne rien faire. Si l'`event_uid` existe mais que l'heure a changé, annule l'ancienne via `cancel(notification_id)` puis replanifie.
> - **Tap sur notification** : Configure `onDidReceiveNotificationResponse` pour naviguer directement vers `EventDetailScreen` de l'event correspondant en passant l'`event_uid` dans le payload de la notification.

---

## 13. ÉTAT DU CODE RÉFÉRENCE (V3 — snapshot technique)

### 📊 Les 8 tables SQLite réelles (+ FTS5 virtuelle)

| Table | Colonnes |
|---|---|
| `events` | id, remote_id, source, type, title, start_date, end_date, is_all_day, location, description, participants, tag_ids, rrule, recurrence_id, calendar_id, notion_page_id, ics_subscription_id, status, reminder_minutes, is_deleted, created_at, updated_at, synced_at, etag, smart_attachments |
| `tags` | id, type, name, color_hex, infomaniak_mapping, notion_mapping, sort_order |
| `event_tags` | event_id, tag_id (PK composite) |
| `notion_databases` | id, notion_id, data_source_id, name, title_property, start_date_property, end_date_property, category_property, priority_property, description_property, participants_property, status_property, location_property, objective_property, material_property, is_enabled, last_synced_at |
| `ics_subscriptions` | id, name, url, color_hex, is_enabled, last_synced_at |
| `sync_state` | id, source, last_synced_at, sync_token, status, error_message |
| `sync_queue` | id, action, source, event_id, payload, created_at, retry_count, last_error, status |
| `system_logs` | id, level, source, message, details, created_at, is_read |
| `events_fts` (FTS5) | title, description, location (content=events, content_rowid=id) |

**Index** : `idx_events_start_date`, `idx_events_source`, `idx_events_deleted`, `idx_sync_queue_status`, `idx_system_logs_level`

### 🔐 Les 5 clés flutter_secure_storage

| Clé | Usage |
|---|---|
| `infomaniak_username` | CalDAV Basic Auth — username |
| `infomaniak_app_password` | CalDAV Basic Auth — app password |
| `infomaniak_calendar_url` | URL racine du calendrier CalDAV |
| `notion_api_key` | Notion API Bearer token |
| `db_encryption_key` | Clé AES-256 pour SQLCipher (auto-générée) |

### 🏗️ Hiérarchie Riverpod complète

**Providers de données :**
- `settingsProvider` — `AsyncNotifierProvider<SettingsNotifier, AppSettings>`
- `eventsInRangeProvider` — `FutureProvider<List<EventModel>>`
- `eventsForDayProvider` — `FutureProvider.family<List<EventModel>, DateTime>`
- `eventsNotifierProvider` — mutations CRUD events
- `tagsProvider` — `FutureProvider<List<TagModel>>`
- `categoryTagsProvider` / `priorityTagsProvider` — filtered tags
- `tagsNotifierProvider` — mutations tags
- `notionDatabasesProvider` / `notionDbNamesMapProvider` — Notion DB config

**Providers de sync :**
- `syncNotifierProvider` — `NotifierProvider<SyncNotifier, SyncState>` (sync orchestrator)
- `forceOfflineProvider` — `NotifierProvider<ForceOfflineNotifier, bool>` (manual offline toggle)
- `isOfflineProvider` — `Provider<bool>` (computed: forceOffline || !connectivity)
- `connectivityStreamProvider` — `StreamProvider<bool>` (réseau physique)
- `pendingSyncCountProvider` / `unreadErrorCountProvider` — `FutureProvider<int>`
- `serverSyncErrorProvider` — `StateProvider<String?>` (bannière erreur serveur)
- `etagConflictProvider` — `StateProvider<EventModel?>` (notification conflit ETag)

**Providers de services :**
- `infomaniakServiceProvider` — `Provider<InfomaniakService>`
- `notionServiceProvider` — `Provider<NotionService>`
- `syncEngineProvider` — `Provider<SyncEngine>`
- `syncQueueWorkerProvider` — `Provider<SyncQueueWorker>`

**Providers UI :**
- `displayedDateRangeProvider` — `StateProvider<DateRange>`
- `selectedDateProvider` — `StateProvider<DateTime>`
- `hiddenSourcesProvider` — `StateProvider<Set<String>>`
- `autoSyncOnConnectivityProvider` / `periodicSyncRetryProvider` — `Provider<void>` (side-effects)
