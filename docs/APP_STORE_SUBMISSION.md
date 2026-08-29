# SafeBiteAI App Store Submission Pack

## Release Recommendation

Do not upload the existing build `1.0.0 (2)`. Its archive and IPA were created
before the latest recall-notification, branding and iPhone-only changes. Finish
the blockers below, then create a clean release using build number `3` or later.

## Release Blockers

1. Add in-app Firebase account deletion. Apple requires apps that support
   account creation to let users initiate deletion inside the app. SafeBiteAI
   currently supports Google and Apple account creation but only provides sign
   out.
2. Publish and verify these public pages without redirects or 404 responses:
   - `https://safebiteai.co.uk/privacy`
   - `https://safebiteai.co.uk/support`
3. Point `safebiteai.co.uk` at the deployed Firebase Hosting site and add the
   domain to Firebase Authentication's authorised domains.
4. Confirm rights and attribution requirements for Open Food Facts, FatSecret,
   Food Standards Agency data and Google Places photos.
5. Complete a fresh iPhone release QA pass and build `1.0.0 (3)` or later.

## App Record

| Field | Value |
| --- | --- |
| App name | `SafeBiteAI` |
| Bundle ID | `com.necsca.safebitesapp` |
| SKU | `SAFEBITEAI-IOS-001` |
| Primary language | English (UK) |
| Version | `1.0.0` |
| Next build | `3` or later |
| Platform | iPhone only |
| Minimum iOS | iOS 15.5 |
| Primary category | Food & Drink |
| Secondary category | Lifestyle |
| Price | Free |
| Initial availability | United Kingdom |
| Copyright | `2026 NECSCA LTD` |
| Privacy policy | `https://safebiteai.co.uk/privacy` |
| Support URL | `https://safebiteai.co.uk/support` |
| Marketing URL | `https://safebiteai.co.uk/` |
| Support email | `support@safebiteai.co.uk` |
| Release method | Manual release after approval |

The Firebase project ID remains `safebites-4a21a`. It is an infrastructure
identifier and must not be renamed as part of the public branding change.

## Store Listing

### Name

`SafeBiteAI`

### Subtitle

`Food allergy & recall alerts`

### Promotional Text

`Scan barcodes and ingredient labels, check household allergens, receive selected-store recall alerts, and explore nearby official hygiene ratings.`

### Keywords

`allergy,allergen,barcode,scanner,recall,ingredients,hygiene,supermarket,family,food safety`

### Description

SafeBiteAI helps UK households make better-informed food choices before buying
or eating a product.

Create family profiles with allergy and intolerance preferences, then scan a
food barcode to compare available product information with the household's
needs. SafeBiteAI can also read a current ingredient label from the camera or a
photo when online product information is incomplete.

KEY FEATURES

• Scan packaged-food barcodes

• Check listed allergens and “may contain” warnings

• Create profiles for you, your partner and family members

• Read ingredient labels using on-device text recognition

• Discover verified alternatives, with optional AI-assisted ranking

• Receive recall notifications only for supermarkets you select

• Review official UK food recall notices and affected batch information

• Explore nearby food-business hygiene ratings

• Use previously downloaded product information when connectivity is limited

SAFE, TRANSPARENT RESULTS

SafeBiteAI checks deterministic allergen rules before any optional AI ranking
is used. Household names, allergen profiles and location remain on the device.
Recall matching stores only an app installation token and selected retailer
identifiers in Firebase.

IMPORTANT

SafeBiteAI is an informational aid, not medical advice. Product databases can
be incomplete or outdated. Recipes, ingredients and manufacturing processes can
change. Always read the current package label, check the affected batch or date
on official recall notices, and contact the manufacturer or a qualified
healthcare professional when uncertain.

Product information is provided by Open Food Facts, with an optional live
fallback where configured. Food hygiene ratings and recall notices come from
the UK Food Standards Agency.

Privacy policy: https://safebiteai.co.uk/privacy

Support: support@safebiteai.co.uk

## TestFlight Information

### Beta Description

`SafeBiteAI is a UK food-safety companion for household allergen checks, barcode and ingredient-label scanning, selected-supermarket recall notifications, product alternatives and nearby official food hygiene ratings.`

### What to Test

1. Complete the introduction and grant notification and location access.
2. Continue as guest or sign in with Google or Apple.
3. Add household members and allergen preferences.
4. Select supermarkets and adjust the nearby-store radius.
5. Scan several UK food barcodes, including a product with an allergen conflict.
6. Scan an ingredient label when online ingredients are unavailable.
7. Request product alternatives and verify excluded allergens remain excluded.
8. Check nearby hygiene ratings, business photos and directions.
9. Receive a recall push and verify the app-icon badge, Alerts-tab badge and
   unread styling; open the alert and verify the indicators reset.
10. Disable internet access and re-check a previously downloaded product.
11. Sign out and, once implemented, delete the Firebase account in the app.

### Feedback Email

`support@safebiteai.co.uk`

### Test Notes

- Use real packaged-food barcodes where possible.
- Product coverage varies because Open Food Facts is community maintained.
- Recall notifications are filtered to supermarkets selected in the Family tab.
- AI ranking is optional and runs only after deterministic allergen filtering.
- Never treat a test result as medical advice; always verify the physical label.

## App Review Notes

SafeBiteAI helps UK households compare packaged-food information with locally
stored household allergen preferences. Camera access is used for barcode and
ingredient-label scanning. Photo-library access is used only when the user
selects a label image. Location is requested only for nearby food businesses,
hygiene ratings and stores; the app does not track location in the background.

