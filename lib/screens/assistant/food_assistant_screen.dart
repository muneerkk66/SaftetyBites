import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_session.dart';
import '../../core/app_theme.dart';
import '../../core/auth_controller.dart';
import '../../models/allergen.dart';
import '../../models/food_assistant_analysis.dart';
import '../../models/product.dart';
import '../../services/allergen_matcher.dart';
import '../../services/food_assistant_service.dart';
import '../../services/product_repository.dart';
import '../../widgets/member_avatar.dart';

class FoodAssistantScreen extends StatefulWidget {
  const FoodAssistantScreen({
    super.key,
    required this.session,
    required this.auth,
    required this.onOpenFamily,
  });

  final AppSession session;
  final AuthController auth;
  final VoidCallback onOpenFamily;

  @override
  State<FoodAssistantScreen> createState() => _FoodAssistantScreenState();
}

class _FoodAssistantScreenState extends State<FoodAssistantScreen> {
  final _assistant = FoodAssistantService();
  final _products = ProductRepository.instance;
  final _picker = ImagePicker();
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final List<_AssistantMessage> _messages = [];

  FoodAssistantAnalysis? _analysis;
  bool _busy = false;
  String? _error;
  Timer? _thinkingTimer;
  int _thinkingStage = 0;
  bool _thinkingAboutImage = false;

  static const _thinkingMessages = [
    'Looking at the product…',
    'Reading visible label text…',
    'Checking allergen evidence…',
    'Preparing a clear answer…',
  ];

