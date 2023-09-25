
import 'package:flutter_devicelab/framework/devices.dart';
import 'package:flutter_devicelab/framework/framework.dart';
import 'package:flutter_devicelab/framework/task_result.dart';
import 'package:flutter_devicelab/framework/utils.dart';
import 'package:flutter_devicelab/tasks/integration_tests.dart';
import 'package:path/path.dart' as path;

Future<void> main() async {
  deviceOperatingSystem = DeviceOperatingSystem.android;
  await task(() async {
    await createFlavorsTest().call();
    await createIntegrationTestFlavorsTest().call();

    final TaskResult installTestsResult = await inDirectory(
      '${flutterDirectory.path}/dev/integration_tests/flavors',
      () async {
        await flutter(
          'install',
          options: <String>['--debug', '--flavor', 'paid'],
        );
        await flutter(
          'install',
          options: <String>['--debug', '--flavor', 'paid', '--uninstall-only'],
        );

        final StringBuffer stderr = StringBuffer();
        await evalFlutter(
          'install',
          canFail: true,
          stderr: stderr,
          options: <String>['--flavor', 'bogus'],
        );

        final String stderrString = stderr.toString();
        final String expectedApkPath = path.join('build', 'app', 'outputs', 'flutter-apk', 'app-bogus-release.apk');
        if (!stderrString.contains('"$expectedApkPath" does not exist.')) {
          print(stderrString);
          return TaskResult.failure('Should not succeed with bogus flavor');
        }

        return TaskResult.success(null);
      },
    );

    return installTestsResult;
  });
}