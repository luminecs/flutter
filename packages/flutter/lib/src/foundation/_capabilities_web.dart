// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:js_interop';

// This value is set by the engine. It is used to determine if the application is
// using canvaskit.
@JS('window.flutterCanvasKit')
external JSAny? get _windowFlutterCanvasKit;

bool get isCanvasKit => _windowFlutterCanvasKit != null;