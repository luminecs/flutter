
import 'dart:math' as math;

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';

import 'text_input.dart';

export 'package:flutter/foundation.dart' show TargetPlatform;

export 'text_input.dart' show TextEditingValue;

// Examples can assume:
// late RegExp _pattern;

enum MaxLengthEnforcement {
  none,

  enforced,

  truncateAfterCompositionEnds,
}

abstract class TextInputFormatter {
  const TextInputFormatter();

  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  );

  static TextInputFormatter withFunction(
    TextInputFormatFunction formatFunction,
  ) {
    return _SimpleTextInputFormatter(formatFunction);
  }
}

typedef TextInputFormatFunction = TextEditingValue Function(
  TextEditingValue oldValue,
  TextEditingValue newValue,
);

class _SimpleTextInputFormatter extends TextInputFormatter {
  _SimpleTextInputFormatter(this.formatFunction);

  final TextInputFormatFunction formatFunction;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return formatFunction(oldValue, newValue);
  }
}

// A mutable, half-open range [`base`, `extent`) within a string.
class _MutableTextRange {
  _MutableTextRange(this.base, this.extent);

  static _MutableTextRange? fromComposingRange(TextRange range) {
    return range.isValid && !range.isCollapsed
      ? _MutableTextRange(range.start, range.end)
      : null;
  }

  static _MutableTextRange? fromTextSelection(TextSelection selection) {
    return selection.isValid
      ? _MutableTextRange(selection.baseOffset, selection.extentOffset)
      : null;
  }

  int base;

  int extent;
}

// The intermediate state of a [FilteringTextInputFormatter] when it's
// formatting a new user input.
class _TextEditingValueAccumulator {
  _TextEditingValueAccumulator(this.inputValue)
    : selection = _MutableTextRange.fromTextSelection(inputValue.selection),
      composingRegion = _MutableTextRange.fromComposingRange(inputValue.composing);

  // The original string that was sent to the [FilteringTextInputFormatter] as
  // input.
  final TextEditingValue inputValue;

  final StringBuffer stringBuffer = StringBuffer();

  final _MutableTextRange? selection;

  final _MutableTextRange? composingRegion;

  // Whether this state object has reached its end-of-life.
  bool debugFinalized = false;

  TextEditingValue finalize() {
    debugFinalized = true;
    final _MutableTextRange? selection = this.selection;
    final _MutableTextRange? composingRegion = this.composingRegion;
    return TextEditingValue(
      text: stringBuffer.toString(),
      composing: composingRegion == null || composingRegion.base == composingRegion.extent
          ? TextRange.empty
          : TextRange(start: composingRegion.base, end: composingRegion.extent),
      selection: selection == null
          ? const TextSelection.collapsed(offset: -1)
          : TextSelection(
              baseOffset: selection.base,
              extentOffset: selection.extent,
              // Try to preserve the selection affinity and isDirectional. This
              // may not make sense if the selection has changed.
              affinity: inputValue.selection.affinity,
              isDirectional: inputValue.selection.isDirectional,
            ),
    );
  }
}

class FilteringTextInputFormatter extends TextInputFormatter {
  // TODO(goderbauer): Cannot link to the constructor because of https://github.com/dart-lang/dartdoc/issues/2276.
  FilteringTextInputFormatter(
    this.filterPattern, {
    required this.allow,
    this.replacementString = '',
  });

  FilteringTextInputFormatter.allow(
    Pattern filterPattern, {
    String replacementString = '',
  }) : this(filterPattern, allow: true, replacementString: replacementString);

  FilteringTextInputFormatter.deny(
    Pattern filterPattern, {
    String replacementString = '',
  }) : this(filterPattern, allow: false, replacementString: replacementString);

  final Pattern filterPattern;

  final bool allow;

