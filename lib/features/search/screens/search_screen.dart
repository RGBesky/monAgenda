import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/database/database_helper.dart';
import '../../../core/models/event_model.dart';
import '../../../core/models/tag_model.dart';
import '../../../core/utils/date_utils.dart';
import '../../../providers/tags_provider.dart';
import '../../events/screens/event_detail_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _searchController = TextEditingController();
  List<EventModel> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  // Filtres
  final List<TagModel> _selectedTags = [];
  DateTime? _startDate;
  DateTime? _endDate;
  String? _participantEmail;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final results = await DatabaseHelper.instance.searchEvents(
        keyword: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        tagIds: _selectedTags.isEmpty
            ? null
            : _selectedTags.map((t) => t.id!).toList(),
        participantEmail: _participantEmail?.trim().isEmpty == true
            ? null
            : _participantEmail,
        startDate: _startDate,
        endDate: _endDate,
      );

      setState(() => _results = results);
    } finally {
      setState(() => _isSearching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recherche'),
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Rechercher un événement...',
              leading: const Icon(Icons.search),
              trailing: [
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {
                        _results = [];
                        _hasSearched = false;
                      });
                    },
                  ),
              ],
              onSubmitted: (_) => _search(),
              onChanged: (v) => setState(() {}),
            ),
          ),

          // Filtres avancés
          _buildFilters(),

          // Bouton rechercher
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isSearching ? null : _search,
                child: _isSearching
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Rechercher'),
              ),
            ),
          ),

          const Divider(height: 1),

          // Résultats
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    final tagsAsync = ref.watch(tagsNotifierProvider);

    return ExpansionTile(
      title: Text(
        'Filtres avancés',
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
      ),
      leading: const Icon(Icons.filter_list),
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filtres par tags
              tagsAsync.when(
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
                data: (tags) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tags',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: tags.map((tag) {
                        final isSelected =
                            _selectedTags.any((t) => t.id == tag.id);
                        final color = AppColors.fromHex(tag.colorHex);
                        return FilterChip(
                          label: Text(tag.name,
                              style: const TextStyle(fontSize: 12)),
                          selected: isSelected,
                          selectedColor: color.withValues(alpha: 0.2),
                          checkmarkColor: color,
                          labelStyle: TextStyle(
                            color: isSelected ? color : null,
                          ),
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedTags.add(tag);
                              } else {
                                _selectedTags
                                    .removeWhere((t) => t.id == tag.id);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Plage de dates
              Text(
                'Période',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(isStart: true),
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: Text(
                        _startDate != null
                            ? CalendarDateUtils.formatShortDate(_startDate!)
                            : 'Du',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(isStart: false),
                      icon: const Icon(Icons.event, size: 16),
                      label: Text(
                        _endDate != null
                            ? CalendarDateUtils.formatShortDate(_endDate!)
                            : 'Au',
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  if (_startDate != null || _endDate != null)
                    IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () => setState(() {
                        _startDate = null;
                        _endDate = null;
                      }),
                    ),
                ],
              ),

              const SizedBox(height: 8),

              // Email participant
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Email participant',
                  prefixIcon: Icon(Icons.person_search_outlined),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.emailAddress,
                onChanged: (v) => setState(() => _participantEmail = v),
              ),

              if (_selectedTags.isNotEmpty ||
                  _startDate != null ||
                  _endDate != null ||
                  (_participantEmail?.isNotEmpty == true)) ...[
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text('Effacer les filtres'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildResults() {
    if (!_hasSearched) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Lancez une recherche',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_results.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'Aucun résultat',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final event = _results[index];
        return _buildEventTile(event);
      },
    );
  }

  Widget _buildEventTile(EventModel event) {
    final firstCategory = event.categoryTags.firstOrNull;
    final accent = firstCategory != null
        ? AppColors.fromHex(firstCategory.colorHex)
        : (event.isFromInfomaniak
            ? const Color(0xFF0098FF)
            : const Color(0xFF007AFF));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = AppColors.pastelBg(accent, isDark: isDark);
    final textColor = AppColors.textOnPastel(accent, isDark: isDark);
    final subColor = textColor.withValues(alpha: 0.7);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      color: bg,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EventDetailScreen(event: event),
          ),
        ),
        child: IntrinsicHeight(
          child: Row(
            children: [
              // Accent bar
              Container(
                width: 4,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
              ),
              // Content
              Expanded(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title + source
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              event.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                                color: textColor,
                                letterSpacing: -0.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildSourceIcon(event, isDark),
                        ],
                      ),
                      const SizedBox(height: 5),
                      // Date + tag + status
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          // Date
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.access_time_rounded,
                                  size: 12, color: subColor),
                              const SizedBox(width: 3),
                              Text(
                                event.isAllDay
                                    ? CalendarDateUtils.formatDisplayDate(
                                        event.startDate)
                                    : CalendarDateUtils.formatDisplayDateTime(
                                        event.startDate),
                                style: TextStyle(fontSize: 12, color: subColor),
                              ),
                            ],
                          ),
                          // Category tag
                          if (firstCategory != null)
                            _buildTagChip(firstCategory),
                          // Status
                          if (event.status != null && event.status!.isNotEmpty)
                            _buildStatusChip(event, isDark),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTagChip(TagModel tag) {
    final color = AppColors.fromHex(tag.colorHex);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        tag.name,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildStatusChip(EventModel event, bool isDark) {
    final statusColor = _getStatusColor(event.status!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: isDark ? 0.18 : 0.1),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: statusColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            event.status!,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    final s = status.toLowerCase();
    if (s.contains('terminé') || s.contains('done') || s.contains('fini')) {
      return const Color(0xFF34C759);
    }
    if (s.contains('cours') || s.contains('progress')) {
      return const Color(0xFF007AFF);
    }
    if (s.contains('attente') || s.contains('wait') || s.contains('pause')) {
      return const Color(0xFFFF9500);
    }
    if (s.contains('annulé') || s.contains('cancel')) {
      return const Color(0xFFFF3B30);
    }
    return const Color(0xFF8E8E93);
  }

  Widget _buildSourceIcon(EventModel event, bool isDark) {
    if (event.isFromIcs) {
      return Icon(Icons.event_outlined,
          size: 14,
          color: isDark ? const Color(0xFF6B6B6B) : const Color(0xFF9B9A97));
    }
    final isIk = event.isFromInfomaniak;
    final color = isIk
        ? const Color(0xFF0098FF)
        : (isDark ? const Color(0xFF9B9A97) : const Color(0xFF5856D6));
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Text(
        isIk ? 'ik' : 'N',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isStart}) async {
    final date = await showDatePicker(
      context: context,
      initialDate: (isStart ? _startDate : _endDate) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      locale: const Locale('fr', 'FR'),
    );

    if (date != null) {
      setState(() {
        if (isStart) {
          _startDate = date;
        } else {
          _endDate = date;
        }
      });
    }
  }

  void _clearFilters() {
    setState(() {
      _selectedTags.clear();
      _startDate = null;
      _endDate = null;
      _participantEmail = null;
    });
  }
}
