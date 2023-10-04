import 'package:flutter_devicelab/framework/framework.dart';
import 'package:flutter_devicelab/tasks/analysis.dart';

Future<void> main() async {
  await task(analyzerBenchmarkTask);
}