  @override
  void dispose() {
    _thinkingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListenableBuilder(
        listenable: Listenable.merge([widget.session, widget.auth]),
        builder: (context, _) {
          final signedIn = widget.auth.isSignedIn;
          return Column(
            children: [
              _ChatHeader(
                canReset: _messages.isNotEmpty,
                onReset: _newCheck,
              ),
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    if (!signedIn)
                      _SignInPrompt(onPressed: widget.onOpenFamily)
                    else if (_messages.isEmpty && !_busy)
                      _EmptyChat(onAddPhoto: _openPhotoOptions)
                    else ...[
                      ..._messages.map(
                        (message) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: switch (message.kind) {
                            _MessageKind.photo => _PhotoBubble(
                                imageBytes: message.imageBytes!,
                              ),
                            _MessageKind.user =>
                              _UserBubble(text: message.text),
                            _MessageKind.assistant => _AssistantResultCard(
                                analysis: message.analysis!,
                                session: widget.session,
                                busy: _busy,
                                onOpenFamily: widget.onOpenFamily,
                                onAddPhoto: _openPhotoOptions,
                                onQuestion: _sendQuestion,
                              ),
                          },
                        ),
                      ),
                      if (_busy)
                        _ThinkingBubble(
                          message: _thinkingAboutImage
                              ? _thinkingMessages[_thinkingStage]
                              : 'Thinking…',
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        _ErrorBubble(
                          message: _error!,
                          onRetry: _openPhotoOptions,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              if (signedIn)
                _ChatComposer(
                  controller: _messageController,
                  enabled: !_busy && _analysis != null,
                  onSend: () => _sendQuestion(_messageController.text),
                  onAddPhoto: _busy ? null : _openPhotoOptions,
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openPhotoOptions() async {
    if (_busy) return;
    if (kIsWeb) {
      await _pickImage(ImageSource.gallery);
      return;
    }
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add a product photo',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => Navigator.pop(context, ImageSource.camera),
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('Take photo'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context, ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Choose from photos'),
              ),
            ],
          ),
        ),
      ),
    );
    if (source != null) await _pickImage(source);
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_busy) return;
    final image = await _picker.pickImage(
      source: source,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 78,
      preferredCameraDevice: CameraDevice.rear,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (bytes.length > FoodAssistantService.maximumImageBytes) {
      setState(() {
        _error = 'That photo is too large. Please choose a smaller image.';
      });
      return;
    }
    await _analyseImage(
      bytes,
      _supportedMimeType(image.mimeType, image.name),
    );
  }

  Future<void> _analyseImage(Uint8List bytes, String mimeType) async {
    final previousAnalysis = _analysis;
    final history = _history;
    final question = previousAnalysis == null
        ? 'Identify this product and explain only what the visible packaging or label can verify.'
        : 'Use this additional photo to update the product and label information.';
    _startThinking(aboutImage: true);
    setState(() {
      _busy = true;
      _error = null;
      _messages.add(_AssistantMessage.photo(bytes));
    });
    _scrollToBottom();
    try {
      final result = await _assistant.ask(
        message: question,
        imageBytes: bytes,
        mimeType: mimeType,
        context: previousAnalysis,
        history: history,
      );
      final enrichedResult = await _withLocalProduct(result);
      if (!mounted) return;
      setState(() {
        _analysis = enrichedResult;
        _messages.add(_AssistantMessage.assistant(enrichedResult));
      });
    } on FoodAssistantException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      _stopThinking();
      if (mounted) {
        setState(() => _busy = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _sendQuestion(String rawMessage) async {
    final message = rawMessage.trim();
    final analysis = _analysis;
    if (message.isEmpty || analysis == null || _busy) return;
    final history = _history;
    _messageController.clear();
    _startThinking(aboutImage: false);
    setState(() {
      _busy = true;
      _error = null;
      _messages.add(_AssistantMessage.user(message));
    });
    _scrollToBottom();
    try {
      final result = await _assistant.ask(
        message: message,
        context: analysis,
        history: history,
      );
      final enrichedResult = await _withLocalProduct(result);
      if (!mounted) return;
      setState(() {
        _analysis = enrichedResult;
        _messages.add(_AssistantMessage.assistant(enrichedResult));
      });
    } on FoodAssistantException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      _stopThinking();
      if (mounted) {
        setState(() => _busy = false);
        _scrollToBottom();
      }
    }
  }

  List<FoodAssistantTurn> get _history => _messages
      .where((message) => message.kind != _MessageKind.photo)
      .map(
        (message) => FoodAssistantTurn(
          role: message.kind == _MessageKind.user ? 'user' : 'assistant',
          text: message.kind == _MessageKind.user
              ? message.text
              : message.analysis!.reply,
        ),
      )
      .toList();

  Future<FoodAssistantAnalysis> _withLocalProduct(
    FoodAssistantAnalysis analysis,
  ) async {
    final name = analysis.product.name.trim();
    if (name.isEmpty || name == 'Product not confirmed') return analysis;
    final localProduct = await _products.findLocalProduct(
      barcode: analysis.product.barcode,
      name: name,
      brand: analysis.product.brand,
    );
    return localProduct == null
        ? analysis
        : analysis.withCatalogProduct(localProduct);
  }

  void _newCheck() {
    if (_busy) return;
    setState(() {
      _analysis = null;
      _messages.clear();
      _error = null;
      _messageController.clear();
    });
  }

  void _startThinking({required bool aboutImage}) {
    _thinkingTimer?.cancel();
    _thinkingStage = 0;
    _thinkingAboutImage = aboutImage;
    if (!aboutImage) return;
    _thinkingTimer = Timer.periodic(const Duration(milliseconds: 1300), (_) {
      if (!mounted) return;
      setState(() {
        _thinkingStage = (_thinkingStage + 1) % _thinkingMessages.length;
      });
    });
  }

  void _stopThinking() {
    _thinkingTimer?.cancel();
    _thinkingTimer = null;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  String _supportedMimeType(String? mimeType, String name) {
    final normalized = mimeType?.toLowerCase() ?? '';
    if (normalized == 'image/png' || normalized == 'image/webp') {
      return normalized;
    }
    if (name.toLowerCase().endsWith('.png')) return 'image/png';
    if (name.toLowerCase().endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}

class _ChatHeader extends StatelessWidget {
  const _ChatHeader({required this.canReset, required this.onReset});

  final bool canReset;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 12, 10),
      decoration: const BoxDecoration(
        color: Color(0xFFFAFFFA),
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.acid,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Image.asset('assets/images/safebiteai-logo.png'),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ask SafeBiteAI',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Text(
                  'Product and label assistant',
                  style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
                ),
              ],
            ),
          ),
          if (canReset)
            IconButton(
              tooltip: 'Start a new check',
              onPressed: onReset,
              icon: const Icon(Icons.add_comment_outlined),
            ),
        ],
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.onAddPhoto});

  final VoidCallback onAddPhoto;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 54, 20, 20),
          child: Column(
            children: [
              Container(
                width: 74,
                height: 74,
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  gradient: AppGradients.primarySoft,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Image.asset('assets/images/safebiteai-logo.png'),
              ),
              const SizedBox(height: 20),
              Text(
                'What would you like to check?',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Add one clear product or ingredient-label photo. SafeBiteAI will read it automatically.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppColors.inkSoft,
                    ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onAddPhoto,
                icon: const Icon(Icons.add_a_photo_rounded),
                label: const Text('Add product photo'),
              ),
              const SizedBox(height: 12),
              const Text(
                'For allergen checks, include the full ingredients and “may contain” wording.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.inkSoft,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SignInPrompt extends StatelessWidget {
  const _SignInPrompt({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 64, 20, 20),
          child: Column(
            children: [
              const Icon(
                Icons.lock_outline_rounded,
                color: AppColors.green,
                size: 42,
              ),
              const SizedBox(height: 16),
              Text(
                'Sign in to ask SafeBiteAI',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Sign-in protects the AI service. Your household profiles remain on this device.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: onPressed,
                child: const Text('Open account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoBubble extends StatelessWidget {
  const _PhotoBubble({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        width: MediaQuery.sizeOf(context).width > 700 ? 300 : 230,
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: AppColors.acidSoft,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.aqua),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(17),
          child: AspectRatio(
            aspectRatio: 1.15,
            child: Image.memory(imageBytes, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

class _UserBubble extends StatelessWidget {
  const _UserBubble({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: AppColors.acidSoft,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomLeft: Radius.circular(20),
            bottomRight: Radius.circular(5),
          ),
        ),
        child: Text(text, style: const TextStyle(height: 1.4)),
      ),
    );
  }
}

class _ThinkingBubble extends StatelessWidget {
  const _ThinkingBubble({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 29,
              height: 29,
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: AppColors.acid,
                shape: BoxShape.circle,
              ),
              child: Image.asset('assets/images/safebiteai-logo.png'),
            ),
            const SizedBox(width: 11),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 260),
              child: Text(
                message,
                key: ValueKey(message),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 10),
            const _TypingDots(),
          ],
        ),
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (index) {
          final position = _controller.value * 3;
          final distance = (position - index).abs().clamp(0.0, 1.0);
          return Container(
            width: 5,
            height: 5,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              color: AppColors.green.withValues(alpha: 1 - distance * 0.65),
              shape: BoxShape.circle,
            ),
          );
        }),
      ),
    );
  }
}

class _AssistantResultCard extends StatelessWidget {
  const _AssistantResultCard({
    required this.analysis,
    required this.session,
    required this.busy,
    required this.onOpenFamily,
    required this.onAddPhoto,
    required this.onQuestion,
  });

