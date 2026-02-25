import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'core/constants/app_constants.dart';
import 'providers/settings_provider.dart';
import 'providers/sync_provider.dart';
import 'features/calendar/screens/calendar_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/search/screens/search_screen.dart';

class UnifiedCalendarApp extends ConsumerWidget {
  const UnifiedCalendarApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(settingsProvider);

    return settingsAsync.when(
      loading: () => const MaterialApp(
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      error: (e, _) => MaterialApp(
        home: Scaffold(body: Center(child: Text('Erreur : $e'))),
      ),
      data: (settings) => MaterialApp(
        title: 'Calendrier Unifié',
        debugShowCheckedModeBanner: false,
        themeMode: settings.themeMode,
        theme: _buildLightTheme(),
        darkTheme: _buildDarkTheme(),
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [Locale('fr', 'FR')],
        locale: const Locale('fr', 'FR'),
        home: const AppShell(),
      ),
    );
  }

  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1565C0),
        brightness: Brightness.light,
      ),
      fontFamily: 'Inter',
      cardTheme: CardTheme(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF1565C0),
        brightness: Brightness.dark,
      ),
      fontFamily: 'Inter',
      cardTheme: CardTheme(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
    );
  }
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  int _selectedIndex = 0;

  final _screens = const [
    CalendarScreen(),
    SearchScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Sync automatique au lancement
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(syncNotifierProvider.notifier).syncAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isOffline = ref.watch(isOfflineProvider);
    final syncState = ref.watch(syncNotifierProvider);

    return Scaffold(
      body: Column(
        children: [
          if (isOffline) _buildOfflineBanner(),
          Expanded(child: _screens[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: [
          NavigationDestination(
            icon: syncState.isSyncing
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.calendar_month_outlined),
            selectedIcon: const Icon(Icons.calendar_month),
            label: 'Calendrier',
          ),
          const NavigationDestination(
            icon: Icon(Icons.search_outlined),
            selectedIcon: Icon(Icons.search),
            label: 'Recherche',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }

  Widget _buildOfflineBanner() {
    return Container(
      width: double.infinity,
      color: const Color(0xFFFF6D00),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: const Row(
        children: [
          Icon(Icons.wifi_off, color: Colors.white, size: 16),
          SizedBox(width: 8),
          Text(
            'Mode hors ligne — Lecture seule',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
