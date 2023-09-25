// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'box.dart';
import 'layer.dart';
import 'object.dart';

class TextureBox extends RenderBox {
  TextureBox({
    required int textureId,
    bool freeze = false,
    FilterQuality filterQuality = FilterQuality.low,
  }) : _textureId = textureId,
      _freeze = freeze,
      _filterQuality = filterQuality;

  int get textureId => _textureId;
  int _textureId;
  set textureId(int value) {
    if (value != _textureId) {
      _textureId = value;
      markNeedsPaint();
    }
  }

  bool get freeze => _freeze;
  bool _freeze;
  set freeze(bool value) {
    if (value != _freeze) {
      _freeze = value;
      markNeedsPaint();
    }
  }

  FilterQuality get filterQuality => _filterQuality;
  FilterQuality _filterQuality;
  set filterQuality(FilterQuality value) {
    if (value != _filterQuality) {
      _filterQuality = value;
      markNeedsPaint();
    }
  }

  @override
  bool get sizedByParent => true;

  @override
  bool get alwaysNeedsCompositing => true;

  @override
  bool get isRepaintBoundary => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return constraints.biggest;
  }

  @override
  bool hitTestSelf(Offset position) => true;

  @override
  void paint(PaintingContext context, Offset offset) {
    context.addLayer(TextureLayer(
      rect: Rect.fromLTWH(offset.dx, offset.dy, size.width, size.height),
      textureId: _textureId,
      freeze: freeze,
      filterQuality: _filterQuality,
    ));
  }
}