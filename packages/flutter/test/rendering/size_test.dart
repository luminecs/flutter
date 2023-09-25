import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'rendering_tester.dart';

void main() {
  TestRenderingFlutterBinding.ensureInitialized();

  test('Stack can layout with top, right, bottom, left 0.0', () {
    final RenderBox box = RenderConstrainedBox(
      additionalConstraints: BoxConstraints.tight(const Size(100.0, 100.0)),
    );

    layout(box, constraints: const BoxConstraints());

    expect(box.size.width, equals(100.0));
    expect(box.size.height, equals(100.0));
    expect(box.size, equals(const Size(100.0, 100.0)));
    expect(box.size.runtimeType.toString(), equals('_DebugSize'));
  });
}