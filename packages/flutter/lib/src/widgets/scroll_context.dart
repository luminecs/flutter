// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import 'framework.dart';
import 'ticker_provider.dart';

abstract class ScrollContext {
  BuildContext? get notificationContext;

  // TODO(goderbauer): Deprecate this when state restoration supports all features of PageStorage.
  BuildContext get storageContext;

  TickerProvider get vsync;

  AxisDirection get axisDirection;

  double get devicePixelRatio;

  void setIgnorePointer(bool value);

  void setCanDrag(bool value);

  void setSemanticsActions(Set<SemanticsAction> actions);

  void saveOffset(double offset);
}