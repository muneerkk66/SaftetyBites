import 'package:flutter/material.dart';

class AllergenOption {
  const AllergenOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.terms,
  });

  final String id;
  final String label;
  final IconData icon;
  final List<String> terms;
}

abstract final class Allergens {
  static const options = <AllergenOption>[
    AllergenOption(
      id: 'peanuts',
      label: 'Peanuts',
      icon: Icons.eco_outlined,
      terms: ['peanut', 'groundnut', 'arachis'],
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
    ),
    AllergenOption(
      id: 'milk',
      label: 'Milk',
      icon: Icons.local_drink_outlined,
      terms: ['milk', 'whey', 'casein', 'caseinate', 'butter', 'cream'],
    ),
    AllergenOption(
      id: 'eggs',
      label: 'Eggs',
      icon: Icons.egg_outlined,
      terms: ['egg', 'albumen', 'ovalbumin'],
    ),
    AllergenOption(
      id: 'gluten',
      label: 'Gluten',
      icon: Icons.grass_outlined,
      terms: ['wheat', 'barley', 'rye', 'oats', 'spelt', 'gluten'],
    ),
    AllergenOption(
      id: 'soya',
      label: 'Soya',
      icon: Icons.spa_outlined,
      terms: ['soya', 'soy', 'edamame', 'tofu'],
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
      id: 'shellfish',
      label: 'Shellfish',
      icon: Icons.water_outlined,
      terms: ['crustacean', 'prawn', 'shrimp', 'crab', 'lobster', 'mollusc'],
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
    ),
  ];

  static AllergenOption byId(String id) =>
      options.firstWhere((option) => option.id == id);
}
