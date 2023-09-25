// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final MemoryAllocations ma = MemoryAllocations.instance;

  setUp(() {
    assert(!ma.hasListeners);
  });

  testWidgets(
    '$MemoryAllocations is noop when kFlutterMemoryAllocationsEnabled is false.',
    (WidgetTester tester) async {
      ObjectEvent? receivedEvent;
      ObjectEvent listener(ObjectEvent event) => receivedEvent = event;

      ma.addListener(listener);
      expect(ma.hasListeners, isFalse);

      await _activateFlutterObjects(tester);
      expect(receivedEvent, isNull);
      expect(ma.hasListeners, isFalse);

      ma.removeListener(listener);
    },
  );
}

class _TestRenderObject extends RenderObject {
  @override
  void debugAssertDoesMeetConstraints() {}

  @override
  Rect get paintBounds => throw UnimplementedError();

  @override
  void performLayout() {}

  @override
  void performResize() {}

  @override
  Rect get semanticBounds => throw UnimplementedError();
}

class _TestLayer extends Layer{
  @override
  void addToScene(SceneBuilder builder) {}
}

Future<void> _activateFlutterObjects(WidgetTester tester) async {
  final RenderObject renderObject = _TestRenderObject();
  final Layer layer = _TestLayer();

  renderObject.dispose();
  // It is ok to use protected members for testing.
  // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
  layer.dispose();
}