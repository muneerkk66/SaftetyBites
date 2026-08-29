import 'package:flutter/material.dart';

import '../core/app_theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.compact = false, this.onDark = false});

  final bool compact;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final foreground = onDark ? Colors.white : AppColors.greenDark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(compact ? 10 : 13),
          child: Image.asset(
            'assets/images/safebiteai-logo.png',
            width: compact ? 36 : 46,
            height: compact ? 36 : 46,
            fit: BoxFit.cover,
            semanticLabel: 'SafeBiteAI logo',
          ),
        ),
        const SizedBox(width: 11),
        Text(
          'SafeBiteAI',
          style: TextStyle(
            color: foreground,
            fontSize: compact ? 20 : 25,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
          ),
        ),
      ],
    );
  }
}
