import 'package:flutter_devicelab/framework/framework.dart';
import 'package:flutter_devicelab/tasks/android_choreographer_do_frame_test.dart';

Future<void> main() async {
  await task(androidChoreographerDoFrameTest());
}
