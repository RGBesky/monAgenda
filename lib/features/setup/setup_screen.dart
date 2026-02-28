import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hugeicons/hugeicons.dart';
import '../../providers/settings_provider.dart';
import '../../providers/sync_provider.dart';
import '../../services/logger_service.dart';

/// Écran d'onboarding en 3 étapes : Infomaniak, Notion (optionnel), Test connexion.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _pageController = PageController();
  int _currentPage = 0;

  // Page 1 — Infomaniak
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _calendarUrlController = TextEditingController();
  bool _obscurePassword = true;

  // Page 2 — Notion
  final _notionKeyController = TextEditingController();
  bool _obscureNotionKey = true;

  // Page 3 — Test
  bool _testingInfomaniak = false;
  bool? _infomaniakOk;
  String? _infomaniakError;
  bool _testingNotion = false;
  bool? _notionOk;
  String? _notionError;

  static final _calDavUrlRegExp = RegExp(r'^https://.+/calendar/.+$');

  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _calendarUrlController.dispose();
    _notionKeyController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(page,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // Logo + Titre
            Text(
              'Bienvenue sur monAgenda',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Configurez vos comptes pour commencer',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
            ),
            const SizedBox(height: 24),
            // Indicateur 3 dots
            _buildDots(isDark),
            const SizedBox(height: 24),
            // Pages
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (i) => setState(() => _currentPage = i),
                children: [
                  _buildInfomaniakPage(context),
                  _buildNotionPage(context),
                  _buildTestPage(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDots(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) {
        final active = i == _currentPage;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: active ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: active
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }

  // ────────────────────────────────────────────────────────────
  // PAGE 1 — Infomaniak CalDAV
  // ────────────────────────────────────────────────────────────
  Widget _buildInfomaniakPage(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.cloud_outlined, size: 48, color: Color(0xFF0098FF)),
          const SizedBox(height: 12),
          Text('Étape 1 — Infomaniak CalDAV',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            'Connectez votre calendrier Infomaniak pour synchroniser vos événements.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _usernameController,
            decoration: const InputDecoration(
              labelText: 'Nom d\'utilisateur',
              prefixIcon: Icon(Icons.person_outline),
              filled: true,
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Mot de passe applicatif',
              prefixIcon: const Icon(Icons.lock_outline),
              filled: true,
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword
                    ? Icons.visibility_off
                    : Icons.visibility),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _calendarUrlController,
            decoration: const InputDecoration(
              labelText: 'URL du calendrier CalDAV',
              prefixIcon: Icon(Icons.link),
              filled: true,
              hintText: 'https://...infomaniak.com/calendar/...',
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _canProceedInfomaniak() ? () => _saveAndNext1() : null,
            child: const Text('Suivant'),
          ),
        ],
      ),
    );
  }

  bool _canProceedInfomaniak() {
    return _usernameController.text.trim().isNotEmpty &&
        _passwordController.text.trim().isNotEmpty &&
        _calDavUrlRegExp.hasMatch(_calendarUrlController.text.trim());
  }

  Future<void> _saveAndNext1() async {
    final notifier = ref.read(settingsProvider.notifier);
    await notifier.updateInfomaniakCredentials(
      username: _usernameController.text.trim(),
      appPassword: _passwordController.text.trim(),
      calendarUrl: _calendarUrlController.text.trim(),
    );
    _goToPage(1);
  }

  // ────────────────────────────────────────────────────────────
  // PAGE 2 — Notion
  // ────────────────────────────────────────────────────────────
  Widget _buildNotionPage(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.auto_awesome_mosaic_outlined,
              size: 48, color: Color(0xFF5856D6)),
          const SizedBox(height: 12),
          Text('Étape 2 — Notion (optionnel)',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(
            'Connectez Notion pour synchroniser vos tâches et bases de données.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _notionKeyController,
            obscureText: _obscureNotionKey,
            decoration: InputDecoration(
              labelText: 'Clé API Notion',
              prefixIcon: const Icon(Icons.vpn_key_outlined),
              filled: true,
              hintText: 'secret_...',
              suffixIcon: IconButton(
                icon: Icon(_obscureNotionKey
                    ? Icons.visibility_off
                    : Icons.visibility),
                onPressed: () =>
                    setState(() => _obscureNotionKey = !_obscureNotionKey),
              ),
            ),
            textInputAction: TextInputAction.done,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _goToPage(2),
                  child: const Text('Passer'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _notionKeyController.text.trim().isNotEmpty
                      ? () => _saveAndNext2()
                      : null,
                  child: const Text('Connecter'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _saveAndNext2() async {
    final notifier = ref.read(settingsProvider.notifier);
    await notifier.updateNotionApiKey(_notionKeyController.text.trim());
    _goToPage(2);
  }

  // ────────────────────────────────────────────────────────────
  // PAGE 3 — Test de connexion
  // ────────────────────────────────────────────────────────────
  Widget _buildTestPage(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Icon(Icons.check_circle_outline,
              size: 48, color: Color(0xFF34C759)),
          const SizedBox(height: 12),
          Text('Étape 3 — Test de connexion',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 24),
          // Infomaniak test
          _buildTestRow(
            context,
            label: 'Infomaniak CalDAV',
            icon: HugeIcons.strokeRoundedCalendar01,
            testing: _testingInfomaniak,
            ok: _infomaniakOk,
            error: _infomaniakError,
          ),
          const SizedBox(height: 16),
          // Notion test (if configured)
          if (_notionKeyController.text.trim().isNotEmpty)
            _buildTestRow(
              context,
              label: 'Notion API',
              icon: HugeIcons.strokeRoundedNote01,
              testing: _testingNotion,
              ok: _notionOk,
              error: _notionError,
            ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _testingInfomaniak || _testingNotion
                ? null
                : () => _runTests(),
            icon: _testingInfomaniak || _testingNotion
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.play_arrow),
            label: const Text('Tester la connexion'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _infomaniakOk == true ? () => _finish() : null,
            child: const Text('Commencer'),
          ),
        ],
      ),
    );
  }

  Widget _buildTestRow(
    BuildContext context, {
    required String label,
    required dynamic icon,
    required bool testing,
    required bool? ok,
    required String? error,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            HugeIcon(
                icon: icon,
                size: 22,
                color: Theme.of(context).colorScheme.onSurface),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  if (error != null)
                    Text(error,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.red)),
                ],
              ),
            ),
            if (testing)
              const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            if (!testing && ok == true)
              const Icon(Icons.check_circle, color: Colors.green, size: 22),
            if (!testing && ok == false)
              const Icon(Icons.cancel, color: Colors.red, size: 22),
          ],
        ),
      ),
    );
  }

  Future<void> _runTests() async {
    setState(() {
      _testingInfomaniak = true;
      _infomaniakOk = null;
      _infomaniakError = null;
      _testingNotion = _notionKeyController.text.trim().isNotEmpty;
      _notionOk = null;
      _notionError = null;
    });

    // Test Infomaniak
    try {
      final service = ref.read(infomaniakServiceProvider);
      await service.validateCredentials();
      setState(() {
        _infomaniakOk = true;
        _testingInfomaniak = false;
      });
    } catch (e) {
      AppLogger.instance.error('Setup', 'Infomaniak test failed', e);
      setState(() {
        _infomaniakOk = false;
        _infomaniakError = e.toString().replaceFirst('Exception: ', '');
        _testingInfomaniak = false;
      });
    }

    // Test Notion (si configuré)
    if (_notionKeyController.text.trim().isNotEmpty) {
      try {
        final notionService = ref.read(notionServiceProvider);
        await notionService.validateApiKey();
        setState(() {
          _notionOk = true;
          _testingNotion = false;
        });
      } catch (e) {
        AppLogger.instance.error('Setup', 'Notion test failed', e);
        setState(() {
          _notionOk = false;
          _notionError = e.toString().replaceFirst('Exception: ', '');
          _testingNotion = false;
        });
      }
    }
  }

  void _finish() {
    // Invalider settingsProvider force un rebuild de UnifiedCalendarApp
    // qui redirigera vers AppShell puisque isInfomaniakConfigured == true
    ref.invalidate(settingsProvider);
    // Remplacer l'écran par la route racine
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const _SettingsReloadRedirect()),
    );
  }
}

/// Widget temporaire qui attend le rechargement des settings puis redirige.
class _SettingsReloadRedirect extends ConsumerWidget {
  const _SettingsReloadRedirect();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Simplement retourner un indicateur de chargement.
    // Le rebuild de la MaterialApp (via settingsProvider invalidation)
    // va remplacer tout le widget tree par AppShell.
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
