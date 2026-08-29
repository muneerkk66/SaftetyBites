import 'package:flutter/material.dart';

import '../../core/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const publicUrl = 'https://safebiteai.co.uk/privacy';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy policy')),
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.page),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 42),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: AppGradients.primary,
                borderRadius: BorderRadius.circular(26),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.privacy_tip_outlined,
                      color: AppColors.acid, size: 34),
                  const SizedBox(height: 14),
                  Text(
                    'Your household data stays close to you.',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'SafeBiteAI uses the minimum information needed for family allergen checks, recalls and nearby hygiene searches.',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _PolicyNotice(),
            const _PolicySection(
              title: 'Who we are',
              body:
                  'SafeBiteAI is operated by NECSCA LTD. For privacy questions, requests or complaints, contact support@safebiteai.co.uk. NECSCA LTD is the data controller for account information and service requests we receive.',
            ),
            const _PolicySection(
              title: 'Information you choose to provide',
              body:
                  'Account information may include your email address, display name and Firebase user identifier. Household profiles may include a name or nickname, relationship and selected allergies or intolerances. Allergy information can be health data. Only add another person when you have their permission or authority to do so.',
            ),
            const _PolicySection(
              title: 'Information stored on your device',
              body:
                  'Household profiles, allergy choices, postcode, coordinates, selected stores, search radius and eligible Open Food Facts product records are stored locally on your phone or in browser storage. Household and allergy information is not synchronised to a SafeBiteAI database. Your operating-system backup may include local app information according to your device and backup settings. You can remove profiles in the Family tab or remove local information by resetting or uninstalling the app and clearing website storage.',
            ),
            const _PolicySection(
              title: 'Location and nearby searches',
              body:
                  'Location is requested only when you choose nearby features. Your device supplies coordinates, which may be precise, and may use Apple or Google location and geocoding services. Coordinates and search radius are sent to the Food Standards Agency hygiene-rating API to find nearby businesses. A postcode you enter is sent to Postcodes.io to obtain coordinates. SafeBiteAI sends a nearby business name, address and coordinates through Firebase to Google Places to display its public venue photo. When you request directions, SafeBiteAI opens the business address or coordinates in Google Maps or Apple Maps. SafeBiteAI does not continuously track your location.',
            ),
            const _PolicySection(
              title: 'Recall notifications',
              body:
                  'If you enable notifications, Firebase Cloud Messaging assigns the app installation a messaging token. SafeBiteAI stores that token, a random installation identifier and the supermarket identifiers you select in Firebase so recalls can be sent directly to matching devices. SafeBiteAI does not upload family names, allergen choices, scanned products or location for notification matching. Invalid messaging tokens are removed when Firebase reports that they can no longer receive messages. You can disable notifications in your device settings.',
            ),
            const _PolicySection(
              title: 'Barcode and label checks',
              body:
                  'SafeBiteAI checks its on-device catalogue first. If a product is not available locally, the barcode is sent to Open Food Facts. Open Food Facts results may be stored on your device for later offline use. If Open Food Facts has no result, signed-in users may request a live FatSecret lookup through Firebase. FatSecret product details are not added to SafeBiteAI’s database or local catalogue. If no provider has a result, SafeBiteAI records the barcode, scan count and review status in Firebase for manual product research; it does not attach household or allergy information. Ingredient-label photographs are processed on your device and are not uploaded by SafeBiteAI.',
            ),
            const _PolicySection(
              title: 'AI alternative ranking',
              body:
                  'Your device first removes alternatives with household allergen or trace conflicts. If you request AI ranking while signed in, only product details from that filtered shortlist are sent through an authenticated Firebase Cloud Function to the OpenAI API. Family names, allergy choices and location are not sent to OpenAI. The request uses store=false. OpenAI may retain API abuse-monitoring logs for up to 30 days under its applicable controls.',
            ),
            const _PolicySection(
              title: 'Why we use information',
              body:
                  'We use information to provide the features you request, authenticate accounts, prevent abuse, remember local preferences and respond to support or privacy requests. For account and requested service processing, our UK GDPR basis is performance of our service contract. Where allergy information is processed, we ask for explicit consent because it may be special-category health data. You may withdraw that consent by deleting the relevant profile or resetting the app.',
            ),
            const _PolicySection(
              title: 'Service providers and data sources',
              body:
                  'Firebase Authentication, Cloud Functions, Cloud Firestore, Cloud Messaging and the missing-barcode review queue are provided by Google. Apple provides Sign in with Apple and APNs notification delivery when you choose those options. Product data and images come from Open Food Facts, with FatSecret used as a live fallback where configured. Hygiene ratings and food alerts come from the UK Food Standards Agency. Google Places supplies food-business photos. Postcode coordinates come from Postcodes.io. AI ranking is provided by OpenAI. These providers may receive network information such as your IP address and apply their own security, retention and international-transfer arrangements.',
            ),
            const _PolicySection(
              title: 'International transfers',
              body:
                  'Some providers, including Firebase and OpenAI, may process personal data outside the UK, including in the United States. Where UK data-protection law restricts a transfer, we rely on the provider’s applicable safeguards, such as an adequacy decision, the UK International Data Transfer Addendum or approved contractual clauses. Contact us for more information about the safeguards relevant to your data.',
            ),
            const _PolicySection(
              title: 'Automated processing',
              body:
                  'SafeBiteAI uses rules to flag possible allergen conflicts and may use AI to rank product alternatives. These results are informational suggestions only. They do not make decisions that produce legal or similarly significant effects, and you remain in control of every purchase and safety decision.',
            ),
            const _PolicySection(
              title: 'Retention',
              body:
                  'Local information remains until you delete profiles, reset the app, clear browser storage or uninstall. SafeBiteAI retains missing barcodes until they are researched, resolved or no longer needed for catalogue improvement. Live FatSecret product responses are not retained by SafeBiteAI. Recall installation records are updated while notifications remain enabled and invalid tokens are deleted when detected. Firebase account information remains while your account is active and for a limited period where needed for security, legal obligations or dispute handling. Contact us to request account deletion.',
            ),
            const _PolicySection(
              title: 'Your rights',
              body:
                  'Depending on the circumstances, UK data-protection law may give you rights to access, correct, erase, restrict, object to processing and receive portable copies of personal data, and to withdraw consent. Contact support@safebiteai.co.uk to exercise a right. You may also complain to the UK Information Commissioner’s Office at ico.org.uk.',
            ),
            const _PolicySection(
              title: 'Children and family profiles',
              body:
                  'SafeBiteAI is designed for an adult account holder to manage household profiles. We do not ask for children’s dates of birth, addresses or medical records. Use a nickname where possible and only enter information you are authorised to manage.',
            ),
            const _PolicySection(
              title: 'Security and important limitations',
              body:
                  'We use platform security controls and authenticated Firebase services, but no system can guarantee absolute security. SafeBiteAI is an informational aid, not medical advice, and does not guarantee that a product or venue is safe. Always check current labels and speak to qualified professionals about allergy management.',
            ),
            const _PolicySection(
              title: 'Changes to this policy',
              body:
                  'We will update this policy when SafeBiteAI’s features or data practices change and will show the new effective date. Material changes will be brought to users’ attention before the new processing begins.',
            ),
            const SizedBox(height: 12),
            Text('Effective: 29 August 2026',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            const SelectableText(
              publicUrl,
              style: TextStyle(
                color: AppColors.green,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PolicyNotice extends StatelessWidget {
  const _PolicyNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: BorderRadius.circular(18),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.gavel_outlined, color: AppColors.warning),
          SizedBox(width: 11),
          Expanded(
            child: Text(
              'This policy describes SafeBiteAI’s current features. We will review and update it whenever cloud sync, analytics, advertising, payments or marketing are added.',
              style: TextStyle(color: AppColors.ink, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 7),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
