import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:safebite/models/allergen.dart';
import 'package:safebite/widgets/allergen_selector.dart';

void main() {
  testWidgets('search tolerates a small spelling mistake', (tester) async {
    var selected = <String>{};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => AllergenSelector(
              selectedIds: selected,
              onChanged: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('View all or search'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'lactos',
    );
    await tester.pumpAndSettle();

    expect(find.text('Lactose'), findsOneWidget);
  });

  testWidgets('adds a custom ingredient from search', (tester) async {
    var selected = <String>{};
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) => AllergenSelector(
              selectedIds: selected,
              onChanged: (value) => setState(() => selected = value),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('View all or search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Buckwheat');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add “Buckwheat”'));
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(selected, contains(Allergens.customId('Buckwheat')));
    expect(find.text('Buckwheat'), findsOneWidget);
  });
}
