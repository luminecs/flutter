import 'package:flutter_devicelab/framework/framework.dart';
import 'package:flutter_devicelab/tasks/web_benchmarks.dart';

Future<void> main() async {
  await task(() async {
    return runWebBenchmark((webRenderer: 'html', useWasm: false));
  });
}
