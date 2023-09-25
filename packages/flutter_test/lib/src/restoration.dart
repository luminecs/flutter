// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class TestRestorationManager extends RestorationManager {
  TestRestorationManager() {
    // Ensures that [rootBucket] always returns a synchronous future to avoid
    // extra pumps in tests.
    restoreFrom(TestRestorationData.empty);
  }

  @override
  Future<RestorationBucket?> get rootBucket {
    _debugRootBucketAccessed = true;
    return super.rootBucket;
  }

  TestRestorationData get restorationData => _restorationData;
  late TestRestorationData _restorationData;

  bool get debugRootBucketAccessed => _debugRootBucketAccessed;
  bool _debugRootBucketAccessed = false;

  void restoreFrom(TestRestorationData data) {
    _restorationData = data;
    handleRestorationUpdateFromEngine(enabled: true, data: data.binary);
  }

  void disableRestoration() {
    _restorationData = TestRestorationData.empty;
    handleRestorationUpdateFromEngine(enabled: false, data: null);
  }

  @override
  Future<void> sendToEngine(Uint8List encodedData) async {
    _restorationData = TestRestorationData._(encodedData);
  }
}

class TestRestorationData {
  const TestRestorationData._(this.binary);

  static const TestRestorationData empty = TestRestorationData._(null);

  @protected
  final Uint8List? binary;
}