import 'package:flutter/foundation.dart';

import 'basic.dart';
import 'framework.dart';

class _PlaceholderPainter extends CustomPainter {
  const _PlaceholderPainter({
    required this.color,
    required this.strokeWidth,
  });

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    final Rect rect = Offset.zero & size;
    final Path path = Path()
      ..addRect(rect)
      ..addPolygon(<Offset>[rect.topRight, rect.bottomLeft], false)
      ..addPolygon(<Offset>[rect.topLeft, rect.bottomRight], false);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PlaceholderPainter oldPainter) {
    return oldPainter.color != color
        || oldPainter.strokeWidth != strokeWidth;
  }

  @override
  bool hitTest(Offset position) => false;
}

class Placeholder extends StatelessWidget {
  const Placeholder({
    super.key,
    this.color = const Color(0xFF455A64), // Blue Grey 700
    this.strokeWidth = 2.0,
    this.fallbackWidth = 400.0,
    this.fallbackHeight = 400.0,
    this.child
  });

  final Color color;

  final double strokeWidth;

  final double fallbackWidth;

  final double fallbackHeight;

  final Widget? child;
  @override
  Widget build(BuildContext context) {
    return LimitedBox(
      maxWidth: fallbackWidth,
      maxHeight: fallbackHeight,
      child: CustomPaint(
        size: Size.infinite,
        painter: _PlaceholderPainter(
          color: color,
          strokeWidth: strokeWidth,
        ),
        child: child,
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('color', color, defaultValue: const Color(0xFF455A64)));
    properties.add(DoubleProperty('strokeWidth', strokeWidth, defaultValue: 2.0));
    properties.add(DoubleProperty('fallbackWidth', fallbackWidth, defaultValue: 400.0));
    properties.add(DoubleProperty('fallbackHeight', fallbackHeight, defaultValue: 400.0));
    properties.add(DiagnosticsProperty<Widget>('child', child, defaultValue: null));
  }
}