Product data comes from Open Food Facts, with an optional live fallback where
configured. Hygiene ratings and recall notices come from the UK Food Standards
Agency. Google Places supplies a public venue photo when available. Recall
notifications are delivered only for retailers selected by the user.

The app checks allergen conflicts locally before optional AI alternative
ranking. SafeBiteAI is an informational aid and does not replace current package
labels, official recall batch details, manufacturer guidance or medical advice.

The reviewer can use guest mode for the main flows. Provide a dedicated review
account only if Apple requests authenticated fallback or AI testing. Do not use
real household or health information in review credentials.

## App Privacy Questionnaire

Review the final production SDK behaviour before submission. Based on the
current implementation, declare at least:

| Data type | Linked to user | Tracking | Purpose |
| --- | --- | --- | --- |
| Name | Yes | No | App functionality and authentication |
| Email address | Yes | No | App functionality and authentication |
| User ID | Yes | No | App functionality and authentication |
| Device ID | No | No | App functionality and recall delivery |
| Precise location | No | No | App functionality |

Also disclose data collected by every third-party SDK included in the submitted
binary. SafeBiteAI does not currently use advertising, cross-app tracking,
Firebase Analytics or Crashlytics. Household names, allergen choices, product
history and location are not uploaded for recall matching.

## Compliance Answers

- Export compliance: the app declares `ITSAppUsesNonExemptEncryption = false`.
- Advertising identifier: not used.
- App Tracking Transparency: not used.
- Regulated medical device: No, provided the app remains an informational food
  aid and makes no diagnosis or treatment claims.
- Age rating: complete Apple's current questionnaire truthfully. The app has no
  user-generated content, gambling, violence, sexual content or unrestricted
  web browser. Describe allergen information as informational health content.
- EU Digital Services Act: NECSCA LTD should declare trader status if the app is
  distributed in the EU and provide the required verified contact information.
- Sign in with Apple: enabled because Google sign-in is offered.
- Account deletion: must be available inside the app before review.

## Screenshot Plan

The app is configured for iPhone only, so no iPad screenshots are required.
Upload 6–8 portrait screenshots using a current accepted iPhone screenshot size.

1. Home — “Know what is in your food”
2. Barcode scanner — “Scan before you buy”
3. Allergen result — “Check your whole household”
4. Alternatives — “Find a better match”
5. Recall alerts — “Only the stores you choose”
6. Hygiene search — “Official nearby ratings”
7. Family profiles — “One app for your household”
8. Offline support — “Recheck saved products anywhere”

Do not place unverified safety claims such as “100% safe” in screenshots.

## Release QA

- Test a fresh install on a physical iPhone.
- Verify portrait-only orientation.
- Verify the SafeBiteAI name, new logo, launch image and app icon.
- Verify Google and Apple sign-in plus sign out.
- Verify in-app account deletion after implementation.
- Deny and later enable camera, photos, location and notification permissions.
- Test valid, missing, non-food and ingredient-incomplete barcodes.
- Confirm scanner loading stops after every result or error.
- Test label OCR from camera and photo library.
- Test alternative ranking and deterministic fallback.
- Test selected-store recall delivery in foreground, background and terminated
  states.
- Verify app-icon, Alerts-tab and unread-message badges reset correctly.
- Verify nearby hygiene search by GPS, postcode and business name.
- Verify venue photo fallback and Apple/Google Maps directions.
- Verify offline lookup after a successful online product check.
- Verify privacy and support URLs on mobile data and Wi-Fi.
- Run Flutter tests and static analysis.
- Archive with Release configuration and production entitlements.

## Build and Upload

1. Confirm App Store distribution signing in Xcode for team `Y89LU2A58Y`.
2. Increment the build number in `pubspec.yaml` to at least `1.0.0+3`.
3. From the project root, run:

   ```bash
   flutter clean
   flutter pub get
   cd ios && env -u GEM_HOME -u GEM_PATH pod install --repo-update && cd ..
   flutter test
   flutter analyze
   env -u GEM_HOME -u GEM_PATH flutter build ipa --release \
     --build-name 1.0.0 \
     --build-number 3 \
     --export-options-plist=ios/ExportOptions.plist
   ```

4. Open the new `.ipa` in Apple Transporter and choose **Deliver**, or open
   `ios/Runner.xcworkspace` in Xcode and use **Product > Archive > Distribute
   App > App Store Connect > Upload**.
5. Wait for App Store Connect processing and resolve any compliance prompts.

## TestFlight Rollout

1. Add the processed build to an internal group first.
2. Test on at least two physical iPhones and supported iOS versions.
3. Fix any crash, permission, auth, notification or scanner issue and upload a
   higher build number.
4. Add the build to an external group with the beta description, What to Test,
   feedback email and compliance answers.
5. Submit the first external build for Beta App Review.
6. Run a short external beta before selecting the build for App Review.

## App Store Submission

1. Create version `1.0.0` in App Store Connect.
2. Paste the listing metadata and upload final screenshots.
3. Complete App Privacy, age rating, content rights, export compliance, DSA
   trader status, availability and pricing.
4. Add App Review contact details and any requested test credentials.
5. Select the final tested build.
6. Choose manual release and submit for review.
7. After approval, verify production authentication, notifications, Cloud
   Functions, privacy/support pages and recall delivery before releasing.

## Official Apple References

- [Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/)
- [TestFlight overview](https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/)
- [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information/)
- [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information/)
- [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/)
- [Manage app privacy](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy/)
- [Set an age rating](https://developer.apple.com/help/app-store-connect/manage-app-information/set-an-app-age-rating/)
- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [EU DSA trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/)
