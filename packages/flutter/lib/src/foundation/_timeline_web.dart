// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:js_interop';

double get performanceTimestamp => 1000 * _performance.now();

@JS()
@staticInterop
class _DomPerformance {}

@JS('performance')
external _DomPerformance get _performance;

extension _DomPerformanceExtension on _DomPerformance {
  @JS()
  external double now();
}