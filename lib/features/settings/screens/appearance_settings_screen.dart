import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../providers/settings_provider.dart';

class AppearanceSettingsScreen extends ConsumerWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            RadioListTile<String>(
              title: const Text('Automatique (système)'),
              subtitle: const Text('Suit les préférences de votre appareil'),
              value: AppConstants.themeAuto,
              groupValue: settings.theme,
              onChanged: (v) async {
                if (v != null) {
                  await ref.read(settingsProvider.notifier).setTheme(v);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Mode clair'),
              value: AppConstants.themeLight,
              groupValue: settings.theme,
              onChanged: (v) async {
                if (v != null) {
                  await ref.read(settingsProvider.notifier).setTheme(v);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Mode sombre'),
              value: AppConstants.themeDark,
              groupValue: settings.theme,
              onChanged: (v) async {
                if (v != null) {
                  await ref.read(settingsProvider.notifier).setTheme(v);
                }
              },
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
            RadioListTile<String>(
              title: const Text('Mois'),
              value: AppConstants.viewMonth,
              groupValue: settings.defaultView,
              onChanged: (v) async {
                if (v != null) {
                  await ref
                      .read(settingsProvider.notifier)
                      .setDefaultView(v);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Semaine'),
              value: AppConstants.viewWeek,
              groupValue: settings.defaultView,
              onChanged: (v) async {
                if (v != null) {
                  await ref
                      .read(settingsProvider.notifier)
                      .setDefaultView(v);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Jour'),
              value: AppConstants.viewDay,
              groupValue: settings.defaultView,
              onChanged: (v) async {
                if (v != null) {
                  await ref
                      .read(settingsProvider.notifier)
                      .setDefaultView(v);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Agenda'),
              value: AppConstants.viewAgenda,
              groupValue: settings.defaultView,
              onChanged: (v) async {
                if (v != null) {
                  await ref
                      .read(settingsProvider.notifier)
                      .setDefaultView(v);
                }
              },
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
            RadioListTile<String>(
              title: const Text('Lundi'),
              value: AppConstants.firstDayMonday,
              groupValue: settings.firstDayOfWeek,
              onChanged: (v) async {
                if (v != null) {
                  await ref
                      .read(settingsProvider.notifier)
                      .setFirstDayOfWeek(v);
                }
              },
            ),
            RadioListTile<String>(
              title: const Text('Dimanche'),
              value: AppConstants.firstDaySunday,
              groupValue: settings.firstDayOfWeek,
              onChanged: (v) async {
                if (v != null) {
                  await ref
                      .read(settingsProvider.notifier)
                      .setFirstDayOfWeek(v);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
