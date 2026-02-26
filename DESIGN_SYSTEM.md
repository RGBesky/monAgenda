# DESIGN SYSTEM & UX
## Unified Calendar — "Organic & Unified"

> **Philosophie** : Une interface unifiée qui ne sépare pas les mondes "Pro" et "Perso", ni "Tâches" et "Rendez-vous". Tout est sur une seule timeline fluide.

---

## 1. Palette & Typographie

### Philosophie : "The Notion Way"
Inspiré par la vision d'Ivan Zhao : **"Software should be tool-making."**
L'interface doit s'effacer pour laisser place au contenu. Le design est calme, structuré, utilisant des espaces blancs (`whitespace`) généreux et des frontières subtiles. Pas de dégradés agressifs ni d'ombres lourdes.

### Palette "Stabilo Boss" (Inspiration Image)
Une gamme de couleurs "Highlighter" vibrante mais douce, pour les Tags et Catégories.

| Nom | Hex (Approx) | Usage suggéré |
|---|---|---|
| **Stabilo Beige** | `#E6D2A8` | 40° Sable chaud – Admin / Autre |
| **Stabilo Lilac** | `#CCA0DC` | 285° Orchidée – Famille |
| **Stabilo Blue** | `#8ABBE6` | 212° Ciel d'été – Travail |
| **Stabilo Mint** | `#82D2CC` | 172° Menthe glacée – Sport |
| **Stabilo Green** | `#9CD8A8` | 130° Sauge fraîche – Santé |
| **Stabilo Lime** | `#C2DC8C` | 82° Tilleul – Projets |
| **Stabilo Yellow** | `#EAE08C` | 55° Citron doux – Loisirs |
| **Stabilo Orange** | `#FFBD98` | 22° Pêche douce – Important |
| **Stabilo Pink** | `#F2A5B8` | 350° Rose poudré – Urgent |

### Structure & Thème
| Usage | Light Mode | Dark Mode | Rôle |
|---|---|---|---|
| **Fond** | `#F7F6F3` (Notion Off-white) | `#191919` (OLED Black) | Fond d'écran apaisant |
| **Surface** | `#FFFFFF` | `#252525` | Cartes événements, BottomSheet |
| **Primaire** | `#007AFF` | `#0A84FF` | Actions principales (FAB, Liens) |
| **Texte** | `#37352F` | `#FFFFFF` | Lisibilité maximale |
| **Subd** | `#787774` | `#A1A1AA` | Métadonnées (heure, lieu) |

### Typographie
Police : **Inter** (Google Fonts).

