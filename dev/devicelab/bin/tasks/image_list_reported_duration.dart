import 'package:flutter_devicelab/framework/framework.dart';
import 'package:flutter_devicelab/framework/utils.dart';
import 'package:flutter_devicelab/tasks/perf_tests.dart';

Future<void> main() async {
  await task(ReportedDurationTest(
    ReportedDurationTestFlavor.release,
    '${flutterDirectory.path}/examples/image_list',
    'lib/main.dart',
    'com.example.image_list',
    RegExp(r'===image_list=== all loaded in ([\d]+)ms.'),
  ).run);
}