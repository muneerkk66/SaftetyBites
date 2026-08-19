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
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: Allergens.options.map((allergen) {
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
          side: BorderSide(color: selected ? AppColors.green : AppColors.line),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 11,
            vertical: compact ? 7 : 10,
          ),
          onSelected: (_) {
            final next = Set<String>.from(selectedIds);
            selected ? next.remove(allergen.id) : next.add(allergen.id);
            onChanged(next);
          },
        );
      }).toList(),
    );
  }
}