*   **Display** : 24px Bold (Titres de pages "Jeudi 26")
*   **H2** : 18px SemiBold (Titres de sections "Cet après-midi")
*   **Body** : 15px Regular (Titres d'événements)
*   **Caption** : 13px Medium (Heures, Tags)
*   **Tiny** : 11px Medium (Labels discrets)

---

## 2. Iconographie (HugeIcons)
Utilisation exclusive de la librairie `hugeicons` (Stroke Rounded).

*   **Navigation** :
    *   Agenda : `HugeIcons.strokeRoundedCalendar03`
    *   Mois/Semaine : `HugeIcons.strokeRoundedCalendar01`
    *   Paramètres : `HugeIcons.strokeRoundedSettings02`
*   **Actions** :
    *   Ajout : `HugeIcons.strokeRoundedAdd01`
    *   Recherche : `HugeIcons.strokeRoundedSearch01`
    *   Sync : `HugeIcons.strokeRoundedRefresh`
*   **Métadonnées** :
    *   Heure : `HugeIcons.strokeRoundedTime01`
    *   Lieu : `HugeIcons.strokeRoundedLocation01`
    *   Description : `HugeIcons.strokeRoundedNote01`

---

## 3. Structure de Navigation

### A. Mobile (Bottom Navigation)
Une barre de navigation flottante (Floating style) ou classique, avec 3 onglets simples :

1.  **Agenda** (Accueil par défaut) : Liste chronologique unifiée.
2.  **Calendrier** : Vues grille (Mois, Semaine, 3 Jours).
3.  **Paramètres** : Configuration des comptes et préférences.

> Le **FAB** (Bouton d'action) est centré ou à droite, permettant de créer rapidement un RDV (Infomaniak) ou une Tâche (Notion).

### B. Desktop (Linux)
Navigation latérale (Rail) à gauche qui se replie. `NavigationRail` standard Flutter.

---

## 4. Composants UX Majeurs

### 4.1 La "Unified Event Card" (Carte Événement)
C'est l'atome de l'application. Elle doit afficher beaucoup d'infos sans être surchargée.

**Structure Visuelle :**
```text
┌── 🔴 ────────────────────────────────────────┐  <- 🔴 Bordure gauche : PRIORITÉ (Couleur)
│  TITRE DE L'ÉVÉNEMENT (Gras 16px)       🔗   │  <- 🔗 Logo source (Notion/Infomaniak)
│                                              │
│  [🏷️ Catégorie]  [🔄 En cours]               │  <- Chips : Catégorie & Statut
│  🕒 14:00 - 15:00                            │
└── 🔴 ────────────────────────────────────────┘
```

**Règles de design :**
1.  **Titre** : Grande visibilité, première chose qu'on lit.
2.  **Source** : Icône `HugeIcons` (16px) en haut à droite, *toujours visible*.
    *   Infomaniak : `HugeIcons.strokeRoundedCalendar03`
    *   Notion : `HugeIcons.strokeRoundedTask01`
3.  **Catégorie** : Badge (Chip) avec fond coloré pastel + texte couleur forte.
4.  **Statut** :
    *   *Notion* : Badge de statut ("À faire", "En cours", "Fait").
    *   *Infomaniak* : Statut de participation ("Accepté", "En attente") si pertinent, sinon masqué.
5.  **Priorité** :
    *   **Bordure gauche** épaisse (4px) de la couleur de priorité.
    *   Alternative : Une pastille de couleur avant le titre.
6.  **Interaction** :
    *   Tap simple = Ouvre le détail complet (Description, participants, lieu).
    *   Long press = Actions rapides (Supprimer, Modifier statut).

### 4.2 La Vue Agenda (Timeline)
Liste infinie groupée par jour.

*   **En-tête de jour** : "Aujourd'hui", "Demain", "Mardi 28". Sticky header (reste collé en haut).
*   **Indicateur "Maintenant"** : Une ligne horizontale rouge traverse la liste à l'heure actuelle.
*   **Météo** : Un petit widget météo s'insère sous chaque en-tête de jour (ex: "🌤️ 14°/22°").

### 4.3 Le "Quick Add" (Création Rapide)
Au tap sur le FAB `+` :
*   Apparition d'une modale (BottomSheet) simple.
*   Deux gros boutons clairs :
    1.  🔵 **Rendez-vous** (Infomaniak)
    2.  🟣 **Tâche** (Notion)
*   Ou un champ texte intelligent "Créer..." qui détecte si c'est une tâche ou un RDV (Évolution V2).

---

## 5. Mockup Textuel : Vue "Agenda" Unifiée

```text
  9:41 📱                        📶 🔋
┌──────────────────────────────────────┐
│ Aujourd'hui             🔍   ⚙️      │
│ Jeudi 26 Fév • 🌤️ 14°               │
├──────────────────────────────────────┤
│               (Timeline)             │
│                                      │
│  09:00                               │
│  ┌── 🔴 ──────────────────────────┐  │
│  │ Daily Meeting               📅 │  │  <- RDV Infomaniak
│  │ [🏢 Travail]                   │  │
│  │ 09:00 - 10:00                  │  │
│  └── 🔴 ──────────────────────────┘  │
│                                      │
│  ─── 10:42 (Maintenant) ───────────  │
│                                      │
│  11:00                               │
│  ┌── 🟠 ──────────────────────────┐  │
│  │ Relancer client X           📝 │  │  <- Tâche Notion
│  │ [💼 Pro] [⏳ En cours]         │  │  <- Statut bien visible
│  │ 11:00                          │  │
│  └── 🟠 ──────────────────────────┘  │
│                                      │
│  Toute la journée                    │
│  ┌── 🔵 ──────────────────────────┐  │
│  │ Rédiger specs V2            📝 │  │
│  │ [💻 Dev] [✅ Fait]             │  │
│  └── 🔵 ──────────────────────────┘  │
│                                      │
└──────────────────────────────────────┘
```

## 6. Adaptations Spécifiques

### Gestion des Tâches Notion
*   Les tâches avec une heure (`Include time`) s'affichent dans la chronologie.
*   Les tâches sans heure (juste une date) s'affichent dans une section "Toute la journée" en haut du jour, ou listées après les heures selon le tri choisi.
*   **Check-box** : Possibilité d'ajouter une case à cocher `○` directement sur la carte pour compléter une tâche Notion sans l'ouvrir.

### Gestion des RDV Infomaniak
*   Pas de case à cocher.
*   Clic = Ouvre le détail complet.
