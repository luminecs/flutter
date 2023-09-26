import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = AutomatedTestWidgetsFlutterBinding.ensureInitialized();
  binding.runTest(
    () async {},
    () {},
    // Changes made in https://github.com/flutter/flutter/pull/89952
    timeout: Duration(minutes: 30),
  );
}
