// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'binding.dart';

// ignore: avoid_classes_with_only_static_members
class BackgroundIsolateBinaryMessenger {
  static BinaryMessenger get instance {
    throw UnsupportedError('Isolates not supported on web.');
  }
}