  final FoodAssistantAnalysis analysis;
  final AppSession session;
  final bool busy;
  final VoidCallback onOpenFamily;
  final VoidCallback onAddPhoto;
  final ValueChanged<String> onQuestion;

  @override
  Widget build(BuildContext context) {
    final assessments = session.family
        .map((member) => AllergenMatcher.assess(analysis.product, member))
        .toList();
    final presentation = _presentation(_overallLevel(assessments));
    final productName = analysis.product.name.trim().isEmpty
        ? 'Product not confirmed'
        : analysis.product.name;
    final confidence = (analysis.confidence * 100).round();

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              padding: const EdgeInsets.all(5),
              decoration: const BoxDecoration(
                color: AppColors.acid,
                shape: BoxShape.circle,
              ),
              child: Image.asset('assets/images/safebiteai-logo.png'),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(17),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(5),
                    topRight: Radius.circular(22),
                    bottomLeft: Radius.circular(22),
                    bottomRight: Radius.circular(22),
                  ),
                  border: Border.all(color: AppColors.line),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.greenDark.withValues(alpha: 0.06),
                      blurRadius: 18,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      analysis.reply,
                      style: const TextStyle(
                        color: AppColors.ink,
                        height: 1.45,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: AppColors.greenSoft,
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: const Icon(
                            Icons.inventory_2_outlined,
                            color: AppColors.green,
                          ),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                productName,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              if (analysis.product.brand.trim().isNotEmpty)
                                Text(
                                  analysis.product.brand,
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                            ],
                          ),
                        ),
                        Text(
                          '$confidence%',
                          style: const TextStyle(
                            color: AppColors.green,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(
                        color: presentation.background,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            presentation.icon,
                            color: presentation.color,
                            size: 25,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  presentation.title,
                                  style: TextStyle(
                                    color: presentation.color,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  presentation.detail,
                                  style: const TextStyle(
                                    color: AppColors.ink,
                                    fontSize: 12,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (session.family.isEmpty) ...[
                      const SizedBox(height: 11),
                      TextButton.icon(
                        onPressed: onOpenFamily,
                        icon: const Icon(Icons.group_add_outlined),
                        label: const Text('Add family profiles for matching'),
                      ),
                    ] else ...[
                      const SizedBox(height: 12),
                      ...session.family.asMap().entries.map((entry) {
                        final member = entry.value;
                        final result = _memberResult(assessments[entry.key]);
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Row(
                            children: [
                              MemberAvatar(member: member, size: 30),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${member.name}: ${result.detail}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                              Text(
                                result.label,
                                style: TextStyle(
                                  color: result.color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                    if (analysis.findings.isNotEmpty) ...[
                      const SizedBox(height: 13),
                      Text(
                        'What I found',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      ...analysis.findings.map(_FindingRow.new),
                    ],
                    if (analysis.product.ingredients.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Theme(
                        data: Theme.of(context)
                            .copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          childrenPadding: const EdgeInsets.only(bottom: 8),
                          title: Text(
                            analysis.product.dataSource ==
                                    'SafeBiteAI image analysis'
                                ? 'Visible ingredients'
                                : 'Recorded ingredients',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                analysis.product.ingredients,
                                style: const TextStyle(
                                  color: AppColors.inkSoft,
                                  fontSize: 12,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (analysis.needsAnotherImage) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(13),
                        decoration: BoxDecoration(
                          color: AppColors.warningSoft,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              analysis.nextImagePrompt.isEmpty
                                  ? 'Add a clear photo of the full ingredients and may-contain label.'
                                  : analysis.nextImagePrompt,
                              style: const TextStyle(
                                color: AppColors.ink,
                                fontSize: 12,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 9),
                            OutlinedButton.icon(
                              onPressed: busy ? null : onAddPhoto,
                              icon: const Icon(Icons.add_a_photo_outlined),
                              label: const Text('Add clearer photo'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (analysis.suggestedQuestions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: analysis.suggestedQuestions
                            .take(3)
                            .map(
                              (question) => ActionChip(
                                label: Text(question),
                                onPressed:
                                    busy ? null : () => onQuestion(question),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                    const SizedBox(height: 13),
                    const Text(
                      'AI can miss label details and does not guarantee food safety. Always check the current package.',
                      style: TextStyle(
                        color: AppColors.inkSoft,
                        fontSize: 10.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  MatchLevel _overallLevel(List<MemberAssessment> assessments) {
    if (assessments.any((item) => item.level == MatchLevel.avoid)) {
      return MatchLevel.avoid;
    }
    if (assessments.any((item) => item.level == MatchLevel.caution)) {
      return MatchLevel.caution;
    }
    if (assessments.isEmpty ||
        assessments.any((item) => item.level == MatchLevel.unableToVerify)) {
      return MatchLevel.unableToVerify;
    }
    return MatchLevel.noListedMatch;
  }

  _ResultPresentation _presentation(MatchLevel level) => switch (level) {
        MatchLevel.avoid => const _ResultPresentation(
            title: 'Avoid for this household',
            detail: 'A selected profile matches a listed allergen.',
            color: AppColors.danger,
            background: AppColors.dangerSoft,
            icon: Icons.cancel_rounded,
          ),
        MatchLevel.caution => const _ResultPresentation(
            title: 'Check the warning carefully',
            detail: 'A selected profile matches a may-contain warning.',
            color: AppColors.warning,
            background: AppColors.warningSoft,
            icon: Icons.warning_amber_rounded,
          ),
        MatchLevel.noListedMatch => const _ResultPresentation(
            title: 'No listed conflict found',
            detail: 'Based only on the complete visible label.',
            color: AppColors.green,
            background: AppColors.greenSoft,
            icon: Icons.check_circle_rounded,
          ),
        MatchLevel.unableToVerify => const _ResultPresentation(
            title: 'More label detail needed',
            detail: 'Add a complete ingredients and may-contain label photo.',
            color: AppColors.inkSoft,
            background: Color(0xFFF0F3EE),
            icon: Icons.help_outline_rounded,
          ),
      };

  _MemberResult _memberResult(MemberAssessment assessment) {
    final detected = assessment.detectedAllergenIds
        .map((id) => Allergens.byId(id).label)
        .join(', ');
    final traces = assessment.traceAllergenIds
        .map((id) => Allergens.byId(id).label)
        .join(', ');
    return switch (assessment.level) {
      MatchLevel.avoid => _MemberResult(
          label: 'AVOID',
          detail: detected.isEmpty ? 'listed allergen match' : detected,
          color: AppColors.danger,
        ),
      MatchLevel.caution => _MemberResult(
          label: 'CAUTION',
          detail: traces.isEmpty ? 'may-contain match' : 'may contain $traces',
          color: AppColors.warning,
        ),
      MatchLevel.noListedMatch => const _MemberResult(
          label: 'NO MATCH',
          detail: 'no selected allergen listed',
          color: AppColors.green,
        ),
      MatchLevel.unableToVerify => const _MemberResult(
          label: 'UNVERIFIED',
          detail: 'complete label needed',
          color: AppColors.inkSoft,
        ),
    };
  }
}

class _FindingRow extends StatelessWidget {
  const _FindingRow(this.finding);

  final AssistantFinding finding;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (finding.level) {
      AssistantFindingLevel.positive => (
          Icons.check_circle_rounded,
          AppColors.green
        ),
      AssistantFindingLevel.warning => (
          Icons.warning_rounded,
          AppColors.warning
        ),
      AssistantFindingLevel.info => (Icons.info_rounded, AppColors.inkSoft),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              finding.text,
              style: const TextStyle(fontSize: 12, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBubble extends StatelessWidget {
  const _ErrorBubble({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.dangerSoft,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: AppColors.danger),
            const SizedBox(width: 10),
            Expanded(child: Text(message)),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.enabled,
    required this.onSend,
    required this.onAddPhoto,
  });

  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onSend;
  final VoidCallback? onAddPhoto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFFFA),
        border: const Border(top: BorderSide(color: AppColors.line)),
        boxShadow: [
          BoxShadow(
            color: AppColors.greenDark.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            tooltip: 'Add product photo',
            onPressed: onAddPhoto,
            icon: const Icon(Icons.add_circle_rounded),
            color: AppColors.green,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: TextField(
              controller: controller,
              enabled: enabled,
              minLines: 1,
              maxLines: 5,
              keyboardType: TextInputType.multiline,
              textInputAction: TextInputAction.newline,
              decoration: InputDecoration(
                hintText: enabled
                    ? 'Ask about this product…'
                    : 'Add a photo to start',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 7),
          IconButton.filled(
            tooltip: 'Send',
            onPressed: enabled ? onSend : null,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.greenDark,
              foregroundColor: AppColors.acid,
            ),
            icon: const Icon(Icons.arrow_upward_rounded),
          ),
        ],
      ),
    );
  }
}

enum _MessageKind { photo, user, assistant }

class _AssistantMessage {
  const _AssistantMessage._({
    required this.kind,
    this.text = '',
    this.imageBytes,
    this.analysis,
  });

  factory _AssistantMessage.photo(Uint8List bytes) => _AssistantMessage._(
        kind: _MessageKind.photo,
        imageBytes: bytes,
      );

  factory _AssistantMessage.user(String text) => _AssistantMessage._(
        kind: _MessageKind.user,
        text: text,
      );

  factory _AssistantMessage.assistant(FoodAssistantAnalysis analysis) =>
      _AssistantMessage._(
        kind: _MessageKind.assistant,
        analysis: analysis,
      );

  final _MessageKind kind;
  final String text;
  final Uint8List? imageBytes;
  final FoodAssistantAnalysis? analysis;
}

class _ResultPresentation {
  const _ResultPresentation({
    required this.title,
    required this.detail,
    required this.color,
    required this.background,
    required this.icon,
  });

  final String title;
  final String detail;
  final Color color;
  final Color background;
  final IconData icon;
}

class _MemberResult {
  const _MemberResult({
    required this.label,
    required this.detail,
    required this.color,
  });

  final String label;
  final String detail;
  final Color color;
}
