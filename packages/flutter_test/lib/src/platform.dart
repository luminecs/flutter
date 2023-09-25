// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

const bool isBrowser = identical(0, 0.0);

bool get isWindows {
  if (isBrowser) {
    return false;
  }
  return Platform.isWindows;
}

bool get isMacOS {
  if (isBrowser) {
    return false;
  }
  return Platform.isMacOS;
}

bool get isLinux {
  if (isBrowser) {
    return false;
  }
  return Platform.isLinux;
}