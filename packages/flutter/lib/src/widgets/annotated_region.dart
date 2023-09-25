// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/rendering.dart';

import 'framework.dart';

class AnnotatedRegion<T extends Object> extends SingleChildRenderObjectWidget {
  const AnnotatedRegion({
    super.key,
    required Widget super.child,
    required this.value,
    this.sized = true,
  });

  final T value;

  final bool sized;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderAnnotatedRegion<T>(value: value, sized: sized);
  }

  @override
  void updateRenderObject(BuildContext context, RenderAnnotatedRegion<T> renderObject) {
    renderObject
      ..value = value
      ..sized = sized;
  }
}