import 'package:flutter/material.dart';

class SwipeBadge extends StatelessWidget {
  final String text;
  final Color color;
  final double opacity;

  const SwipeBadge({
    super.key,
    required this.text,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          border: Border.all(color: color, width: 3),
          borderRadius: BorderRadius.circular(14),
          color: const Color(0xFF101418).withOpacity(0.45),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}
