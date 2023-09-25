// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math';

import 'package:characters/characters.dart' show CharacterRange;

import 'text_layout_metrics.dart';

// Examples can assume:
// late TextLayoutMetrics textLayout;
// late TextSpan text;
// bool isWhitespace(int? codeUnit) => true;

typedef UntilPredicate = bool Function(int offset, bool forward);

abstract class TextBoundary {
  const TextBoundary();

  int? getLeadingTextBoundaryAt(int position) {
    if (position < 0) {
      return null;
    }
    final int start = getTextBoundaryAt(position).start;
    return start >= 0 ? start : null;
  }

  int? getTrailingTextBoundaryAt(int position) {
    final int end = getTextBoundaryAt(max(0, position)).end;
    return end >= 0 ? end : null;
  }

  TextRange getTextBoundaryAt(int position) {
    final int start = getLeadingTextBoundaryAt(position) ?? -1;
    final int end = getTrailingTextBoundaryAt(position) ?? -1;
    return TextRange(start: start, end: end);
  }
}

class CharacterBoundary extends TextBoundary {
  const CharacterBoundary(this._text);

  final String _text;

  @override
  int? getLeadingTextBoundaryAt(int position) {
    if (position < 0) {
      return null;
    }
    final int graphemeStart = CharacterRange.at(_text, min(position, _text.length)).stringBeforeLength;
    assert(CharacterRange.at(_text, graphemeStart).isEmpty);
    return graphemeStart;
  }

  @override
  int? getTrailingTextBoundaryAt(int position) {
    if (position >= _text.length) {
      return null;
    }
    final CharacterRange rangeAtPosition = CharacterRange.at(_text, max(0, position + 1));
    final int nextBoundary = rangeAtPosition.stringBeforeLength + rangeAtPosition.current.length;
    assert(nextBoundary == _text.length || CharacterRange.at(_text, nextBoundary).isEmpty);
    return nextBoundary;
  }

  @override
  TextRange getTextBoundaryAt(int position) {
    if (position < 0) {
      return TextRange(start: -1, end: getTrailingTextBoundaryAt(position) ?? -1);
    } else if (position >= _text.length) {
      return TextRange(start: getLeadingTextBoundaryAt(position) ?? -1, end: -1);
    }
    final CharacterRange rangeAtPosition = CharacterRange.at(_text, position);
    return rangeAtPosition.isNotEmpty
      ? TextRange(start: rangeAtPosition.stringBeforeLength, end: rangeAtPosition.stringBeforeLength + rangeAtPosition.current.length)
      // rangeAtPosition is empty means `position` is a grapheme boundary.
      : TextRange(start: rangeAtPosition.stringBeforeLength, end: getTrailingTextBoundaryAt(position) ?? -1);
  }
}

class LineBoundary extends TextBoundary {
  const LineBoundary(this._textLayout);

  final TextLayoutMetrics _textLayout;

  @override
  TextRange getTextBoundaryAt(int position) => _textLayout.getLineAtOffset(TextPosition(offset: max(position, 0)));
}

class ParagraphBoundary extends TextBoundary {
  const ParagraphBoundary(this._text);

  final String _text;

  @override
  int? getLeadingTextBoundaryAt(int position) {
    if (position < 0 || _text.isEmpty) {
      return null;
    }

    if (position >= _text.length) {
      return _text.length;
    }

    if (position == 0) {
      return 0;
    }

    int index = position;

    if (index > 1 && _text.codeUnitAt(index) == 0x0A && _text.codeUnitAt(index - 1) == 0x0D) {
      index -= 2;
    } else if (TextLayoutMetrics.isLineTerminator(_text.codeUnitAt(index))) {
      index -= 1;
    }

    while (index > 0) {
      if (TextLayoutMetrics.isLineTerminator(_text.codeUnitAt(index))) {
        return index + 1;
      }
      index -= 1;
    }

    return max(index, 0);
  }

  @override
  int? getTrailingTextBoundaryAt(int position) {
    if (position >= _text.length || _text.isEmpty) {
      return null;
    }

    if (position < 0) {
      return 0;
    }

    int index = position;

    while (!TextLayoutMetrics.isLineTerminator(_text.codeUnitAt(index))) {
      index += 1;
      if (index == _text.length) {
        return index;
      }
    }

    return index < _text.length - 1
                && _text.codeUnitAt(index) == 0x0D
                && _text.codeUnitAt(index + 1) == 0x0A
                ? index + 2
                : index + 1;
  }
}

class DocumentBoundary extends TextBoundary {
  const DocumentBoundary(this._text);

  final String _text;

  @override
  int? getLeadingTextBoundaryAt(int position) => position < 0 ? null : 0;
  @override
  int? getTrailingTextBoundaryAt(int position) => position >= _text.length ? null : _text.length;
}