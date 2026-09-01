import 'package:flutter/material.dart';

class AllergenOption {
  const AllergenOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.terms,
    this.searchAliases = const [],
    this.isRegulated = true,
    this.isFeatured = false,
  });

  final String id;
  final String label;
  final IconData icon;
  final List<String> terms;
  final List<String> searchAliases;
  final bool isRegulated;
  final bool isFeatured;
}

abstract final class Allergens {
  static const options = <AllergenOption>[
    AllergenOption(
      id: 'peanuts',
      label: 'Peanuts',
      icon: Icons.eco_outlined,
      terms: ['peanut', 'groundnut', 'arachis'],
      isFeatured: true,
    ),
    AllergenOption(
      id: 'tree_nuts',
      label: 'Tree nuts',
      icon: Icons.park_outlined,
      terms: [
        'almond',
        'hazelnut',
        'walnut',
        'cashew',
        'pecan',
        'pistachio',
        'macadamia',
        'brazil nut',
      ],
      isFeatured: true,
    ),
    AllergenOption(
      id: 'milk',
      label: 'Milk',
      icon: Icons.local_drink_outlined,
      terms: ['milk', 'whey', 'casein', 'caseinate', 'butter', 'cream'],
      searchAliases: ['dairy'],
      isFeatured: true,
    ),
    AllergenOption(
      id: 'eggs',
      label: 'Eggs',
      icon: Icons.egg_outlined,
      terms: ['egg', 'albumen', 'ovalbumin'],
      isFeatured: true,
    ),
    AllergenOption(
      id: 'gluten',
      label: 'Cereals with gluten',
      icon: Icons.grass_outlined,
      terms: ['wheat', 'barley', 'rye', 'oats', 'spelt', 'gluten'],
      searchAliases: ['coeliac', 'celiac'],
      isFeatured: true,
    ),
    AllergenOption(
      id: 'soya',
      label: 'Soya',
      icon: Icons.spa_outlined,
      terms: ['soya', 'soy', 'edamame', 'tofu'],
      searchAliases: ['soybean'],
      isFeatured: true,
    ),
    AllergenOption(
      id: 'sesame',
      label: 'Sesame',
      icon: Icons.blur_circular_outlined,
      terms: ['sesame', 'tahini'],
    ),
    AllergenOption(
      id: 'fish',
      label: 'Fish',
      icon: Icons.set_meal_outlined,
      terms: ['fish', 'anchovy', 'salmon', 'tuna', 'cod'],
    ),
    AllergenOption(
      id: 'crustaceans',
      label: 'Crustaceans',
      icon: Icons.water_outlined,
      terms: ['crustacean', 'prawn', 'shrimp', 'crab', 'lobster', 'crayfish'],
      searchAliases: ['shellfish'],
    ),
    AllergenOption(
      id: 'molluscs',
      label: 'Molluscs',
      icon: Icons.water_outlined,
      terms: [
        'mollusc',
        'mussel',
        'oyster',
        'squid',
        'octopus',
        'scallop',
        'clam',
        'snail',
      ],
      searchAliases: ['shellfish'],
    ),
    AllergenOption(
      id: 'mustard',
      label: 'Mustard',
      icon: Icons.grain_outlined,
      terms: ['mustard'],
    ),
    AllergenOption(
      id: 'celery',
      label: 'Celery',
      icon: Icons.energy_savings_leaf_outlined,
      terms: ['celery', 'celeriac'],
    ),
    AllergenOption(
      id: 'lupin',
      label: 'Lupin',
      icon: Icons.local_florist_outlined,
      terms: ['lupin', 'lupine'],
    ),
    AllergenOption(
      id: 'sulphites',
      label: 'Sulphites',
      icon: Icons.bubble_chart_outlined,
      terms: ['sulphite', 'sulfite', 'sulphur dioxide'],
      searchAliases: ['sulfur dioxide'],
    ),
    AllergenOption(
      id: 'lactose',
      label: 'Lactose',
      icon: Icons.local_drink_outlined,
      terms: ['lactose', 'milk sugar'],
      isRegulated: false,
    ),
    AllergenOption(
      id: 'wheat',
      label: 'Wheat',
      icon: Icons.grass_outlined,
      terms: ['wheat', 'durum', 'semolina', 'spelt'],
      isRegulated: false,
    ),
    AllergenOption(
      id: 'coconut',
      label: 'Coconut',
      icon: Icons.park_outlined,
      terms: ['coconut', 'coconut milk', 'coconut oil'],
      isRegulated: false,
    ),
    AllergenOption(
      id: 'maize',
      label: 'Maize or corn',
      icon: Icons.grain_outlined,
      terms: ['maize', 'corn', 'cornflour', 'corn starch', 'cornstarch'],
      isRegulated: false,
    ),
    AllergenOption(
      id: 'kiwi',
      label: 'Kiwi',
      icon: Icons.eco_outlined,
      terms: ['kiwi', 'kiwifruit'],
      isRegulated: false,
    ),
    AllergenOption(
      id: 'legumes',
      label: 'Other legumes',
      icon: Icons.spa_outlined,
      terms: ['pea', 'chickpea', 'lentil', 'bean', 'legume'],
      isRegulated: false,
    ),
    AllergenOption(
      id: 'yeast',
      label: 'Yeast',
      icon: Icons.bubble_chart_outlined,
      terms: ['yeast', 'yeast extract'],
      isRegulated: false,
    ),
  ];

  static List<AllergenOption> get regulatedOptions =>
      options.where((option) => option.isRegulated).toList(growable: false);

  static List<AllergenOption> get additionalOptions =>
      options.where((option) => !option.isRegulated).toList(growable: false);

  static List<AllergenOption> get featuredOptions =>
      options.where((option) => option.isFeatured).toList(growable: false);

  static AllergenOption byId(String id) {
    for (final option in options) {
      if (option.id == id) return option;
    }
    if (id == 'shellfish') {
      return const AllergenOption(
        id: 'shellfish',
        label: 'Shellfish',
        icon: Icons.water_outlined,
        terms: ['crustacean', 'mollusc', 'shellfish'],
      );
    }
    if (isCustomId(id)) {
      final term = customTerm(id);
      return AllergenOption(
        id: id,
        label: _titleCase(term),
        icon: Icons.edit_outlined,
        terms: [term],
        isRegulated: false,
      );
    }
    return AllergenOption(
      id: id,
      label: _titleCase(id.replaceAll('_', ' ')),
      icon: Icons.help_outline_rounded,
      terms: [id.replaceAll('_', ' ')],
      isRegulated: false,
    );
  }

  static bool isCustomId(String id) => id.startsWith('custom:');

  static String customId(String value) {
    final normalized = value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[^a-z0-9 +&-]'), '');
    return 'custom:$normalized';
  }

  static String customTerm(String id) =>
      isCustomId(id) ? id.substring('custom:'.length) : id;

  static Set<String> expandLegacyIds(Iterable<String> ids) {
    final expanded = Set<String>.from(ids);
    if (expanded.remove('shellfish')) {
      expanded.addAll(const {'crustaceans', 'molluscs'});
    }
    return expanded;
  }

  static String _titleCase(String value) => value
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}
