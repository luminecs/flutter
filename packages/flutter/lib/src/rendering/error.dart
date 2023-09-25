import 'dart:ui' as ui show Paragraph, ParagraphBuilder, ParagraphConstraints, ParagraphStyle, TextStyle;

import 'box.dart';
import 'object.dart';

const double _kMaxWidth = 100000.0;
const double _kMaxHeight = 100000.0;

class RenderErrorBox extends RenderBox {
  RenderErrorBox([ this.message = '' ]) {
    try {
      if (message != '') {
        // This class is intentionally doing things using the low-level
        // primitives to avoid depending on any subsystems that may have ended
        // up in an unstable state -- after all, this class is mainly used when
        // things have gone wrong.
        //
        // Generally, the much better way to draw text in a RenderObject is to
        // use the TextPainter class. If you're looking for code to crib from,
        // see the paragraph.dart file and the RenderParagraph class.
        final ui.ParagraphBuilder builder = ui.ParagraphBuilder(paragraphStyle);
        builder.pushStyle(textStyle);
        builder.addText(message);
        _paragraph = builder.build();
      } else {
        _paragraph = null;
      }
    } catch (error) {
      // If an error happens here we're in a terrible state, so we really should
      // just forget about it and let the developer deal with the already-reported
      // errors. It's unlikely that these errors are going to help with that.
    }
  }

  final String message;

  late final ui.Paragraph? _paragraph;

  @override
  double computeMaxIntrinsicWidth(double height) {
    return _kMaxWidth;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    return _kMaxHeight;
  }

  @override
  bool get sizedByParent => true;

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return constraints.constrain(const Size(_kMaxWidth, _kMaxHeight));
  }

  static EdgeInsets padding = const EdgeInsets.fromLTRB(64.0, 96.0, 64.0, 12.0);

  static double minimumWidth = 200.0;

  static Color backgroundColor = _initBackgroundColor();

  static Color _initBackgroundColor() {
    Color result = const Color(0xF0C0C0C0);
    assert(() {
      result = const Color(0xF0900000);
      return true;
    }());
    return result;
  }

  static ui.TextStyle textStyle = _initTextStyle();

  static ui.TextStyle _initTextStyle() {
    ui.TextStyle result = ui.TextStyle(
      color: const Color(0xFF303030),
      fontFamily: 'sans-serif',
      fontSize: 18.0,
    );
    assert(() {
      result = ui.TextStyle(
        color: const Color(0xFFFFFF66),
        fontFamily: 'monospace',
        fontSize: 14.0,
        fontWeight: FontWeight.bold,
      );
      return true;
    }());
    return result;
  }

  static ui.ParagraphStyle paragraphStyle = ui.ParagraphStyle(
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.left,
  );

  @override
  void paint(PaintingContext context, Offset offset) {
    try {
      context.canvas.drawRect(offset & size, Paint() .. color = backgroundColor);
      if (_paragraph != null) {
        double width = size.width;
        double left = 0.0;
        double top = 0.0;
        if (width > padding.left + minimumWidth + padding.right) {
          width -= padding.left + padding.right;
          left += padding.left;
        }
        _paragraph.layout(ui.ParagraphConstraints(width: width));
        if (size.height > padding.top + _paragraph.height + padding.bottom) {
          top += padding.top;
        }
        context.canvas.drawParagraph(_paragraph, offset + Offset(left, top));
      }
    } catch (error) {
      // If an error happens here we're in a terrible state, so we really should
      // just forget about it and let the developer deal with the already-reported
      // errors. It's unlikely that these errors are going to help with that.
    }
  }
}