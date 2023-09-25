import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

void main() {
  testWidgetsWithLeakTracking('RenderOpacity avoids repainting and does not drop layer at fully opaque', (WidgetTester tester) async {
    RenderTestObject.paintCount = 0;
    await tester.pumpWidget(
      const ColoredBox(
        color: Colors.red,
        child: Opacity(
          opacity: 0.0,
          child: TestWidget(),
        ),
      )
    );

    expect(RenderTestObject.paintCount, 0);

    await tester.pumpWidget(
      const ColoredBox(
        color: Colors.red,
        child: Opacity(
          opacity: 0.1,
          child: TestWidget(),
        ),
      )
    );

    expect(RenderTestObject.paintCount, 1);

    await tester.pumpWidget(
      const ColoredBox(
        color: Colors.red,
        child: Opacity(
          opacity: 1,
          child: TestWidget(),
        ),
      )
    );

    expect(RenderTestObject.paintCount, 1);
  });

  testWidgetsWithLeakTracking('RenderOpacity allows opacity layer to be dropped at 0 opacity', (WidgetTester tester) async {
    RenderTestObject.paintCount = 0;

    await tester.pumpWidget(
      const ColoredBox(
        color: Colors.red,
        child: Opacity(
          opacity: 0.5,
          child: TestWidget(),
        ),
      )
    );

    expect(RenderTestObject.paintCount, 1);

    await tester.pumpWidget(
      const ColoredBox(
        color: Colors.red,
        child: Opacity(
          opacity: 0.0,
          child: TestWidget(),
        ),
      )
    );

    expect(RenderTestObject.paintCount, 1);
    expect(tester.layers, isNot(contains(isA<OpacityLayer>())));
  });
}

class TestWidget extends SingleChildRenderObjectWidget {
  const TestWidget({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderTestObject();
  }
}

class RenderTestObject extends RenderProxyBox {
  static int paintCount = 0;

  @override
  void paint(PaintingContext context, Offset offset) {
    paintCount += 1;
    super.paint(context, offset);
  }
}