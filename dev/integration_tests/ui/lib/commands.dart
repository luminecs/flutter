import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

void main() {
  print('called main');
  runApp(const MaterialApp(home: Test()));
}

class Test extends SingleChildRenderObjectWidget {
  const Test({super.key});

  @override
  RenderTest createRenderObject(BuildContext context) => RenderTest();
}

class RenderTest extends RenderProxyBox {
  RenderTest({RenderBox? child}) : super(child);

  @override
  void debugPaintSize(PaintingContext context, Offset offset) {
    super.debugPaintSize(context, offset);
    print('called debugPaintSize');
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    print('called paint');
  }

  @override
  void reassemble() {
    print('called reassemble');
    super.reassemble();
  }
}
