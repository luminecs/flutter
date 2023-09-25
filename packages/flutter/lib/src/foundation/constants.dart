// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

const bool kReleaseMode = bool.fromEnvironment('dart.vm.product');

const bool kProfileMode = bool.fromEnvironment('dart.vm.profile');

const bool kDebugMode = !kReleaseMode && !kProfileMode;

const double precisionErrorTolerance = 1e-10;

const bool kIsWeb = bool.fromEnvironment('dart.library.js_util');