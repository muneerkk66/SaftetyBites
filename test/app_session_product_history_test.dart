import 'package:flutter_test/flutter_test.dart';
import 'package:safebite/core/app_session.dart';
import 'package:safebite/models/product.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('persists recently checked products in newest-first order', () async {
    SharedPreferences.setMockInitialValues({});
    final session = await AppSession.load();

    session.saveCheckedProduct(_product('111', 'First product'));
    session.saveCheckedProduct(_product('222', 'Second product'));
    await Future<void>.delayed(Duration.zero);

    final restored = await AppSession.load();
    expect(restored.recentlyChecked.map((product) => product.barcode), [
      '222',
      '111',
    ]);
  });

  test('keeps the latest product when a barcode is checked again', () async {
    SharedPreferences.setMockInitialValues({});
    final session = await AppSession.load();

    session.saveCheckedProduct(_product('111', 'Old name'));
    session.saveCheckedProduct(_product('111', 'Updated name'));
    await Future<void>.delayed(Duration.zero);

    final restored = await AppSession.load();
    expect(restored.recentlyChecked, hasLength(1));
    expect(restored.recentlyChecked.single.name, 'Updated name');
  });
}

ProductInfo _product(String barcode, String name) {
  return ProductInfo(
    barcode: barcode,
    name: name,
    brand: 'Test brand',
    ingredients: 'Milk',
    allergenIds: const {'milk'},
    traceAllergenIds: const {},
    imageUrl: 'https://example.com/$barcode.png',
  );
}
