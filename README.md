# SafeBiteAI

SafeBiteAI is a Flutter app for family allergen checks and UK food recall protection. The same project targets iOS, Android, and web.

## Included MVP

- White and green responsive design system
- GPS-first onboarding with automatic nearby-store discovery
- User-selected supermarkets with no default selections
- Editable 5, 10, 15, or 20-mile supermarket search radius
- Family-tab supermarket management for adding or removing brands
- Family profiles with UK-regulated allergen preferences
- Barcode scanning on mobile and web
- Official UK food hygiene ratings loaded automatically from GPS
- Optional restaurant-name filtering within five miles
- Postcode area updates through the Postcodes.io lookup service
- Offline-first SQLite product catalogue on iOS and Android
- Open Food Facts lookup and local caching when an offline product is missing
- Optional live FatSecret fallback through authenticated Firebase Functions
- Missing-barcode review queue that stores no household or allergy data
- Camera OCR for current ingredient labels on iOS and Android
- Manual ingredient entry fallback on web
- Separate `contains` and `may contain` safety states
- Rule-filtered alternative products with optional AI ranking and explanations
- Live FSA recall feed with scheduled Firebase notifications
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

## AI alternative ranking

SafeBiteAI always removes products with listed household allergens or trace
warnings before AI is called. The Firebase callable function then uses
`gpt-5.6-luna` to rank the already-filtered shortlist and produce concise
similarity explanations. If the function is unavailable, the app shows the
deterministically ranked shortlist instead.

The OpenAI key is stored in Firebase Secret Manager and must never be added to
Flutter source or a Dart define:

```bash
firebase functions:secrets:set OPENAI_API_KEY
firebase deploy --only functions:ai-ranking
```

Cloud Functions deployment requires the Firebase project to use the Blaze
plan. Signed-out users receive rule-filtered recommendations without an AI
request. For production, enable Firebase App Check before allowing broader
traffic.

The household allergen filter runs on the user's device. Only product details
from the already-filtered shortlist are sent to the ranking function; family
names, allergy choices and location are not sent to OpenAI.

## Food business photos

Hygiene results come from the Food Standards Agency. SafeBiteAI enriches each
result with one public Google Places photo through an authenticated Firebase
Function, keeping the Places key out of the Flutter app. Enable Places API
(New), create a restricted server key, then configure and deploy the function:

```bash
firebase functions:secrets:set GOOGLE_PLACES_API_KEY
firebase deploy --only functions:venue-photos
```

If Google has no matching photo or the service is unavailable, the card shows
the SafeBiteAI restaurant artwork instead of a separate photo button.

## UK food recalls

The `food-recalls` Firebase codebase polls the free Food Standards Agency Food
Alerts API every 15 minutes and imports Allergy Alerts, Product Recall
Information Notices and Food Alerts for Action. The first import does not send
notifications, preventing historical alerts from being pushed to users.

Mobile users can enable Firebase Cloud Messaging in the Alerts tab. SafeBiteAI
registers each installation's messaging token and selected retailer identifiers
with Firebase. The scheduled function sends new alerts directly to matching
device tokens; family names, specific allergens, product history and location
remain on the device. Deploy the backend with:

```bash
firebase deploy --only functions:food-recalls
```

An Apple APNs authentication key must be uploaded in Firebase Console before
iOS production notifications can be delivered. The scheduler job is normally
covered by Google Cloud Scheduler's three-job allowance; FCM has no usage fee,
and normal early-stage alert storage is far below Firestore's free daily quota.

## Offline product catalogue

Product checks use this order:

1. On-device SQLite catalogue on iOS and Android, or the smaller browser cache.
2. Open Food Facts API; successful results are saved locally.
3. FatSecret barcode lookup through Firebase for signed-in users.
4. A Firebase `missing_products` record containing only the unresolved barcode,
   timestamps, status and scan count.

FatSecret results are displayed live and are never written to the app catalogue.
Set the two provider secrets and deploy the lookup functions:

```bash
firebase functions:secrets:set FATSECRET_CLIENT_ID
firebase functions:secrets:set FATSECRET_CLIENT_SECRET
firebase deploy --only functions:product-api
```

To produce a compressed UK Open Food Facts pack from the official CSV export:

```bash
python3 scripts/build_offline_catalog.py \
  --input /path/to/en.openfoodfacts.org.products.csv.gz \
  --output-dir dist/catalog \
  --version 2026-08-25 \
  --base-url https://your-catalog-host.example/catalog
```

The builder keeps only products with usable ingredient, allergen or trace
evidence. It stores the product identity, full ingredient text, mapped household
allergens, one specific category, ranking signals and a small image URL. Records
without safety evidence are left to the online provider chain instead of taking
up device storage without supporting an offline decision.

Publish `manifest.json` and the generated `.jsonl.gz` file under
`https://safebites-4a21a.web.app/catalog/`. The mobile app checks this manifest
silently on startup and resume, throttled to once per 24 hours. A different
catalogue host can be selected at build time:

```bash
flutter build ios \
  --dart-define=OFFLINE_CATALOG_MANIFEST_URL=https://your-catalog-host.example/catalog/manifest.json
```

Firebase Hosting runs `scripts/stage_offline_catalog.sh` before every deploy.
The script stages `dist/catalog` when a new pack has been built, otherwise it
preserves the currently published pack. Deployment fails rather than removing
the catalogue when neither source is valid.

## Web deployment

The `main` branch is deployed to Firebase Hosting after GitHub Actions successfully runs analysis, tests, and a release web build. The workflow authenticates with the encrypted repository secret `FIREBASE_SERVICE_ACCOUNT_SAFEBITES_4A21A`; never commit the service-account JSON file.

If CocoaPods is affected by conflicting user Ruby paths on macOS, run Flutter with `GEM_HOME` and `GEM_PATH` unset for that command.

## Store release

The production privacy policy URL is
<https://safebiteai.co.uk/privacy>. The iOS App Store privacy,
review and upload checklist is in `docs/APP_STORE_SUBMISSION.md`.

Android release builds require a private `android/key.properties` file and
upload keystore. Use `android/key.properties.example` as the template; never
commit either secret file. The public upload certificate can be registered
with Google Play and Firebase when Android publishing resumes.

## Data and Safety

Open Food Facts is community-maintained and may be incomplete or outdated. SafeBiteAI therefore asks users to check the current package label and never describes a product as guaranteed safe.

The recall feed is informational and depends on the FSA's published data.
Always follow the linked official notice and the product's identifying batch or
date information.