  final String replacementString;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue, // unused.
    TextEditingValue newValue,
  ) {
    final _TextEditingValueAccumulator formatState = _TextEditingValueAccumulator(newValue);
    assert(!formatState.debugFinalized);

    final Iterable<Match> matches = filterPattern.allMatches(newValue.text);
    Match? previousMatch;
    for (final Match match in matches) {
      assert(match.end >= match.start);
      // Compute the non-match region between this `Match` and the previous
      // `Match`. Depending on the value of `allow`, either the match region or
      // the non-match region is the banned pattern.
      //
      // The non-matching region.
      _processRegion(allow, previousMatch?.end ?? 0, match.start, formatState);
      assert(!formatState.debugFinalized);
      // The matched region.
      _processRegion(!allow, match.start, match.end, formatState);
      assert(!formatState.debugFinalized);

      previousMatch = match;
    }

    // Handle the last non-matching region between the last match region and the
    // end of the text.
    _processRegion(allow, previousMatch?.end ?? 0, newValue.text.length, formatState);
    assert(!formatState.debugFinalized);
    return formatState.finalize();
  }

  void _processRegion(bool isBannedRegion, int regionStart, int regionEnd, _TextEditingValueAccumulator state) {
    final String replacementString = isBannedRegion
      ? (regionStart == regionEnd ? '' : this.replacementString)
      : state.inputValue.text.substring(regionStart, regionEnd);

    state.stringBuffer.write(replacementString);

    if (replacementString.length == regionEnd - regionStart) {
      // We don't have to adjust the indices if the replaced string and the
      // replacement string have the same length.
      return;
    }

    int adjustIndex(int originalIndex) {
      // The length added by adding the replacementString.
      final int replacedLength = originalIndex <= regionStart && originalIndex < regionEnd ? 0 : replacementString.length;
      // The length removed by removing the replacementRange.
      final int removedLength = originalIndex.clamp(regionStart, regionEnd) - regionStart; // ignore_clamp_double_lint
      return replacedLength - removedLength;
    }

    state.selection?.base += adjustIndex(state.inputValue.selection.baseOffset);
    state.selection?.extent += adjustIndex(state.inputValue.selection.extentOffset);
    state.composingRegion?.base += adjustIndex(state.inputValue.composing.start);
    state.composingRegion?.extent += adjustIndex(state.inputValue.composing.end);
  }

  static final TextInputFormatter singleLineFormatter = FilteringTextInputFormatter.deny('\n');

  static final TextInputFormatter digitsOnly = FilteringTextInputFormatter.allow(RegExp(r'[0-9]'));
}

class LengthLimitingTextInputFormatter extends TextInputFormatter {
  LengthLimitingTextInputFormatter(
    this.maxLength, {
    this.maxLengthEnforcement,
  }) : assert(maxLength == null || maxLength == -1 || maxLength > 0);

  final int? maxLength;

  final MaxLengthEnforcement? maxLengthEnforcement;

  static MaxLengthEnforcement getDefaultMaxLengthEnforcement([
    TargetPlatform? platform,
  ]) {
    if (kIsWeb) {
      return MaxLengthEnforcement.truncateAfterCompositionEnds;
    } else {
      switch (platform ?? defaultTargetPlatform) {
        case TargetPlatform.android:
        case TargetPlatform.windows:
          return MaxLengthEnforcement.enforced;
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
        case TargetPlatform.linux:
        case TargetPlatform.fuchsia:
          return MaxLengthEnforcement.truncateAfterCompositionEnds;
      }
    }
  }

  @visibleForTesting
  static TextEditingValue truncate(TextEditingValue value, int maxLength) {
    final CharacterRange iterator = CharacterRange(value.text);
    if (value.text.characters.length > maxLength) {
      iterator.expandNext(maxLength);
    }
    final String truncated = iterator.current;

    return TextEditingValue(
      text: truncated,
      selection: value.selection.copyWith(
        baseOffset: math.min(value.selection.start, truncated.length),
        extentOffset: math.min(value.selection.end, truncated.length),
      ),
      composing: !value.composing.isCollapsed && truncated.length > value.composing.start
        ? TextRange(
            start: value.composing.start,
            end: math.min(value.composing.end, truncated.length),
          )
        : TextRange.empty,
    );
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final int? maxLength = this.maxLength;

    if (maxLength == null ||
      maxLength == -1 ||
      newValue.text.characters.length <= maxLength) {
      return newValue;
    }

    assert(maxLength > 0);

    switch (maxLengthEnforcement ?? getDefaultMaxLengthEnforcement()) {
      case MaxLengthEnforcement.none:
        return newValue;
      case MaxLengthEnforcement.enforced:
        // If already at the maximum and tried to enter even more, and has no
        // selection, keep the old value.
        if (oldValue.text.characters.length == maxLength && oldValue.selection.isCollapsed) {
          return oldValue;
        }

        // Enforced to return a truncated value.
        return truncate(newValue, maxLength);
      case MaxLengthEnforcement.truncateAfterCompositionEnds:
        // If already at the maximum and tried to enter even more, and the old
        // value is not composing, keep the old value.
        if (oldValue.text.characters.length == maxLength &&
          !oldValue.composing.isValid) {
          return oldValue;
        }

        // Temporarily exempt `newValue` from the maxLength limit if it has a
        // composing text going and no enforcement to the composing value, until
        // the composing is finished.
        if (newValue.composing.isValid) {
          return newValue;
        }

        return truncate(newValue, maxLength);
    }
  }
}