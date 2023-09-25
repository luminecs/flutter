// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '_capabilities_io.dart'
  if (dart.library.js_util) '_capabilities_web.dart' as capabilities;

bool get isCanvasKit => capabilities.isCanvasKit;