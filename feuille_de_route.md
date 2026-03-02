# Feuille de route monAgenda — 2 mars 2026

> **Branche** : `claude/save-agenda-github-bajxr`  
> **HEAD** : `442e2e6`  
> **Méthode** : Croisement Code × Git × Archives (3 passes, grep exhaustif)  
> **Décisions** : Session GO/NO-GO interactive du 2 mars 2026

---

## Comptage vérité (code-first)

| Catégorie | Nombre |
|---|---|
| ✅ Fait et confirmé en code | **112** |
| 🟡 Partiel (écart documenté) | **23** |
| ❌ Non fait (voulu mais absent du code) | **15** |
| 🆕 Bonus (dans le code mais jamais planifié) | **~38** |

---

## Phase 0 — STOP THE BLEEDING (fait le 01/03/2026, commit 442e2e6)

| ID | Tâche | Statut |
|---|---|---|
| P0-1 | WAL mode + busy_timeout=5000 (Desktop + Mobile) | ✅ Committé |
| P0-2 | Manifest HEAD corrigé b3bdba1 → 2d05d8e | ✅ Committé |
| P0-3 | 9 items manifest recochés (vérifiés en code) | ✅ Committé |

---

## Phase 1 — CORRECTIONS RAPIDES (effort S, risque faible)

> Chaque fix = 1 commit isolé, testé avant le suivant.  
> Priorité : du plus impactant au moins impactant.

| ID | Tâche | Effort | Fichiers | Critère d'acceptation |
|---|---|---|---|---|
| P1-1 | **Logos PNG haute qualité, toujours clair** | S | `lib/core/widgets/source_logos.dart`, `assets/logos/` | Logos Infomaniak + Notion visibles en light ET dark, PNG haute résolution, jamais de logo invisible |
| P1-2 | **Supprimer 2 debugPrint()** | S | `lib/features/calendar/screens/agenda_screen.dart`, `lib/features/calendar/widgets/unified_event_card.dart` | Zero `debugPrint` dans `lib/` |
| P1-3 | **Invalider pendingSyncCount après create/update** | S | `lib/providers/events_provider.dart` | Badge "X en attente" se met à jour immédiatement après création/modif d'un event |
| P1-4 | **Purge soft-deleted events > 30 jours** | S | `lib/core/database/database_helper.dart`, `lib/main.dart` | `DELETE WHERE is_deleted=1 AND deleted_at < 30j` au démarrage |
| P1-5 | **Warning changement credentials si sync pending** | S | `lib/features/settings/screens/connections_settings_screen.dart` | Dialog "X actions en attente seront perdues, continuer ?" avant save credentials |
| P1-6 | **Ajouter "Changer statut" dans long press** | S | `lib/features/calendar/screens/agenda_screen.dart` | Long press → 3 actions : Modifier, Supprimer, Changer statut (Notion tasks) |
| P1-7 | **Nettoyer open_filex + champ smartAttachments** | S | `lib/features/events/screens/event_detail_screen.dart`, `lib/core/models/event_model.dart` | Suppression import open_filex, suppression champ smartAttachments mort |
| P1-8 | **Unifier 36 SnackBars vers scaffoldMessengerKey** | S | ~10 fichiers | 0 appels `ScaffoldMessenger.of(context)` restants, tout via `scaffoldMessengerKey` |
| P1-9 | **Widget Android : nombre events paramétrable** | S | `lib/services/widget_service.dart`, settings | Slider 3-10 events dans paramètres, valeur sauvée en SharedPreferences |

---

## Phase 2 — FONCTIONNALITÉS MANQUANTES (effort M)

> Chaque feature = 1 branche ou 1 série de commits isolés.

| ID | Tâche | Effort | Description | Critère d'acceptation |
|---|---|---|---|---|
| P2-1 | **Parser ATTENDEE + ORGANIZER CalDAV** | M | Extraire ATTENDEE (CN, mailto, PARTSTAT) + ORGANIZER depuis les VEVENT CalDAV entrants | Les participants apparaissent dans le détail d'un event reçu par sync |
| P2-2 | **Sync CalDAV en background (WorkManager)** | M | Ajouter tâche `caldav_sync` dans callbackDispatcher | Les events se synchronisent même app fermée (vérifiable via widget mis à jour) |
| P2-3 | **Table participants SQLite** | M | Nouvelle table `participants` pré-synchronisée depuis CalDAV ATTENDEE | Recherche participants rapide (SELECT), plus de parse JSON à la volée |
| P2-4 | **Migrer Platform.isLinux → LayoutBuilder** | M | Remplacer ~15 endroits Platform.isLinux par `LayoutBuilder(builder: (ctx, box) => box.maxWidth > 800 ? desktop : mobile)` | Aucune référence Platform.isLinux dans la logique UI (garde Platform seulement pour Process.run, paths) |
| P2-5 | **Géolocalisation GPS + saisie manuelle fallback** | M | Demander permission GPS, géoloc précise pour météo, fallback saisie manuelle ville si GPS refusé | Météo fonctionne : GPS > IP > saisie manuelle > villes suisses |
| P2-6 | **FadeTransition sur cartes événements** | S-M | AnimatedList ou FadeTransition wrapper sur les cartes dans agenda + calendar | Apparition progressive des cartes au scroll/chargement |
| P2-7 | **Migrer setState locaux → Riverpod** | M | Identifier ~15 setState dans les formulaires, migrer vers StateProvider ou StateNotifier local | Zero `setState` dans `lib/` sauf `initState/dispose` life cycle |
| P2-8 | **Résumé matinal IA** | M | Charger modèle en background → inférer résumé des events du jour → notification texte intelligent | Notification matinale avec contenu personnalisé ("3 rdv dont réunion 2h avec Marc") au lieu de comptage simple |

