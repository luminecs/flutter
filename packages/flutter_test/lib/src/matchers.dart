// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Card;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:matcher/expect.dart';
import 'package:matcher/src/expect/async_matcher.dart'; // ignore: implementation_imports
import 'package:vector_math/vector_math_64.dart' show Matrix3;

import '_matchers_io.dart' if (dart.library.html) '_matchers_web.dart' show MatchesGoldenFile, captureImage;
import 'accessibility.dart';
import 'binding.dart';
import 'controller.dart';
import 'finders.dart';
import 'goldens.dart';
import 'widget_tester.dart' show WidgetTester;

const Matcher findsNothing = _FindsCountMatcher(null, 0);

const Matcher findsWidgets = _FindsCountMatcher(1, null);

const Matcher findsAny = _FindsCountMatcher(1, null);

const Matcher findsOneWidget = _FindsCountMatcher(1, 1);

const Matcher findsOne = _FindsCountMatcher(1, 1);

Matcher findsNWidgets(int n) => _FindsCountMatcher(n, n);

Matcher findsExactly(int n) => _FindsCountMatcher(n, n);

Matcher findsAtLeastNWidgets(int n) => _FindsCountMatcher(n, null);

Matcher findsAtLeast(int n) => _FindsCountMatcher(n, null);

const Matcher isOffstage = _IsOffstage();

const Matcher isOnstage = _IsOnstage();

const Matcher isInCard = _IsInCard();

const Matcher isNotInCard = _IsNotInCard();

Matcher isSameColorAs(Color color) => _ColorMatcher(targetColor: color);

const Matcher hasOneLineDescription = _HasOneLineDescription();

const Matcher hasAGoodToStringDeep = _HasGoodToStringDeep();

final Matcher throwsFlutterError = throwsA(isFlutterError);

final Matcher throwsAssertionError = throwsA(isAssertionError);

final TypeMatcher<FlutterError> isFlutterError = isA<FlutterError>();

final TypeMatcher<AssertionError> isAssertionError = isA<AssertionError>();

TypeMatcher<T> isInstanceOf<T>() => isA<T>();

Matcher moreOrLessEquals(double value, { double epsilon = precisionErrorTolerance }) {
  return _MoreOrLessEquals(value, epsilon);
}

Matcher rectMoreOrLessEquals(Rect value, { double epsilon = precisionErrorTolerance }) {
  return _IsWithinDistance<Rect>(_rectDistance, value, epsilon);
}

Matcher matrixMoreOrLessEquals(Matrix4 value, { double epsilon = precisionErrorTolerance }) {
  return _IsWithinDistance<Matrix4>(_matrixDistance, value, epsilon);
}

Matcher matrix3MoreOrLessEquals(Matrix3 value, { double epsilon = precisionErrorTolerance }) {
  return _IsWithinDistance<Matrix3>(_matrix3Distance, value, epsilon);
}

Matcher offsetMoreOrLessEquals(Offset value, { double epsilon = precisionErrorTolerance }) {
  return _IsWithinDistance<Offset>(_offsetDistance, value, epsilon);
}

Matcher equalsIgnoringHashCodes(Object value) {
  assert(value is String || value is Iterable<String>, "Only String or Iterable<String> are allowed types for equalsIgnoringHashCodes, it doesn't accept ${value.runtimeType}");
  return _EqualsIgnoringHashCodes(value);
}

Matcher isMethodCall(String name, { required dynamic arguments }) {
  return _IsMethodCall(name, arguments);
}

Matcher coversSameAreaAs(Path expectedPath, { required Rect areaToCompare, int sampleSize = 20 })
  => _CoversSameAreaAs(expectedPath, areaToCompare: areaToCompare, sampleSize: sampleSize);

// Examples can assume:
// late Image image;
// late Future<Image> imageFuture;
// typedef MyWidget = Placeholder;
// late Future<ByteData> someFont;
// late WidgetTester tester;

AsyncMatcher matchesGoldenFile(Object key, {int? version}) {
  if (key is Uri) {
    return MatchesGoldenFile(key, version);
  } else if (key is String) {
    return MatchesGoldenFile.forStringPath(key, version);
  }
  throw ArgumentError('Unexpected type for golden file: ${key.runtimeType}');
}

AsyncMatcher matchesReferenceImage(ui.Image image) {
  return _MatchesReferenceImage(image);
}

Matcher matchesSemantics({
  String? label,
  AttributedString? attributedLabel,
  String? hint,
  AttributedString? attributedHint,
  String? value,
  AttributedString? attributedValue,
  String? increasedValue,
  AttributedString? attributedIncreasedValue,
  String? decreasedValue,
  AttributedString? attributedDecreasedValue,
  String? tooltip,
  TextDirection? textDirection,
  Rect? rect,
  Size? size,
  double? elevation,
  double? thickness,
  int? platformViewId,
  int? maxValueLength,
  int? currentValueLength,
  // Flags //
  bool hasCheckedState = false,
  bool isChecked = false,
  bool isCheckStateMixed = false,
  bool isSelected = false,
  bool isButton = false,
  bool isSlider = false,
  bool isKeyboardKey = false,
  bool isLink = false,
  bool isFocused = false,
  bool isFocusable = false,
  bool isTextField = false,
  bool isReadOnly = false,
  bool hasEnabledState = false,
  bool isEnabled = false,
  bool isInMutuallyExclusiveGroup = false,
  bool isHeader = false,
  bool isObscured = false,
  bool isMultiline = false,
  bool namesRoute = false,
  bool scopesRoute = false,
  bool isHidden = false,
  bool isImage = false,
  bool isLiveRegion = false,
  bool hasToggledState = false,
  bool isToggled = false,
  bool hasImplicitScrolling = false,
  bool hasExpandedState = false,
  bool isExpanded = false,
  // Actions //
  bool hasTapAction = false,
  bool hasLongPressAction = false,
  bool hasScrollLeftAction = false,
  bool hasScrollRightAction = false,
  bool hasScrollUpAction = false,
  bool hasScrollDownAction = false,
  bool hasIncreaseAction = false,
  bool hasDecreaseAction = false,
  bool hasShowOnScreenAction = false,
  bool hasMoveCursorForwardByCharacterAction = false,
  bool hasMoveCursorBackwardByCharacterAction = false,
  bool hasMoveCursorForwardByWordAction = false,
  bool hasMoveCursorBackwardByWordAction = false,
  bool hasSetTextAction = false,
  bool hasSetSelectionAction = false,
  bool hasCopyAction = false,
  bool hasCutAction = false,
  bool hasPasteAction = false,
  bool hasDidGainAccessibilityFocusAction = false,
  bool hasDidLoseAccessibilityFocusAction = false,
  bool hasDismissAction = false,
  // Custom actions and overrides
  String? onTapHint,
  String? onLongPressHint,
  List<CustomSemanticsAction>? customActions,
  List<Matcher>? children,
}) {
  return _MatchesSemanticsData(
    label: label,
    attributedLabel: attributedLabel,
    hint: hint,
    attributedHint: attributedHint,
    value: value,
    attributedValue: attributedValue,
    increasedValue: increasedValue,
    attributedIncreasedValue: attributedIncreasedValue,
    decreasedValue: decreasedValue,
    attributedDecreasedValue: attributedDecreasedValue,
    tooltip: tooltip,
    textDirection: textDirection,
    rect: rect,
    size: size,
    elevation: elevation,
    thickness: thickness,
    platformViewId: platformViewId,
    customActions: customActions,
    maxValueLength: maxValueLength,
    currentValueLength: currentValueLength,
    // Flags
    hasCheckedState: hasCheckedState,
    isChecked: isChecked,
    isCheckStateMixed: isCheckStateMixed,
    isSelected: isSelected,
    isButton: isButton,
    isSlider: isSlider,
    isKeyboardKey: isKeyboardKey,
    isLink: isLink,
    isFocused: isFocused,
    isFocusable: isFocusable,
    isTextField: isTextField,
    isReadOnly: isReadOnly,
    hasEnabledState: hasEnabledState,
    isEnabled: isEnabled,
    isInMutuallyExclusiveGroup: isInMutuallyExclusiveGroup,
    isHeader: isHeader,
    isObscured: isObscured,
    isMultiline: isMultiline,
    namesRoute: namesRoute,
    scopesRoute: scopesRoute,
    isHidden: isHidden,
    isImage: isImage,
    isLiveRegion: isLiveRegion,
    hasToggledState: hasToggledState,
    isToggled: isToggled,
    hasImplicitScrolling: hasImplicitScrolling,
    hasExpandedState: hasExpandedState,
    isExpanded: isExpanded,
    // Actions
    hasTapAction: hasTapAction,
    hasLongPressAction: hasLongPressAction,
    hasScrollLeftAction: hasScrollLeftAction,
    hasScrollRightAction: hasScrollRightAction,
    hasScrollUpAction: hasScrollUpAction,
    hasScrollDownAction: hasScrollDownAction,
    hasIncreaseAction: hasIncreaseAction,
    hasDecreaseAction: hasDecreaseAction,
    hasShowOnScreenAction: hasShowOnScreenAction,
    hasMoveCursorForwardByCharacterAction: hasMoveCursorForwardByCharacterAction,
    hasMoveCursorBackwardByCharacterAction: hasMoveCursorBackwardByCharacterAction,
    hasMoveCursorForwardByWordAction: hasMoveCursorForwardByWordAction,
    hasMoveCursorBackwardByWordAction: hasMoveCursorBackwardByWordAction,
    hasSetTextAction: hasSetTextAction,
    hasSetSelectionAction: hasSetSelectionAction,
    hasCopyAction: hasCopyAction,
    hasCutAction: hasCutAction,
    hasPasteAction: hasPasteAction,
    hasDidGainAccessibilityFocusAction: hasDidGainAccessibilityFocusAction,
    hasDidLoseAccessibilityFocusAction: hasDidLoseAccessibilityFocusAction,
    hasDismissAction: hasDismissAction,
    // Custom actions and overrides
    children: children,
    onLongPressHint: onLongPressHint,
    onTapHint: onTapHint,
  );
}

