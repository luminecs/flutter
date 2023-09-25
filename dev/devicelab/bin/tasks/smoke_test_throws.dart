import 'package:flutter_devicelab/framework/framework.dart';

Future<void> main() async {
  await task(() async {
    throw 'failed';
  });
}