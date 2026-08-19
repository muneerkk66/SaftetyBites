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
        Container(
          width: compact ? 36 : 46,
          height: compact ? 36 : 46,
          decoration: BoxDecoration(
            color: onDark ? Colors.white.withOpacity(0.12) : AppColors.acid,
            shape: BoxShape.circle,
            border: Border.all(
              color:
                  onDark ? Colors.white.withOpacity(0.18) : AppColors.greenDark,
              width: 1.5,
            ),
            boxShadow: onDark
                ? null
                : [
                    BoxShadow(
                      color: AppColors.greenDark.withOpacity(0.14),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Icon(Icons.shield_rounded,
                  color: foreground, size: compact ? 25 : 32),
              Positioned(
                top: compact ? 8 : 10,
                child: Icon(
                  Icons.eco_rounded,
                  color: onDark ? AppColors.mint : AppColors.lime,
                  size: compact ? 12 : 15,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 11),
        Text(
          'SafeBite',
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
