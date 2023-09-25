
import 'package:flutter_devicelab/framework/framework.dart';
import 'package:flutter_devicelab/tasks/flutter_tool_startup.dart';

Future<void> main() async {
  await task(flutterToolStartupBenchmarkTask);
}