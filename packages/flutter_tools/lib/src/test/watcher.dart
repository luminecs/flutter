// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'test_device.dart';

abstract class TestWatcher {
  void handleStartedDevice(Uri? vmServiceUri) { }

  Future<void> handleFinishedTest(TestDevice testDevice);

  Future<void> handleTestCrashed(TestDevice testDevice);

  Future<void> handleTestTimedOut(TestDevice testDevice);
}