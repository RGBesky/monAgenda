import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/database/database_helper.dart';
import '../../../providers/settings_provider.dart';

/// Représente un calendrier dans la liste de tri.
class _CalendarEntry {
  final String key; // ex: "infomaniak:", "notion:2a35b8e6..."
  final String label; // ex: "Infomaniak", "Calendrier garde"
  final String source; // "infomaniak", "notion", "ics"
  final List<List<dynamic>> icon;

  const _CalendarEntry({
    required this.key,
    required this.label,
    required this.source,
    required this.icon,
  });
}

class AppearanceSettingsScreen extends ConsumerStatefulWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  ConsumerState<AppearanceSettingsScreen> createState() =>
      _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState
    extends ConsumerState<AppearanceSettingsScreen> {
  List<_CalendarEntry> _calendars = [];
  bool _loadingCalendars = true;

  @override
  void initState() {
    super.initState();
    _loadCalendars();
  }

  Future<void> _loadCalendars() async {
    final db = DatabaseHelper.instance;
    final notionDbs = await db.getNotionDatabases();
    final icsSubs = await db.getIcsSubscriptions();
    final settings = ref.read(settingsProvider).valueOrNull;

    final entries = <_CalendarEntry>[];

    // Infomaniak
    if (settings?.isInfomaniakConfigured == true) {
      entries.add(const _CalendarEntry(
        key: 'infomaniak:',
        label: 'Infomaniak (CalDAV)',
        source: 'infomaniak',
        icon: HugeIcons.strokeRoundedCalendar03,
      ));
    }

    // Notion databases
    for (final ndb in notionDbs) {
      if (!ndb.isEnabled) continue;
      entries.add(_CalendarEntry(
        key: 'notion:${ndb.effectiveSourceId}',
        label: ndb.name,
        source: 'notion',
        icon: HugeIcons.strokeRoundedListView,
      ));
    }

    // ICS subscriptions
    for (final sub in icsSubs) {
      if (!sub.isEnabled) continue;
      entries.add(_CalendarEntry(
        key: 'ics:${sub.id}',
        label: sub.name,
        source: 'ics',
        icon: HugeIcons.strokeRoundedCalendarDownload01,
      ));
    }

    // Appliquer l'ordre sauvegardé si disponible
    final savedOrder = settings?.calendarOrder ?? [];
    if (savedOrder.isNotEmpty) {
      entries.sort((a, b) {
        final ai = savedOrder.indexOf(a.key);
        final bi = savedOrder.indexOf(b.key);
        // -1 = pas dans la liste sauvée → à la fin
        final aIdx = ai == -1 ? 999 : ai;
        final bIdx = bi == -1 ? 999 : bi;
        return aIdx.compareTo(bIdx);
      });
    }

    if (mounted) {
      setState(() {
        _calendars = entries;
        _loadingCalendars = false;
      });
    }
  }

  Future<void> _saveCalendarOrder() async {
    final order = _calendars.map((e) => e.key).toList();
    await ref.read(settingsProvider.notifier).setCalendarOrder(order);
    // Activer automatiquement le tri par calendrier
    await ref
        .read(settingsProvider.notifier)
        .setEventSortMode(AppConstants.sortByCalendar);
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Apparence')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (settings) => ListView(
          children: [
            // Thème
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'THÈME',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            RadioGroup<String>(
              groupValue: settings.theme,
              onChanged: (v) async {
                if (v != null) {
                  await ref.read(settingsProvider.notifier).setTheme(v);
                }
              },
              child: const Column(
                children: [
                  RadioListTile<String>(
                    title: Text('Automatique (système)'),
                    subtitle: Text('Suit les préférences de votre appareil'),
                    value: AppConstants.themeAuto,
                  ),
                  RadioListTile<String>(
                    title: Text('Mode clair'),
                    value: AppConstants.themeLight,
                  ),
                  RadioListTile<String>(
                    title: Text('Mode sombre'),
                    value: AppConstants.themeDark,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Vue par défaut
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'VUE PAR DÉFAUT',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            RadioGroup<String>(
              groupValue: settings.defaultView,
              onChanged: (v) async {
                if (v != null) {
                  await ref.read(settingsProvider.notifier).setDefaultView(v);
                }
              },
              child: const Column(
                children: [
                  RadioListTile<String>(
                    title: Text('Mois'),
                    value: AppConstants.viewMonth,
                  ),
                  RadioListTile<String>(
                    title: Text('Semaine'),
                    value: AppConstants.viewWeek,
                  ),
                  RadioListTile<String>(
                    title: Text('Jour'),
                    value: AppConstants.viewDay,
                  ),
                  RadioListTile<String>(
                    title: Text('Agenda'),
                    value: AppConstants.viewAgenda,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Premier jour de la semaine
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'PREMIER JOUR DE LA SEMAINE',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            RadioGroup<String>(
              groupValue: settings.firstDayOfWeek,
              onChanged: (v) async {
                if (v != null) {
                  await ref
                      .read(settingsProvider.notifier)
                      .setFirstDayOfWeek(v);
                }
              },
              child: const Column(
                children: [
                  RadioListTile<String>(
                    title: Text('Lundi'),
                    value: AppConstants.firstDayMonday,
                  ),
                  RadioListTile<String>(
                    title: Text('Dimanche'),
                    value: AppConstants.firstDaySunday,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Tri des événements
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                'TRI DES ÉVÉNEMENTS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            RadioGroup<String>(
              groupValue: settings.eventSortMode,
              onChanged: (v) async {
                if (v != null) {
                  await ref.read(settingsProvider.notifier).setEventSortMode(v);
                }
              },
              child: const Column(
                children: [
                  RadioListTile<String>(
                    title: Text('Chronologique'),
                    subtitle: Text('Par heure de début uniquement'),
                    value: AppConstants.sortChronological,
                  ),
                  RadioListTile<String>(
                    title: Text('Par calendrier'),
                    subtitle: Text('Par heure, puis par ordre de calendrier'),
                    value: AppConstants.sortByCalendar,
                  ),
                ],
              ),
            ),

            // Ordre des calendriers (visible si tri par calendrier)
            if (settings.eventSortMode == AppConstants.sortByCalendar) ...[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  'ORDRE DES CALENDRIERS',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.primary,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Glissez pour réorganiser la priorité d\'affichage',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
              ),
              if (_loadingCalendars)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_calendars.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    'Aucun calendrier configuré',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.5),
                    ),
                  ),
                )
              else
                _buildReorderableCalendarList(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildReorderableCalendarList(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _calendars.length,
      onReorder: (oldIndex, newIndex) {
        setState(() {
          if (newIndex > oldIndex) newIndex--;
          final item = _calendars.removeAt(oldIndex);
          _calendars.insert(newIndex, item);
        });
        _saveCalendarOrder();
      },
      proxyDecorator: (child, index, animation) {
        return AnimatedBuilder(
          animation: animation,
          builder: (context, child) => Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: child,
          ),
          child: child,
        );
      },
      itemBuilder: (context, index) {
        final cal = _calendars[index];
        return ListTile(
          key: ValueKey(cal.key),
          leading: HugeIcon(
            icon: cal.icon,
            color: colorScheme.primary,
            size: 20,
          ),
          title: Text(
            cal.label,
            style: const TextStyle(fontSize: 14),
          ),
          subtitle: Text(
            _sourceLabel(cal.source),
            style: TextStyle(
              fontSize: 11,
              color: colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.drag_handle,
                color: colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _sourceLabel(String source) {
    switch (source) {
      case 'infomaniak':
        return 'CalDAV';
      case 'notion':
        return 'Notion';
      case 'ics':
        return 'Abonnement ICS';
      default:
        return 'Local';
    }
  }
}
