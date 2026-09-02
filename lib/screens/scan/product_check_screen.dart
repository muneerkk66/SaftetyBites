import 'package:flutter/material.dart';

import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../models/allergen.dart';
import '../../models/family_member.dart';
import '../../models/product.dart';
import '../../services/allergen_matcher.dart';
import '../../services/product_alternative_service.dart';
import '../../widgets/member_avatar.dart';

class ProductCheckScreen extends StatefulWidget {
  const ProductCheckScreen({
    super.key,
    required this.session,
    required this.product,
  });

  final AppSession session;
  final ProductInfo product;

  @override
  State<ProductCheckScreen> createState() => _ProductCheckScreenState();
}

class _ProductCheckScreenState extends State<ProductCheckScreen> {
  final _alternativeService = ProductAlternativeService();
  late ProductInfo _product;
  bool _findingAlternatives = false;
  AlternativeSearchResult? _alternativeResult;
  String? _alternativeError;

  @override
  void initState() {
    super.initState();
    _product = widget.product;
  }

  @override
  Widget build(BuildContext context) {
    final assessments = widget.session.family
        .map((member) => AllergenMatcher.assess(_product, member))
        .toList();
    final overall = _overallLevel(assessments);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Product check'),
        actions: [
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 19),
            label: const Text('Scan again'),
          ),
          IconButton(
            tooltip: 'Important information',
            onPressed: _showSafetyNotice,
            icon: const Icon(Icons.info_outline_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 34),
        children: [
          _ProductHeader(product: _product),
          const SizedBox(height: 18),
          _OverallResult(level: overall),
          if (overall == MatchLevel.avoid || overall == MatchLevel.caution) ...[
            const SizedBox(height: 16),
            _AlternativeFinder(
              result: _alternativeResult,
              loading: _findingAlternatives,
              error: _alternativeError,
              onFind: _findAlternatives,
              onOpen: _openAlternative,
            ),
          ],
          const SizedBox(height: 25),
          Row(
            children: [
              Text('Family results',
                  style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              Text(
                '${widget.session.family.length} checked',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.green,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...widget.session.family.map((member) {
            final assessment =
                assessments.firstWhere((item) => item.memberId == member.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MemberResultCard(member: member, assessment: assessment),
            );
          }),
          const SizedBox(height: 24),
          _DataSourceCard(product: _product),
        ],
      ),
    );
  }

  Future<void> _findAlternatives() async {
    setState(() {
      _findingAlternatives = true;
      _alternativeError = null;
    });
    try {
      final result = await _alternativeService.findAlternatives(
        source: _product,
        family: widget.session.family,
      );
      if (!mounted) return;
      setState(() => _alternativeResult = result);
    } on ProductAlternativeException catch (error) {
      if (!mounted) return;
      setState(() => _alternativeError = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _alternativeError =
            'Alternatives are unavailable right now. Please try again shortly.';
      });
    } finally {
      if (mounted) setState(() => _findingAlternatives = false);
    }
  }

  Future<void> _openAlternative(ProductInfo product) async {
    widget.session.saveCheckedProduct(product);
    final scanAgain = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            ProductCheckScreen(session: widget.session, product: product),
      ),
    );
    if (scanAgain == true && mounted) Navigator.of(context).pop(true);
  }

  MatchLevel _overallLevel(List<MemberAssessment> assessments) {
    if (assessments.any((item) => item.level == MatchLevel.avoid)) {
      return MatchLevel.avoid;
    }
    if (assessments.any((item) => item.level == MatchLevel.caution)) {
      return MatchLevel.caution;
    }
    if (assessments.any((item) => item.level == MatchLevel.unableToVerify)) {
      return MatchLevel.unableToVerify;
    }
    return MatchLevel.noListedMatch;
  }

  void _showSafetyNotice() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Important'),
        content: const Text(
          'SafeBiteAI checks available product data and visible label text. It cannot guarantee that a food is safe. Always verify the current package and follow professional medical advice.',
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('I understand')),
        ],
      ),
    );
  }
}

class _AlternativeFinder extends StatelessWidget {
  const _AlternativeFinder({
    required this.result,
    required this.loading,
    required this.error,
    required this.onFind,
    required this.onOpen,
  });

  final AlternativeSearchResult? result;
  final bool loading;
  final String? error;
  final VoidCallback onFind;
  final ValueChanged<ProductInfo> onOpen;

