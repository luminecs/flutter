// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// See also test_async_utils.dart which has some stack manipulation code.

import 'package:flutter/foundation.dart';

int reportExpectCall(StackTrace stack, List<DiagnosticsNode> information) {
  final RegExp line0 = RegExp(r'^#0 +fail \(.+\)$');
  final RegExp line1 = RegExp(r'^#1 +_expect \(.+\)$');
  final RegExp line2 = RegExp(r'^#2 +expect \(.+\)$');
  final RegExp line3 = RegExp(r'^#3 +expect \(.+\)$');
  final RegExp line4 = RegExp(r'^#4 +[^(]+ \((.+?):([0-9]+)(?::[0-9]+)?\)$');
  final List<String> stackLines = stack.toString().split('\n');
  if (line0.firstMatch(stackLines[0]) != null &&
      line1.firstMatch(stackLines[1]) != null &&
      line2.firstMatch(stackLines[2]) != null &&
      line3.firstMatch(stackLines[3]) != null) {
    final Match expectMatch = line4.firstMatch(stackLines[4])!;
    assert(expectMatch.groupCount == 2);
    information.add(DiagnosticsStackTrace.singleFrame(
      'This was caught by the test expectation on the following line',
      frame: '${expectMatch.group(1)} line ${expectMatch.group(2)}',
    ));

    return 4;
  }
  return 0;
}