import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class TierOverlayPainter extends CustomPainter {
  final List<Rect> tierRects; // in widget coordinates
  final Color color;

  TierOverlayPainter({required this.tierRects, this.color = Colors.amber});

  @override
  void paint(Canvas canvas, Size size) {
    if (tierRects.isEmpty) return;

    final paint = Paint()
      ..color = color.withOpacity(0.5)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (final rect in tierRects) {
      // Draw a subtle underline 2px below the text baseline
      final underlineY = rect.bottom + 2;
      path.moveTo(rect.left, underlineY);
      path.lineTo(rect.right, underlineY);
    }
    canvas.drawPath(path, paint);

    // Add a very faint glow for visual depth
    final glowPaint = Paint()
      ..color = color.withOpacity(0.15)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    for (final rect in tierRects) {
      final underlineY = rect.bottom + 2;
      canvas.drawLine(
        Offset(rect.left, underlineY),
        Offset(rect.right, underlineY),
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(TierOverlayPainter oldDelegate) {
    return tierRects != oldDelegate.tierRects;
  }
}
