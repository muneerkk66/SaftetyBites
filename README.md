# SafeBite

SafeBite is a Flutter app for family allergen checks and UK food recall protection. The same project targets iOS, Android, and web.

## Included MVP

- White and green responsive design system
- Postcode or GPS-assisted onboarding
- Preferred supermarket selection
- Family profiles with UK-regulated allergen preferences
- Barcode scanning on mobile and web
- Live barcode lookup through Open Food Facts
- Camera OCR for current ingredient labels on iOS and Android
- Manual ingredient entry fallback on web
- Separate `contains` and `may contain` safety states
- Recall dashboard ready for a production FSA alert backend
- Local profile persistence

## Run

```bash
flutter pub get
flutter run
```

Web:

```bash
flutter run -d chrome
```

## Validate

```bash
flutter analyze
flutter test
flutter build web
flutter build ios --simulator --no-codesign
flutter build appbundle
```

## Web deployment

The `main` branch is deployed to Firebase Hosting after GitHub Actions successfully runs analysis, tests, and a release web build. The workflow authenticates with the encrypted repository secret `FIREBASE_SERVICE_ACCOUNT_SAFEBITES_4A21A`; never commit the service-account JSON file.

If CocoaPods is affected by conflicting user Ruby paths on macOS, run Flutter with `GEM_HOME` and `GEM_PATH` unset for that command.

## Data and Safety

Open Food Facts is community-maintained and may be incomplete or outdated. SafeBite therefore asks users to check the current package label and never describes a product as guaranteed safe.

The recall screen is currently the client-side product experience. Production recall notifications require a backend that polls the FSA Food Alerts API, normalises retailer and batch information, matches relevant households, and sends APNs/FCM notifications.
