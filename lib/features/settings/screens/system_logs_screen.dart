import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_helper.dart';
import '../../../providers/sync_provider.dart';

/// Écran des logs système — erreurs de synchronisation, etc.
class SystemLogsScreen extends ConsumerStatefulWidget {
  const SystemLogsScreen({super.key});

  @override
  ConsumerState<SystemLogsScreen> createState() => _SystemLogsScreenState();
}

class _SystemLogsScreenState extends ConsumerState<SystemLogsScreen> {
  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;
  int _totalLogCount = 0;
  String? _levelFilter; // null = tous, 'error', 'warning', 'info'

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);

    final logs = _levelFilter != null
        ? await DatabaseHelper.instance.getAllLogs(levelFilter: _levelFilter)
        : await DatabaseHelper.instance.getAllLogs();
    final count = await DatabaseHelper.instance.getLogCount();

    if (mounted) {
      setState(() {
        _logs = logs;
        _totalLogCount = count;
        _isLoading = false;
      });
    }
    // Marquer comme lus
    await DatabaseHelper.instance.markAllLogsAsRead();
    ref.invalidate(unreadErrorCountProvider);
  }

  Future<void> _clearAllLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Purger tous les logs ?'),
        content: Text(
          'Supprimer les $_totalLogCount logs de la base de données.\n'
          'Cette action est irréversible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            style:
                TextButton.styleFrom(foregroundColor: const Color(0xFFFF3B30)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Purger tout'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      final deleted = await DatabaseHelper.instance.clearAllLogs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$deleted logs supprimés')),
        );
      }
      _loadLogs();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs système'),
        actions: [
          // Filtre par niveau
          PopupMenuButton<String?>(
            icon: Icon(
              Icons.filter_list,
              color: _levelFilter != null ? const Color(0xFF007AFF) : null,
            ),
            tooltip: 'Filtrer par niveau',
            onSelected: (value) {
              setState(() => _levelFilter = value);
              _loadLogs();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: null,
                child: Row(
                  children: [
                    Icon(
                      Icons.all_inclusive,
                      color: _levelFilter == null
                          ? const Color(0xFF007AFF)
                          : Colors.grey,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text('Tous'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'error',
                child: Row(
                  children: [
                    Icon(
                      Icons.error,
                      color: _levelFilter == 'error'
                          ? const Color(0xFFFF3B30)
                          : Colors.grey,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text('Erreurs'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'warning',
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber,
                      color: _levelFilter == 'warning'
                          ? const Color(0xFFFF9500)
                          : Colors.grey,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text('Avertissements'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'info',
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: _levelFilter == 'info'
                          ? const Color(0xFF007AFF)
                          : Colors.grey,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    const Text('Informations'),
                  ],
                ),
              ),
            ],
          ),
          // Nettoyer anciens (> 7j)
          IconButton(
            icon: const Icon(Icons.auto_delete),
            tooltip: 'Nettoyer les logs > 7 jours',
            onPressed: () async {
              final deleted = await DatabaseHelper.instance.cleanOldLogs();
              if (!mounted) return;
              // ignore: use_build_context_synchronously
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('$deleted anciens logs supprimés')),
              );
              _loadLogs();
            },
          ),
          // Purger TOUT
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Color(0xFFFF3B30)),
            tooltip: 'Purger tous les logs',
            onPressed: _totalLogCount > 0 ? _clearAllLogs : null,
          ),
        ],
      ),
      body: Column(
        children: [
          // Header avec compteur
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF7F6F3),
            child: Row(
              children: [
                Icon(
                  Icons.storage,
                  size: 16,
                  color: _totalLogCount > 800
                      ? const Color(0xFFFF9500)
                      : isDark
                          ? const Color(0xFF9B9A97)
                          : const Color(0xFF787774),
                ),
                const SizedBox(width: 8),
                Text(
                  '$_totalLogCount / ${DatabaseHelper.maxLogEntries} logs en base',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: _totalLogCount > 800
                        ? const Color(0xFFFF9500)
                        : isDark
                            ? const Color(0xFF9B9A97)
                            : const Color(0xFF787774),
                  ),
                ),
                const Spacer(),
                if (_levelFilter != null)
                  Chip(
                    label: Text(
                      _levelFilter == 'error'
                          ? 'Erreurs'
                          : _levelFilter == 'warning'
                              ? 'Avertissements'
                              : 'Infos',
                      style: const TextStyle(fontSize: 11),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 14),
                    onDeleted: () {
                      setState(() => _levelFilter = null);
                      _loadLogs();
                    },
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                if (_levelFilter == null)
                  Text(
                    '${_logs.length} affichés',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? const Color(0xFF9B9A97)
                          : const Color(0xFF787774),
                    ),
                  ),
              ],
            ),
          ),

          // Barre de progression si > 80% plein
          if (_totalLogCount > 800)
            LinearProgressIndicator(
              value: _totalLogCount / DatabaseHelper.maxLogEntries,
              backgroundColor:
                  isDark ? const Color(0xFF2D2D2D) : const Color(0xFFE0E0E0),
              valueColor: AlwaysStoppedAnimation<Color>(
                _totalLogCount > 950
                    ? const Color(0xFFFF3B30)
                    : const Color(0xFFFF9500),
              ),
              minHeight: 3,
            ),

          // Liste des logs
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _logs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              size: 64,
                              color: Color(0xFF34C759),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _levelFilter != null
                                  ? 'Aucun log de type "$_levelFilter"'
                                  : 'Aucun log',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Tout fonctionne normalement',
                              style: TextStyle(
                                color: isDark
                                    ? const Color(0xFF9B9A97)
                                    : const Color(0xFF787774),
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadLogs,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _logs.length,
                          itemBuilder: (context, index) =>
                              _buildLogTile(_logs[index], isDark),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogTile(Map<String, dynamic> log, bool isDark) {
    final level = log['level'] as String;
    final source = log['source'] as String;
    final message = log['message'] as String;
    final details = log['details'] as String?;
    final createdAt = log['created_at'] as String;

    final color = _levelColor(level);
    final icon = _levelIcon(level);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ExpansionTile(
        leading: Icon(icon, color: color, size: 20),
        title: Text(
          message,
          style: const TextStyle(fontSize: 14),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '$source • ${_formatDate(createdAt)}',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? const Color(0xFF9B9A97) : const Color(0xFF787774),
          ),
        ),
        children: [
          if (details != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1A1A1A)
                      : const Color(0xFFF7F6F3),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  details,
                  style: TextStyle(
                    fontSize: 12,
                    fontFamily: 'monospace',
                    color: isDark
                        ? const Color(0xFF9B9A97)
                        : const Color(0xFF787774),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'error':
        return const Color(0xFFFF3B30);
      case 'warning':
        return const Color(0xFFFF9500);
      case 'info':
        return const Color(0xFF007AFF);
      default:
        return const Color(0xFF8E8E93);
    }
  }

  IconData _levelIcon(String level) {
    switch (level) {
      case 'error':
        return Icons.error;
      case 'warning':
        return Icons.warning_amber;
      case 'info':
        return Icons.info_outline;
      default:
        return Icons.circle;
    }
  }

  String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      final now = DateTime.now();
      if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
      return '${dt.day}/${dt.month} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return iso;
    }
  }
}
