// A test script that invokes compute() to start an isolate.

import 'package:flutter/src/foundation/_isolates_io.dart';

int getLength(String s) {
  throw 10;
}

Future<void> main() async {
  const String s = 'hello world';
  try {
    await compute(getLength, s);
  } catch (e) {
    if (e != 10) {
      throw Exception('compute threw bad result');
    }
  }
}
