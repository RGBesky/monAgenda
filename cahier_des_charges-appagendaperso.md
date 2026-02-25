# CAHIER DES CHARGES
## Application Calendrier Unifiée
### Infomaniak · Notion · Flutter

| | |
|---|---|
| **Version** | 1.0 — V1 |
| **Plateformes** | Android · Linux Desktop |
| **Stack** | Flutter / Dart |
| **Statut** | Usage personnel |

---

## 1. Contexte et objectifs

> **Objectif principal** : remplacer totalement Outlook Calendar et Google Calendar au quotidien par une solution unifiée, souveraine et personnalisée.

### 1.1 Problématique

Aucune application existante ne répond simultanément aux besoins suivants :

- Intégration native avec Infomaniak Calendar (souveraineté des données, hébergement européen)
- Intégration native avec Notion (gestion des tâches et projets)
- Compatibilité Android et Linux dans une même application
- Système de tags unifiés avec autorité sur les couleurs et catégories
- Gestion distincte des rendez-vous (Infomaniak) et des tâches/projets (Notion)

### 1.2 Vision produit

L'application est la **source de vérité** pour les tags, les couleurs et les événements Infomaniak. Elle synchronise de manière bidirectionnelle avec Notion pour permettre des modifications depuis n'importe quel contexte.

---

## 2. Sources de données

| Source | Contenu | Mode de sync |
|---|---|---|
| Infomaniak Calendar | Rendez-vous, événements | Appli → Infomaniak (source de vérité) |
| Notion (BDD multiples) | Tâches et projets | Bidirectionnel |
| Calendriers .ics publics | Vacances, paroisses… | Lecture seule |

### 2.1 Infomaniak Calendar

- Authentification via Bearer Token (API REST Infomaniak)
- Scopes requis : `workspace:calendar` + `user_info`
- Un seul calendrier en V1, architecture préparée pour plusieurs
- L'appli est source de vérité : toute modification passe par l'appli

### 2.2 Notion

- Authentification via API Key Notion
- Plusieurs bases de données existantes à synchroniser
- Structure globalement identique entre les BDD, mapping unique avec exceptions par BDD
- Synchronisation bidirectionnelle : les modifications depuis Notion web remontent dans l'appli
- Notion gère les tâches et projets uniquement (pas les rendez-vous)

### 2.3 Calendriers .ics publics

- Abonnement par URL .ics publique (vacances scolaires, calendrier paroissial, etc.)
- Lecture seule, aucune authentification
- Couleur dédiée configurable par abonnement
- Gestion dans les paramètres de l'appli

---

## 3. Types d'événements

| Type | Description |
|---|---|
| Rendez-vous simple | Titre, date/heure début-fin, lieu, description, participants — stocké dans Infomaniak |
| Événement journée entière | Anniversaires, congés, jours fériés — format DATE sans heure |
| Événement récurrent | Réunion hebdo, rappel mensuel — règles RRULE standard iCalendar |
| Tâche | Todo avec date d'échéance, badge sur la date dans le calendrier — stocké dans Notion |
| Projet multi-jours | Durée sur plusieurs jours, barre visuelle dans la vue calendrier — stocké dans Notion |

> **Règle clé** : les rendez-vous sont gérés par Infomaniak, les tâches et projets par Notion. Cette séparation est au cœur de l'architecture.

---

## 4. Système de tags

L'appli est l'**autorité absolue** sur les tags : elle définit les noms, les couleurs et pousse ces valeurs vers Infomaniak et Notion dans leur format natif respectif.

### 4.1 Deux dimensions de tags

| Dimension | Définition | Exemples | Cardinalité |
|---|---|---|---|
| **Catégorie** | De quoi parle l'événement | Travail, Perso, Santé, Famille… | Multi-select : plusieurs possibles |
| **Priorité** | Niveau d'importance | Urgent, Haute, Normale, Basse | Select : une seule par événement |

### 4.2 Mapping vers les services

