import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/widgets/settings_logo_header.dart';
import '../../../providers/settings_provider.dart';
import '../../../services/notification_service.dart';

class NotificationsSettingsScreen extends ConsumerWidget {
  const NotificationsSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: settingsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur : $e')),
        data: (settings) => ListView(
          children: [
            const SettingsLogoHeader(),
            SwitchListTile(
              title: const Text('Rappels d\'événements'),
              subtitle: const Text('Notification avant chaque événement'),
              value: settings.reminderEnabled,
              onChanged: (v) async {
                await ref
                    .read(settingsProvider.notifier)
                    .updatePreference('reminder_enabled', v);
              },
            ),
            const Divider(height: 1),
            if (settings.reminderEnabled) ...[
              ListTile(
                title: const Text('Délai de rappel par défaut'),
                subtitle: Text(
                  _formatMinutes(settings.defaultReminderMinutes),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pickReminderDelay(context, ref, settings),
              ),
              const Divider(height: 1),
            ],
            SwitchListTile(
              title: const Text('Résumé matinal'),
              subtitle: const Text('Récapitulatif quotidien de votre agenda'),
              value: settings.morningSummaryEnabled,
              onChanged: (v) async {
                await ref
                    .read(settingsProvider.notifier)
                    .updatePreference('morning_summary', v);
                if (v) {
                  await NotificationService.instance.scheduleDailySummary(
                    hour: settings.morningSummaryHour,
                    minute: settings.morningSummaryMinute,
                  );
                } else {
                  await NotificationService.instance.cancelAllReminders();
                }
              },
            ),
            const Divider(height: 1),
            if (settings.morningSummaryEnabled) ...[
              ListTile(
                title: const Text('Heure du résumé'),
                subtitle: Text(
                  '${settings.morningSummaryHour.toString().padLeft(2, '0')}:'
                  '${settings.morningSummaryMinute.toString().padLeft(2, '0')}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _pickMorningSummaryTime(context, ref, settings),
              ),
              const Divider(height: 1),
            ],
            Padding(
              padding: const EdgeInsets.all(16),
              child: OutlinedButton.icon(
                onPressed: () async {
                  await NotificationService.instance.showInstantNotification(
                    title: 'Test de notification',
                    body: 'Les notifications fonctionnent correctement !',
                  );
                },
                icon: const Icon(Icons.notifications_outlined),
                label: const Text('Tester les notifications'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickReminderDelay(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final options = {
      5: '5 minutes',
      10: '10 minutes',
      15: '15 minutes',
      30: '30 minutes',
      60: '1 heure',
      120: '2 heures',
      1440: '1 jour',
    };

    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Délai de rappel'),
        children: options.entries
            .map(
              (e) => SimpleDialogOption(
                onPressed: () => Navigator.pop(ctx, e.key),
                child: Text(
                  e.value,
                  style: TextStyle(
                    fontWeight: e.key == settings.defaultReminderMinutes
                        ? FontWeight.w600
                        : null,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );

    if (result != null) {
      await ref
          .read(settingsProvider.notifier)
          .updatePreference('reminder_minutes', result);
    }
  }

  Future<void> _pickMorningSummaryTime(
    BuildContext context,
    WidgetRef ref,
    AppSettings settings,
  ) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.morningSummaryHour,
        minute: settings.morningSummaryMinute,
      ),
    );

    if (picked != null) {
      await ref
          .read(settingsProvider.notifier)
          .updatePreference('morning_hour', picked.hour);
      await ref
          .read(settingsProvider.notifier)
          .updatePreference('morning_minute', picked.minute);
      await NotificationService.instance.scheduleDailySummary(
        hour: picked.hour,
        minute: picked.minute,
      );
    }
  }

  String _formatMinutes(int minutes) {
    if (minutes < 60) return '$minutes minutes';
    if (minutes == 60) return '1 heure';
    if (minutes < 1440) return '${minutes ~/ 60} heures';
    return '1 jour';
  }
}