  @override
  Widget build(BuildContext context) {
    final recommendations = result?.recommendations ?? const [];
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppGradients.primarySoft,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.aqua),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(
                  color: AppColors.greenDark,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: AppColors.acid, size: 23),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Find a better alternative',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(
                      'SafeBiteAI first removes products with listed household allergens and traces, then AI ranks the closest matches.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (error != null) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(15),
              ),
              child:
                  Text(error!, style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
          if (recommendations.isEmpty) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: loading ? null : onFind,
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.greenDark,
                      ),
                    )
                  : const Icon(Icons.search_rounded),
              label: Text(loading
                  ? 'Finding alternatives…'
                  : error == null
                      ? 'Find alternatives'
                      : 'Try again'),
            ),
          ] else ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Recommended matches',
                    style: Theme.of(context).textTheme.titleMedium),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: result!.usedAiRanking
                        ? AppColors.greenDark
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    result!.usedAiRanking ? 'AI RANKED' : 'RULE FILTERED',
                    style: TextStyle(
                      color: result!.usedAiRanking
                          ? AppColors.acid
                          : AppColors.green,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ...recommendations.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: _AlternativeCard(
                    recommendation: item,
                    onOpen: () => onOpen(item.product),
                  ),
                )),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: loading ? null : onFind,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Refresh matches'),
              ),
            ),
          ],
          const SizedBox(height: 9),
          Text(
            'AI receives product details only—not family profiles, allergy choices or location. Always verify the latest package before purchase.',
            style:
                Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _AlternativeCard extends StatelessWidget {
  const _AlternativeCard({
    required this.recommendation,
    required this.onOpen,
  });

  final AlternativeRecommendation recommendation;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final product = recommendation.product;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: Container(
                  width: 60,
                  height: 60,
                  color: AppColors.greenSoft,
                  child: product.imageUrl == null
                      ? const Icon(Icons.shopping_bag_outlined,
                          color: AppColors.green)
                      : Image.network(
                          product.imageUrl!,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.shopping_bag_outlined,
                            color: AppColors.green,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(product.brand,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(height: 5),
                    Text(
                      recommendation.reason,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 5),
              const Icon(Icons.chevron_right_rounded, color: AppColors.green),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProductHeader extends StatelessWidget {
  const _ProductHeader({required this.product});

  final ProductInfo product;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Container(
                width: 76,
                height: 76,
                color: AppColors.greenSoft,
                child: product.imageUrl == null
                    ? const Icon(Icons.shopping_bag_outlined,
                        color: AppColors.green, size: 34)
                    : Image.network(
                        product.imageUrl!,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.shopping_bag_outlined,
                          color: AppColors.green,
                          size: 34,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(product.brand,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 7),
                  Text(
                    product.barcode,
                    style: const TextStyle(
                      color: AppColors.inkSoft,
                      fontSize: 12,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OverallResult extends StatelessWidget {
  const _OverallResult({required this.level});

  final MatchLevel level;

  @override
  Widget build(BuildContext context) {
    final config = _ResultConfig.from(level);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: config.background,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration:
                BoxDecoration(color: config.color, shape: BoxShape.circle),
            child: Icon(config.icon, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(config.title,
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 5),
                Text(config.detail,
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MemberResultCard extends StatelessWidget {
  const _MemberResultCard({required this.member, required this.assessment});

  final FamilyMember member;
  final MemberAssessment assessment;

  @override
  Widget build(BuildContext context) {
    final config = _ResultConfig.from(assessment.level);
    final matches = assessment.detectedAllergenIds.isNotEmpty
        ? assessment.detectedAllergenIds
        : assessment.traceAllergenIds;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Row(
          children: [
            MemberAvatar(member: member, size: 47),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.name,
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(
                    matches.isEmpty
                        ? config.shortDetail
                        : matches
                            .map((id) => Allergens.byId(id).label)
                            .join(', '),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: config.background,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Icon(config.icon, size: 16, color: config.color),
                  const SizedBox(width: 5),
                  Text(
                    config.badge,
                    style: TextStyle(
                        color: config.color,
                        fontSize: 12,
                        fontWeight: FontWeight.w800),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DataSourceCard extends StatelessWidget {
  const _DataSourceCard({required this.product});

  final ProductInfo product;

  @override
  Widget build(BuildContext context) {
    final isOpenFoodFacts = product.dataSource.contains('Open Food Facts');
    final isPaidLive = product.dataSource.contains('FatSecret');
    final detail = isOpenFoodFacts || !isPaidLive
        ? 'Data licence: safebiteai.co.uk/data-licences. Always verify the current package label.'
        : 'Live product data is not saved to SafeBiteAI’s product database. Always verify the current package label. Licence details: safebiteai.co.uk/data-licences.';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        detail,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.inkSoft,
              fontSize: 10,
              height: 1.35,
            ),
      ),
    );
  }
}

class _ResultConfig {
  const _ResultConfig({
    required this.title,
    required this.detail,
    required this.shortDetail,
    required this.badge,
    required this.icon,
    required this.color,
    required this.background,
  });

  final String title;
  final String detail;
  final String shortDetail;
  final String badge;
  final IconData icon;
  final Color color;
  final Color background;

  factory _ResultConfig.from(MatchLevel level) {
    return switch (level) {
      MatchLevel.avoid => const _ResultConfig(
          title: 'Avoid for this household',
          detail: 'At least one selected profile has a listed allergen match.',
          shortDetail: 'Listed allergen detected',
          badge: 'AVOID',
          icon: Icons.close_rounded,
          color: AppColors.danger,
          background: AppColors.dangerSoft,
        ),
      MatchLevel.caution => const _ResultConfig(
          title: 'Check carefully',
          detail:
              'The product includes precautionary “may contain” information.',
          shortDetail: 'Possible trace allergen',
          badge: 'CAUTION',
          icon: Icons.priority_high_rounded,
          color: AppColors.warning,
          background: AppColors.warningSoft,
        ),
      MatchLevel.noListedMatch => const _ResultConfig(
          title: 'No listed match found',
          detail:
              'Verify the current package before buying or eating. This is not a safety guarantee.',
          shortDetail: 'No listed match found',
          badge: 'CHECKED',
          icon: Icons.check_rounded,
          color: AppColors.green,
          background: AppColors.greenSoft,
        ),
      MatchLevel.unableToVerify => const _ResultConfig(
          title: 'Ingredient details unavailable',
          detail:
              'We identified the product, but cannot verify its ingredients. Check the current package label before buying or eating.',
          shortDetail: 'Check the current package label',
          badge: 'CHECK LABEL',
          icon: Icons.question_mark_rounded,
          color: AppColors.inkSoft,
          background: AppColors.line,
        ),
    };
  }
}