| Tag | Infomaniak | Notion |
|---|---|---|
| Catégorie | `CATEGORIES:Travail` (iCalendar) | Propriété Multi-select |
| Priorité | `PRIORITY:1-9` (standard iCalendar) | Propriété Select |
| Couleur | Définie par l'appli uniquement | Option couleur Notion (best effort) |

> La liste des tags (noms et couleurs) sera définie lors de la configuration initiale. Une liste prédéfinie sera fournie lors du développement.

---

## 5. Interface et vues calendrier

### 5.1 Vues disponibles

- **Vue Mois** — aperçu mensuel avec indicateurs d'événements
- **Vue Semaine** — créneaux horaires, style Outlook, avec événements multi-jours en barre
- **Vue Jour** — détail complet de la journée
- **Vue Agenda** — liste chronologique des prochains événements

### 5.2 Représentation visuelle des blocs événements

Chaque bloc événement combine **trois informations visuelles simultanées** :

| Élément visuel | Information encodée |
|---|---|
| Bordure gauche colorée | Priorité (ex: rouge = Urgent, orange = Haute) |
| Couleur de fond du bloc | Catégorie (ex: bleu = Travail, vert = Perso) |
| Logo en coin supérieur droit | Source : logo Infomaniak ou logo Notion |

> **Exemple** : bloc bleu (Travail) + bordure rouge (Urgent) + logo Infomaniak = réunion pro urgente. Trois informations d'un seul regard sans surcharge visuelle.

```
┌──────────────────────────────┐
🔴│ Réunion équipe    [ik logo]│  ← Infomaniak
  │ [Travail]                  │
└──────────────────────────────┘

🔴│ Projet site web    [N logo]│  ← Notion
  │ [Travail]                  │
└──────────────────────────────┘
```

- Projets multi-jours Notion : barre horizontale sur toute la durée, même logique couleur
- Tâches simples Notion : badge/point sur la date d'échéance avec couleur de catégorie
- Événements .ics publics : couleur dédiée configurable, sans logo source
- Météo : icône et température via Open-Meteo en haut de la vue jour/semaine

#### Logos sources

- Logo Infomaniak : coin supérieur droit du bloc, format 16×16px
- Logo Notion : coin supérieur droit du bloc, format 16×16px
- Usage strictement personnel non distribué — vérifier CGU si distribution future envisagée

### 5.3 Rendu visuel cible

> Cible : rendu proche de Microsoft Outlook Calendar. Package recommandé : `syncfusion_flutter_calendar` (vues natives, drag & drop, événements récurrents).

### 5.4 Thème

- Mode clair / Mode sombre selon le système (auto OS)
- Bascule manuelle disponible dans les paramètres

---

## 6. Gestion des événements

### 6.1 Création

- Destination par défaut : **Infomaniak**
- Possibilité de créer dans Notion (tâche/projet)
- Création par clic sur un créneau dans la vue semaine/jour
- Champs : titre, date/heure, lieu, description, participants, tags catégorie + priorité, rappel

### 6.2 Participants

- Sélection depuis les contacts Android (permission `READ_CONTACTS`) + saisie manuelle d'email
  - **Android** : accès contacts natifs du téléphone
  - **Linux** : saisie manuelle + autocomplétion sur emails déjà utilisés
- Envoi d'invitations géré par Infomaniak (protocole iTIP/iMIP)
- Affichage du statut de réponse : Accepté / Refusé / En attente

### 6.3 Événements récurrents

- Création de règles de récurrence (quotidien, hebdo, mensuel, annuel)
- Modification d'une occurrence ou de toute la série
- Suppression d'une occurrence ou de toute la série

---

## 7. Notifications locales

> **Approche** : notifications locales uniquement (`flutter_local_notifications`). Aucun backend requis. L'appli programme les alertes à la synchronisation.

- Rappel configurable par événement (X minutes avant, défini à la création)
- Résumé matinal quotidien avec les événements du jour
- L'appli se déclare gestionnaire de calendrier par défaut :
  - **Android** : enregistrement comme handler `.ics` et intent calendrier
  - **Linux** : fichier `.desktop` avec `MimeType` pour les fichiers `.ics`

