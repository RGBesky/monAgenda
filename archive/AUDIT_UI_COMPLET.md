# AUDIT UI COMPLET — monAgenda

**Date :** Génération automatique  
**Périmètre :** 22 fichiers Dart UI (21 dans `lib/features/` + `lib/app.dart`)  
**Total lignes :** ~12 400 lignes

---

## Table des matières

1. [Inventaire des fichiers](#1-inventaire-des-fichiers)
2. [Bugs & erreurs de compilation](#2-bugs--erreurs-de-compilation)
3. [Audit par points de contrôle](#3-audit-par-points-de-contrôle)
4. [Audit détaillé par fichier](#4-audit-détaillé-par-fichier)
5. [Résumé des actions prioritaires](#5-résumé-des-actions-prioritaires)
6. [Matrice de conformité Design System](#6-matrice-de-conformité-design-system)

---

## 1. Inventaire des fichiers

| # | Chemin | Lignes | Rôle |
|---|--------|--------|------|
| 1 | `lib/app.dart` | 1 063 | Shell principal, thèmes light/dark, NavigationRail/BottomNav, raccourcis clavier, Quick Add sheet, bannières offline/erreur |
| 2 | `lib/features/calendar/screens/agenda_screen.dart` | 1 070 | Vue To Do / Agenda avec sections « Aujourd'hui / Demain / Cette semaine / … », filtre sources, tri, empty state |
| 3 | `lib/features/calendar/screens/calendar_screen.dart` | 1 859 | Calendrier Syncfusion multi-vues (semaine/mois/jour/schedule), drag-and-drop, resize, appointmentBuilder adaptatif, météo |
| 4 | `lib/features/calendar/widgets/event_block.dart` | 320 | Bloc visuel d'un événement dans SfCalendar + MultiDayEventBar |
| 5 | `lib/features/calendar/widgets/unified_event_card.dart` | 433 | Carte d'événement « atome » pour la vue agenda – design Notion-like, FadeTransition |
| 6 | `lib/features/calendar/widgets/weather_header.dart` | 164 | En-tête météo (Open-Meteo) |
| 7 | `lib/features/events/screens/event_detail_screen.dart` | 766 | Détail d'un événement : pastel bg, source badge, tags, attachements, notes meeting Notion |
| 8 | `lib/features/events/screens/event_form_screen.dart` | 927 | Formulaire création/édition événement, mode dialog, tags, récurrence, rappel |
| 9 | `lib/features/events/widgets/event_detail_popup.dart` | 153 | Dialog desktop pour détail inline avec edit-in-place |
| 10 | `lib/features/import/import_qr_screen.dart` | 315 | Import config via QR (mobile) ou fichier (desktop), déchiffrement AES-256 |
| 11 | `lib/features/magic/magic_entry_screen.dart` | 449 | Saisie Magique NLP (Spotlight desktop / fullscreen mobile), modèle H2O Danube 3 |
| 12 | `lib/features/project/project_view_screen.dart` | 376 | Vue Project (desktop only) : split panel SfCalendar + tâches Notion drag-and-drop |
| 13 | `lib/features/search/screens/search_screen.dart` | 540 | Recherche avancée : mot-clé, tags, date range, participant, résultats filtrés |
| 14 | `lib/features/settings/screens/appearance_settings_screen.dart` | 418 | Thème (auto/light/dark), vue par défaut, 1er jour semaine, tri, réordonnement calendriers |
| 15 | `lib/features/settings/screens/backup_settings_screen.dart` | 491 | Backup kDrive (dépôt link), backup local chiffré AES-256, restoration |
| 16 | `lib/features/settings/screens/connections_settings_screen.dart` | 1 091 | 3 onglets (Infomaniak / Notion / ICS), mapping Notion, abonnements ICS |
| 17 | `lib/features/settings/screens/import_config_screen.dart` | 453 | Import config QR + paste manuelle |
| 18 | `lib/features/settings/screens/notifications_settings_screen.dart` | 171 | Toggle rappel, résumé matinal, test notification |
| 19 | `lib/features/settings/screens/settings_screen.dart` | 2 545 | Hub paramètres (desktop NavigationRail + mobile ExpansionTile), export ICS/CSV/PPT, QR export, config import/export, IA feedback, raccourcis dialog |
| 20 | `lib/features/settings/screens/system_logs_screen.dart` | 193 | Viewer de logs erreur/warning/info, nettoyage |
| 21 | `lib/features/settings/screens/tags_settings_screen.dart` | 413 | Gestion tags : catégories + priorités, palette 30 couleurs, reset |
| 22 | `lib/features/setup/setup_screen.dart` | 483 | Onboarding 3 étapes : Infomaniak → Notion → Test connexion |

---

## 2. Bugs & erreurs de compilation

### `flutter analyze` — 0 erreurs, 0 warnings, 8 infos

```
info • curly_braces_in_flow_control_structures   → app_colors.dart:122,124
info • dangling_library_doc_comments              → cert_pins.dart:12
info • use_build_context_synchronously (×2)       → calendar_screen.dart:252,262
info • deprecated_member_use (×2)                 → event_form_screen.dart:405,406 (Radio.groupValue/onChanged)
info • prefer_conditional_assignment              → magic_entry_service.dart:377
```

**Aucune erreur de compilation.** Les 8 infos sont des style hints et 2 deprecations Radio (Flutter 3.32+).

### BUG-1 · `NotionTaskModel.copyWith` retourne `this` ⚠️ LOGIC ERROR

**Fichier :** `project_view_screen.dart`  
**Problème :** Le `copyWith` dans la logique drag-and-drop de tâches Notion appelle `copyWith(assignedDate: date)` mais la méthode `copyWith` de `NotionTaskModel` retourne `this` au lieu de créer une copie modifiée. Le drag-and-drop de tâches dans la vue Project ne modifie donc **jamais** la date.  
**Impact :** Le time-blocking est cassé — les tâches ne se déplacent pas.

---

## 3. Audit par points de contrôle

### 3.1 · IntrinsicHeight overflow (Priorité 0.1) ✅ RÉSOLU + ⚠️ RÉSIDU

**Statut agenda_screen.dart :** ✅ Aucun `IntrinsicHeight` — le fix historique (commit `7246224`) a été appliqué.

**Résidu dans search_screen.dart ligne 338 :** `IntrinsicHeight` enveloppe un `Row` avec une barre d'accent et du contenu dans `_buildEventTile`. Cet usage est **correct et nécessaire** car la barre d'accent (`Container(width: 4)`) a besoin de `CrossAxisAlignment.stretch` qui requiert `IntrinsicHeight` dans un `ListView`. Pas de débordement car le contenu est borné (titre + date + chips).

**Verdict :** Pas de problème d'overflow actif. Le `IntrinsicHeight` de search_screen est légitime.

---

### 3.2 · Bouton recherche ne navigue pas 🔴 BUG CONFIRMÉ

**Fichier :** `agenda_screen.dart` ligne 225

```dart
onPressed: () {},  // ← VIDE — ne fait rien
```

Le `SearchScreen` existe et est fonctionnel, mais le bouton de l'AppBar ne redirige pas.

**Correctif :**
```dart
onPressed: () => Navigator.push(
  context,
  MaterialPageRoute(builder: (_) => const SearchScreen()),
),
```

---

### 3.3 · QR Code payload size ✅ GÉRÉ

**Fichier :** `settings_screen.dart` lignes ~2108-2130

Le code vérifie explicitement la taille avant génération :
```dart
const maxQrDataLength = 2900;
if (encryptedStr.length > maxQrDataLength) {
  // Affiche un dialog d'erreur avec suggestion d'utiliser l'export JSON
}
```

**Verdict :** Protection présente et correcte. Suggestion : ajouter un compteur dans le dialog pour informer l'utilisateur.

---

### 3.4 · Double confirmation reset settings 🟡 NON IMPLÉMENTÉ

**Tags reset** (`tags_settings_screen.dart`) : confirmation simple (1 dialog).  
**Feedback IA clear** (`settings_screen.dart` `_clearMagicFeedback`) : confirmation simple.  
**Backup restore** (`backup_settings_screen.dart`) : confirmation simple.

Aucun « double-confirm » (2 étapes ou saisie textuelle) n'est implémenté nulle part. Si c'est requis, il faut l'ajouter.

---

### 3.5 · Filtrage tags dans la vue To Do ✅ IMPLÉMENTÉ

**Fichier :** `agenda_screen.dart` — Le filtre panel (`_buildFilterPanel`) permet de masquer/afficher les sources (Infomaniak, Notion, ICS). Le filtrage se fait via `_visibleSources` qui est appliqué au `filteredEvents`.

**Incohérence filtre sources :** Dans `agenda_screen.dart`, Infomaniak est toggleable. Dans `calendar_screen.dart`, Infomaniak a `enabled: false` (toujours visible, non désactivable). → ***Incohérence design***.

Le filtrage par tag (catégorie/priorité/statut) n'est **PAS** disponible dans le filtre panel de la vue To Do — seul le filtre par source est proposé. Si un filtrage par tag est requis, c'est manquant.

---

### 3.6 · Design Notion-like des event cards ✅ CONFORME

**Fichier :** `unified_event_card.dart`

- ✅ Barre de priorité latérale gauche (4px, couleur selon priorité)
- ✅ Fond pastel Stabilo (via `AppColors.pastelBg`)
- ✅ Chips catégorie/statut
- ✅ Badge source (Infomaniak/Notion/ICS) avec icône
- ✅ Animation FadeTransition à l'apparition
- ✅ dispose() propre de `AnimationController`

---

### 3.7 · Empty states ✅ IMPLÉMENTÉS

| Écran | Empty state |
|-------|-------------|
| Agenda (agenda_screen) | ✅ Illustration + texte + bouton sync |
| Search (search_screen) | ✅ État « pas encore cherché » + « aucun résultat » |
| System logs | ✅ Icône + « Aucun log » |
| Project view | ✅ Texte « Aucune tâche » pour la liste vide |
| Calendar | ❌ Pas d'empty state visible — le calendrier affiche toujours la grille |

---

### 3.8 · Raccourcis clavier ✅ IMPLÉMENTÉS

**Fichier :** `app.dart` lignes 792-815

| Raccourci | Action | Statut |
|-----------|--------|--------|
| `Ctrl+N` | Nouvel événement (EventFormScreen) | ✅ |
| `Ctrl+K` | Saisie Magique (MagicEntryScreen) | ✅ |
| `Ctrl+F` | Switch vers To Do (index 0) | ⚠️ Ne focus pas la barre de recherche — switch seulement l'onglet |
| `Échap` | `Navigator.maybePop` | ✅ |

**Manquant :**
- Pas de raccourci pour naviguer entre onglets (ex: `Ctrl+1/2/3`)
- `Ctrl+F` ne redirige pas vers SearchScreen, change juste l'onglet

**Dialog raccourcis :** `_showKeyboardShortcutsDialog` dans settings_screen.dart affiche les 4 raccourcis dans un `SimpleDialog`. ✅ Fonctionnel.

---

### 3.9 · Mode dark / AMOLED 🟡 PARTIEL

**Fichier :** `app.dart` — deux thèmes complets : `_buildLightTheme()` et `_buildDarkTheme()`.  
**Fichier :** `appearance_settings_screen.dart` — choix entre `auto / light / dark`.

**AMOLED (true black `#000000`) :** ❌ **Non implémenté.** Le dark theme utilise `#191919` (scaffold) / `#202020` (surface) — ce n'est PAS de l'AMOLED true black. Aucune option AMOLED n'existe.

---

### 3.10 · Boutons sidebar (NavigationRail) ✅ CONFORME

**Fichier :** `app.dart` lignes 540-600

Le `NavigationRail` contient :
- **Leading :** Mini FAB offline + FAB `+` (nouvel événement)
- **3 destinations :** To Do, Calendrier, Paramètres
- **Trailing :** Logo monAgenda en bas

**Pas de boutons Infomaniak/Notion directs** dans la sidebar. Les connexions sont dans Paramètres → Connexions. C'est un choix de design cohérent.

---

### 3.11 · Widget Android ✅ SERVICE PRÉSENT

**Fichier :** `lib/services/widget_service.dart`

- Utilise `home_widget` package
- `CalendarWidgetProvider` comme provider Android
- Affiche les 7 prochains événements
- Se met à jour via `WidgetService.updateWidget()`

**Limitation :** Le service est appelé uniquement côté Dart — il faut vérifier que le `CalendarWidgetProvider` existe côté Android natif (`android/app/src/main/java/...`).

---

### 3.12 · Import ICS par clic ✅ IMPLÉMENTÉ

**Fichier :** `settings_screen.dart` ligne 1178 (`_importIcs`)

- Ouvre `FilePicker` avec filtre `.ics`
- Parse via `IcsService.parseIcsFile`
- Insert chaque événement dans la DB locale
- SnackBar avec compteur

**Pas de déduplication** — si un fichier .ics est importé deux fois, les événements seront dupliqués.

---

### 3.13 · dispose() — Gestion des resources ✅ GLOBALEMENT BON

| Fichier | Resources | dispose() |
|---------|-----------|-----------|
| `agenda_screen.dart` | `ScrollController` | ✅ |
| `calendar_screen.dart` | `CalendarController` | ✅ |
| `event_form_screen.dart` | 3× `TextEditingController` | ✅ |
| `unified_event_card.dart` | `AnimationController` | ✅ |
| `import_qr_screen.dart` | `MobileScannerController` | ✅ |
| `magic_entry_screen.dart` | `TextEditingController` + `FocusNode` | ✅ |
| `project_view_screen.dart` | `CalendarController` | ✅ |
| `search_screen.dart` | `SearchController` | ✅ |
| `connections_settings_screen.dart` | `TabController` + 4× `TextEditingController` | ✅ |
| `import_config_screen.dart` | `TextEditingController` + inner `MobileScannerController` | ✅ |
| `setup_screen.dart` | `PageController` + 4× `TextEditingController` | ✅ |
| `backup_settings_screen.dart` | 2× `TextEditingController` | ✅ |

**Problème :** `agenda_screen.dart` utilise `Future.delayed` récursif pour `_scheduleNowUpdate()` au lieu d'un `Timer` annulable. Si le widget est disposé pendant le delay, le callback s'exécute sur un widget mort.

**Correctif :** Utiliser `Timer` et l'annuler dans `dispose()`.

---

### 3.14 · Optimisation `const` 🟡 OPPORTUNITÉS

Les fichiers n'utilisent pas systématiquement `const` pour les widgets statiques. Exemples fréquents :
- `SizedBox(height: 12)` sans `const` dans de nombreux endroits
- `EdgeInsets.symmetric(...)` non-const quand ils pourraient l'être
- `TextStyle(...)` literals sans `const`

Le linter `prefer_const_constructors` semble actif (les `const` sont présents à ~80% des endroits appropriés). Pas de problème critique, mais un passage systématique améliorerait les performances.

---

## 4. Audit détaillé par fichier

### 4.1 · `app.dart` (1 063 lignes)

**Rôle :** Point d'entrée UI — `MaterialApp`, thèmes, `AppShell` avec navigation.

| Point | Détail |
|-------|--------|
| ✅ Thèmes | Light (#F7F6F3 Notion) et Dark (#191919) complets avec M3 ColorScheme |
| ✅ Navigation | Desktop: NavigationRail 3 dest + FABs. Mobile: BottomNavigationBar + FABs |
| ✅ Raccourcis | Ctrl+N/K/F/Esc via `CallbackShortcuts` (desktop only) |
| ✅ Offline | MiniFAB tricolore (vert/orange/rouge) + bannière + toggle switch |
| ✅ Server error | Bannière orange avec retry + dismiss |
| ✅ Quick Add | BottomSheet « Rendez-vous Infomaniak / Tâche Notion » |
| ⚠️ Auto-sync | `initState()` vide — le commentaire dit « syncAll déclenché par autoSyncOnConnectivityProvider ». Correct mais implicite. |
| ❌ AMOLED | Absent — dark scaffold = #191919, pas #000000 |

---

### 4.2 · `agenda_screen.dart` (1 070 lignes)

**Rôle :** Vue To Do avec sections temporelles.

| Point | Détail |
|-------|--------|
| 🔴 Recherche | `onPressed: () {}` — **bouton mort** (ligne 225) |
| ⚠️ Timer | `_scheduleNowUpdate()` avec `Future.delayed` récursif — risque de callback sur widget disposé |
| ⚠️ Filtre | Infomaniak toggleable ici mais pas dans CalendarScreen — **incohérence** |
| ✅ Empty state | Illustration + texte + bouton sync |
| ✅ Sections | Aujourd'hui → Demain → Cette semaine → Prochain → Plus tard → Terminé |
| ✅ Tri | Par heure, status (pas fait → en cours → terminé → annulé) |
| ✅ Swipe actions | Swipe gauche = terminé, swipe droit = reporter |

---

### 4.3 · `calendar_screen.dart` (1 859 lignes)

**Rôle :** Calendrier SfCalendar multi-vues.

| Point | Détail |
|-------|--------|
| ✅ Vues | Semaine, Mois, Jour, Schedule |
| ✅ Drag & drop | `onDragEnd` avec snap 15min, confirmation si changement de jour, undo SnackBar |
| ✅ Resize | `onAppointmentResizeEnd` avec snap 15min, durée min 15min |
| ✅ Sizing adaptatif | 5 tiers : tiny (<18px), compact (<28px), medium (<44px), normal (<66px), grand (≥66px) |
| ✅ Weather | Header intégré pour la vue schedule |
| ✅ ICS read-only | Protection drag/resize avec SnackBar orange |
| ⚠️ Filtre | Infomaniak non-toggleable (`enabled: false`) — **incohérence** avec agenda |
| ✅ DataSource | `_CalendarDataSource` avec micro-offset pour préserver l'ordre de tri secondaire |

---

### 4.4 · `event_block.dart` (320 lignes)

**Rôle :** Widget de rendu d'événement dans SfCalendar.

| Point | Détail |
|-------|--------|
| ✅ Design | Pastel bg, barre gauche, icône source, catégorie dot |
| ✅ ICS lock | Badge 🔒 pour les événements ICS |
| ✅ Multi-day | `MultiDayEventBar` dédié avec styling adapté |
| ✅ StatelessWidget | Pas de dispose() nécessaire |

---

### 4.5 · `unified_event_card.dart` (433 lignes)

**Rôle :** Carte d'événement pour la vue agenda.

| Point | Détail |
|-------|--------|
| ✅ Notion-like | Barre priorité, pastel bg, chips source/catégorie/statut |
| ✅ Animation | FadeTransition + léger slide vertical |
| ✅ dispose() | AnimationController correctement disposé |
| ✅ `withValues(alpha:)` | Utilisation moderne (pas de `withOpacity`) |

---

### 4.6 · `weather_header.dart` (164 lignes)

✅ Aucun problème. StatelessWidget propre. Affiche un résumé météo + icône + températures.

---

### 4.7 · `event_detail_screen.dart` (766 lignes)

| Point | Détail |
|-------|--------|
| ✅ ConsumerWidget | Stateless — pas de dispose() nécessaire |
| ✅ Delete confirm | Dialog simple (pas double — voir §3.4) |
| ✅ Attachements | File picker (desktop), rendu avec HugeIcons |
| ✅ Notion meeting | Bouton ouvrir/créer page Notion |
| ✅ Pastel bg | Fond coloré selon priorité/catégorie |

---

### 4.8 · `event_form_screen.dart` (927 lignes)

| Point | Détail |
|-------|--------|
| ✅ `initialValue` | Vérifié — hérité de `FormField`, paramètre valide |
| ⚠️ Radio deprecated | `groupValue` et `onChanged` de `Radio` sont dépréciés (Flutter 3.32+, utiliser `RadioGroup`) |
| ✅ dispose() | 3 TextEditingControllers correctement disposés |
| ✅ Dialog mode | `asDialogBody` pour popup desktop |
| ✅ Tags | Sections catégories / priorités / statuts avec chips |
| ⚠️ Validation | Seul le titre est validé comme non-vide. Pas de validation de dates (début < fin). |

---

### 4.9 · `event_detail_popup.dart` (153 lignes)

✅ Propre. Dialog desktop avec toggle edit-in-place. Gestion d'état simple avec `StatefulWidget`.

---

### 4.10 · `import_qr_screen.dart` (315 lignes)

| Point | Détail |
|-------|--------|
| ✅ Scanner | Mobile via `MobileScannerController` (dispose OK) |
| ✅ Desktop | File picker pour fichier texte contenant la payload |
| ✅ Chiffrement | AES-256 déchiffrement via `CryptoUtils` |
| ✅ Erreurs | Try-catch avec SnackBar d'erreur |

---

### 4.11 · `magic_entry_screen.dart` (449 lignes)

| Point | Détail |
|-------|--------|
| ✅ Spotlight | Desktop = dialog Spotlight, Mobile = fullscreen |
| ✅ dispose() | TextEditingController + FocusNode disposés |
| ✅ Download | Dialog progrès pour téléchargement modèle H2O Danube 3 |
| ✅ Feedback | Enregistrement corrections utilisateur pour fine-tuning |
| ⚠️ UX | Pas de loader pendant l'inférence — l'utilisateur ne sait pas que le modèle travaille |

---

### 4.12 · `project_view_screen.dart` (376 lignes)

| Point | Détail |
|-------|--------|
| 🔴 copyWith | `NotionTaskModel.copyWith` retourne `this` → time-blocking cassé |
| ✅ dispose() | CalendarController disposé |
| ⚠️ Desktop only | `if (!isDesktop)` → retourne juste un Scaffold vide. Pas d'indication mobile. |
| ⚠️ DataSource | Utilise `Appointment` au lieu de `EventModel` → perd le styling custom |

---

### 4.13 · `search_screen.dart` (540 lignes)

| Point | Détail |
|-------|--------|
| ✅ Recherche | Keyword, date range, tags, participant email |
| ✅ IntrinsicHeight | Usage **correct** pour la barre d'accent dans les résultats |
| ✅ Empty states | « Tapez pour chercher » + « Aucun résultat » |
| ✅ dispose() | SearchController disposé |
| ⚠️ Performance | Recherche lancée à chaque frappe (`onChanged`) sans debounce |

---

### 4.14 · `appearance_settings_screen.dart` (418 lignes)

| Point | Détail |
|-------|--------|
| ❌ AMOLED | Seuls auto/light/dark — pas d'option AMOLED true black |
| ✅ Reorder | `ReorderableListView` pour réordonner les calendriers |
| ✅ Thème | SegmentedButton auto/light/dark |
| ✅ AnimatedBuilder | Vérifié — le widget existe bien en Flutter 3.x |

---

### 4.15 · `backup_settings_screen.dart` (491 lignes)

| Point | Détail |
|-------|--------|
| ✅ kDrive | Backup via deposit link |
| ✅ Local | Backup/restore chiffré AES-256 |
| ✅ dispose() | 2 TextEditingControllers disposés |
| ⚠️ Restore | Confirmation simple (pas double) |

---

### 4.16 · `connections_settings_screen.dart` (1 091 lignes)

| Point | Détail |
|-------|--------|
| ✅ 3 onglets | Infomaniak, Notion, ICS — TabBar |
| ✅ Notion discovery | Auto-découverte des bases + mapping propriétés |
| ✅ ICS | Ajout d'abonnements + collecte initiale |
| ✅ dispose() | TabController + 4 TextEditingControllers |
| ⚠️ UX Notion | Le mapping est complexe — pas de validation des mappings avant sauvegarde |

---

### 4.17 · `import_config_screen.dart` (453 lignes)

✅ Propre. QR scan + paste manuelle. Inner `_QrScannerView` dispose son `MobileScannerController`.

---

### 4.18 · `notifications_settings_screen.dart` (171 lignes)

✅ Propre. ConsumerWidget (stateless). Toggle rappel + résumé matinal + heure + test notification.

---

### 4.19 · `settings_screen.dart` (2 545 lignes)

| Point | Détail |
|-------|--------|
| ✅ Desktop layout | NavigationRail avec sections |
| ✅ Mobile layout | ExpansionTile accordéon |
| ✅ ICS import | Via `FilePicker` → `IcsService.parseIcsFile` |
| ✅ CSV export | Manuel avec headers |
| ✅ PPT export | Via script Python avec detection auto + install dépendances |
| ✅ QR export | AES-256 avec vérification taille payload |
| ✅ Config export/import | JSON (export sans credentials) |
| ✅ Feedback IA | Export CSV + clear avec confirmation |
| ✅ Météo | Géolocalisation IP + choix villes suisses + saisie custom |
| ✅ Raccourcis dialog | SimpleDialog avec 4 raccourcis en style clavier |
| ⚠️ ICS import sans dédup | Double import = doublons |
| ⚠️ Fichier trop long | 2545 lignes — devrait être découpé en sous-widgets |

---

### 4.20 · `system_logs_screen.dart` (193 lignes)

✅ Propre. Viewer avec couleurs par niveau. Nettoyage, marquage lu, empty state.

---

### 4.21 · `tags_settings_screen.dart` (413 lignes)

| Point | Détail |
|-------|--------|
| ✅ CRUD | Ajout/édition/suppression de tags |
| ✅ Palette | 30 couleurs Stabilo prédéfinies |
| ⚠️ Reset | Confirmation simple — pas de double-confirm |

---

### 4.22 · `setup_screen.dart` (483 lignes)

| Point | Détail |
|-------|--------|
| ✅ Onboarding | 3 étapes : Infomaniak → Notion (optionnel) → Test |
| ✅ dispose() | PageController + 4 TextEditingControllers |
| ✅ Validation | Regex CalDAV URL + champs requis |
| ✅ Test connexion | Infomaniak + Notion avec indicateurs visuels |
| ⚠️ Notion button | Le bouton « Connecter » n'est activé que si le texte n'est pas vide, mais il utilise l'état initial — pas de `addListener` pour rebuild sur saisie |

---

## 5. Résumé des actions prioritaires

### 🔴 Critiques (fonctionnalité cassée)

| # | Fichier | Problème | Effort |
|---|---------|----------|--------|
| 1 | `agenda_screen.dart:225` | Bouton recherche `onPressed: () {}` → naviguer vers `SearchScreen` | 5 min |
| 2 | `project_view_screen.dart` | `NotionTaskModel.copyWith` retourne `this` — time-blocking cassé | 15 min (dans le modèle) |

### 🟠 Importants (UX / cohérence)

| # | Fichier | Problème | Effort |
|---|---------|----------|--------|
| 4 | `agenda_screen.dart` | `Future.delayed` récursif → `Timer` annulable dans dispose() | 10 min |
| 5 | `agenda_screen.dart` vs `calendar_screen.dart` | Incohérence filtre Infomaniak (toggleable vs fixe) | 10 min |
| 6 | `appearance_settings_screen.dart` | Ajouter mode AMOLED (scaffold #000000) | 30 min |
| 7 | `search_screen.dart` | Ajouter debounce (300ms) sur la recherche | 10 min |
| 8 | `app.dart` | `Ctrl+F` ne redirige pas vers SearchScreen | 10 min |
| 9 | `settings_screen.dart` | ICS import sans déduplication (UID) | 20 min |

### 🟡 Améliorations (polish)

| # | Fichier | Problème | Effort |
|---|---------|----------|--------|
| 10 | `tags_settings_screen.dart` | Ajouter double-confirm pour reset (si requis) | 15 min |
| 11 | `event_form_screen.dart` | Validation dates début < fin | 10 min |
| 12 | `settings_screen.dart` | Découper le fichier (2545 lignes) en sous-widgets | 1-2h |
| 13 | `project_view_screen.dart` | Message explicite pour mobile (« Vue desktop uniquement ») | 5 min |
| 14 | `magic_entry_screen.dart` | Ajouter indicateur de chargement pendant l'inférence | 10 min |
| 15 | Tous fichiers | Passe `const` systématique | 30 min |

---

## 6. Matrice de conformité Design System

| Fonctionnalité | Desktop | Mobile | Notes |
|---------------|---------|--------|-------|
| NavigationRail | ✅ | N/A | 3 destinations + FABs leading |
| BottomNavigationBar | N/A | ✅ | 3 destinations |
| Thème Light | ✅ | ✅ | Notion-inspired #F7F6F3 |
| Thème Dark | ✅ | ✅ | #191919 scaffold |
| AMOLED | ❌ | ❌ | Non implémenté |
| Raccourcis clavier | ✅ | N/A | Ctrl+N/K/F + Échap |
| Drag & drop calendrier | ✅ | ✅ | Snap 15min, confirm jour |
| Resize événement | ✅ | ✅ | Snap 15min, min 15min |
| Weather header | ✅ | ✅ | Scheduled uniquement |
| Quick Add sheet | ✅ | ✅ | Infomaniak + Notion |
| Offline mode | ✅ | ✅ | Mini FAB tricolore + bannière |
| QR config transfer | ✅ | ✅ | AES-256, taille vérifiée |
| Magic Entry NLP | ✅ Spotlight | ✅ Fullscreen | H2O Danube 3 |
| Project view | ✅ | ❌ Desktop only | Time-blocking cassé (copyWith) |
| Android widget | N/A | ✅ Service | Via home_widget, 7 next events |

---

*Fin de l'audit. `flutter analyze` = 0 erreurs, 8 infos. 2 bugs critiques, 6 améliorations importantes, 6 items de polish identifiés.*