Matcher containsSemantics({
  String? label,
  AttributedString? attributedLabel,
  String? hint,
  AttributedString? attributedHint,
  String? value,
  AttributedString? attributedValue,
  String? increasedValue,
  AttributedString? attributedIncreasedValue,
  String? decreasedValue,
  AttributedString? attributedDecreasedValue,
  String? tooltip,
  TextDirection? textDirection,
  Rect? rect,
  Size? size,
  double? elevation,
  double? thickness,
  int? platformViewId,
  int? maxValueLength,
  int? currentValueLength,
  // Flags
  bool? hasCheckedState,
  bool? isChecked,
  bool? isCheckStateMixed,
  bool? isSelected,
  bool? isButton,
  bool? isSlider,
  bool? isKeyboardKey,
  bool? isLink,
  bool? isFocused,
  bool? isFocusable,
  bool? isTextField,
  bool? isReadOnly,
  bool? hasEnabledState,
  bool? isEnabled,
  bool? isInMutuallyExclusiveGroup,
  bool? isHeader,
  bool? isObscured,
  bool? isMultiline,
  bool? namesRoute,
  bool? scopesRoute,
  bool? isHidden,
  bool? isImage,
  bool? isLiveRegion,
  bool? hasToggledState,
  bool? isToggled,
  bool? hasImplicitScrolling,
  bool? hasExpandedState,
  bool? isExpanded,
  // Actions
  bool? hasTapAction,
  bool? hasLongPressAction,
  bool? hasScrollLeftAction,
  bool? hasScrollRightAction,
  bool? hasScrollUpAction,
  bool? hasScrollDownAction,
  bool? hasIncreaseAction,
  bool? hasDecreaseAction,
  bool? hasShowOnScreenAction,
  bool? hasMoveCursorForwardByCharacterAction,
  bool? hasMoveCursorBackwardByCharacterAction,
  bool? hasMoveCursorForwardByWordAction,
  bool? hasMoveCursorBackwardByWordAction,
  bool? hasSetTextAction,
  bool? hasSetSelectionAction,
  bool? hasCopyAction,
  bool? hasCutAction,
  bool? hasPasteAction,
  bool? hasDidGainAccessibilityFocusAction,
  bool? hasDidLoseAccessibilityFocusAction,
  bool? hasDismissAction,
  // Custom actions and overrides
  String? onTapHint,
  String? onLongPressHint,
  List<CustomSemanticsAction>? customActions,
  List<Matcher>? children,
}) {
  return _MatchesSemanticsData(
    label: label,
    attributedLabel: attributedLabel,
    hint: hint,
    attributedHint: attributedHint,
    value: value,
    attributedValue: attributedValue,
    increasedValue: increasedValue,
    attributedIncreasedValue: attributedIncreasedValue,
    decreasedValue: decreasedValue,
    attributedDecreasedValue: attributedDecreasedValue,
    tooltip: tooltip,
    textDirection: textDirection,
    rect: rect,
    size: size,
    elevation: elevation,
    thickness: thickness,
    platformViewId: platformViewId,
    customActions: customActions,
    maxValueLength: maxValueLength,
    currentValueLength: currentValueLength,
    // Flags
    hasCheckedState: hasCheckedState,
    isChecked: isChecked,
    isCheckStateMixed: isCheckStateMixed,
    isSelected: isSelected,
    isButton: isButton,
    isSlider: isSlider,
    isKeyboardKey: isKeyboardKey,
    isLink: isLink,
    isFocused: isFocused,
    isFocusable: isFocusable,
    isTextField: isTextField,
    isReadOnly: isReadOnly,
    hasEnabledState: hasEnabledState,
    isEnabled: isEnabled,
    isInMutuallyExclusiveGroup: isInMutuallyExclusiveGroup,
    isHeader: isHeader,
    isObscured: isObscured,
    isMultiline: isMultiline,
    namesRoute: namesRoute,
    scopesRoute: scopesRoute,
    isHidden: isHidden,
    isImage: isImage,
    isLiveRegion: isLiveRegion,
    hasToggledState: hasToggledState,
    isToggled: isToggled,
    hasImplicitScrolling: hasImplicitScrolling,
    hasExpandedState: hasExpandedState,
    isExpanded: isExpanded,
    // Actions
    hasTapAction: hasTapAction,
    hasLongPressAction: hasLongPressAction,
    hasScrollLeftAction: hasScrollLeftAction,
    hasScrollRightAction: hasScrollRightAction,
    hasScrollUpAction: hasScrollUpAction,
    hasScrollDownAction: hasScrollDownAction,
    hasIncreaseAction: hasIncreaseAction,
    hasDecreaseAction: hasDecreaseAction,
    hasShowOnScreenAction: hasShowOnScreenAction,
    hasMoveCursorForwardByCharacterAction: hasMoveCursorForwardByCharacterAction,
    hasMoveCursorBackwardByCharacterAction: hasMoveCursorBackwardByCharacterAction,
    hasMoveCursorForwardByWordAction: hasMoveCursorForwardByWordAction,
    hasMoveCursorBackwardByWordAction: hasMoveCursorBackwardByWordAction,
    hasSetTextAction: hasSetTextAction,
    hasSetSelectionAction: hasSetSelectionAction,
    hasCopyAction: hasCopyAction,
    hasCutAction: hasCutAction,
    hasPasteAction: hasPasteAction,
    hasDidGainAccessibilityFocusAction: hasDidGainAccessibilityFocusAction,
    hasDidLoseAccessibilityFocusAction: hasDidLoseAccessibilityFocusAction,
    hasDismissAction: hasDismissAction,
    // Custom actions and overrides
    children: children,
    onLongPressHint: onLongPressHint,
    onTapHint: onTapHint,
  );
}

AsyncMatcher meetsGuideline(AccessibilityGuideline guideline) {
  return _MatchesAccessibilityGuideline(guideline);
}

AsyncMatcher doesNotMeetGuideline(AccessibilityGuideline guideline) {
  return _DoesNotMatchAccessibilityGuideline(guideline);
}

class _FindsCountMatcher extends Matcher {
  const _FindsCountMatcher(this.min, this.max);

  final int? min;
  final int? max;

  @override
  bool matches(covariant FinderBase<dynamic> finder, Map<dynamic, dynamic> matchState) {
    assert(min != null || max != null);
    assert(min == null || max == null || min! <= max!);
    matchState[FinderBase] = finder;
    int count = 0;
    final Iterator<dynamic> iterator = finder.evaluate().iterator;
    if (min != null) {
      while (count < min! && iterator.moveNext()) {
        count += 1;
      }
      if (count < min!) {
        return false;
      }
    }
    if (max != null) {
      while (count <= max! && iterator.moveNext()) {
        count += 1;
      }
      if (count > max!) {
        return false;
      }
    }
    return true;
  }

  @override
  Description describe(Description description) {
    assert(min != null || max != null);
    if (min == max) {
      if (min == 1) {
        return description.add('exactly one matching candidate');
      }
      return description.add('exactly $min matching candidates');
    }
    if (min == null) {
      if (max == 0) {
        return description.add('no matching candidates');
      }
      if (max == 1) {
        return description.add('at most one matching candidate');
      }
      return description.add('at most $max matching candidates');
    }
    if (max == null) {
      if (min == 1) {
        return description.add('at least one matching candidate');
      }
      return description.add('at least $min matching candidates');
    }
    return description.add('between $min and $max matching candidates (inclusive)');
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    final FinderBase<dynamic> finder = matchState[FinderBase] as FinderBase<dynamic>;
    final int count = finder.found.length;
    if (count == 0) {
      assert(min != null && min! > 0);
      if (min == 1 && max == 1) {
        return mismatchDescription.add('means none were found but one was expected');
      }
      return mismatchDescription.add('means none were found but some were expected');
    }
    if (max == 0) {
      if (count == 1) {
        return mismatchDescription.add('means one was found but none were expected');
      }
      return mismatchDescription.add('means some were found but none were expected');
    }
    if (min != null && count < min!) {
      return mismatchDescription.add('is not enough');
    }
    assert(max != null && count > min!);
    return mismatchDescription.add('is too many');
  }
}

