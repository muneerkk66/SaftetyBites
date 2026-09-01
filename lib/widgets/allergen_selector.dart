import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/allergen.dart';

class AllergenSelector extends StatelessWidget {
  const AllergenSelector({
    super.key,
    required this.selectedIds,
    required this.onChanged,
    this.compact = false,
  });

  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final displayed = <AllergenOption>[
      ...Allergens.featuredOptions,
      ...selectedIds
          .where((id) => !Allergens.featuredOptions.any(
                (option) => option.id == id,
              ))
          .map(Allergens.byId),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: displayed.map((allergen) {
            final selected = selectedIds.contains(allergen.id);
            return FilterChip(
              selected: selected,
              showCheckmark: false,
              avatar: Icon(
                allergen.icon,
                size: compact ? 17 : 19,
                color: selected ? Colors.white : AppColors.greenDark,
              ),
              label: Text(allergen.label),
              labelStyle: TextStyle(
                color: selected ? Colors.white : AppColors.ink,
                fontSize: compact ? 13 : 14,
                fontWeight: FontWeight.w700,
              ),
              selectedColor: AppColors.green,
              backgroundColor: Colors.white,
              side: BorderSide(
                color: selected ? AppColors.green : AppColors.line,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 11,
                vertical: compact ? 7 : 10,
              ),
              onSelected: (_) => _toggle(allergen.id),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _openPicker(context),
          icon: const Icon(Icons.search_rounded),
          label: const Text('View all or search'),
        ),
      ],
    );
  }

  void _toggle(String id) {
    final next = Set<String>.from(selectedIds);
    next.contains(id) ? next.remove(id) : next.add(id);
    onChanged(next);
  }

  Future<void> _openPicker(BuildContext context) async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => _AllergenPickerSheet(selectedIds: selectedIds),
    );
    if (result != null) onChanged(result);
  }
}

class _AllergenPickerSheet extends StatefulWidget {
  const _AllergenPickerSheet({required this.selectedIds});

  final Set<String> selectedIds;

  @override
  State<_AllergenPickerSheet> createState() => _AllergenPickerSheetState();
}

class _AllergenPickerSheetState extends State<_AllergenPickerSheet> {
  late final TextEditingController _searchController;
  late Set<String> _selectedIds;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _selectedIds = Set<String>.from(widget.selectedIds);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = Allergens.options
        .where((option) => _matches(option, _query))
        .toList(growable: false);

    return FractionallySizedBox(
      heightFactor: 0.88,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          12,
          20,
          16 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.line,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Allergies and intolerances',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _selectedIds),
                  child: const Text('Done'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                hintText: 'Search allergy or intolerance',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (value) => setState(() => _query = value.trim()),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _query.isEmpty
                  ? ListView(
                      children: [
                        _sectionTitle(context, 'UK regulated allergens'),
                        ...Allergens.regulatedOptions.map(_optionTile),
                        _sectionTitle(context, 'Other common sensitivities'),
                        ...Allergens.additionalOptions.map(_optionTile),
                      ],
                    )
                  : ListView(
                      children: [
                        if (filtered.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Text(
                              'No close match found. Check the spelling or add it as a custom ingredient.',
                              style: TextStyle(color: AppColors.inkSoft),
                            ),
                          ),
                        ...filtered.map(_optionTile),
                        if (_canAddCustom()) _customTile(),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.fromLTRB(8, 18, 8, 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: AppColors.greenDark,
                fontWeight: FontWeight.w800,
              ),
        ),
      );

  Widget _optionTile(AllergenOption option) {
    final selected = _selectedIds.contains(option.id);
    return CheckboxListTile(
      value: selected,
      onChanged: (_) => setState(() {
        selected ? _selectedIds.remove(option.id) : _selectedIds.add(option.id);
      }),
      controlAffinity: ListTileControlAffinity.trailing,
      secondary: CircleAvatar(
        backgroundColor: AppColors.greenSoft,
        foregroundColor: AppColors.greenDark,
        child: Icon(option.icon, size: 20),
      ),
      title: Text(option.label),
      subtitle: Text(
        option.isRegulated ? 'UK regulated allergen' : 'Additional sensitivity',
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }

  Widget _customTile() {
    final customId = Allergens.customId(_query);
    final selected = _selectedIds.contains(customId);
    return ListTile(
      onTap: () => setState(() {
        selected ? _selectedIds.remove(customId) : _selectedIds.add(customId);
      }),
      leading: const CircleAvatar(
        backgroundColor: AppColors.warningSoft,
        foregroundColor: AppColors.warning,
        child: Icon(Icons.edit_outlined, size: 20),
      ),
      title: Text('${selected ? 'Remove' : 'Add'} “$_query”'),
      subtitle: const Text(
        'Custom checks use this exact ingredient wording and may not recognise every synonym.',
      ),
      trailing: Icon(
        selected ? Icons.check_circle_rounded : Icons.add_circle_outline,
        color: AppColors.green,
      ),
    );
  }

  bool _canAddCustom() {
    if (_query.trim().length < 3) return false;
    final normalized = _normalize(_query);
    return !Allergens.options.any(
      (option) => _normalize(option.label) == normalized,
    );
  }

  bool _matches(AllergenOption option, String query) {
    final normalizedQuery = _normalize(query);
    if (normalizedQuery.isEmpty) return true;
    final candidates = [option.label, ...option.terms, ...option.searchAliases]
        .map(_normalize);
    return candidates.any((candidate) {
      if (candidate.contains(normalizedQuery)) {
        return true;
      }
      final tolerance = normalizedQuery.length >= 7 ? 2 : 1;
      return _editDistance(candidate, normalizedQuery) <= tolerance;
    });
  }

  String _normalize(String value) =>
      value.trim().toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  int _editDistance(String first, String second) {
    if (first == second) return 0;
    if (first.isEmpty) return second.length;
    if (second.isEmpty) return first.length;
    var previous = List<int>.generate(second.length + 1, (index) => index);
    for (var row = 1; row <= first.length; row++) {
      final current = List<int>.filled(second.length + 1, 0)..[0] = row;
      for (var column = 1; column <= second.length; column++) {
        final substitution = first[row - 1] == second[column - 1] ? 0 : 1;
        current[column] = [
          current[column - 1] + 1,
          previous[column] + 1,
          previous[column - 1] + substitution,
        ].reduce((left, right) => left < right ? left : right);
      }
      previous = current;
    }
    return previous.last;
  }
}
