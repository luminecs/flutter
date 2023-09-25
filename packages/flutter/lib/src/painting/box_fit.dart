// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'basic_types.dart';

enum BoxFit {
  fill,

  contain,

  cover,

  fitWidth,

  fitHeight,

  none,

  scaleDown,
}

@immutable
class FittedSizes {
  const FittedSizes(this.source, this.destination);

  final Size source;

  final Size destination;
}

FittedSizes applyBoxFit(BoxFit fit, Size inputSize, Size outputSize) {
  if (inputSize.height <= 0.0 || inputSize.width <= 0.0 || outputSize.height <= 0.0 || outputSize.width <= 0.0) {
    return const FittedSizes(Size.zero, Size.zero);
  }

  Size sourceSize, destinationSize;
  switch (fit) {
    case BoxFit.fill:
      sourceSize = inputSize;
      destinationSize = outputSize;
    case BoxFit.contain:
      sourceSize = inputSize;
      if (outputSize.width / outputSize.height > sourceSize.width / sourceSize.height) {
        destinationSize = Size(sourceSize.width * outputSize.height / sourceSize.height, outputSize.height);
      } else {
        destinationSize = Size(outputSize.width, sourceSize.height * outputSize.width / sourceSize.width);
      }
    case BoxFit.cover:
      if (outputSize.width / outputSize.height > inputSize.width / inputSize.height) {
        sourceSize = Size(inputSize.width, inputSize.width * outputSize.height / outputSize.width);
      } else {
        sourceSize = Size(inputSize.height * outputSize.width / outputSize.height, inputSize.height);
      }
      destinationSize = outputSize;
    case BoxFit.fitWidth:
      if (outputSize.width / outputSize.height > inputSize.width / inputSize.height) {
        // Like "cover"
        sourceSize = Size(inputSize.width, inputSize.width * outputSize.height / outputSize.width);
        destinationSize = outputSize;
      } else {
        // Like "contain"
        sourceSize = inputSize;
        destinationSize = Size(outputSize.width, sourceSize.height * outputSize.width / sourceSize.width);
      }
    case BoxFit.fitHeight:
      if (outputSize.width / outputSize.height > inputSize.width / inputSize.height) {
        // Like "contain"
        sourceSize = inputSize;
        destinationSize = Size(sourceSize.width * outputSize.height / sourceSize.height, outputSize.height);
      } else {
        // Like "cover"
        sourceSize = Size(inputSize.height * outputSize.width / outputSize.height, inputSize.height);
        destinationSize = outputSize;
      }
    case BoxFit.none:
      sourceSize = Size(math.min(inputSize.width, outputSize.width), math.min(inputSize.height, outputSize.height));
      destinationSize = sourceSize;
    case BoxFit.scaleDown:
      sourceSize = inputSize;
      destinationSize = inputSize;
      final double aspectRatio = inputSize.width / inputSize.height;
      if (destinationSize.height > outputSize.height) {
        destinationSize = Size(outputSize.height * aspectRatio, outputSize.height);
      }
      if (destinationSize.width > outputSize.width) {
        destinationSize = Size(outputSize.width, outputSize.width / aspectRatio);
      }
  }
  return FittedSizes(sourceSize, destinationSize);
}