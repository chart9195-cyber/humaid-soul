import 'package:flutter/material.dart';

class AutoLinkPainter extends CustomPainter {
  final List<Rect> linkRects;

  AutoLinkPainter({required this.linkRects});

  @override
  void paint(Canvas canvas, Size size) {
    if (linkRects.isEmpty) return;

    final paint = Paint()
      ..color = Colors.blueAccent.withOpacity(0.7)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = Colors.blueAccent.withOpacity(0.2)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

    for (final rect in linkRects) {
      final underlineY = rect.bottom + 2;
      canvas.drawLine(
        Offset(rect.left, underlineY),
        Offset(rect.right, underlineY),
        glowPaint,
      );
      canvas.drawLine(
        Offset(rect.left, underlineY),
        Offset(rect.right, underlineY),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(AutoLinkPainter oldDelegate) {
    return linkRects != oldDelegate.linkRects;
  }
}
