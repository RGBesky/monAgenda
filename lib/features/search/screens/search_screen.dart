import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  List<TagModel> _selectedTags = [];
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
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: tags.map((tag) {
                        final isSelected =
                            _selectedTags.any((t) => t.id == tag.id);
                        final color = _colorFromHex(tag.colorHex);
                        return FilterChip(
                          label: Text(tag.name, style: const TextStyle(fontSize: 12)),
                          selected: isSelected,
                          selectedColor: color.withOpacity(0.2),
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
    final categoryColor = firstCategory != null
        ? _colorFromHex(firstCategory.colorHex)
        : Colors.grey;
    final priorityColor = event.priorityTag != null
        ? _colorFromHex(event.priorityTag!.colorHex)
        : Colors.transparent;

    return ListTile(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => EventDetailScreen(event: event),
        ),
      ),
      leading: Container(
        width: 4,
        height: 40,
        decoration: BoxDecoration(
          color: priorityColor,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      title: Text(
        event.title,
        style: const TextStyle(fontWeight: FontWeight.w500),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        event.isAllDay
            ? CalendarDateUtils.formatDisplayDate(event.startDate)
            : CalendarDateUtils.formatDisplayDateTime(event.startDate),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (firstCategory != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: categoryColor.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                firstCategory.name,
                style: TextStyle(
                  color: categoryColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          const SizedBox(width: 4),
          _buildSourceIcon(event),
        ],
      ),
    );
  }

  Widget _buildSourceIcon(EventModel event) {
    if (event.isFromIcs) {
      return const Icon(Icons.calendar_today, size: 16, color: Colors.grey);
    }
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: event.isFromInfomaniak
            ? const Color(0xFF0D6EFD)
            : Colors.black87,
        borderRadius: BorderRadius.circular(event.isFromInfomaniak ? 9 : 3),
      ),
      child: Center(
        child: Text(
          event.isFromInfomaniak ? 'ik' : 'N',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 8,
            fontWeight: FontWeight.bold,
          ),
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

  Color _colorFromHex(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 6 || hex.length == 7) buffer.write('ff');
    buffer.write(hex.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
