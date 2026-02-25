import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
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
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF007AFF),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFD0E4FF),
      onPrimaryContainer: Color(0xFF003D99),
      secondary: Color(0xFF6AAB73),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFDCEFDF),
      onSecondaryContainer: Color(0xFF3D6B44),
      tertiary: Color(0xFF9065C0),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFEDE4F5),
      onTertiaryContainer: Color(0xFF5C3D80),
      error: Color(0xFFE03E3E),
      onError: Colors.white,
      errorContainer: Color(0xFFFCE4E4),
      onErrorContainer: Color(0xFF8B2020),
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF37352F),
      onSurfaceVariant: Color(0xFF787774),
      outline: Color(0xFFE3E2DE),
      outlineVariant: Color(0xFFF1F0ED),
      shadow: Color(0x0A000000),
      surfaceContainerHighest: Color(0xFFF1F0ED),
      surfaceContainerHigh: Color(0xFFF4F3F0),
      surfaceContainerLow: Color(0xFFFAFAF8),
      surfaceContainer: Color(0xFFF7F6F3),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFF7F6F3),
      textTheme: GoogleFonts.interTextTheme().apply(
        bodyColor: const Color(0xFF37352F),
        displayColor: const Color(0xFF37352F),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFFE3E2DE), width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: Color(0xFFFFFFFF),
        foregroundColor: Color(0xFF37352F),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF37352F),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE3E2DE),
        thickness: 0.5,
        space: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFF007AFF).withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF007AFF),
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF787774),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFF007AFF), size: 22);
          }
          return const IconThemeData(color: Color(0xFF787774), size: 22);
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: const Color(0xFF007AFF),
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: WidgetStateProperty.all(0),
        backgroundColor: WidgetStateProperty.all(const Color(0xFFF1F0ED)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFFE3E2DE), width: 0.5),
          ),
        ),
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF0A84FF),
      onPrimary: Colors.white,
      primaryContainer: Color(0xFF003566),
      onPrimaryContainer: Color(0xFF8FC5FF),
      secondary: Color(0xFF6AAB73),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFF2A4A30),
      onSecondaryContainer: Color(0xFFA8D5AE),
      tertiary: Color(0xFFB08AD8),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFF3D2A55),
      onTertiaryContainer: Color(0xFFD4BFE8),
      error: Color(0xFFF07070),
      onError: Colors.white,
      errorContainer: Color(0xFF4A1A1A),
      onErrorContainer: Color(0xFFF5B0B0),
      surface: Color(0xFF202020),
      onSurface: Color(0xFFE8E7E4),
      onSurfaceVariant: Color(0xFF9B9A97),
      outline: Color(0xFF373737),
      outlineVariant: Color(0xFF2D2D2D),
      shadow: Color(0x40000000),
      surfaceContainerHighest: Color(0xFF373737),
      surfaceContainerHigh: Color(0xFF303030),
      surfaceContainerLow: Color(0xFF232323),
      surfaceContainer: Color(0xFF282828),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFF191919),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).apply(
        bodyColor: const Color(0xFFE8E7E4),
        displayColor: const Color(0xFFE8E7E4),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF202020),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF373737), width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: Color(0xFF202020),
        foregroundColor: Color(0xFFE8E7E4),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFFE8E7E4),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF373737),
        thickness: 0.5,
        space: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: const Color(0xFF202020),
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFF0A84FF).withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0A84FF),
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF9B9A97),
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFF0A84FF), size: 22);
          }
          return const IconThemeData(color: Color(0xFF9B9A97), size: 22);
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: const Color(0xFF0A84FF),
        foregroundColor: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: WidgetStateProperty.all(0),
        backgroundColor: WidgetStateProperty.all(const Color(0xFF282828)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: const BorderSide(color: Color(0xFF373737), width: 0.5),
          ),
        ),
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
    final isOffline = ref.watch(isOfflineProvider).value ?? false;
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
