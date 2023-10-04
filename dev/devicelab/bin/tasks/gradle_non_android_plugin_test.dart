import 'package:flutter_devicelab/framework/framework.dart';
import 'package:flutter_devicelab/framework/task_result.dart';

Future<void> main() async {
  await task(() async {
    // TODO(jmagman): Remove once gradle_non_android_plugin_test builder can be deleted, https://github.com/flutter/flutter/issues/85347
    return TaskResult.success(null);
  });
}
