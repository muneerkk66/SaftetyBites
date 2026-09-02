import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../services/open_food_facts_service.dart';
import '../../services/product_repository.dart';
import 'product_check_screen.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key, required this.session});

  final AppSession session;

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen> {
  final _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    returnImage: false,
  );
  final _lookupService = ProductRepository.instance;
  bool _handling = false;
  String? _status;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final code = capture.barcodes
                  .map((barcode) => barcode.rawValue)
                  .whereType<String>()
                  .firstOrNull;
              if (code != null) _handleBarcode(code);
            },
            errorBuilder: (context, error, child) => _CameraError(
              message: 'Camera access is needed to scan a barcode.',
              onManual: _showManualEntry,
            ),
          ),
          const _ScannerShade(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Row(
                    children: [
                      _RoundButton(
                        icon: Icons.close_rounded,
                        onPressed: () => Navigator.pop(context),
                      ),
                      const Spacer(),
                      const Text(
                        'Scan barcode',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      _RoundButton(
                        icon: Icons.flashlight_on_rounded,
                        onPressed: _controller.toggleTorch,
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    width: 292,
                    height: 190,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 2.5),
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    _status ?? 'Place the full barcode inside the frame',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Column(
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.info_outline_rounded,
                                color: AppColors.green),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'SafeBiteAI checks available product and allergen data. Always verify the current package label.',
                                style: TextStyle(
                                    color: AppColors.ink, height: 1.35),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton(
                          onPressed: _handling ? null : _showManualEntry,
                          child: const Text('Enter barcode manually'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_handling)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.56),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.white),
                    SizedBox(height: 16),
                    Text(
                      'Checking product…',
                      style: TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleBarcode(String code) async {
    if (_handling) return;
    setState(() {
      _handling = true;
      _status = 'Barcode found';
    });
    await _controller.stop();
    try {
      final result = await _lookupService.lookup(code);
      final product = result.product;
      widget.session.saveCheckedProduct(product);
      if (!mounted) return;
      setState(() {
        _status = switch (result.origin) {
          ProductLookupOrigin.offlineCatalog => 'Found in offline catalogue',
          ProductLookupOrigin.verifiedCatalog =>
            'Found in SafeBiteAI verified catalogue',
          ProductLookupOrigin.openFoodFacts => 'Found online and saved offline',
          ProductLookupOrigin.paidLive => 'Found using live provider data',
        };
      });
      await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) =>
              ProductCheckScreen(session: widget.session, product: product),
        ),
      );
    } on ProductLookupException catch (error) {
      if (!mounted) return;
      setState(() {
        _handling = false;
        _status = 'Ready to scan another product';
      });
      await _showLookupError(code, error.message);
    } finally {
      if (mounted) {
        setState(() {
          _handling = false;
          _status = null;
        });
        try {
          await _controller.start();
        } catch (_) {}
      }
    }
  }

  Future<void> _showLookupError(String barcode, String message) async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (context) => Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: AppColors.warningSoft,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.search_off_rounded,
                  color: AppColors.warning, size: 30),
            ),
            const SizedBox(height: 15),
            Text('Product not confirmed',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 5),
            Text('Barcode: $barcode',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Try another product'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showManualEntry() async {
    final controller = TextEditingController();
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      builder: (context) => Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          22,
          22,
          MediaQuery.of(context).viewInsets.bottom + 22,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Enter barcode',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(hintText: '8–14 digit barcode'),
              onSubmitted: (value) => Navigator.pop(context, value),
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Check product'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (code != null && code.trim().isNotEmpty) await _handleBarcode(code);
  }
}

class _ScannerShade extends StatelessWidget {
  const _ScannerShade();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.6),
              Colors.transparent,
              Colors.transparent,
              Colors.black.withValues(alpha: 0.72),
            ],
            stops: const [0, 0.28, 0.58, 1],
          ),
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.35),
      ),
      icon: Icon(icon, color: Colors.white),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.message, required this.onManual});

  final String message;
  final VoidCallback onManual;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.ink,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.no_photography_outlined,
                  color: Colors.white, size: 48),
              const SizedBox(height: 16),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 18),
              FilledButton(
                  onPressed: onManual,
                  child: const Text('Enter barcode manually')),
            ],
          ),
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
