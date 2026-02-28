import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'dart:io' show Platform;
import 'providers/settings_provider.dart';
import 'providers/sync_provider.dart';
import 'features/calendar/screens/agenda_screen.dart';
import 'features/calendar/screens/calendar_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/setup/setup_screen.dart';
import 'features/events/screens/event_form_screen.dart';
import 'features/magic/magic_entry_screen.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_constants.dart';

/// Raccourcis clavier Desktop — données publiques pour affichage dans Settings.
class AppShellShortcuts {
  AppShellShortcuts._();
  static const all = [
    ('Ctrl + N', 'Nouvel événement'),
    ('Ctrl + K', 'Saisie Magique (Spotlight)'),
    ('Ctrl + F', 'Rechercher'),
    ('Échap', 'Fermer / Retour'),
  ];
}

class UnifiedCalendarApp extends ConsumerWidget {
  const UnifiedCalendarApp({super.key});

  /// Clé globale pour le ScaffoldMessenger racine.
  /// Permet d'afficher des SnackBars depuis n'importe où,
  /// même avec des Scaffolds imbriqués.
  static final scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

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
        title: 'monAgenda',
        scaffoldMessengerKey: UnifiedCalendarApp.scaffoldMessengerKey,
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
        home: settings.isInfomaniakConfigured
            ? const AppShell()
            : const SetupScreen(),
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
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFF37352F)),
        titleLarge: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF37352F)),
        bodyLarge: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: Color(0xFF37352F)),
        bodyMedium: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF37352F)),
        labelLarge: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF787774)),
        bodySmall: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF787774)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE3E2DE), width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: Color(0xFFF7F6F3),
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
        showCloseIcon: true,
        backgroundColor: const Color(0xFF37352F),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        actionTextColor: const Color(0xFF69AEFF),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          side: const BorderSide(color: Color(0xFFE3E2DE)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF7F6F3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE3E2DE), width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE3E2DE), width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF007AFF), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
      textTheme:
          GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
        displayLarge: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFFE8E7E4)),
        titleLarge: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFFE8E7E4)),
        bodyLarge: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: Color(0xFFE8E7E4)),
        bodyMedium: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFFE8E7E4)),
        labelLarge: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF9B9A97)),
        bodySmall: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Color(0xFF9B9A97)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: const Color(0xFF252525),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
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
        showCloseIcon: true,
        backgroundColor: const Color(0xFFE8E7E4),
        contentTextStyle:
            const TextStyle(color: Color(0xFF37352F), fontSize: 14),
        actionTextColor: const Color(0xFF0A84FF),
        closeIconColor: const Color(0xFF37352F),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          side: const BorderSide(color: Color(0xFF373737)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF282828),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF373737), width: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF373737), width: 0.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFF0A84FF), width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return const Color(0xFF9B9A97); // gris visible
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF0A84FF);
          }
          return const Color(0xFF404040); // track visible sur fond sombre
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return const Color(0xFF5A5A5A); // bordure visible
        }),
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
  int _selectedIndex = 0; // 0=To Do, 1=Calendrier, 2=Paramètres

  final _screens = const [
    AgendaScreen(),
    CalendarScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // syncAll est déclenché par autoSyncOnConnectivityProvider — pas de double appel
  }

  @override
  Widget build(BuildContext context) {
    // V2 : Garde le listener auto-sync actif en permanence
    ref.watch(autoSyncOnConnectivityProvider);
    // V2 : Fallback périodique pour Linux (connectivity_plus parfois muet)
    ref.watch(periodicSyncRetryProvider);

    final isOffline = ref.watch(isOfflineProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.of(context).size.width >= 800;

    if (isDesktop) {
      // ── Desktop : NavigationRail latéral (Design System §3.B) ──
      final desktopScaffold = Scaffold(
        body: Row(
          children: [
            _buildNavigationRail(isDark),
            const VerticalDivider(width: 1, thickness: 0.5),
            Expanded(
              child: Column(
                children: [
                  if (isOffline) _buildOfflineBanner(),
                  _buildServerErrorBanner(),
                  Expanded(child: _screens[_selectedIndex]),
                ],
              ),
            ),
          ],
        ),
      );

      // ── Raccourcis clavier Desktop (6.4) ──
      if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
        return CallbackShortcuts(
          bindings: _buildKeyboardShortcuts(context),
          child: Focus(
            autofocus: true,
            child: desktopScaffold,
          ),
        );
      }
      return desktopScaffold;
    }

    // ── Mobile : BottomNavigationBar (Design System §3.A) ──
    return Scaffold(
      body: Column(
        children: [
          if (isOffline) _buildOfflineBanner(),
          _buildServerErrorBanner(),
          Expanded(child: _screens[_selectedIndex]),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(isDark),
      floatingActionButton: _buildFab(context, isDark),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildNavigationRail(bool isDark) {
    final selectedColor =
        isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final unselectedColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final bgColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;

    return NavigationRail(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (i) => setState(() => _selectedIndex = i),
      backgroundColor: bgColor,
      indicatorColor: selectedColor.withValues(alpha: 0.12),
      labelType: NavigationRailLabelType.all,
      trailing: Expanded(
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Opacity(
              opacity: 0.7,
              child: Image.asset(
                'logo_pack/logo_color_48x48.png',
                width: 32,
                height: 32,
                filterQuality: FilterQuality.medium,
              ),
            ),
          ),
        ),
      ),
      leading: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bouton hors-ligne toujours visible
            Builder(
              builder: (context) {
                final forceOffline = ref.watch(forceOfflineProvider);
                final isOffline = ref.watch(isOfflineProvider);
                final isDarkRail =
                    Theme.of(context).brightness == Brightness.dark;
                return _buildOfflineMiniFab(
                    forceOffline, isOffline, isDarkRail);
              },
            ),
            const SizedBox(height: 8),
            FloatingActionButton.small(
              heroTag: 'rail_fab',
              onPressed: () => _showQuickAddSheet(context, isDark),
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedAdd01,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
      destinations: [
        NavigationRailDestination(
          icon: HugeIcon(
              icon: HugeIcons.strokeRoundedTask01,
              color: unselectedColor,
              size: 22),
          selectedIcon: HugeIcon(
              icon: HugeIcons.strokeRoundedTask01,
              color: selectedColor,
              size: 22),
          label: Text('To Do',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: unselectedColor)),
        ),
        NavigationRailDestination(
          icon: HugeIcon(
              icon: HugeIcons.strokeRoundedCalendar01,
              color: unselectedColor,
              size: 22),
          selectedIcon: HugeIcon(
              icon: HugeIcons.strokeRoundedCalendar01,
              color: selectedColor,
              size: 22),
          label: Text('Calendrier',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: unselectedColor)),
        ),
        NavigationRailDestination(
          icon: HugeIcon(
              icon: HugeIcons.strokeRoundedSettings02,
              color: unselectedColor,
              size: 22),
          selectedIcon: HugeIcon(
              icon: HugeIcons.strokeRoundedSettings02,
              color: selectedColor,
              size: 22),
          label: Text('Paramètres',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: unselectedColor)),
        ),
      ],
    );
  }

  Widget _buildBottomNavBar(bool isDark) {
    final selectedColor =
        isDark ? AppColors.darkPrimary : AppColors.lightPrimary;
    final unselectedColor =
        isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return NavigationBar(
      selectedIndex: _selectedIndex,
      onDestinationSelected: (i) => setState(() => _selectedIndex = i),
      destinations: [
        NavigationDestination(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedTask01,
            color: unselectedColor,
            size: 22,
          ),
          selectedIcon: HugeIcon(
            icon: HugeIcons.strokeRoundedTask01,
            color: selectedColor,
            size: 22,
          ),
          label: 'To Do',
        ),
        NavigationDestination(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedCalendar01,
            color: unselectedColor,
            size: 22,
          ),
          selectedIcon: HugeIcon(
            icon: HugeIcons.strokeRoundedCalendar01,
            color: selectedColor,
            size: 22,
          ),
          label: 'Calendrier',
        ),
        NavigationDestination(
          icon: HugeIcon(
            icon: HugeIcons.strokeRoundedSettings02,
            color: unselectedColor,
            size: 22,
          ),
          selectedIcon: HugeIcon(
            icon: HugeIcons.strokeRoundedSettings02,
            color: selectedColor,
            size: 22,
          ),
          label: 'Paramètres',
        ),
      ],
    );
  }

  Widget _buildFab(BuildContext context, bool isDark) {
    final forceOffline = ref.watch(forceOfflineProvider);
    final isOffline = ref.watch(isOfflineProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bouton hors-ligne toujours visible
        _buildOfflineMiniFab(forceOffline, isOffline, isDark),
        const SizedBox(height: 10),
        // FAB principal
        FloatingActionButton(
          heroTag: 'main_fab',
          onPressed: () => _showQuickAddSheet(context, isDark),
          tooltip: 'Créer',
          child: const HugeIcon(
            icon: HugeIcons.strokeRoundedAdd01,
            color: Colors.white,
            size: 26,
          ),
        ),
      ],
    );
  }

  /// Mini FAB hors-ligne — toujours visible au-dessus du FAB principal.
  /// Couleurs : vert=connecté, orange=pas de réseau, rouge=hors-ligne forcé.
  Widget _buildOfflineMiniFab(bool forceOffline, bool isOffline, bool isDark) {
    final Color bg;
    final Color iconColor;
    final dynamic icon;
    final String tooltip;

    if (forceOffline) {
      // Forcé hors-ligne : ROUGE
      bg = const Color(0xFFFF3B30);
      iconColor = Colors.white;
      icon = HugeIcons.strokeRoundedWifiDisconnected04;
      tooltip = 'Mode hors-ligne (cliquer pour reconnecter)';
    } else if (isOffline) {
      // Pas de réseau : ORANGE
      bg = const Color(0xFFFF9500);
      iconColor = Colors.white;
      icon = HugeIcons.strokeRoundedWifi02;
      tooltip = 'Pas de réseau';
    } else {
      // En ligne : VERT
      bg = const Color(0xFF34C759);
      iconColor = Colors.white;
      icon = HugeIcons.strokeRoundedWifiFullSignal;
      tooltip = 'Connecté — cliquer pour forcer hors-ligne';
    }

    return FloatingActionButton.small(
      heroTag: 'offline_fab',
      onPressed: () => ref.read(forceOfflineProvider.notifier).toggle(),
      tooltip: tooltip,
      backgroundColor: bg,
      elevation: forceOffline || isOffline ? 4 : 2,
      child: HugeIcon(
        icon: icon,
        color: iconColor,
        size: 18,
      ),
    );
  }

  // ── Raccourcis clavier Desktop (Task 6.4) ──────────────────
  Map<ShortcutActivator, VoidCallback> _buildKeyboardShortcuts(
      BuildContext context) {
    return {
      // Ctrl+N → Créer un événement
      const SingleActivator(LogicalKeyboardKey.keyN, control: true): () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const EventFormScreen()),
        );
      },
      // Ctrl+K → Saisie Magique (Spotlight)
      const SingleActivator(LogicalKeyboardKey.keyK, control: true): () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MagicEntryScreen()),
        );
      },
      // Ctrl+F → Focus recherche (switch to Agenda tab with search)
      const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
        setState(() => _selectedIndex = 0);
        // The search bar is in AgendaScreen — switching to it is sufficient
      },
      // Escape → Fermer modal/BottomSheet
      const SingleActivator(LogicalKeyboardKey.escape): () {
        Navigator.maybePop(context);
      },
    };
  }

  /// Liste des raccourcis pour affichage dans Settings
  /// (Accessible via AppShellShortcuts.all depuis d'autres fichiers)

  void _showQuickAddSheet(BuildContext context, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkSurface : AppColors.lightSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pill
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: (isDark ? AppColors.darkText : AppColors.lightText)
                      .withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Créer…',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  // ── Rendez-vous Infomaniak ──────────────
                  Expanded(
                    child: _QuickAddButton(
                      icon: HugeIcons.strokeRoundedCalendar03,
                      label: 'Rendez-vous',
                      sublabel: 'Infomaniak',
                      color: AppColors.stabiloBlue,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EventFormScreen(
                              initialSource: AppConstants.sourceInfomaniak,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  // ── Tâche Notion ────────────────────────
                  Expanded(
                    child: _QuickAddButton(
                      icon: HugeIcons.strokeRoundedTask01,
                      label: 'Tâche',
                      sublabel: 'Notion',
                      color: AppColors.stabiloLilac,
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const EventFormScreen(
                              initialSource: AppConstants.sourceNotion,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOfflineBanner() {
    final forceOffline = ref.watch(forceOfflineProvider);
    final pendingCount = ref.watch(pendingSyncCountProvider).valueOrNull ?? 0;

    return GestureDetector(
      onTap: () => ref.read(forceOfflineProvider.notifier).toggle(),
      child: Container(
        width: double.infinity,
        color: forceOffline
            ? const Color(0xFFFF3B30) // Rouge si forcé hors-ligne
            : const Color(0xFFFF9500), // Orange si pas de réseau
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        child: Row(
          children: [
            HugeIcon(
              icon: forceOffline
                  ? HugeIcons.strokeRoundedWifiDisconnected04
                  : HugeIcons.strokeRoundedWifi02,
              color: Colors.white,
              size: 16,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                forceOffline
                    ? 'Mode hors-ligne activé${pendingCount > 0 ? ' · $pendingCount en attente' : ''}'
                    : 'Pas de connexion${pendingCount > 0 ? ' · $pendingCount en attente' : ''}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            // Toggle rapide
            SizedBox(
              height: 24,
              child: Transform.scale(
                scale: 0.7,
                child: Switch(
                  value: forceOffline,
                  onChanged: (_) =>
                      ref.read(forceOfflineProvider.notifier).toggle(),
                  activeThumbColor: Colors.white,
                  activeTrackColor: Colors.white24,
                  inactiveThumbColor: Colors.white70,
                  inactiveTrackColor: Colors.white12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// V3 : Bannière d'erreur serveur (429/500/503/timeout).
  Widget _buildServerErrorBanner() {
    final serverError = ref.watch(serverSyncErrorProvider);
    if (serverError == null) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      color: const Color(0xFFFF9500),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
      child: Row(
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedAlert02,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '⚠️ $serverError',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(serverSyncErrorProvider.notifier).state = null;
              ref.read(syncNotifierProvider.notifier).syncAll();
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 28),
            ),
            child: const Text('Réessayer', style: TextStyle(fontSize: 12)),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white, size: 16),
            constraints: const BoxConstraints(maxWidth: 28, maxHeight: 28),
            padding: EdgeInsets.zero,
            onPressed: () {
              ref.read(serverSyncErrorProvider.notifier).state = null;
            },
          ),
        ],
      ),
    );
  }
}

// ── Bouton du Quick Add Sheet ─────────────────────────────────────────────
class _QuickAddButton extends StatelessWidget {
  final dynamic icon;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  const _QuickAddButton({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: isDark
              ? color.withValues(alpha: 0.12)
              : color.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? color.withValues(alpha: 0.25) : color,
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            HugeIcon(
              icon: icon,
              color: isDark ? color : AppColors.textOnStabilo(color),
              size: 32,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? color : AppColors.textOnStabilo(color),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              sublabel,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w400,
                color: (isDark ? color : AppColors.textOnStabilo(color))
                    .withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
