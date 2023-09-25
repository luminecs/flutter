import 'package:flutter_devicelab/framework/framework.dart';
import 'package:flutter_devicelab/framework/task_result.dart';

Future<void> main() async {
  await task(() async {
    return TaskResult.failure('Failed');
  });
}