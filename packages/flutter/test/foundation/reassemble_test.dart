import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class TestFoundationFlutterBinding extends BindingBase {
  bool? wasLocked;

  @override
  Future<void> performReassemble() async {
    wasLocked = locked;
    return super.performReassemble();
  }
}

TestFoundationFlutterBinding binding = TestFoundationFlutterBinding();

void main() {
  test('Pointer events are locked during reassemble', () async {
    await binding.reassembleApplication();
    expect(binding.wasLocked, isTrue);
  });
}