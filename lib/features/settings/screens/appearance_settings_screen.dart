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
          ],
        ),
      ),
    );
  }
}
