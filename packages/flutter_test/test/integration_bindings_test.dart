import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Initializes httpOverrides and testTextInput', () async {
    expect(HttpOverrides.current, null);
    final TestWidgetsFlutterBinding binding = CustomBindings();
    expect(WidgetsBinding.instance, isA<CustomBindings>());
    expect(binding.testTextInput.isRegistered, false);
    expect(HttpOverrides.current, null);
  });
}

class CustomBindings extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;

  @override
  bool get registerTestTextInput => false;
}