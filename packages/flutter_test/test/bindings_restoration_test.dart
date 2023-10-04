import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Can access restoration manager without crashing', () {
    final AutomatedTestWidgetsFlutterBinding binding =
        AutomatedTestWidgetsFlutterBinding();
    expect(binding.restorationManager, isA<RestorationManager>());
  });
}
