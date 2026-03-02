# Manifest Final — monAgenda

> **Ce document est immuable.** Il capture l'esprit, la philosophie et les principes fondateurs du projet. Il ne change pas au fil des versions — seuls le cadrage_projet.md et la feuille_de_route.md évoluent.

> **Date de cristallisation** : 2 mars 2026

---

## L'Esprit

monAgenda est né d'une frustration simple : aucune app calendrier ne respecte à la fois ta vie privée, tes outils de travail, et ta façon de penser.

Google Calendar vend tes données. Outlook t'enferme dans Microsoft 365. Notion Calendar est mort-né. Les apps "souveraines" sont moches et fonctionnent mal.

monAgenda fait un pari : **une seule app, ta vie entière dedans, zéro compromis sur la vie privée.**

---

## Les 7 Principes Inviolables

### 1. Souveraineté absolue des données

Tes données transitent entre ton téléphone, ton PC, Infomaniak (Suisse) et Notion. **Jamais ailleurs.** Pas de Google Analytics, pas de Firebase, pas de Sentry, pas de telemetry. L'app ne parle à aucun serveur que tu n'as pas choisi toi-même.

Le modèle IA tourne **sur ton appareil**. Tes mots ne quittent jamais ton téléphone.

### 2. Tu es la source de vérité

L'app decide des couleurs, des catégories, des priorités. Infomaniak et Notion s'adaptent à **tes** choix, pas l'inverse. Si tu dis qu'un tag est vert, il sera vert partout — dans l'app, dans CalDAV (`CATEGORIES:`), dans Notion (propriété Select).

Tu n'es pas l'utilisateur d'un service. Tu es le propriétaire de ton système.

### 3. Offline-first, pas offline-maybe

L'interface ne lit **jamais** que la base locale. Zéro spinner d'attente HTTP. Zéro "Chargement en cours...". Tu ouvres l'app, tout est là, immédiatement. Les syncs se font en arrière-plan, silencieusement. Si ça échoue, tu as un badge discret, pas un écran d'erreur.

Le réseau est un luxe, pas une dépendance.

### 4. Desktop ≠ Mobile — et c'est voulu

Le Desktop (Linux) est l'usine à gaz : Time Blocking, Drag & Drop, Meeting Notes, export PPT, raccourcis clavier, split-panel. C'est là que tu planifies, que tu réorganises, que tu fais le travail de fond.

Le Mobile (Android) est l'immédiateté : consulter en 2 secondes, créer un event en 5 mots via la Saisie Magique, voir son widget sur l'écran d'accueil. C'est là que tu vis.

Les deux sont la même app, pas la même expérience.

### 5. L'IA est un outil, pas un maître

La Saisie Magique comprend `"Dîner avec @Marc vendredi 20h au Resto #Perso"` et crée l'événement. C'est tout. Elle ne te propose pas de "repenser ta journée". Elle ne "recommande" rien. Elle n'apprend pas tes secrets pour les revendre.

Le modèle tourne localement, se charge en mémoire le temps de l'inférence, puis se décharge. Il fait **une chose bien** : transformer du texte libre en événement structuré. Le regex fait le gros du travail (~80% des cas). L'IA prend le reste.

Si l'IA se trompe, tu corriges, et elle apprend via la table `magic_habits`. Pas d'algorithme opaque.

### 6. Infomaniak pour les rendez-vous, Notion pour les tâches

C'est le contrat social de l'app. Tu ne crées pas de tâche dans Infomaniak. Tu ne crées pas de rendez-vous dans Notion. Chaque outil fait ce qu'il fait le mieux.

Infomaniak = CalDAV = protocole ouvert = interopérable.  
Notion = API REST = flexibilité structurelle = projets.

L'app fusionne les deux dans une seule timeline. Mais elle ne mélange pas les responsabilités.

### 7. Zéro permission inutile

Pas de READ_CONTACTS (les participants viennent de CalDAV). Pas de caméra (sauf mobile_scanner pour le QR import). Pas de micro. Pas de SEND_SMS. L'app demande le strict minimum : réseau, notifications, stockage (max API 28), alarme exacte.

Si Android demande "Autoriser monAgenda à accéder à vos contacts ?", c'est qu'on a cassé un principe.

---

## Ce que monAgenda n'est PAS

- **Pas un client mail.** Les invitations iTIP/iMIP, c'est Infomaniak qui gère.
- **Pas un carnet d'adresses.** Les contacts sont côté serveur CalDAV.
- **Pas un outil collaboratif.** C'est ton agenda personnel. Point.
- **Pas un assistant IA cloud.** L'IA est locale, bête et efficace.
- **Pas une app commerciale.** Usage personnel, possible open source.

---

## Le Design

L'interface est inspirée de Notion : calme, propre, silencieuse. Les couleurs Stabilo apportent de la vie sans agresser. Le fond `#F7F6F3` (light) ou `#191919` (dark) ne fatigue pas les yeux. Les logos Infomaniak et Notion sont toujours visibles sur chaque carte, en PNG haute qualité, version claire.

Les animations sont subtiles : shimmer pendant le chargement IA, fade sur les cartes. Pas de bounce, pas de confetti, pas de "wow effect". L'app est un outil de travail qui se fait oublier.

---

## Les Choix Techniques Irréversibles

Ces choix ont été faits délibérément, testés, et ne seront pas remis en question :

| Choix | Raison | Date |
|---|---|---|
| **Riverpod** (pas Provider, pas Bloc) | Compile-safe, tree-shakable, pas de BuildContext dans la logique | Depuis V1 |
| **SQLCipher** (pas sqflite brut) | Chiffrement AES-256 au repos, zéro effort côté app | V2 |
| **llama.cpp FFI** (pas TFLite, pas OpenAI) | Inférence locale, modèles GGUF, pas de TFLite pour les LLM | V3 |
| **Qwen2.5** (pas H2O Danube 3) | Danube testé et abandonné — résultats trop mauvais | V3, mars 2026 |
| **SfCalendar Syncfusion** (pas table_calendar) | D&D natif, resize, multi-vues, schedule view | Depuis V1 |
| **HugeIcons** (pas Material Icons) | Cohérence Notion Way, stroke rounded exclusif | V3 |
| **PBKDF2 100k iter** (pas Key.fromUtf8) | Sécurité backup, rétro-compatible magic header `MAP2` | V3 |
| **WAL mode** (ajouté V3) | Protection "database is locked" multi-connexion | V3, mars 2026 |

---

## La Règle d'Or du Développement

> **Un fix = un commit. Un commit = un test. Un bug cascade = revert immédiat.**

Leçon apprise le dur chemin : un commit "fix 30 bugs" a créé 4 niveaux de cascades (IntrinsicHeight → cartes 0px → 25000 erreurs → 582 Mo logs → "database is locked" → écran vide). Plus jamais.

---

## Ce Document

Ce manifest ne sera **jamais** modifié pour "ajouter une feature". Les features vont dans le cadrage_projet.md. La priorisation va dans la feuille_de_route.md.

Ce document dit **pourquoi** monAgenda existe et **comment** il pense.  
Les autres documents disent **quoi** faire et **quand**.

---

*monAgenda — Ton agenda, tes données, tes règles.*
