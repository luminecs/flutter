
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

import 'test_widgets.dart';

void main() {
  testWidgetsWithLeakTracking('Stateful widget smoke test', (WidgetTester tester) async {
    void checkTree(BoxDecoration expectedDecoration) {
      final SingleChildRenderObjectElement element = tester.element(
        find.byElementPredicate((Element element) => element is SingleChildRenderObjectElement && element.renderObject is! RenderView),
      );
      expect(element, isNotNull);
      expect(element.renderObject, isA<RenderDecoratedBox>());
      final RenderDecoratedBox renderObject = element.renderObject as RenderDecoratedBox;
      expect(renderObject.decoration, equals(expectedDecoration));
    }

    await tester.pumpWidget(
      const FlipWidget(
        left: DecoratedBox(decoration: kBoxDecorationA),
        right: DecoratedBox(decoration: kBoxDecorationB),
      ),
    );

    checkTree(kBoxDecorationA);

    await tester.pumpWidget(
      const FlipWidget(
        left: DecoratedBox(decoration: kBoxDecorationB),
        right: DecoratedBox(decoration: kBoxDecorationA),
      ),
    );

    checkTree(kBoxDecorationB);

    flipStatefulWidget(tester);

    await tester.pump();

    checkTree(kBoxDecorationA);

    await tester.pumpWidget(
      const FlipWidget(
        left: DecoratedBox(decoration: kBoxDecorationA),
        right: DecoratedBox(decoration: kBoxDecorationB),
      ),
    );

    checkTree(kBoxDecorationB);
  });

  testWidgetsWithLeakTracking("Don't rebuild subwidgets", (WidgetTester tester) async {
    await tester.pumpWidget(
      const FlipWidget(
        key: Key('rebuild test'),
        left: TestBuildCounter(),
        right: DecoratedBox(decoration: kBoxDecorationB),
      ),
    );

    expect(TestBuildCounter.buildCount, equals(1));

    flipStatefulWidget(tester);

    await tester.pump();

    expect(TestBuildCounter.buildCount, equals(1));
  });
}