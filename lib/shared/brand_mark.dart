import 'package:flutter/material.dart';

import '../core/theme.dart';

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 26 : 32,
          height: compact ? 26 : 32,
          decoration: BoxDecoration(
            color: DshColors.navy,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            Icons.auto_awesome_rounded,
            size: compact ? 15 : 18,
            color: Colors.white,
          ),
        ),
        const SizedBox(width: 9),
        Text(
          'deepseek',
          style: TextStyle(
            fontFamily: 'Montserrat',
            fontSize: compact ? 18 : 22,
            fontWeight: FontWeight.w700,
            color: DshColors.text,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(width: 7),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: DshColors.text,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text(
            'HARNESS',
            style: TextStyle(
              fontFamily: 'FragmentMono',
              fontSize: 9,
              height: 1,
              color: Colors.white,
              letterSpacing: 0,
            ),
          ),
        ),
      ],
    );
  }
}