bool _hasAncestorMatching(Finder finder, bool Function(Widget widget) predicate) {
  final Iterable<Element> nodes = finder.evaluate();
  if (nodes.length != 1) {
    return false;
  }
  bool result = false;
  nodes.single.visitAncestorElements((Element ancestor) {
    if (predicate(ancestor.widget)) {
      result = true;
      return false;
    }
    return true;
  });
  return result;
}

bool _hasAncestorOfType(Finder finder, Type targetType) {
  return _hasAncestorMatching(finder, (Widget widget) => widget.runtimeType == targetType);
}

class _IsOffstage extends Matcher {
  const _IsOffstage();

  @override
  bool matches(covariant Finder finder, Map<dynamic, dynamic> matchState) {
    return _hasAncestorMatching(finder, (Widget widget) {
      if (widget is Offstage) {
        return widget.offstage;
      }
      return false;
    });
  }

  @override
  Description describe(Description description) => description.add('offstage');
}

class _IsOnstage extends Matcher {
  const _IsOnstage();

  @override
  bool matches(covariant Finder finder, Map<dynamic, dynamic> matchState) {
    final Iterable<Element> nodes = finder.evaluate();
    if (nodes.length != 1) {
      return false;
    }
    bool result = true;
    nodes.single.visitAncestorElements((Element ancestor) {
      final Widget widget = ancestor.widget;
      if (widget is Offstage) {
        result = !widget.offstage;
        return false;
      }
      return true;
    });
    return result;
  }

  @override
  Description describe(Description description) => description.add('onstage');
}

class _IsInCard extends Matcher {
  const _IsInCard();

  @override
  bool matches(covariant Finder finder, Map<dynamic, dynamic> matchState) => _hasAncestorOfType(finder, Card);

  @override
  Description describe(Description description) => description.add('in card');
}

class _IsNotInCard extends Matcher {
  const _IsNotInCard();

  @override
  bool matches(covariant Finder finder, Map<dynamic, dynamic> matchState) => !_hasAncestorOfType(finder, Card);

  @override
  Description describe(Description description) => description.add('not in card');
}

class _HasOneLineDescription extends Matcher {
  const _HasOneLineDescription();

  @override
  bool matches(dynamic object, Map<dynamic, dynamic> matchState) {
    final String description = object.toString();
    return description.isNotEmpty
        && !description.contains('\n')
        && !description.contains('Instance of ')
        && description.trim() == description;
  }

  @override
  Description describe(Description description) => description.add('one line description');
}

class _EqualsIgnoringHashCodes extends Matcher {
  _EqualsIgnoringHashCodes(Object v) : _value = _normalize(v);

  final Object _value;

  static final Object _mismatchedValueKey = Object();

  static String _normalizeString(String value) {
    return value.replaceAll(RegExp(r'#[\da-fA-F]{5}'), '#00000');
  }

  static Object _normalize(Object value, {bool expected = true}) {
    if (value is String) {
      return _normalizeString(value);
    }
    if (value is Iterable<String>) {
      return value.map<String>((dynamic item) => _normalizeString(item.toString()));
    }
    throw ArgumentError('The specified ${expected ? 'expected' : 'comparison'} value for '
        'equalsIgnoringHashCodes must be a String or an Iterable<String>, '
        'not a ${value.runtimeType}');
  }

  @override
  bool matches(dynamic object, Map<dynamic, dynamic> matchState) {
    final Object normalized = _normalize(object as Object, expected: false);
    if (!equals(_value).matches(normalized, matchState)) {
      matchState[_mismatchedValueKey] = normalized;
      return false;
    }
    return true;
  }

  @override
  Description describe(Description description) {
    if (_value is String) {
      return description.add('normalized value matches $_value');
    }
    return description.add('normalized value matches\n').addDescriptionOf(_value);
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (matchState.containsKey(_mismatchedValueKey)) {
      final Object actualValue = matchState[_mismatchedValueKey] as Object;
      // Leading whitespace is added so that lines in the multiline
      // description returned by addDescriptionOf are all indented equally
      // which makes the output easier to read for this case.
      return mismatchDescription
          .add('was expected to be normalized value\n')
          .addDescriptionOf(_value)
          .add('\nbut got\n')
          .addDescriptionOf(actualValue);
    }
    return mismatchDescription;
  }
}

bool _isWhitespace(int c) => (c <= 0x000D && c >= 0x0009) || c == 0x0020;

bool _isVerticalLine(int c) {
  return c == 0x2502 || c == 0x2503 || c == 0x2551 || c == 0x254e;
}

bool _isAllTreeConnectorCharacters(String line) {
  for (int i = 0; i < line.length; ++i) {
    final int c = line.codeUnitAt(i);
    if (!_isWhitespace(c) && !_isVerticalLine(c)) {
      return false;
    }
  }
  return true;
}

class _HasGoodToStringDeep extends Matcher {
  const _HasGoodToStringDeep();

  static final Object _toStringDeepErrorDescriptionKey = Object();

  @override
  bool matches(dynamic object, Map<dynamic, dynamic> matchState) {
    final List<String> issues = <String>[];
    String description = object.toStringDeep() as String; // ignore: avoid_dynamic_calls
    if (description.endsWith('\n')) {
      // Trim off trailing \n as the remaining calculations assume
      // the description does not end with a trailing \n.
      description = description.substring(0, description.length - 1);
    } else {
      issues.add('Not terminated with a line break.');
    }

    if (description.trim() != description) {
      issues.add('Has trailing whitespace.');
    }

    final List<String> lines = description.split('\n');
    if (lines.length < 2) {
      issues.add('Does not have multiple lines.');
    }

    if (description.contains('Instance of ')) {
      issues.add('Contains text "Instance of ".');
    }

    for (int i = 0; i < lines.length; ++i) {
      final String line = lines[i];
      if (line.isEmpty) {
        issues.add('Line ${i + 1} is empty.');
      }

      if (line.trimRight() != line) {
        issues.add('Line ${i + 1} has trailing whitespace.');
      }
    }

    if (_isAllTreeConnectorCharacters(lines.last)) {
      issues.add('Last line is all tree connector characters.');
    }

    // If a toStringDeep method doesn't properly handle nested values that
    // contain line breaks it can fail to add the required prefixes to all
    // lined when toStringDeep is called specifying prefixes.
    const String prefixLineOne = 'PREFIX_LINE_ONE____';
    const String prefixOtherLines = 'PREFIX_OTHER_LINES_';
    final List<String> prefixIssues = <String>[];
    // ignore: avoid_dynamic_calls
    String descriptionWithPrefixes = object.toStringDeep(prefixLineOne: prefixLineOne, prefixOtherLines: prefixOtherLines) as String;
    if (descriptionWithPrefixes.endsWith('\n')) {
      // Trim off trailing \n as the remaining calculations assume
      // the description does not end with a trailing \n.
      descriptionWithPrefixes = descriptionWithPrefixes.substring(
          0, descriptionWithPrefixes.length - 1);
    }
    final List<String> linesWithPrefixes = descriptionWithPrefixes.split('\n');
    if (!linesWithPrefixes.first.startsWith(prefixLineOne)) {
      prefixIssues.add('First line does not contain expected prefix.');
    }

    for (int i = 1; i < linesWithPrefixes.length; ++i) {
      if (!linesWithPrefixes[i].startsWith(prefixOtherLines)) {
        prefixIssues.add('Line ${i + 1} does not contain the expected prefix.');
      }
    }

    final StringBuffer errorDescription = StringBuffer();
    if (issues.isNotEmpty) {
      errorDescription.writeln('Bad toStringDeep():');
      errorDescription.writeln(description);
      errorDescription.writeAll(issues, '\n');
    }

    if (prefixIssues.isNotEmpty) {
      errorDescription.writeln(
          'Bad toStringDeep(prefixLineOne: "$prefixLineOne", prefixOtherLines: "$prefixOtherLines"):');
      errorDescription.writeln(descriptionWithPrefixes);
      errorDescription.writeAll(prefixIssues, '\n');
    }

    if (errorDescription.isNotEmpty) {
      matchState[_toStringDeepErrorDescriptionKey] =
          errorDescription.toString();
      return false;
    }
    return true;
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    if (matchState.containsKey(_toStringDeepErrorDescriptionKey)) {
      return mismatchDescription.add(matchState[_toStringDeepErrorDescriptionKey] as String);
    }
    return mismatchDescription;
  }

  @override
  Description describe(Description description) {
    return description.add('multi line description');
  }
}

typedef DistanceFunction<T> = num Function(T a, T b);

typedef AnyDistanceFunction = num Function(Never a, Never b);

