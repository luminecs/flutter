// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/animation.dart';

// The easing curves of the Material Library

// TODO(guidezpl): deprecate the three curves below once customers (packages/plugins) are migrated

const Curve standardEasing = Curves.fastOutSlowIn;

const Curve accelerateEasing = Cubic(0.4, 0.0, 1.0, 1.0);

const Curve decelerateEasing = Cubic(0.0, 0.0, 0.2, 1.0);