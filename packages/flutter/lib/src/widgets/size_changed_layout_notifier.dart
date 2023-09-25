// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/rendering.dart';

import 'framework.dart';
import 'notification_listener.dart';

class SizeChangedLayoutNotification extends LayoutChangedNotification {
  const SizeChangedLayoutNotification();
}

class SizeChangedLayoutNotifier extends SingleChildRenderObjectWidget {
  const SizeChangedLayoutNotifier({
    super.key,
    super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSizeChangedWithCallback(
      onLayoutChangedCallback: () {
        const SizeChangedLayoutNotification().dispatch(context);
      },
    );
  }
}

class _RenderSizeChangedWithCallback extends RenderProxyBox {
  _RenderSizeChangedWithCallback({
    RenderBox? child,
    required this.onLayoutChangedCallback,
  }) : super(child);

  // There's a 1:1 relationship between the _RenderSizeChangedWithCallback and
  // the `context` that is captured by the closure created by createRenderObject
  // above to assign to onLayoutChangedCallback, and thus we know that the
  // onLayoutChangedCallback will never change nor need to change.

  final VoidCallback onLayoutChangedCallback;

  Size? _oldSize;

  @override
  void performLayout() {
    super.performLayout();
    // Don't send the initial notification, or this will be SizeObserver all
    // over again!
    if (_oldSize != null && size != _oldSize) {
      onLayoutChangedCallback();
    }
    _oldSize = size;
  }
}