const Map<Type, AnyDistanceFunction> _kStandardDistanceFunctions = <Type, AnyDistanceFunction>{
  Color: _maxComponentColorDistance,
  HSVColor: _maxComponentHSVColorDistance,
  HSLColor: _maxComponentHSLColorDistance,
  Offset: _offsetDistance,
  int: _intDistance,
  double: _doubleDistance,
  Rect: _rectDistance,
  Size: _sizeDistance,
};

int _intDistance(int a, int b) => (b - a).abs();
double _doubleDistance(double a, double b) => (b - a).abs();
double _offsetDistance(Offset a, Offset b) => (b - a).distance;

double _maxComponentColorDistance(Color a, Color b) {
  int delta = math.max<int>((a.red - b.red).abs(), (a.green - b.green).abs());
  delta = math.max<int>(delta, (a.blue - b.blue).abs());
  delta = math.max<int>(delta, (a.alpha - b.alpha).abs());
  return delta.toDouble();
}

// Compares hue by converting it to a 0.0 - 1.0 range, so that the comparison
// can be a similar error percentage per component.
double _maxComponentHSVColorDistance(HSVColor a, HSVColor b) {
  double delta = math.max<double>((a.saturation - b.saturation).abs(), (a.value - b.value).abs());
  delta = math.max<double>(delta, ((a.hue - b.hue) / 360.0).abs());
  return math.max<double>(delta, (a.alpha - b.alpha).abs());
}

// Compares hue by converting it to a 0.0 - 1.0 range, so that the comparison
// can be a similar error percentage per component.
double _maxComponentHSLColorDistance(HSLColor a, HSLColor b) {
  double delta = math.max<double>((a.saturation - b.saturation).abs(), (a.lightness - b.lightness).abs());
  delta = math.max<double>(delta, ((a.hue - b.hue) / 360.0).abs());
  return math.max<double>(delta, (a.alpha - b.alpha).abs());
}

double _rectDistance(Rect a, Rect b) {
  double delta = math.max<double>((a.left - b.left).abs(), (a.top - b.top).abs());
  delta = math.max<double>(delta, (a.right - b.right).abs());
  delta = math.max<double>(delta, (a.bottom - b.bottom).abs());
  return delta;
}

double _matrixDistance(Matrix4 a, Matrix4 b) {
  double delta = 0.0;
  for (int i = 0; i < 16; i += 1) {
    delta = math.max<double>((a[i] - b[i]).abs(), delta);
  }
  return delta;
}

double _matrix3Distance(Matrix3 a, Matrix3 b) {
  double delta = 0.0;
  for (int i = 0; i < 9; i += 1) {
    delta = math.max<double>((a[i] - b[i]).abs(), delta);
  }
  return delta;
}

double _sizeDistance(Size a, Size b) {
  // TODO(a14n): remove ignore when lint is updated, https://github.com/dart-lang/linter/issues/1843
  // ignore: unnecessary_parenthesis
  final Offset delta = (b - a) as Offset;
  return delta.distance;
}

Matcher within<T>({
  required num distance,
  required T from,
  DistanceFunction<T>? distanceFunction,
}) {
  distanceFunction ??= _kStandardDistanceFunctions[T] as DistanceFunction<T>?;

  if (distanceFunction == null) {
    throw ArgumentError(
      'The specified distanceFunction was null, and a standard distance '
      'function was not found for type ${from.runtimeType} of the provided '
      '`from` argument.'
    );
  }

  return _IsWithinDistance<T>(distanceFunction, from, distance);
}

class _IsWithinDistance<T> extends Matcher {
  const _IsWithinDistance(this.distanceFunction, this.value, this.epsilon);

  final DistanceFunction<T> distanceFunction;
  final T value;
  final num epsilon;

  @override
  bool matches(dynamic object, Map<dynamic, dynamic> matchState) {
    if (object is! T) {
      return false;
    }
    if (object == value) {
      return true;
    }
    final num distance = distanceFunction(object, value);
    if (distance < 0) {
      throw ArgumentError(
        'Invalid distance function was used to compare a ${value.runtimeType} '
        'to a ${object.runtimeType}. The function must return a non-negative '
        'double value, but it returned $distance.'
      );
    }
    matchState['distance'] = distance;
    return distance <= epsilon;
  }

  @override
  Description describe(Description description) => description.add('$value (±$epsilon)');

  @override
  Description describeMismatch(
    dynamic object,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    mismatchDescription.add('was ${matchState['distance']} away from the desired value.');
    return mismatchDescription;
  }
}

class _MoreOrLessEquals extends Matcher {
  const _MoreOrLessEquals(this.value, this.epsilon)
    : assert(epsilon >= 0);

  final double value;
  final double epsilon;

  @override
  bool matches(dynamic object, Map<dynamic, dynamic> matchState) {
    if (object is! num) {
      return false;
    }
    if (object == value) {
      return true;
    }
    return (object - value).abs() <= epsilon;
  }

  @override
  Description describe(Description description) => description.add('$value (±$epsilon)');

  @override
  Description describeMismatch(dynamic item, Description mismatchDescription, Map<dynamic, dynamic> matchState, bool verbose) {
    return super.describeMismatch(item, mismatchDescription, matchState, verbose)
      ..add('$item is not in the range of $value (±$epsilon).');
  }
}

class _IsMethodCall extends Matcher {
  const _IsMethodCall(this.name, this.arguments);

  final String name;
  final dynamic arguments;

  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
    if (item is! MethodCall) {
      return false;
    }
    if (item.method != name) {
      return false;
    }
    return _deepEquals(item.arguments, arguments);
  }

  bool _deepEquals(dynamic a, dynamic b) {
    if (a == b) {
      return true;
    }
    if (a is List) {
      return b is List && _deepEqualsList(a, b);
    }
    if (a is Map) {
      return b is Map && _deepEqualsMap(a, b);
    }
    return false;
  }

  bool _deepEqualsList(List<dynamic> a, List<dynamic> b) {
    if (a.length != b.length) {
      return false;
    }
    for (int i = 0; i < a.length; i++) {
      if (!_deepEquals(a[i], b[i])) {
        return false;
      }
    }
    return true;
  }

  bool _deepEqualsMap(Map<dynamic, dynamic> a, Map<dynamic, dynamic> b) {
    if (a.length != b.length) {
      return false;
    }
    for (final dynamic key in a.keys) {
      if (!b.containsKey(key) || !_deepEquals(a[key], b[key])) {
        return false;
      }
    }
    return true;
  }

  @override
  Description describe(Description description) {
    return description
        .add('has method name: ').addDescriptionOf(name)
        .add(' with arguments: ').addDescriptionOf(arguments);
  }
}

const Matcher clipsWithBoundingRect = _ClipsWithBoundingRect();

const Matcher hasNoImmediateClip = _MatchAnythingExceptClip();

Matcher clipsWithBoundingRRect({ required BorderRadius borderRadius }) {
  return _ClipsWithBoundingRRect(borderRadius: borderRadius);
}

Matcher clipsWithShapeBorder({ required ShapeBorder shape }) {
  return _ClipsWithShapeBorder(shape: shape);
}

Matcher rendersOnPhysicalModel({
  BoxShape? shape,
  BorderRadius? borderRadius,
  double? elevation,
}) {
  return _RendersOnPhysicalModel(
    shape: shape,
    borderRadius: borderRadius,
    elevation: elevation,
  );
}

Matcher rendersOnPhysicalShape({
  required ShapeBorder shape,
  double? elevation,
}) {
  return _RendersOnPhysicalShape(
    shape: shape,
    elevation: elevation,
  );
}

abstract class _FailWithDescriptionMatcher extends Matcher {
  const _FailWithDescriptionMatcher();

  bool failWithDescription(Map<dynamic, dynamic> matchState, String description) {
    matchState['failure'] = description;
    return false;
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    return mismatchDescription.add(matchState['failure'] as String);
  }
}

class _MatchAnythingExceptClip extends _FailWithDescriptionMatcher {
  const _MatchAnythingExceptClip();

  @override
  bool matches(covariant Finder finder, Map<dynamic, dynamic> matchState) {
    final Iterable<Element> nodes = finder.evaluate();
    if (nodes.length != 1) {
      return failWithDescription(matchState, 'did not have a exactly one child element');
    }
    final RenderObject renderObject = nodes.single.renderObject!;

    switch (renderObject.runtimeType) {
      case const (RenderClipPath):
      case const (RenderClipOval):
      case const (RenderClipRect):
      case const (RenderClipRRect):
        return failWithDescription(matchState, 'had a root render object of type: ${renderObject.runtimeType}');
      default:
        return true;
    }
  }

  @override
  Description describe(Description description) {
    return description.add('does not have a clip as an immediate child');
  }
}

abstract class _MatchRenderObject<M extends RenderObject, T extends RenderObject> extends _FailWithDescriptionMatcher {
  const _MatchRenderObject();

  bool renderObjectMatchesT(Map<dynamic, dynamic> matchState, T renderObject);
  bool renderObjectMatchesM(Map<dynamic, dynamic> matchState, M renderObject);

