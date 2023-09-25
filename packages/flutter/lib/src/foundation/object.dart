// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

String objectRuntimeType(Object? object, String optimizedValue) {
  assert(() {
    optimizedValue = object.runtimeType.toString();
    return true;
  }());
  return optimizedValue;
}