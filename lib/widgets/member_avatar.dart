import 'package:flutter/material.dart';

import '../core/app_theme.dart';
import '../models/family_member.dart';

class MemberAvatar extends StatelessWidget {
  const MemberAvatar({
    super.key,
    required this.member,
    this.size = 48,
    this.showBorder = false,
  });

  final FamilyMember member;
  final double size;
  final bool showBorder;

  static const _colors = [
    Color(0xFFDFF3E6),
    Color(0xFFFFE9CF),
    Color(0xFFE6E8FF),
    Color(0xFFFFE3EA),
    Color(0xFFDCEFF6),
  ];

  @override
  Widget build(BuildContext context) {
    final color = _colors[member.avatarIndex % _colors.length];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: showBorder ? Border.all(color: Colors.white, width: 3) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        member.name.isEmpty ? '?' : member.name.substring(0, 1).toUpperCase(),
        style: TextStyle(
          color: AppColors.greenDark,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
