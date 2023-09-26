import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.runTest(
    () async {},
    () {},
    // Changes made in https://github.com/flutter/flutter/pull/89952
    timeout: Duration(minutes: 30),
  );
}
