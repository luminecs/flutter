// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'box.dart';

typedef ChildLayouter = Size Function(RenderBox child, BoxConstraints constraints);

abstract final class ChildLayoutHelper {
  static Size dryLayoutChild(RenderBox child, BoxConstraints constraints) {
    return child.getDryLayout(constraints);
  }

  static Size layoutChild(RenderBox child, BoxConstraints constraints) {
    child.layout(constraints, parentUsesSize: true);
    return child.size;
  }
}