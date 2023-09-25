
import 'package:file/file.dart';

import '../src/common.dart';
import 'test_data/basic_project.dart';
import 'test_driver.dart';
import 'test_utils.dart';

const Duration requiredLifespan = Duration(seconds: 5);

void main() {
  final BasicProject project = BasicProject();
  late FlutterRunTestDriver flutter;
  late Directory tempDir;

  setUp(() async {
    tempDir = createResolvedTempDirectorySync('lifetime_test.');
    await project.setUpIn(tempDir);
    flutter = FlutterRunTestDriver(tempDir);
  });

  tearDown(() async {
    await flutter.stop();
    tryToDelete(tempDir);
  });

  testWithoutContext('flutter run does not terminate when a debugger is attached', () async {
    await flutter.run(withDebugger: true);
    await Future<void>.delayed(requiredLifespan);
    expect(flutter.hasExited, equals(false));
  });

  testWithoutContext('flutter run does not terminate when a debugger is attached and pause-on-exceptions', () async {
    await flutter.run(withDebugger: true, pauseOnExceptions: true);
    await Future<void>.delayed(requiredLifespan);
    expect(flutter.hasExited, equals(false));
  });
}