// This example shows how to use process input events in the underlying render
// tree.

import 'package:flutter/material.dart'; // Imported just for its color palette.
import 'package:flutter/rendering.dart';

import 'src/binding.dart';

// Material design colors. :p
List<Color> _kColors = <Color>[
  Colors.teal,
  Colors.amber,
  Colors.purple,
  Colors.lightBlue,
  Colors.deepPurple,
  Colors.lime,
];

class Dot {
  Dot({ required Color color }) : _paint = Paint()..color = color;

  final Paint _paint;
  Offset position = Offset.zero;
  double radius = 0.0;

  void update(PointerEvent event) {
    position = event.position;
    radius = 5 + (95 * event.pressure);
  }

  void paint(Canvas canvas, Offset offset) {
    canvas.drawCircle(position + offset, radius, _paint);
  }
}

class RenderDots extends RenderBox {
  RenderDots();

  final Map<int, Dot> _dots = <int, Dot>{};

  @override
  bool get sizedByParent => true;

  @override
  void performResize() {
    size = constraints.biggest;
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void handleEvent(PointerEvent event, BoxHitTestEntry entry) {
    if (event is PointerDownEvent) {
      final Color color = _kColors[event.pointer.remainder(_kColors.length)];
      _dots[event.pointer] = Dot(color: color)..update(event);
      // We call markNeedsPaint to indicate that our painting commands have
      // changed and that paint needs to be called before displaying a new frame
      // to the user. It's harmless to call markNeedsPaint multiple times
      // because the render tree will ignore redundant calls.
      markNeedsPaint();
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      _dots.remove(event.pointer);
      markNeedsPaint();
    } else if (event is PointerMoveEvent) {
      _dots[event.pointer]!.update(event);
      markNeedsPaint();
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final Canvas canvas = context.canvas;
    // The "size" property indicates the size of that this render box was
    // allotted during layout. Here we paint our bounds white. Notice that we're
    // located at "offset" from the origin of the canvas' coordinate system.
    // Passing offset during the render tree's paint walk is an optimization to
    // avoid having to change the origin of the canvas's coordinate system too
    // often.
    canvas.drawRect(offset & size, Paint()..color = const Color(0xFFFFFFFF));

    // We iterate through our model and paint each dot.
    for (final Dot dot in _dots.values) {
      dot.paint(canvas, offset);
    }
  }
}

void main() {
  // Create some styled text to tell the user to interact with the app.
  final RenderParagraph paragraph = RenderParagraph(
    const TextSpan(
      style: TextStyle(color: Colors.black87),
      text: 'Touch me!',
    ),
    textDirection: TextDirection.ltr,
  );
  // A stack is a render object that layers its children on top of each other.
  // The bottom later is our RenderDots object, and on top of that we show the
  // text.
  final RenderStack stack = RenderStack(
    textDirection: TextDirection.ltr,
    children: <RenderBox>[
      RenderDots(),
      paragraph,
    ],
  );
  // The "parentData" field of a render object is controlled by the render
  // object's parent render object. Now that we've added the paragraph as a
  // child of the RenderStack, the paragraph's parentData field has been
  // populated with a StackParentData, which we can use to provide input to the
  // stack's layout algorithm.
  //
  // We use the StackParentData of the paragraph to position the text in the top
  // left corner of the screen.
  final StackParentData paragraphParentData = paragraph.parentData! as StackParentData;
  paragraphParentData
    ..top = 40.0
    ..left = 20.0;

  // Finally, we attach the render tree we've built to the screen.
  ViewRenderingFlutterBinding(root: stack).scheduleFrame();
}