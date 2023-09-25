// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/rendering.dart';
import 'framework.dart';

class Texture extends LeafRenderObjectWidget {
  const Texture({
    super.key,
    required this.textureId,
    this.freeze = false,
    this.filterQuality = FilterQuality.low,
  });

  final int textureId;

  final bool freeze;

  final FilterQuality filterQuality;

  @override
  TextureBox createRenderObject(BuildContext context) => TextureBox(textureId: textureId, freeze: freeze, filterQuality: filterQuality);

  @override
  void updateRenderObject(BuildContext context, TextureBox renderObject) {
    renderObject.textureId = textureId;
    renderObject.freeze = freeze;
    renderObject.filterQuality = filterQuality;
  }
}