  @override
  bool matches(covariant Finder finder, Map<dynamic, dynamic> matchState) {
    final Iterable<Element> nodes = finder.evaluate();
    if (nodes.length != 1) {
      return failWithDescription(matchState, 'did not have a exactly one child element');
    }
    final RenderObject renderObject = nodes.single.renderObject!;

    if (renderObject.runtimeType == T) {
      return renderObjectMatchesT(matchState, renderObject as T);
    }

    if (renderObject.runtimeType == M) {
      return renderObjectMatchesM(matchState, renderObject as M);
    }

    return failWithDescription(matchState, 'had a root render object of type: ${renderObject.runtimeType}');
  }
}

class _RendersOnPhysicalModel extends _MatchRenderObject<RenderPhysicalShape, RenderPhysicalModel> {
  const _RendersOnPhysicalModel({
    this.shape,
    this.borderRadius,
    this.elevation,
  });

  final BoxShape? shape;
  final BorderRadius? borderRadius;
  final double? elevation;

  @override
  bool renderObjectMatchesT(Map<dynamic, dynamic> matchState, RenderPhysicalModel renderObject) {
    if (shape != null && renderObject.shape != shape) {
      return failWithDescription(matchState, 'had shape: ${renderObject.shape}');
    }

    if (borderRadius != null && renderObject.borderRadius != borderRadius) {
      return failWithDescription(matchState, 'had borderRadius: ${renderObject.borderRadius}');
    }

    if (elevation != null && renderObject.elevation != elevation) {
      return failWithDescription(matchState, 'had elevation: ${renderObject.elevation}');
    }

    return true;
  }

  @override
  bool renderObjectMatchesM(Map<dynamic, dynamic> matchState, RenderPhysicalShape renderObject) {
    if (renderObject.clipper.runtimeType != ShapeBorderClipper) {
      return failWithDescription(matchState, 'clipper was: ${renderObject.clipper}');
    }
    final ShapeBorderClipper shapeClipper = renderObject.clipper! as ShapeBorderClipper;

    if (borderRadius != null && !assertRoundedRectangle(shapeClipper, borderRadius!, matchState)) {
      return false;
    }

    if (borderRadius == null &&
      shape == BoxShape.rectangle &&
      !assertRoundedRectangle(shapeClipper, BorderRadius.zero, matchState)) {
      return false;
    }

    if (borderRadius == null &&
      shape == BoxShape.circle &&
      !assertCircle(shapeClipper, matchState)) {
      return false;
    }

    if (elevation != null && renderObject.elevation != elevation) {
      return failWithDescription(matchState, 'had elevation: ${renderObject.elevation}');
    }

    return true;
  }

  bool assertRoundedRectangle(ShapeBorderClipper shapeClipper, BorderRadius borderRadius, Map<dynamic, dynamic> matchState) {
    if (shapeClipper.shape.runtimeType != RoundedRectangleBorder) {
      return failWithDescription(matchState, 'had shape border: ${shapeClipper.shape}');
    }
    final RoundedRectangleBorder border = shapeClipper.shape as RoundedRectangleBorder;
    if (border.borderRadius != borderRadius) {
      return failWithDescription(matchState, 'had borderRadius: ${border.borderRadius}');
    }
    return true;
  }

  bool assertCircle(ShapeBorderClipper shapeClipper, Map<dynamic, dynamic> matchState) {
    if (shapeClipper.shape.runtimeType != CircleBorder) {
      return failWithDescription(matchState, 'had shape border: ${shapeClipper.shape}');
    }
    return true;
  }

  @override
  Description describe(Description description) {
    description.add('renders on a physical model');
    if (shape != null) {
      description.add(' with shape $shape');
    }
    if (borderRadius != null) {
      description.add(' with borderRadius $borderRadius');
    }
    if (elevation != null) {
      description.add(' with elevation $elevation');
    }
    return description;
  }
}

class _RendersOnPhysicalShape extends _MatchRenderObject<RenderPhysicalShape, RenderPhysicalModel> {
  const _RendersOnPhysicalShape({
    required this.shape,
    this.elevation,
  });

  final ShapeBorder shape;
  final double? elevation;

  @override
  bool renderObjectMatchesM(Map<dynamic, dynamic> matchState, RenderPhysicalShape renderObject) {
    if (renderObject.clipper.runtimeType != ShapeBorderClipper) {
      return failWithDescription(matchState, 'clipper was: ${renderObject.clipper}');
    }
    final ShapeBorderClipper shapeClipper = renderObject.clipper! as ShapeBorderClipper;

    if (shapeClipper.shape != shape) {
      return failWithDescription(matchState, 'shape was: ${shapeClipper.shape}');
    }

    if (elevation != null && renderObject.elevation != elevation) {
      return failWithDescription(matchState, 'had elevation: ${renderObject.elevation}');
    }

    return true;
  }

  @override
  bool renderObjectMatchesT(Map<dynamic, dynamic> matchState, RenderPhysicalModel renderObject) {
    return false;
  }

  @override
  Description describe(Description description) {
    description.add('renders on a physical model with shape $shape');
    if (elevation != null) {
      description.add(' with elevation $elevation');
    }
    return description;
  }
}

class _ClipsWithBoundingRect extends _MatchRenderObject<RenderClipPath, RenderClipRect> {
  const _ClipsWithBoundingRect();

  @override
  bool renderObjectMatchesT(Map<dynamic, dynamic> matchState, RenderClipRect renderObject) {
    if (renderObject.clipper != null) {
      return failWithDescription(matchState, 'had a non null clipper ${renderObject.clipper}');
    }
    return true;
  }

  @override
  bool renderObjectMatchesM(Map<dynamic, dynamic> matchState, RenderClipPath renderObject) {
    if (renderObject.clipper.runtimeType != ShapeBorderClipper) {
      return failWithDescription(matchState, 'clipper was: ${renderObject.clipper}');
    }
    final ShapeBorderClipper shapeClipper = renderObject.clipper! as ShapeBorderClipper;
    if (shapeClipper.shape.runtimeType != RoundedRectangleBorder) {
      return failWithDescription(matchState, 'shape was: ${shapeClipper.shape}');
    }
    final RoundedRectangleBorder border = shapeClipper.shape as RoundedRectangleBorder;
    if (border.borderRadius != BorderRadius.zero) {
      return failWithDescription(matchState, 'borderRadius was: ${border.borderRadius}');
    }
    return true;
  }

  @override
  Description describe(Description description) =>
    description.add('clips with bounding rectangle');
}

class _ClipsWithBoundingRRect extends _MatchRenderObject<RenderClipPath, RenderClipRRect> {
  const _ClipsWithBoundingRRect({required this.borderRadius});

  final BorderRadius borderRadius;


  @override
  bool renderObjectMatchesT(Map<dynamic, dynamic> matchState, RenderClipRRect renderObject) {
    if (renderObject.clipper != null) {
      return failWithDescription(matchState, 'had a non null clipper ${renderObject.clipper}');
    }

    if (renderObject.borderRadius != borderRadius) {
      return failWithDescription(matchState, 'had borderRadius: ${renderObject.borderRadius}');
    }

    return true;
  }

  @override
  bool renderObjectMatchesM(Map<dynamic, dynamic> matchState, RenderClipPath renderObject) {
    if (renderObject.clipper.runtimeType != ShapeBorderClipper) {
      return failWithDescription(matchState, 'clipper was: ${renderObject.clipper}');
    }
    final ShapeBorderClipper shapeClipper = renderObject.clipper! as ShapeBorderClipper;
    if (shapeClipper.shape.runtimeType != RoundedRectangleBorder) {
      return failWithDescription(matchState, 'shape was: ${shapeClipper.shape}');
    }
    final RoundedRectangleBorder border = shapeClipper.shape as RoundedRectangleBorder;
    if (border.borderRadius != borderRadius) {
      return failWithDescription(matchState, 'had borderRadius: ${border.borderRadius}');
    }
    return true;
  }

  @override
  Description describe(Description description) =>
    description.add('clips with bounding rounded rectangle with borderRadius: $borderRadius');
}

class _ClipsWithShapeBorder extends _MatchRenderObject<RenderClipPath, RenderClipRRect> {
  const _ClipsWithShapeBorder({required this.shape});

  final ShapeBorder shape;

  @override
  bool renderObjectMatchesM(Map<dynamic, dynamic> matchState, RenderClipPath renderObject) {
    if (renderObject.clipper.runtimeType != ShapeBorderClipper) {
      return failWithDescription(matchState, 'clipper was: ${renderObject.clipper}');
    }
    final ShapeBorderClipper shapeClipper = renderObject.clipper! as ShapeBorderClipper;
    if (shapeClipper.shape != shape) {
      return failWithDescription(matchState, 'shape was: ${shapeClipper.shape}');
    }
    return true;
  }

  @override
  bool renderObjectMatchesT(Map<dynamic, dynamic> matchState, RenderClipRRect renderObject) {
    return false;
  }


  @override
  Description describe(Description description) =>
    description.add('clips with shape: $shape');
}

