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
import 'features/search/screens/search_screen.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_constants.dart';
import 'core/models/event_model.dart';
import 'core/widgets/source_logos.dart';
import 'providers/events_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Raccourcis clavier Desktop — données publiques pour affichage dans Settings.
class AppShellShortcuts {
  AppShellShortcuts._();
  static const all = [
    ('Ctrl + N', 'Nouvel événement'),
    ('Ctrl + K', 'Saisie Magique (Spotlight)'),
    ('Ctrl + F', 'Rechercher'),
    ('Ctrl + S', 'Synchroniser maintenant'),
    ('Ctrl + ,', 'Paramètres'),
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
        darkTheme: _buildDarkTheme(settings.amoledMode),
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
      primary: Color(0xFF2383E2), // Bleu Notion
      onPrimary: Colors.white,
      primaryContainer: Color(0xFFE8F0FE),
      onPrimaryContainer: Color(0xFF174EA6),
      secondary: Color(0xFF0F7B6C), // Vert Notion
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFFDBEDDB),
      onSecondaryContainer: Color(0xFF0A5C51),
      tertiary: Color(0xFF9065C0),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFF3EEFB),
      onTertiaryContainer: Color(0xFF5C3D80),
      error: Color(0xFFEB5757), // Rouge Notion
      onError: Colors.white,
      errorContainer: Color(0xFFFCE4E4),
      onErrorContainer: Color(0xFF8B2020),
      surface: Color(0xFFFFFFFF),
      onSurface: Color(0xFF37352F), // Noir Notion
      onSurfaceVariant: Color(0xFF6B6B6B),
      outline: Color(0xFFEBEBE9), // Bordure Notion très subtile
      outlineVariant: Color(0xFFF5F5F3),
      shadow: Color(0x05000000), // Ombre quasi-invisible
      surfaceContainerHighest: Color(0xFFF0F0EE),
      surfaceContainerHigh: Color(0xFFF7F6F3),
      surfaceContainerLow: Color(0xFFFCFCFB),
      surfaceContainer: Color(0xFFFAFAF8),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: const Color(0xFFFFFFFF), // Fond blanc pur Notion
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w700,
            color: Color(0xFF191919), // Très noir pour max lisibilité
            letterSpacing: -0.3),
        titleLarge: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Color(0xFF191919),
            letterSpacing: -0.2),
        bodyLarge: const TextStyle(
            fontSize: 16, // Plus gros pour lisibilité
            fontWeight: FontWeight.w400,
            color: Color(0xFF37352F),
            height: 1.5), // Line-height Notion
        bodyMedium: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Color(0xFF37352F),
            height: 1.5),
        labelLarge: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6B6B6B)),
        bodySmall: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF9B9A97)),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        shadowColor: Colors.transparent, // Zéro ombre — style Notion
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(3), // Radius Notion = 3px
          side: const BorderSide(color: Color(0xFFEBEBE9), width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0, // Jamais d'ombre — Notion
        backgroundColor: Color(0xFFFFFFFF), // Blanc pur
        foregroundColor: Color(0xFF37352F),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600, // Semi-bold Notion
          color: Color(0xFF37352F),
          letterSpacing: -0.1,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFF0F0EE), // Divider quasi-invisible Notion
        thickness: 1,
        space: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: const Color(0xFF2383E2).withValues(alpha: 0.08),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2383E2), // Bleu Notion
            );
          }
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Color(0xFF9B9A97), // Gris secondaire Notion
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: Color(0xFF2383E2), size: 22);
          }
          return const IconThemeData(color: Color(0xFF9B9A97), size: 22);
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: const Color(0xFF2383E2), // Bleu Notion
        foregroundColor: Colors.white,
        elevation: 0, // Pas d'ombre
        highlightElevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        showCloseIcon: true,
        backgroundColor: const Color(0xFF37352F),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        actionTextColor: const Color(0xFF6CB4EE),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          elevation: 0,
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          side: const BorderSide(color: Color(0xFFE0DFDB)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF7F6F3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4), // Radius Notion
          borderSide: const BorderSide(color: Color(0xFFE0DFDB), width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFFE0DFDB), width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(4),
          borderSide: const BorderSide(color: Color(0xFF2383E2), width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        hintStyle: const TextStyle(
          color: Color(0xFFC4C4C0), // Placeholder gris clair Notion
          fontSize: 14,
        ),
      ),
      searchBarTheme: SearchBarThemeData(
        elevation: WidgetStateProperty.all(0),
        backgroundColor: WidgetStateProperty.all(const Color(0xFFF7F6F3)),
        shape: WidgetStateProperty.all(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4), // Notion
            side: const BorderSide(color: Color(0xFFE0DFDB), width: 1),
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.white;
          }
          return const Color(0xFFC4C4C0);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const Color(0xFF2383E2); // Bleu Notion
          }
          return const Color(0xFFE0DFDB);
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return Colors.transparent;
          }
          return const Color(0xFFD3D3CF);
        }),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4), // Notion = petit radius
          side: const BorderSide(color: Color(0xFFEBEBE9), width: 0.5),
        ),
        titleTextStyle: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Color(0xFF37352F),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF7F6F3), // Fond puce Notion
        labelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Color(0xFF37352F),
        ),
        side: BorderSide.none, // Pas de bordure chips Notion
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(3)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      scrollbarTheme: const ScrollbarThemeData(
        thickness: WidgetStatePropertyAll(6),
        radius: Radius.circular(3),
        thumbColor: WidgetStatePropertyAll(Color(0xFFD0CFC9)),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 10,
        dense: true,
        visualDensity: VisualDensity.compact,
      ),
    );
  }

  ThemeData _buildDarkTheme(bool isAmoled) {
    final scaffoldBg =
        isAmoled ? const Color(0xFF000000) : const Color(0xFF191919);
    final surfaceColor =
        isAmoled ? const Color(0xFF0A0A0A) : const Color(0xFF202020);
    final cardColor =
        isAmoled ? const Color(0xFF0F0F0F) : const Color(0xFF252525);
    final appBarBg =
        isAmoled ? const Color(0xFF000000) : const Color(0xFF202020);
    final navBarBg =
        isAmoled ? const Color(0xFF000000) : const Color(0xFF202020);
    final inputFill =
        isAmoled ? const Color(0xFF141414) : const Color(0xFF282828);
    final searchBarBg =
        isAmoled ? const Color(0xFF141414) : const Color(0xFF282828);
    final surfaceContainerLow =
        isAmoled ? const Color(0xFF0D0D0D) : const Color(0xFF232323);
    final surfaceContainer =
        isAmoled ? const Color(0xFF121212) : const Color(0xFF282828);
    final surfaceContainerHigh =
        isAmoled ? const Color(0xFF1A1A1A) : const Color(0xFF303030);
    final surfaceContainerHighest =
        isAmoled ? const Color(0xFF222222) : const Color(0xFF373737);

    final colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: const Color(0xFF0A84FF),
      onPrimary: Colors.white,
      primaryContainer: const Color(0xFF003566),
      onPrimaryContainer: const Color(0xFF8FC5FF),
      secondary: const Color(0xFF6AAB73),
      onSecondary: Colors.white,
      secondaryContainer: const Color(0xFF2A4A30),
      onSecondaryContainer: const Color(0xFFA8D5AE),
      tertiary: const Color(0xFFB08AD8),
      onTertiary: Colors.white,
      tertiaryContainer: const Color(0xFF3D2A55),
      onTertiaryContainer: const Color(0xFFD4BFE8),
      error: const Color(0xFFF07070),
      onError: Colors.white,
      errorContainer: const Color(0xFF4A1A1A),
      onErrorContainer: const Color(0xFFF5B0B0),
      surface: surfaceColor,
      onSurface: const Color(0xFFE8E7E4),
      onSurfaceVariant: const Color(0xFF9B9A97),
      outline: const Color(0xFF373737),
      outlineVariant: const Color(0xFF2D2D2D),
      shadow: const Color(0x40000000),
      surfaceContainerHighest: surfaceContainerHighest,
      surfaceContainerHigh: surfaceContainerHigh,
      surfaceContainerLow: surfaceContainerLow,
      surfaceContainer: surfaceContainer,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBg,
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
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFF373737), width: 0.5),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: appBarBg,
        foregroundColor: const Color(0xFFE8E7E4),
        surfaceTintColor: Colors.transparent,
        titleTextStyle: const TextStyle(
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
        backgroundColor: navBarBg,
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
        fillColor: inputFill,
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
        backgroundColor: WidgetStateProperty.all(searchBarBg),
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
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(6),
        radius: const Radius.circular(3),
        thumbColor: WidgetStatePropertyAll(
          isAmoled ? const Color(0xFF444444) : const Color(0xFF555555),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
        minVerticalPadding: 10,
        dense: true,
        visualDensity: VisualDensity.compact,
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

    // V3 : Afficher un SnackBar lorsqu'un conflit ETag est résolu
    ref.listen<EventModel?>(etagConflictProvider, (prev, next) {
      if (next != null) {
        final messenger = UnifiedCalendarApp.scaffoldMessengerKey.currentState;
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              'Conflit résolu — version serveur appliquée pour «${next.title}»',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Remettre à null après affichage
        ref.read(etagConflictProvider.notifier).state = null;
      }
    });

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
        child: Column(
          children: [
            const Spacer(),
            // ── Boutons sources (Infomaniak + BDD Notion) ──
            _buildSourceButtons(isDark),
            const SizedBox(height: 12),
            Padding(
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
          ],
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

  /// Boutons sources dans le rail : 1 Infomaniak + 1 par BDD Notion.
  /// Si > 3 BDD Notion, les premières sont affichées + un bouton "..." ouvre un popup.
  Widget _buildSourceButtons(bool isDark) {
    final settingsAsync = ref.watch(settingsProvider);
    final settings = settingsAsync.valueOrNull;
    final notionDbsAsync = ref.watch(notionDatabasesProvider);
    final notionDbs = notionDbsAsync.valueOrNull ?? [];

    final hasInfomaniak = settings?.isInfomaniakConfigured ?? false;
    final hasNotion = notionDbs.isNotEmpty;

    if (!hasInfomaniak && !hasNotion) return const SizedBox.shrink();

    const maxVisibleDbs = 3;
    final visibleDbs = notionDbs.take(maxVisibleDbs).toList();
    final overflowDbs = notionDbs.length > maxVisibleDbs
        ? notionDbs.sublist(maxVisibleDbs)
        : <dynamic>[];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Séparateur discret
          Divider(
            color: isDark ? Colors.white12 : const Color(0xFFE8E8E8),
            height: 1,
            indent: 4,
            endIndent: 4,
          ),
          const SizedBox(height: 8),

          // Bouton Infomaniak
          if (hasInfomaniak)
            _SourceRailButton(
              logo: SourceLogos.infomaniak(size: 22),
              label: 'Infomaniak',
              isDark: isDark,
              onTap: () => _openUrl('https://mail.infomaniak.com/'),
            ),

          // Boutons BDD Notion visibles
          ...visibleDbs.map((db) => _SourceRailButton(
                logo: SourceLogos.notion(size: 22, isDark: isDark),
                label: db.name,
                isDark: isDark,
                onTap: () => _openUrl(
                    'https://www.notion.so/${db.notionId.replaceAll('-', '')}'),
              )),

          // Bouton overflow si > maxVisibleDbs
          if (overflowDbs.isNotEmpty)
            _SourceRailButton(
              logo: SourceLogos.notion(size: 18, isDark: isDark),
              label: '+${overflowDbs.length}',
              isDark: isDark,
              onTap: () => _showOverflowNotionDbs(context, isDark, overflowDbs),
            ),
        ],
      ),
    );
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showOverflowNotionDbs(
      BuildContext context, bool isDark, List<dynamic> dbs) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Bases Notion',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF191919),
                ),
              ),
            ),
            ...dbs.map((db) => ListTile(
                  leading: SourceLogos.notion(size: 24, isDark: isDark),
                  title: Text(db.name),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openUrl(
                        'https://www.notion.so/${db.notionId.replaceAll('-', '')}');
                  },
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
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
          tooltip: 'Créer (Ctrl+N / Ctrl+K)',
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
      // Ctrl+F → Ouvrir l'écran de recherche
      const SingleActivator(LogicalKeyboardKey.keyF, control: true): () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SearchScreen()),
        );
      },
      // Ctrl+S → Synchroniser maintenant
      const SingleActivator(LogicalKeyboardKey.keyS, control: true): () {
        ref.read(syncNotifierProvider.notifier).syncAll();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Synchronisation lancée…'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      // Ctrl+, → Ouvrir les paramètres
      const SingleActivator(LogicalKeyboardKey.comma, control: true): () {
        setState(() => _selectedIndex = 2); // 2 = onglet Paramètres
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
                      logo: SourceLogos.infomaniak(size: 28),
                      label: 'Rendez-vous',
                      sublabel: 'Infomaniak',
                      color: AppColors.bluePastel,
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
                      logo: SourceLogos.notion(size: 28, isDark: isDark),
                      label: 'Tâche',
                      sublabel: 'Notion',
                      color: AppColors.violetPastel,
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
  final Widget? logo;
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  const _QuickAddButton({
    required this.icon,
    this.logo,
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
            if (logo != null)
              SizedBox(width: 32, height: 32, child: Center(child: logo!))
            else
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton source compact pour le NavigationRail.
class _SourceRailButton extends StatelessWidget {
  final Widget logo;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _SourceRailButton({
    required this.logo,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Tooltip(
        message: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            width: 64,
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : const Color(0xFFF5F5F5),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                logo,
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: isDark ? Colors.white70 : const Color(0xFF666666),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