---

## Phase 3 — NOUVELLES FEATURES (effort L)

| ID | Tâche | Effort | Description | Critère d'acceptation |
|---|---|---|---|---|
| P3-1 | **magic_conversation_query** | L | Mode question/réponse en langage naturel : "Quand prochain rdv Marc?" → intent JSON → query SQLite → réponse formatée | Poser une question → réponse correcte basée sur les données réelles |
| P3-2 | **Backup direct kDrive via dépôt** | M-L | Upload HTTP automatique vers kDrive via lien de dépôt, sans navigateur | Bouton "Sauvegarder sur kDrive" → upload + confirmation sans ouvrir le navigateur |
| P3-3 | **A/B test prompt français vs anglais** | S | Créer 2 prompts (FR compact, EN actuel), comparer qualité parsing sur 50 entrées types | Tableau comparatif, garder le meilleur |

---

## Phase 4-FUTURE — REPORTÉ (décision consciente)

| FEAT | Raison du report |
|---|---|
| `magic_suggestions_autocomplete` | Pas prioritaire, la barre magique sans suggestions suffit |
| `export_send_kdrive` | V4, quand l'upload kDrive sera stable |
| `mobile_minimal_battery` | V-FUTURE, WorkManager gère déjà les contraintes |
| `architecture_layers` (Repository) | Refacto massive V4, l'architecture actuelle fonctionne |
| `saisie_vocale_v4` | NO-GO définitif |

---

## FERMÉ / RÉSOLU

| FEAT | Résolution |
|---|---|
| `deprecated_gzip_base64` | Méthode supprimée (mieux que @Deprecated). À documenter. |
| `gguf_4bit_model` | Qwen2.5 reste — Danube testé et abandonné (trop mauvais). Documenter le choix. |
| `qr_clipboard_fallback` | NO-GO — QR + export fichier suffisent |
| `export_ppt_stdin` | NO-GO — CLI args fonctionnent, pas de limite observée |
| `smart_context_pdf_desktop` | NO-GO — Pas dans la philosophie de l'app |
| `notification_deduplication` | NO-GO — Overwrite implicite par event.id suffit |
| `magic_timeout` | NO-GO — Garder 15s (téléphones lents) |
| `zero_local_files_principle` | NO-GO — Fallback local acceptable pour exports |
| `kdrive_deposit_link` | À TESTER ENSEMBLE — pas de décision unilatérale |

---

## BONUS NON PLANIFIÉS (38 features déjà dans le code)

Ces features existent dans le code mais n'étaient dans aucun document d'archives. Elles font partie de l'app.

**Raccourcis clavier** : Ctrl+N (new event), Ctrl+S (sync), Ctrl+, (settings), Escape (close)  
**Préférences calendrier** : firstDayOfWeek, tri par priorité calendrier, reorder calendriers, vue par défaut  
**Géolocalisation IP** : ipapi.co + Nominatim reverse geocoding + 8 villes suisses  
**Intents Android** : ICS file handler, INSERT event intent, BOOT_COMPLETED reschedule notifs  
**Exports avancés** : CSV events + protection injection CSV, extraction garde Notion→PPT, résolution venv Python, export/import config JSON chiffré  
**UI** : Event detail popup desktop, server error banner, source filter toggle, Inter typography, Notion DB auto-discover, Notion DB target picker  
**Background** : daily summary notification, WorkManager periodic 6h reschedule, Linux daily timer  
**Autres** : Formulaire récurrence RRULE, reset complet double confirmation, crypto_utils AES-256-CBC

---

## RÈGLES D'EXÉCUTION

1. **Un fix = un commit** avec référence au finding (ex: `fix: P1-3 invalidate pendingSyncCount`)
2. **Jamais de commit monolithique** "fix 30 bugs"
3. **Test runtime** entre chaque commit — `flutter analyze` ≠ "ça marche"
4. **Si un fix crée un nouveau problème** → STOP immédiat, revert, réévaluer
5. **Les décisions ci-dessus sont actées** — pas de re-discussion sauf changement de contexte

---

## LOG DES DÉCISIONS (2 mars 2026)

| Décision | Raison | Réversibilité |
|---|---|---|
| Qwen2.5 au lieu de H2O Danube 3 | Danube testé, trop mauvais en pratique | Réversible (changer URL download + SHA) |
| Timeout IA 15s (pas 8s) | Téléphones lents risquent timeout | Réversible (constante) |
| Pas de Repository layer | Refacto massive, architecture actuelle claire | Réversible (V4) |
| Pas de SmartContextService | Contredit zéro-fichier-local, bouton Notion suffit | Réversible |
| Pas de saisie vocale | NO-GO définitif | Réversible si besoin change |
| Widget 7 events → paramétrable | Mieux que choix arbitraire 3 ou 7 | — |
| Géoloc GPS prioritaire | Plus précis que IP pour météo | Fallback IP + manuel |
| Logos PNG toujours clair PRIORITÉ | Logos actuels "pétés" selon utilisateur | — |