Architecture préparée pour V2 (notifs temps réel) sans reconstruction.

---

## 8. Mode hors ligne (V1)

| Fonctionnalité | Comportement V1 |
|---|---|
| Lecture | ✅ Disponible depuis le cache local (SQLite) |
| Création / Modification | ❌ Bloquée avec message explicite |
| Indicateur | Bandeau visible indiquant le mode hors ligne |
| V2 future | Queue de modifications locales + sync au retour connexion |

---

## 9. Recherche et filtres

Recherche avancée avec **filtres combinables** :

- Par mot-clé (titre, description)
- Par tag catégorie
- Par tag priorité
- Par participant
- Par période de dates (début, fin ou range)
- Combinaison libre de tous les filtres simultanément

---

## 10. Import et Export

### 10.1 Import

- Fichier `.ics` reçu par mail (invitation, calendrier externe)
- Export Google Calendar `.ics` pour migration d'anciens événements
- Fichier `.ics` depuis l'explorateur de fichiers

### 10.2 Export

| Format | Usage |
|---|---|
| `.ics` par événement | Partage ponctuel d'un événement |
| `.ics` global | Sauvegarde complète compatible tous calendriers (migration Proton, etc.) |
| `.csv` global | Sauvegarde lisible, archivage, analyse Excel/Notion |
| `.pptx` planning de garde | Linux uniquement — appel script Python existant |

> **Export PPT** : disponible sur Linux uniquement. L'appli appelle le script Python existant de l'utilisateur en lui passant les données. Paramétrage du chemin du script dans les préférences Linux.

---

## 11. Widget Android

- Widget liste sur **7 jours glissants**
- Affiche les prochains événements du jour et des 6 jours suivants
- Titre de l'événement, heure, badge couleur de catégorie
- Tap sur un événement ouvre l'appli sur l'événement concerné

---

## 12. Météo

- Intégration **Open-Meteo** (open source, sans clé API, données officielles Météo France / ECMWF)
- Affichage dans la vue jour et vue semaine : icône météo + température
- Basé sur la géolocalisation de l'appareil
- Fonctionnalité non critique : si indisponible, l'appli fonctionne normalement

---

## 13. Sauvegarde et restauration

- Sauvegarde automatique de la configuration sur **kDrive** (Infomaniak)
- Contenu sauvegardé : tokens d'auth, tags et couleurs, préférences, abonnements .ics, mapping BDD Notion
- Fichier de config chiffré (AES-256)
- Restauration à la réinstallation : connexion kDrive → récupération automatique
- Sauvegarde manuelle déclenchable depuis les paramètres

---

## 14. Architecture technique

### 14.1 Stack

| Composant | Technologie |
|---|---|
| Langage | Dart |
| Framework UI | Flutter 3.x |
| Calendrier UI | `syncfusion_flutter_calendar` |
| Requêtes HTTP | `dio` |
| Cache local | `sqflite` |
| Tokens / secrets | `flutter_secure_storage` |
| Gestion d'état | `riverpod` |
| Notifications | `flutter_local_notifications` |
| Contacts | `flutter_contacts` (Android) |
| Météo | Open-Meteo (HTTP direct) |
| Widget Android | `home_widget` |
| Sauvegarde | API kDrive (Infomaniak) |

### 14.2 Stockage local (SQLite)

Tables principales :

- `events` — cache des événements toutes sources
- `tags` — tags unifiés (type, nom, couleur, mapping Infomaniak, mapping Notion)
- `event_tags` — liaison événements ↔ tags
- `notion_databases` — BDD Notion configurées avec leur mapping
- `ics_subscriptions` — abonnements .ics publics
- `sync_state` — état de synchronisation par source

### 14.3 Architecture des services

> **Principe** : chaque source de données est encapsulée dans un service isolé. Le `SyncEngine` orchestre la fusion et la gestion des conflits. L'UI ne parle qu'au `SyncEngine`.

