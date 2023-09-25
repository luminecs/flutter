// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui show PlaceholderAlignment;

import 'package:flutter/foundation.dart';

import 'basic_types.dart';
import 'inline_span.dart';
import 'text_painter.dart';
import 'text_span.dart';
import 'text_style.dart';

abstract class PlaceholderSpan extends InlineSpan {
  const PlaceholderSpan({
    this.alignment = ui.PlaceholderAlignment.bottom,
    this.baseline,
    super.style,
  });

  static const int placeholderCodeUnit = 0xFFFC;

  final ui.PlaceholderAlignment alignment;

  final TextBaseline? baseline;

  @override
  void computeToPlainText(StringBuffer buffer, {bool includeSemanticsLabels = true, bool includePlaceholders = true}) {
    if (includePlaceholders) {
      buffer.writeCharCode(placeholderCodeUnit);
    }
  }

  @override
  void computeSemanticsInformation(List<InlineSpanSemanticsInformation> collector) {
    collector.add(InlineSpanSemanticsInformation.placeholder);
  }

  void describeSemantics(Accumulator offset, List<int> semanticsOffsets, List<dynamic> semanticsElements) {
    semanticsOffsets.add(offset.value);
    semanticsOffsets.add(offset.value + 1);
    semanticsElements.add(null); // null indicates this is a placeholder.
    offset.increment(1);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);

    properties.add(EnumProperty<ui.PlaceholderAlignment>('alignment', alignment, defaultValue: null));
    properties.add(EnumProperty<TextBaseline>('baseline', baseline, defaultValue: null));
  }

  @override
  bool debugAssertIsValid() {
    assert(false, 'Consider implementing the WidgetSpan interface instead.');
    return super.debugAssertIsValid();
  }
}