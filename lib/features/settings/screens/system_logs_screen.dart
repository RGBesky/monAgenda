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

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    final logs = await DatabaseHelper.instance.getRecentLogs();
    if (mounted) {
      setState(() {
        _logs = logs;
        _isLoading = false;
      });
    }
    // Marquer comme lus
    await DatabaseHelper.instance.markAllLogsAsRead();
    ref.invalidate(unreadErrorCountProvider);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Logs système'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Nettoyer les anciens logs',
            onPressed: () async {
              await DatabaseHelper.instance.cleanOldLogs();
              _loadLogs();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 64,
                        color: isDark
                            ? const Color(0xFF34C759)
                            : const Color(0xFF34C759),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Aucun log récent',
                        style: TextStyle(fontSize: 16),
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
