// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show TextDirection;

export 'dart:ui' show
  BlendMode,
  BlurStyle,
  Canvas,
  Clip,
  Color,
  ColorFilter,
  FilterQuality,
  FontStyle,
  FontWeight,
  ImageShader,
  Locale,
  MaskFilter,
  Offset,
  Paint,
  PaintingStyle,
  Path,
  PathFillType,
  PathOperation,
  RRect,
  RSTransform,
  Radius,
  Rect,
  Shader,
  Size,
  StrokeCap,
  StrokeJoin,
  TextAffinity,
  TextAlign,
  TextBaseline,
  TextBox,
  TextDecoration,
  TextDecorationStyle,
  TextDirection,
  TextPosition,
  TileMode,
  VertexMode,
  // TODO(werainkhatri): remove these after their deprecation period in engine
  // https://github.com/flutter/flutter/pull/99505
  hashList, // ignore: deprecated_member_use
  hashValues; // ignore: deprecated_member_use

export 'package:flutter/foundation.dart' show VoidCallback;

// Intentionally not exported:
//  - Image, instantiateImageCodec, decodeImageFromList:
//      We use ui.* to make it very explicit that these are low-level image APIs.
//      Generally, higher layers provide more reasonable APIs around images.
//  - lerpDouble:
//      Hopefully this will eventually become Double.lerp.
//  - Paragraph, ParagraphBuilder, ParagraphStyle, TextBox:
//      These are low-level text primitives. Use this package's TextPainter API.
//  - Picture, PictureRecorder, Scene, SceneBuilder:
//      These are low-level primitives. Generally, the rendering layer makes these moot.
//  - Gradient:
//      Use this package's higher-level Gradient API instead.
//  - window, WindowPadding
//      These are generally wrapped by other APIs so we always refer to them directly
//      as ui.* to avoid making them seem like high-level APIs.

enum RenderComparison {
  identical,

  metadata,

  paint,

  layout,
}

enum Axis {
  horizontal,

  vertical,
}

Axis flipAxis(Axis direction) {
  switch (direction) {
    case Axis.horizontal:
      return Axis.vertical;
    case Axis.vertical:
      return Axis.horizontal;
  }
}

enum VerticalDirection {
  up,

  down,
}

enum AxisDirection {
  up,

  right,

  down,

  left,
}

Axis axisDirectionToAxis(AxisDirection axisDirection) {
  switch (axisDirection) {
    case AxisDirection.up:
    case AxisDirection.down:
      return Axis.vertical;
    case AxisDirection.left:
    case AxisDirection.right:
      return Axis.horizontal;
  }
}

AxisDirection textDirectionToAxisDirection(TextDirection textDirection) {
  switch (textDirection) {
    case TextDirection.rtl:
      return AxisDirection.left;
    case TextDirection.ltr:
      return AxisDirection.right;
  }
}

AxisDirection flipAxisDirection(AxisDirection axisDirection) {
  switch (axisDirection) {
    case AxisDirection.up:
      return AxisDirection.down;
    case AxisDirection.right:
      return AxisDirection.left;
    case AxisDirection.down:
      return AxisDirection.up;
    case AxisDirection.left:
      return AxisDirection.right;
  }
}

bool axisDirectionIsReversed(AxisDirection axisDirection) {
  switch (axisDirection) {
    case AxisDirection.up:
    case AxisDirection.left:
      return true;
    case AxisDirection.down:
    case AxisDirection.right:
      return false;
  }
}