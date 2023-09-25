
// A test script that invokes compute() to start an isolate.

import 'dart:isolate';

import 'package:flutter/src/foundation/_isolates_io.dart';

int getLength(ReceivePort s) {
  return 0;
}

Future<void> main() async {
  final ReceivePort s = ReceivePort();

  bool wasError = false;
  try {
    await compute(getLength, s);
  } on Object {
    wasError = true;
  }
  s.close();

  assert(wasError);
}