class _CoversSameAreaAs extends Matcher {
  _CoversSameAreaAs(
    this.expectedPath, {
    required this.areaToCompare,
    this.sampleSize = 20,
  }) : maxHorizontalNoise = areaToCompare.width / sampleSize,
       maxVerticalNoise = areaToCompare.height / sampleSize {
    // Use a fixed random seed to make sure tests are deterministic.
    random = math.Random(1);
  }

  final Path expectedPath;
  final Rect areaToCompare;
  final int sampleSize;
  final double maxHorizontalNoise;
  final double maxVerticalNoise;
  late math.Random random;

  @override
  bool matches(covariant Path actualPath, Map<dynamic, dynamic> matchState) {
    for (int i = 0; i < sampleSize; i += 1) {
      for (int j = 0; j < sampleSize; j += 1) {
        final Offset offset = Offset(
          i * (areaToCompare.width / sampleSize),
          j * (areaToCompare.height / sampleSize),
        );

        if (!_samplePoint(matchState, actualPath, offset)) {
          return false;
        }

        final Offset noise = Offset(
          maxHorizontalNoise * random.nextDouble(),
          maxVerticalNoise * random.nextDouble(),
        );

        if (!_samplePoint(matchState, actualPath, offset + noise)) {
          return false;
        }
      }
    }
    return true;
  }

  bool _samplePoint(Map<dynamic, dynamic> matchState, Path actualPath, Offset offset) {
    if (expectedPath.contains(offset) == actualPath.contains(offset)) {
      return true;
    }

    if (actualPath.contains(offset)) {
      return failWithDescription(matchState, '$offset is contained in the actual path but not in the expected path');
    } else {
      return failWithDescription(matchState, '$offset is contained in the expected path but not in the actual path');
    }
  }

  bool failWithDescription(Map<dynamic, dynamic> matchState, String description) {
    matchState['failure'] = description;
    return false;
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    return mismatchDescription.add(matchState['failure'] as String);
  }

  @override
  Description describe(Description description) =>
    description.add('covers expected area and only expected area');
}

class _ColorMatcher extends Matcher {
  const _ColorMatcher({
    required this.targetColor,
  });

  final Color targetColor;

  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) {
    if (item is Color) {
      return item == targetColor || item.value == targetColor.value;
    }
    return false;
  }

  @override
  Description describe(Description description) => description.add('matches color $targetColor');
}

int _countDifferentPixels(Uint8List imageA, Uint8List imageB) {
  assert(imageA.length == imageB.length);
  int delta = 0;
  for (int i = 0; i < imageA.length; i+=4) {
    if (imageA[i] != imageB[i] ||
        imageA[i + 1] != imageB[i + 1] ||
        imageA[i + 2] != imageB[i + 2] ||
        imageA[i + 3] != imageB[i + 3]) {
      delta++;
    }
  }
  return delta;
}

class _MatchesReferenceImage extends AsyncMatcher {
  const _MatchesReferenceImage(this.referenceImage);

  final ui.Image referenceImage;

  @override
  Future<String?> matchAsync(dynamic item) async {
    Future<ui.Image> imageFuture;
    final bool disposeImage; // set to true if the matcher created and owns the image and must therefore dispose it.
    if (item is Future<ui.Image>) {
      imageFuture = item;
      disposeImage = false;
    } else if (item is ui.Image) {
      imageFuture = Future<ui.Image>.value(item);
      disposeImage = false;
    } else {
      final Finder finder = item as Finder;
      final Iterable<Element> elements = finder.evaluate();
      if (elements.isEmpty) {
        return 'could not be rendered because no widget was found';
      } else if (elements.length > 1) {
        return 'matched too many widgets';
      }
      imageFuture = captureImage(elements.single);
      disposeImage = true;
    }

    final TestWidgetsFlutterBinding binding = TestWidgetsFlutterBinding.instance;
    return binding.runAsync<String?>(() async {
      final ui.Image image = await imageFuture;
      try {
        final ByteData? bytes = await image.toByteData();
        if (bytes == null) {
          return 'could not be encoded.';
        }

        final ByteData? referenceBytes = await referenceImage.toByteData();
        if (referenceBytes == null) {
          return 'could not have its reference image encoded.';
        }

        if (referenceImage.height != image.height || referenceImage.width != image.width) {
          return 'does not match as width or height do not match. $image != $referenceImage';
        }

        final int countDifferentPixels = _countDifferentPixels(
          Uint8List.view(bytes.buffer),
          Uint8List.view(referenceBytes.buffer),
        );
        return countDifferentPixels == 0 ? null : 'does not match on $countDifferentPixels pixels';
      } finally {
        if (disposeImage) {
          image.dispose();
        }
      }
    });
  }

  @override
  Description describe(Description description) {
    return description.add('rasterized image matches that of a $referenceImage reference image');
  }
}

class _MatchesSemanticsData extends Matcher {
  _MatchesSemanticsData({
    required this.label,
    required this.attributedLabel,
    required this.hint,
    required this.attributedHint,
    required this.value,
    required this.attributedValue,
    required this.increasedValue,
    required this.attributedIncreasedValue,
    required this.decreasedValue,
    required this.attributedDecreasedValue,
    required this.tooltip,
    required this.textDirection,
    required this.rect,
    required this.size,
    required this.elevation,
    required this.thickness,
    required this.platformViewId,
    required this.maxValueLength,
    required this.currentValueLength,
    // Flags
    required bool? hasCheckedState,
    required bool? isChecked,
    required bool? isCheckStateMixed,
    required bool? isSelected,
    required bool? isButton,
    required bool? isSlider,
    required bool? isKeyboardKey,
    required bool? isLink,
    required bool? isFocused,
    required bool? isFocusable,
    required bool? isTextField,
    required bool? isReadOnly,
    required bool? hasEnabledState,
    required bool? isEnabled,
    required bool? isInMutuallyExclusiveGroup,
    required bool? isHeader,
    required bool? isObscured,
    required bool? isMultiline,
    required bool? namesRoute,
    required bool? scopesRoute,
    required bool? isHidden,
    required bool? isImage,
    required bool? isLiveRegion,
    required bool? hasToggledState,
    required bool? isToggled,
    required bool? hasImplicitScrolling,
    required bool? hasExpandedState,
    required bool? isExpanded,
    // Actions
    required bool? hasTapAction,
    required bool? hasLongPressAction,
    required bool? hasScrollLeftAction,
    required bool? hasScrollRightAction,
    required bool? hasScrollUpAction,
    required bool? hasScrollDownAction,
    required bool? hasIncreaseAction,
    required bool? hasDecreaseAction,
    required bool? hasShowOnScreenAction,
    required bool? hasMoveCursorForwardByCharacterAction,
    required bool? hasMoveCursorBackwardByCharacterAction,
    required bool? hasMoveCursorForwardByWordAction,
    required bool? hasMoveCursorBackwardByWordAction,
    required bool? hasSetTextAction,
    required bool? hasSetSelectionAction,
    required bool? hasCopyAction,
    required bool? hasCutAction,
    required bool? hasPasteAction,
    required bool? hasDidGainAccessibilityFocusAction,
    required bool? hasDidLoseAccessibilityFocusAction,
    required bool? hasDismissAction,
    // Custom actions and overrides
    required String? onTapHint,
    required String? onLongPressHint,
    required this.customActions,
    required this.children,
  })  : flags = <SemanticsFlag, bool>{
          if (hasCheckedState != null) SemanticsFlag.hasCheckedState: hasCheckedState,
          if (isChecked != null) SemanticsFlag.isChecked: isChecked,
          if (isCheckStateMixed != null) SemanticsFlag.isCheckStateMixed: isCheckStateMixed,
          if (isSelected != null) SemanticsFlag.isSelected: isSelected,
          if (isButton != null) SemanticsFlag.isButton: isButton,
          if (isSlider != null) SemanticsFlag.isSlider: isSlider,
          if (isKeyboardKey != null) SemanticsFlag.isKeyboardKey: isKeyboardKey,
          if (isLink != null) SemanticsFlag.isLink: isLink,
          if (isTextField != null) SemanticsFlag.isTextField: isTextField,
          if (isReadOnly != null) SemanticsFlag.isReadOnly: isReadOnly,
          if (isFocused != null) SemanticsFlag.isFocused: isFocused,
          if (isFocusable != null) SemanticsFlag.isFocusable: isFocusable,
          if (hasEnabledState != null) SemanticsFlag.hasEnabledState: hasEnabledState,
          if (isEnabled != null) SemanticsFlag.isEnabled: isEnabled,
          if (isInMutuallyExclusiveGroup != null) SemanticsFlag.isInMutuallyExclusiveGroup: isInMutuallyExclusiveGroup,
          if (isHeader != null) SemanticsFlag.isHeader: isHeader,
          if (isObscured != null) SemanticsFlag.isObscured: isObscured,
          if (isMultiline != null) SemanticsFlag.isMultiline: isMultiline,
          if (namesRoute != null) SemanticsFlag.namesRoute: namesRoute,
          if (scopesRoute != null) SemanticsFlag.scopesRoute: scopesRoute,
          if (isHidden != null) SemanticsFlag.isHidden: isHidden,
          if (isImage != null) SemanticsFlag.isImage: isImage,
          if (isLiveRegion != null) SemanticsFlag.isLiveRegion: isLiveRegion,
          if (hasToggledState != null) SemanticsFlag.hasToggledState: hasToggledState,
          if (isToggled != null) SemanticsFlag.isToggled: isToggled,
          if (hasImplicitScrolling != null) SemanticsFlag.hasImplicitScrolling: hasImplicitScrolling,
          if (isSlider != null) SemanticsFlag.isSlider: isSlider,
          if (hasExpandedState != null) SemanticsFlag.hasExpandedState: hasExpandedState,
          if (isExpanded != null) SemanticsFlag.isExpanded: isExpanded,
        },
        actions = <SemanticsAction, bool>{
          if (hasTapAction != null) SemanticsAction.tap: hasTapAction,
          if (hasLongPressAction != null) SemanticsAction.longPress: hasLongPressAction,
          if (hasScrollLeftAction != null) SemanticsAction.scrollLeft: hasScrollLeftAction,
          if (hasScrollRightAction != null) SemanticsAction.scrollRight: hasScrollRightAction,
          if (hasScrollUpAction != null) SemanticsAction.scrollUp: hasScrollUpAction,
          if (hasScrollDownAction != null) SemanticsAction.scrollDown: hasScrollDownAction,
          if (hasIncreaseAction != null) SemanticsAction.increase: hasIncreaseAction,
          if (hasDecreaseAction != null) SemanticsAction.decrease: hasDecreaseAction,
          if (hasShowOnScreenAction != null) SemanticsAction.showOnScreen: hasShowOnScreenAction,
          if (hasMoveCursorForwardByCharacterAction != null) SemanticsAction.moveCursorForwardByCharacter: hasMoveCursorForwardByCharacterAction,
          if (hasMoveCursorBackwardByCharacterAction != null) SemanticsAction.moveCursorBackwardByCharacter: hasMoveCursorBackwardByCharacterAction,
          if (hasSetSelectionAction != null) SemanticsAction.setSelection: hasSetSelectionAction,
          if (hasCopyAction != null) SemanticsAction.copy: hasCopyAction,
          if (hasCutAction != null) SemanticsAction.cut: hasCutAction,
          if (hasPasteAction != null) SemanticsAction.paste: hasPasteAction,
          if (hasDidGainAccessibilityFocusAction != null) SemanticsAction.didGainAccessibilityFocus: hasDidGainAccessibilityFocusAction,
          if (hasDidLoseAccessibilityFocusAction != null) SemanticsAction.didLoseAccessibilityFocus: hasDidLoseAccessibilityFocusAction,
          if (customActions != null) SemanticsAction.customAction: customActions.isNotEmpty,
          if (hasDismissAction != null) SemanticsAction.dismiss: hasDismissAction,
          if (hasMoveCursorForwardByWordAction != null) SemanticsAction.moveCursorForwardByWord: hasMoveCursorForwardByWordAction,
          if (hasMoveCursorBackwardByWordAction != null) SemanticsAction.moveCursorBackwardByWord: hasMoveCursorBackwardByWordAction,
          if (hasSetTextAction != null) SemanticsAction.setText: hasSetTextAction,
        },
        hintOverrides = onTapHint == null && onLongPressHint == null
            ? null
            : SemanticsHintOverrides(
                onTapHint: onTapHint,
                onLongPressHint: onLongPressHint,
              );

