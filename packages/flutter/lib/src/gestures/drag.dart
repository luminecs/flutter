// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'drag_details.dart';

export 'drag_details.dart' show DragEndDetails, DragUpdateDetails;

abstract class Drag {
  void update(DragUpdateDetails details) { }

  void end(DragEndDetails details) { }

  void cancel() { }
}