```
Flutter App (Android + Linux)
│
├── InfamoniakService    → API REST Bearer Token, CRUD événements
├── NotionService        → API Notion, lecture/écriture multi-BDD
├── IcsService           → lecture flux .ics publics
├── SyncEngine           → fusion, détection conflits, résolution (last-write-wins V1)
├── WeatherService       → Open-Meteo
├── NotificationService  → programmation alertes locales
└── BackupService        → export/import configuration kDrive
```

---

## 15. Paramètres de l'application

### 15.1 Connexions
- Token API Infomaniak (avec validation de connexion)
- Token API Notion + sélection des BDD à synchroniser
- Abonnements .ics publics (ajout/suppression/couleur)

### 15.2 Tags
- Gestion des catégories (ajout, modification, suppression, couleur)
- Gestion des priorités (ajout, modification, couleur, niveau)
- Import de la liste prédéfinie

### 15.3 Notifications
- Délai de rappel par défaut (X minutes avant événement)
- Heure du résumé matinal
- Activation/désactivation par type de notification

### 15.4 Apparence
- Thème : auto / clair / sombre
- Vue par défaut au lancement
- Premier jour de la semaine (lundi / dimanche)

### 15.5 Linux uniquement
- Chemin vers le script Python de génération PPT
- Chemin vers le modèle PPT

### 15.6 Sauvegarde
- Connexion kDrive
- Déclenchement manuel de la sauvegarde
- Restauration depuis kDrive

---

## 16. Contraintes et exigences non fonctionnelles

| Contrainte | Spécification |
|---|---|
| Langue | Français uniquement |
| Plateformes | Android (API 26+) et Linux Desktop (Ubuntu 22+) |
| Hors ligne | Lecture seule depuis cache, indicateur visible |
| Sécurité | Tokens via `flutter_secure_storage`, config chiffrée AES-256 |
| Confidentialité | Aucun serveur tiers, données entre appli et Infomaniak/Notion uniquement |
| Appli par défaut | Enregistrement comme gestionnaire calendrier Android et Linux |
| Distribution | Usage personnel uniquement (V1), open source GitHub envisagé (V2) |

---

## 17. Roadmap

### Phase 1 — Fondations
- [ ] Initialisation projet Flutter
- [ ] Service Infomaniak (auth + CRUD événements)
- [ ] Vue calendrier de base (syncfusion)
- [ ] Cache SQLite + mode hors ligne lecture

### Phase 2 — Notion et tags
- [ ] Service Notion multi-BDD
- [ ] Système de tags catégories + priorités
- [ ] Synchronisation bidirectionnelle Notion
- [ ] Affichage tâches (badge) et projets (barre)

### Phase 3 — Fonctionnalités avancées
- [ ] Notifications locales (rappels + résumé matin)
- [ ] Abonnements .ics publics
- [ ] Météo Open-Meteo
- [ ] Widget Android 7 jours

### Phase 4 — Finitions
- [ ] Import/Export (.ics, .csv, .pptx Linux)
- [ ] Sauvegarde kDrive
- [ ] Recherche avancée avec filtres
- [ ] Paramètres complets
- [ ] Enregistrement appli par défaut Android + Linux

### V2 — Futures évolutions
- [ ] Création/modification hors ligne avec queue de sync
- [ ] Carnet d'adresses CardDAV Infomaniak
- [ ] Multi-compte Infomaniak
- [ ] Partage / collaboration

---

## 18. Points en suspens

- [ ] Liste définitive des tags catégories et priorités (à fournir)
- [ ] Nom de l'application (à définir)
- [ ] Résolution du 403 Forbidden sur l'API Infomaniak (scope `user_info` manquant probable)
- [ ] Open source GitHub : décision différée après V1 stable

> **Prochaine étape immédiate** : résoudre le 403 Infomaniak (vérifier les scopes `workspace:calendar` + `user_info` sur le token dans `manager.infomaniak.com`), puis initialiser le projet Flutter.