  final String? label;
  final AttributedString? attributedLabel;
  final String? hint;
  final AttributedString? attributedHint;
  final String? value;
  final AttributedString? attributedValue;
  final String? increasedValue;
  final AttributedString? attributedIncreasedValue;
  final String? decreasedValue;
  final AttributedString? attributedDecreasedValue;
  final String? tooltip;
  final SemanticsHintOverrides? hintOverrides;
  final List<CustomSemanticsAction>? customActions;
  final TextDirection? textDirection;
  final Rect? rect;
  final Size? size;
  final double? elevation;
  final double? thickness;
  final int? platformViewId;
  final int? maxValueLength;
  final int? currentValueLength;
  final List<Matcher>? children;

  final Map<SemanticsAction, bool> actions;
  final Map<SemanticsFlag, bool> flags;

  @override
  Description describe(Description description) {
    description.add('has semantics');
    if (label != null) {
      description.add(' with label: $label');
    }
    if (attributedLabel != null) {
      description.add(' with attributedLabel: $attributedLabel');
    }
    if (value != null) {
      description.add(' with value: $value');
    }
    if (attributedValue != null) {
      description.add(' with attributedValue: $attributedValue');
    }
    if (hint != null) {
      description.add(' with hint: $hint');
    }
    if (attributedHint != null) {
      description.add(' with attributedHint: $attributedHint');
    }
    if (increasedValue != null) {
      description.add(' with increasedValue: $increasedValue ');
    }
    if (attributedIncreasedValue != null) {
      description.add(' with attributedIncreasedValue: $attributedIncreasedValue');
    }
    if (decreasedValue != null) {
      description.add(' with decreasedValue: $decreasedValue ');
    }
    if (attributedDecreasedValue != null) {
      description.add(' with attributedDecreasedValue: $attributedDecreasedValue');
    }
    if (tooltip != null) {
      description.add(' with tooltip: $tooltip');
    }
    if (actions.isNotEmpty) {
      final List<SemanticsAction> expectedActions = actions.entries
        .where((MapEntry<ui.SemanticsAction, bool> e) => e.value)
        .map((MapEntry<ui.SemanticsAction, bool> e) => e.key)
        .toList();
      final List<SemanticsAction> notExpectedActions = actions.entries
        .where((MapEntry<ui.SemanticsAction, bool> e) => !e.value)
        .map((MapEntry<ui.SemanticsAction, bool> e) => e.key)
        .toList();

      if (expectedActions.isNotEmpty) {
        description.add(' with actions: ${_createEnumsSummary(expectedActions)} ');
      }
      if (notExpectedActions.isNotEmpty) {
        description.add(' without actions: ${_createEnumsSummary(notExpectedActions)} ');
      }
    }
    if (flags.isNotEmpty) {
      final List<SemanticsFlag> expectedFlags = flags.entries
        .where((MapEntry<ui.SemanticsFlag, bool> e) => e.value)
        .map((MapEntry<ui.SemanticsFlag, bool> e) => e.key)
        .toList();
      final List<SemanticsFlag> notExpectedFlags = flags.entries
        .where((MapEntry<ui.SemanticsFlag, bool> e) => !e.value)
        .map((MapEntry<ui.SemanticsFlag, bool> e) => e.key)
        .toList();

      if (expectedFlags.isNotEmpty) {
        description.add(' with flags: ${_createEnumsSummary(expectedFlags)} ');
      }
      if (notExpectedFlags.isNotEmpty) {
        description.add(' without flags: ${_createEnumsSummary(notExpectedFlags)} ');
      }
    }
    if (textDirection != null) {
      description.add(' with textDirection: $textDirection ');
    }
    if (rect != null) {
      description.add(' with rect: $rect');
    }
    if (size != null) {
      description.add(' with size: $size');
    }
    if (elevation != null) {
      description.add(' with elevation: $elevation');
    }
    if (thickness != null) {
      description.add(' with thickness: $thickness');
    }
    if (platformViewId != null) {
      description.add(' with platformViewId: $platformViewId');
    }
    if (maxValueLength != null) {
      description.add(' with maxValueLength: $maxValueLength');
    }
    if (currentValueLength != null) {
      description.add(' with currentValueLength: $currentValueLength');
    }
    if (customActions != null) {
      description.add(' with custom actions: $customActions');
    }
    if (hintOverrides != null) {
      description.add(' with custom hints: $hintOverrides');
    }
    if (children != null) {
      description.add(' with children:\n');
      for (final _MatchesSemanticsData child in children!.cast<_MatchesSemanticsData>()) {
        child.describe(description);
      }
    }
    return description;
  }

  bool _stringAttributesEqual(List<StringAttribute> first, List<StringAttribute> second) {
    if (first.length != second.length) {
      return false;
    }
    for (int i = 0; i < first.length; i++) {
      if (first[i] is SpellOutStringAttribute &&
          (second[i] is! SpellOutStringAttribute ||
           second[i].range != first[i].range)) {
        return false;
      }
      if (first[i] is LocaleStringAttribute &&
          (second[i] is! LocaleStringAttribute ||
           second[i].range != first[i].range ||
           (second[i] as LocaleStringAttribute).locale != (second[i] as LocaleStringAttribute).locale)) {
        return false;
      }
    }
    return true;
  }

