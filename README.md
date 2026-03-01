# monAgenda — Calendrier Unifié · Infomaniak · Notion · Flutter

> **Dépôt GitHub :** https://github.com/RGBesky/monAgenda

Application calendrier personnelle combinant Infomaniak Calendar, Notion et des abonnements .ics publics dans une interface unifiée.

## Plateformes
- **Android** (API 26+)
- **Linux Desktop** (Ubuntu 22+)

## Fonctionnalités

### Sources de données
| Source | Contenu | Sync |
|---|---|---|
| Infomaniak Calendar | Rendez-vous | CalDAV (source de vérité) |
| Notion | Tâches et projets | Bidirectionnel |
| .ics publics | Vacances, paroisses… | Lecture seule |

### Interface
- Vue Mois / Semaine / Jour / Agenda (Syncfusion)
- Blocs visuels : bordure gauche = priorité, fond = catégorie, logo = source
- Météo Open-Meteo (vue jour et semaine)

### Système de tags
- **Catégories** (multi-sélection) → CATEGORIES iCalendar + Multi-select Notion
- **Priorités** (sélection unique) → PRIORITY iCalendar + Select Notion
- L'appli est l'autorité sur les noms, couleurs et mappings

### Fonctionnalités avancées
- Mode hors ligne (lecture seule depuis SQLite)
- Notifications locales (rappels + résumé matinal)
- Widget Android 7 jours glissants
- Import/Export .ics, .csv
- Export PPT (Linux, script Python)
- Sauvegarde chiffrée AES-256 sur kDrive
- Recherche avancée avec filtres combinables

## Installation

### Cloner le projet
```bash
git clone https://github.com/RGBesky/monAgenda.git
cd monAgenda
```

> **VSCode :** `Fichier → Ouvrir le dossier` → sélectionner `monAgenda/`

### Prérequis
- Flutter 3.x
- Dart 3.x
- Pour Android : Android SDK API 26+
- Pour Linux : GTK3, CMake, **libsqlcipher1** (chiffrement DB)

#### Installer SQLCipher (Linux)
```bash
sudo apt install -y libsqlcipher1 libsqlcipher-dev
```

### Dépendances
```bash
flutter pub get
```

### Licence Syncfusion (OBLIGATOIRE)
Enregistrez votre clé Community License dans `lib/main.dart` :
```dart
SyncfusionLicense.registerLicense('VOTRE_CLE_ICI');
```
Clé gratuite disponible sur : https://www.syncfusion.com/products/communitylicense

### Lancer l'application
```bash
# Android
flutter run -d android

# Linux
flutter run -d linux
```

## Configuration

### Infomaniak
1. Aller sur manager.infomaniak.com → API Tokens
2. Créer un token avec les scopes : `workspace:calendar` + `user_info`
3. Entrer le token dans Paramètres → Connexions → Infomaniak

### Notion
1. Créer une intégration sur notion.so/my-integrations
2. Partager vos bases de données avec l'intégration
3. Entrer la clé API dans Paramètres → Connexions → Notion
4. Cliquer sur "Découvrir les bases de données"
5. Configurer le mapping des propriétés pour chaque BDD

### Abonnements .ics
Paramètres → Connexions → .ics → Ajouter un abonnement

## Architecture

```
lib/
├── main.dart                          # Entrée
├── app.dart                           # Shell + navigation
├── core/
│   ├── constants/                     # Constantes, couleurs
│   ├── database/database_helper.dart  # SQLite (sqflite)
│   ├── models/                        # EventModel, TagModel…
│   └── utils/                         # Date utils, platform utils
├── services/
│   ├── infomaniak_service.dart        # CalDAV Bearer Token
│   ├── notion_service.dart            # API Notion v1
│   ├── ics_service.dart               # Parse/export .ics
│   ├── sync_engine.dart               # Orchestrateur (last-write-wins)
│   ├── weather_service.dart           # Open-Meteo
│   ├── notification_service.dart      # flutter_local_notifications
│   ├── backup_service.dart            # AES-256 + kDrive
│   └── widget_service.dart            # Widget Android 7 jours
├── providers/                         # Riverpod providers
│   ├── settings_provider.dart
│   ├── events_provider.dart
│   ├── tags_provider.dart
│   └── sync_provider.dart
└── features/
    ├── calendar/                      # Vues calendrier (Syncfusion)
    ├── events/                        # Formulaire + détail
    ├── search/                        # Recherche avancée
    └── settings/                      # Tous les paramètres
```

## Roadmap

- **Phase 1** ✅ Fondations (Infomaniak, CalDAV, cache SQLite)
- **Phase 2** ✅ Notion multi-BDD + tags
- **Phase 3** ✅ Notifications, .ics, météo, widget
- **Phase 4** ✅ Import/Export, sauvegarde, recherche
- **V2** Hors ligne complet, CardDAV, multi-compte

## Notes importantes

### Syncfusion Community License
Ce projet utilise `syncfusion_flutter_calendar`. Pour un usage personnel gratuit, enregistrez une Community License. Vérifiez les CGU avant toute distribution.

### Logos Infomaniak / Notion
Les logos sources (Infomaniak "ik", Notion "N") sont utilisés à des fins personnelles uniquement. Vérifiez les CGU de chaque service avant distribution publique.

### Sécurité
- **Base de données chiffrée** : SQLCipher sur mobile (via `sqflite_sqlcipher`) et sur desktop (via `libsqlcipher1` système)
- Tokens stockés via `flutter_secure_storage` (Android Keystore / libsecret)
- Sauvegarde chiffrée AES-256 (mot de passe requis)
- Certificate pinning TOFU (Trust on First Use) pour Infomaniak et Notion
- Aucun serveur tiers — données entre l'appli et Infomaniak/Notion uniquement

### Packaging .deb
Pour distribuer en `.deb`, déclarer la dépendance dans le fichier `debian/control` :
```
Depends: libsqlcipher1 (>= 4.5)
```
Installer avec `apt install ./monagenda.deb` (résout les dépendances automatiquement).

## Licence
Usage personnel uniquement (V1).
