
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Initializing the RendererBinding does not crash when semantics is enabled', () {
    try {
      MyRenderingFlutterBinding();
    } catch (e) {
      fail('Initializing the RenderingBinding threw an unexpected error:\n$e');
    }
    expect(RendererBinding.instance, isA<MyRenderingFlutterBinding>());
    expect(SemanticsBinding.instance.semanticsEnabled, isTrue);
  });
}

// Binding that pretends the platform had semantics enabled before the binding
// is initialized.
class MyRenderingFlutterBinding extends RenderingFlutterBinding {
  @override
  bool get semanticsEnabled => true;
}