
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';

import '../painting/mocks_for_image_cache.dart';


void main() {
  late ImageProvider image;

  setUpAll(() async {
    image = TestImageProvider(
      21,
      42,
      image: await createTestImage(width: 10, height: 10),
    );
  });

  testWidgetsWithLeakTracking('ImageIcon sizing - no theme, default size', (WidgetTester tester) async {
    await tester.pumpWidget(
      Center(
        child: ImageIcon(image),
      ),
    );

    final RenderBox renderObject = tester.renderObject(find.byType(ImageIcon));
    expect(renderObject.size, equals(const Size.square(24.0)));
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgetsWithLeakTracking('Icon opacity', (WidgetTester tester) async {
    await tester.pumpWidget(
      Center(
        child: IconTheme(
          data: const IconThemeData(opacity: 0.5),
          child: ImageIcon(image),
        ),
      ),
    );

    expect(tester.widget<Image>(find.byType(Image)).color!.alpha, equals(128));
  });

  testWidgetsWithLeakTracking('ImageIcon sizing - no theme, explicit size', (WidgetTester tester) async {
    await tester.pumpWidget(
      const Center(
        child: ImageIcon(
          null,
          size: 96.0,
        ),
      ),
    );

    final RenderBox renderObject = tester.renderObject(find.byType(ImageIcon));
    expect(renderObject.size, equals(const Size.square(96.0)));
  });

  testWidgetsWithLeakTracking('ImageIcon sizing - sized theme', (WidgetTester tester) async {
    await tester.pumpWidget(
      const Center(
        child: IconTheme(
          data: IconThemeData(size: 36.0),
          child: ImageIcon(null),
        ),
      ),
    );

    final RenderBox renderObject = tester.renderObject(find.byType(ImageIcon));
    expect(renderObject.size, equals(const Size.square(36.0)));
  });

  testWidgetsWithLeakTracking('ImageIcon sizing - sized theme, explicit size', (WidgetTester tester) async {
    await tester.pumpWidget(
      const Center(
        child: IconTheme(
          data: IconThemeData(size: 36.0),
          child: ImageIcon(
            null,
            size: 48.0,
          ),
        ),
      ),
    );

    final RenderBox renderObject = tester.renderObject(find.byType(ImageIcon));
    expect(renderObject.size, equals(const Size.square(48.0)));
  });

  testWidgetsWithLeakTracking('ImageIcon sizing - sizeless theme, default size', (WidgetTester tester) async {
    await tester.pumpWidget(
      const Center(
        child: IconTheme(
          data: IconThemeData(),
          child: ImageIcon(null),
        ),
      ),
    );

    final RenderBox renderObject = tester.renderObject(find.byType(ImageIcon));
    expect(renderObject.size, equals(const Size.square(24.0)));
  });

  testWidgetsWithLeakTracking('ImageIcon has semantics data', (WidgetTester tester) async {
    final SemanticsHandle handle = tester.ensureSemantics();
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: IconTheme(
            data: IconThemeData(),
            child: ImageIcon(null, semanticLabel: 'test'),
          ),
        ),
      ),
    );

    expect(tester.getSemantics(find.byType(ImageIcon)), matchesSemantics(
      label: 'test',
      textDirection: TextDirection.ltr,
    ));
    handle.dispose();
  });

}