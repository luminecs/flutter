// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '../base/io.dart';

mixin PidTracker {
  final Set<int> pidsToTerminate = <int>{};

  void terminatePids(ProcessSignal signal) {
    pidsToTerminate.forEach(signal.send);
  }
}