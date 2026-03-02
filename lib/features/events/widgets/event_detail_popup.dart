import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/event_detail_screen.dart';
import '../screens/event_form_screen.dart';
import '../../../core/models/event_model.dart';
import '../../../providers/events_provider.dart';

/// Ouvre le détail d'un événement :
/// - Desktop (largeur ≥ 800) → popup/dialog
/// - Mobile → push classique
void openEventDetail(BuildContext context, EventModel event) {
  final isDesktop = _isDesktop(context);

  if (isDesktop) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => EventDetailPopup(event: event),
    );
  } else {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => EventDetailScreen(event: event)),
    );
  }
}

bool _isDesktop(BuildContext context) {
  // Desktop si écran large OU plateforme desktop
  final width = MediaQuery.of(context).size.width;
  final isDesktopPlatform =
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;
  return isDesktopPlatform && width >= 600;
}

/// Dialog grands écrans pour afficher le détail d'un événement.
/// Gère l'édition en place : le formulaire remplace la vue détail
/// sans quitter la popup.
class EventDetailPopup extends ConsumerStatefulWidget {
  final EventModel event;
  const EventDetailPopup({super.key, required this.event});

  @override
  ConsumerState<EventDetailPopup> createState() => _EventDetailPopupState();
}

class _EventDetailPopupState extends ConsumerState<EventDetailPopup> {
  bool _isEditing = false;
  late EventModel _currentEvent;

  @override
  void initState() {
    super.initState();
    _currentEvent = widget.event;
  }

  @override
  Widget build(BuildContext context) {
    // ── Écouter les changements du provider pour rafraîchir _currentEvent ──
    // (attachments, liens kDrive, suppressions…)
    ref.listen<AsyncValue<List<EventModel>>>(eventsNotifierProvider, (prev, next) {
      next.whenData((events) {
        final updated = events
            .cast<EventModel?>()
            .firstWhere((e) => e!.id == _currentEvent.id, orElse: () => null);
        if (updated != null && updated != _currentEvent) {
          setState(() => _currentEvent = updated);
        }
      });
    });

    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width * 0.55).clamp(480.0, 720.0);
    final dialogHeight = (screenSize.height * 0.80).clamp(400.0, 800.0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: dialogWidth,
        height: dialogHeight,
        child: _isEditing
            ? EventFormScreen(
                key: ValueKey(
                    'edit_${_currentEvent.id}_${_currentEvent.updatedAt}'),
                event: _currentEvent,
                asDialogBody: true,
                onSaved: (savedEvent) {
                  setState(() {
                    _currentEvent = savedEvent;
                    _isEditing = false;
                  });
                },
                onCancel: () {
                  setState(() => _isEditing = false);
                },
              )
            : Column(
                children: [
                  // ── Barre de titre avec X ──
                  _buildTitleBar(context),
                  // ── Contenu détail ──
                  Expanded(
                    child: Builder(builder: (ctx) {
                      final dbNames =
                          ref.watch(notionDbNamesMapProvider).value ?? {};
                      final notionDbName = _currentEvent.isFromNotion
                          ? dbNames[_currentEvent.calendarId]
                          : null;
                      return EventDetailScreen(
                        event: _currentEvent,
                        asDialogBody: true,
                        notionDbName: notionDbName,
                        onEditInPlace: () {
                          setState(() => _isEditing = true);
                        },
                      );
                    }),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTitleBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF5F5F7),
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white12 : Colors.black12,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Détail de l\'événement',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const Spacer(),
          // Bouton fermer (pas de confirmation, on est en lecture seule)
          IconButton(
            icon: Icon(
              Icons.close,
              size: 20,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
            onPressed: () => Navigator.pop(context),
            tooltip: 'Fermer',
            splashRadius: 18,
          ),
        ],
      ),
    );
  }
}