  @override
  bool matches(dynamic node, Map<dynamic, dynamic> matchState) {
    if (node == null) {
      return failWithDescription(matchState, 'No SemanticsData provided. '
        'Maybe you forgot to enable semantics?');
    }
    final SemanticsData data = node is SemanticsNode ? node.getSemanticsData() : (node as SemanticsData);
    if (label != null && label != data.label) {
      return failWithDescription(matchState, 'label was: ${data.label}');
    }
    if (attributedLabel != null &&
        (attributedLabel!.string != data.attributedLabel.string ||
         !_stringAttributesEqual(attributedLabel!.attributes, data.attributedLabel.attributes))) {
      return failWithDescription(
          matchState, 'attributedLabel was: ${data.attributedLabel}');
    }
    if (hint != null && hint != data.hint) {
      return failWithDescription(matchState, 'hint was: ${data.hint}');
    }
    if (attributedHint != null &&
        (attributedHint!.string != data.attributedHint.string ||
         !_stringAttributesEqual(attributedHint!.attributes, data.attributedHint.attributes))) {
      return failWithDescription(
          matchState, 'attributedHint was: ${data.attributedHint}');
    }
    if (value != null && value != data.value) {
      return failWithDescription(matchState, 'value was: ${data.value}');
    }
    if (attributedValue != null &&
        (attributedValue!.string != data.attributedValue.string ||
         !_stringAttributesEqual(attributedValue!.attributes, data.attributedValue.attributes))) {
      return failWithDescription(
          matchState, 'attributedValue was: ${data.attributedValue}');
    }
    if (increasedValue != null && increasedValue != data.increasedValue) {
      return failWithDescription(matchState, 'increasedValue was: ${data.increasedValue}');
    }
    if (attributedIncreasedValue != null &&
        (attributedIncreasedValue!.string != data.attributedIncreasedValue.string ||
         !_stringAttributesEqual(attributedIncreasedValue!.attributes, data.attributedIncreasedValue.attributes))) {
      return failWithDescription(
          matchState, 'attributedIncreasedValue was: ${data.attributedIncreasedValue}');
    }
    if (decreasedValue != null && decreasedValue != data.decreasedValue) {
      return failWithDescription(matchState, 'decreasedValue was: ${data.decreasedValue}');
    }
    if (attributedDecreasedValue != null &&
        (attributedDecreasedValue!.string != data.attributedDecreasedValue.string ||
         !_stringAttributesEqual(attributedDecreasedValue!.attributes, data.attributedDecreasedValue.attributes))) {
      return failWithDescription(
          matchState, 'attributedDecreasedValue was: ${data.attributedDecreasedValue}');
    }
    if (tooltip != null && tooltip != data.tooltip) {
      return failWithDescription(matchState, 'tooltip was: ${data.tooltip}');
    }
    if (textDirection != null && textDirection != data.textDirection) {
      return failWithDescription(matchState, 'textDirection was: $textDirection');
    }
    if (rect != null && rect != data.rect) {
      return failWithDescription(matchState, 'rect was: ${data.rect}');
    }
    if (size != null && size != data.rect.size) {
      return failWithDescription(matchState, 'size was: ${data.rect.size}');
    }
    if (elevation != null && elevation != data.elevation) {
      return failWithDescription(matchState, 'elevation was: ${data.elevation}');
    }
    if (thickness != null && thickness != data.thickness) {
      return failWithDescription(matchState, 'thickness was: ${data.thickness}');
    }
    if (platformViewId != null && platformViewId != data.platformViewId) {
      return failWithDescription(matchState, 'platformViewId was: ${data.platformViewId}');
    }
    if (currentValueLength != null && currentValueLength != data.currentValueLength) {
      return failWithDescription(matchState, 'currentValueLength was: ${data.currentValueLength}');
    }
    if (maxValueLength != null && maxValueLength != data.maxValueLength) {
      return failWithDescription(matchState, 'maxValueLength was: ${data.maxValueLength}');
    }
    if (actions.isNotEmpty) {
      final List<SemanticsAction> unexpectedActions = <SemanticsAction>[];
      final List<SemanticsAction> missingActions = <SemanticsAction>[];
      for (final MapEntry<ui.SemanticsAction, bool> actionEntry in actions.entries) {
        final ui.SemanticsAction action = actionEntry.key;
        final bool actionExpected = actionEntry.value;
        final bool actionPresent = (action.index & data.actions) == action.index;
        if (actionPresent != actionExpected) {
          if (actionExpected) {
            missingActions.add(action);
          } else {
            unexpectedActions.add(action);
          }
        }
      }

      if (unexpectedActions.isNotEmpty || missingActions.isNotEmpty) {
        return failWithDescription(matchState, 'missing actions: ${_createEnumsSummary(missingActions)} unexpected actions: ${_createEnumsSummary(unexpectedActions)}');
      }
    }
    if (customActions != null || hintOverrides != null) {
      final List<CustomSemanticsAction> providedCustomActions = data.customSemanticsActionIds?.map<CustomSemanticsAction>((int id) {
        return CustomSemanticsAction.getAction(id)!;
      }).toList() ?? <CustomSemanticsAction>[];
      final List<CustomSemanticsAction> expectedCustomActions = customActions?.toList() ?? <CustomSemanticsAction>[];
      if (hintOverrides?.onTapHint != null) {
        expectedCustomActions.add(CustomSemanticsAction.overridingAction(hint: hintOverrides!.onTapHint!, action: SemanticsAction.tap));
      }
      if (hintOverrides?.onLongPressHint != null) {
        expectedCustomActions.add(CustomSemanticsAction.overridingAction(hint: hintOverrides!.onLongPressHint!, action: SemanticsAction.longPress));
      }
      if (expectedCustomActions.length != providedCustomActions.length) {
        return failWithDescription(matchState, 'custom actions were: $providedCustomActions');
      }
      int sortActions(CustomSemanticsAction left, CustomSemanticsAction right) {
        return CustomSemanticsAction.getIdentifier(left) - CustomSemanticsAction.getIdentifier(right);
      }
      expectedCustomActions.sort(sortActions);
      providedCustomActions.sort(sortActions);
      for (int i = 0; i < expectedCustomActions.length; i++) {
        if (expectedCustomActions[i] != providedCustomActions[i]) {
          return failWithDescription(matchState, 'custom actions were: $providedCustomActions');
        }
      }
    }
    if (flags.isNotEmpty) {
      final List<SemanticsFlag> unexpectedFlags = <SemanticsFlag>[];
      final List<SemanticsFlag> missingFlags = <SemanticsFlag>[];
      for (final MapEntry<ui.SemanticsFlag, bool> flagEntry in flags.entries) {
        final ui.SemanticsFlag flag = flagEntry.key;
        final bool flagExpected = flagEntry.value;
        final bool flagPresent = flag.index & data.flags == flag.index;
        if (flagPresent != flagExpected) {
          if (flagExpected) {
            missingFlags.add(flag);
          } else {
            unexpectedFlags.add(flag);
          }
        }
      }

      if (unexpectedFlags.isNotEmpty || missingFlags.isNotEmpty) {
        return failWithDescription(matchState, 'missing flags: ${_createEnumsSummary(missingFlags)} unexpected flags: ${_createEnumsSummary(unexpectedFlags)}');
      }
    }
    bool allMatched = true;
    if (children != null) {
      int i = 0;
      (node as SemanticsNode).visitChildren((SemanticsNode child) {
        allMatched = children![i].matches(child, matchState) && allMatched;
        i += 1;
        return allMatched;
      });
    }
    return allMatched;
  }

  bool failWithDescription(Map<dynamic, dynamic> matchState, String description) {
    matchState['failure'] = description;
    return false;
  }

  @override
  Description describeMismatch(
    dynamic item,
    Description mismatchDescription,
    Map<dynamic, dynamic> matchState,
    bool verbose,
  ) {
    return mismatchDescription.add(matchState['failure'] as String);
  }

  static String _createEnumsSummary<T extends Object>(List<T> enums) {
    assert(T == SemanticsAction || T == SemanticsFlag, 'This method is only intended for lists of SemanticsActions or SemanticsFlags.');
    if (T == SemanticsAction) {
      return '[${(enums as List<SemanticsAction>).map((SemanticsAction d) => d.name).join(', ')}]';
    } else {
      return '[${(enums as List<SemanticsFlag>).map((SemanticsFlag d) => d.name).join(', ')}]';
    }
  }
}

class _MatchesAccessibilityGuideline extends AsyncMatcher {
  _MatchesAccessibilityGuideline(this.guideline);

  final AccessibilityGuideline guideline;

  @override
  Description describe(Description description) {
    return description.add(guideline.description);
  }

  @override
  Future<String?> matchAsync(covariant WidgetTester tester) async {
    final Evaluation result = await guideline.evaluate(tester);
    if (result.passed) {
      return null;
    }
    return result.reason;
  }
}

class _DoesNotMatchAccessibilityGuideline extends AsyncMatcher {
  _DoesNotMatchAccessibilityGuideline(this.guideline);

  final AccessibilityGuideline guideline;

  @override
  Description describe(Description description) {
    return description.add('Does not ${guideline.description}');
  }

  @override
  Future<String?> matchAsync(covariant WidgetTester tester) async {
    final Evaluation result = await guideline.evaluate(tester);
    if (result.passed) {
      return 'Failed';
    }
    return null;
  }
}