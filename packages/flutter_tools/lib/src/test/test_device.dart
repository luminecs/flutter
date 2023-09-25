// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:stream_channel/stream_channel.dart';

abstract class TestDevice {
  Future<StreamChannel<String>> start(String entrypointPath);

  Future<Uri?> get vmServiceUri;

  Future<void> kill();

  Future<void> get finished;
}

class TestDeviceException implements Exception {
  TestDeviceException(this.message, this.stackTrace);

  final String message;
  final StackTrace stackTrace;

  @override
  String toString() => 'TestDeviceException($message)';
}