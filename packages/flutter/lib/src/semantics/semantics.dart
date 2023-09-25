// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, SemanticsAction, SemanticsFlag, SemanticsUpdate, SemanticsUpdateBuilder, StringAttribute, TextDirection;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show MatrixUtils, TransformProperty;
import 'package:flutter/services.dart';
import 'package:vector_math/vector_math_64.dart';

import 'binding.dart' show SemanticsBinding;
import 'semantics_event.dart';

export 'dart:ui' show Offset, Rect, SemanticsAction, SemanticsFlag, StringAttribute, TextDirection, VoidCallback;

export 'package:flutter/foundation.dart' show DiagnosticLevel, DiagnosticPropertiesBuilder, DiagnosticsNode, DiagnosticsTreeStyle, Key, TextTreeConfiguration;
export 'package:flutter/services.dart' show TextSelection;
export 'package:vector_math/vector_math_64.dart' show Matrix4;

export 'semantics_event.dart' show SemanticsEvent;

typedef SemanticsNodeVisitor = bool Function(SemanticsNode node);

typedef MoveCursorHandler = void Function(bool extendSelection);

typedef SetSelectionHandler = void Function(TextSelection selection);

typedef SetTextHandler = void Function(String text);

typedef SemanticsActionHandler = void Function(Object? args);

typedef SemanticsUpdateCallback = void Function(SemanticsUpdate update);

typedef ChildSemanticsConfigurationsDelegate = ChildSemanticsConfigurationsResult Function(List<SemanticsConfiguration>);

final int _kUnblockedUserActions = SemanticsAction.didGainAccessibilityFocus.index
  | SemanticsAction.didLoseAccessibilityFocus.index;

class SemanticsTag {
  const SemanticsTag(this.name);

  final String name;

  @override
  String toString() => '${objectRuntimeType(this, 'SemanticsTag')}($name)';
}

class ChildSemanticsConfigurationsResult {
  ChildSemanticsConfigurationsResult._(this.mergeUp, this.siblingMergeGroups);

  final List<SemanticsConfiguration> mergeUp;

  final List<List<SemanticsConfiguration>> siblingMergeGroups;
}

class ChildSemanticsConfigurationsResultBuilder {
  ChildSemanticsConfigurationsResultBuilder();

  final List<SemanticsConfiguration> _mergeUp = <SemanticsConfiguration>[];
  final List<List<SemanticsConfiguration>> _siblingMergeGroups = <List<SemanticsConfiguration>>[];

  void markAsMergeUp(SemanticsConfiguration config) => _mergeUp.add(config);

  void markAsSiblingMergeGroup(List<SemanticsConfiguration> configs) => _siblingMergeGroups.add(configs);

  ChildSemanticsConfigurationsResult build() {
    assert((){
      final Set<SemanticsConfiguration> seenConfigs = <SemanticsConfiguration>{};
      for (final SemanticsConfiguration config in <SemanticsConfiguration>[..._mergeUp, ..._siblingMergeGroups.flattened]) {
        assert(
          seenConfigs.add(config),
          'Duplicated SemanticsConfigurations. This can happen if the same '
          'SemanticsConfiguration was marked twice in markAsMergeUp and/or '
          'markAsSiblingMergeGroup'
        );
      }
      return true;
    }());
    return ChildSemanticsConfigurationsResult._(_mergeUp, _siblingMergeGroups);
  }
}

@immutable
class CustomSemanticsAction {
  const CustomSemanticsAction({required String this.label})
    : assert(label != ''),
      hint = null,
      action = null;

  const CustomSemanticsAction.overridingAction({required String this.hint, required SemanticsAction this.action})
    : assert(hint != ''),
      label = null;

  final String? label;

  final String? hint;

  final SemanticsAction? action;

  @override
  int get hashCode => Object.hash(label, hint, action);

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is CustomSemanticsAction
        && other.label == label
        && other.hint == hint
        && other.action == action;
  }

  @override
  String toString() {
    return 'CustomSemanticsAction(${_ids[this]}, label:$label, hint:$hint, action:$action)';
  }

  // Logic to assign a unique id to each custom action without requiring
  // user specification.
  static int _nextId = 0;
  static final Map<int, CustomSemanticsAction> _actions = <int, CustomSemanticsAction>{};
  static final Map<CustomSemanticsAction, int> _ids = <CustomSemanticsAction, int>{};

  static int getIdentifier(CustomSemanticsAction action) {
    int? result = _ids[action];
    if (result == null) {
      result = _nextId++;
      _ids[action] = result;
      _actions[result] = action;
    }
    return result;
  }

  static CustomSemanticsAction? getAction(int id) {
    return _actions[id];
  }
}

@immutable
class AttributedString {
  AttributedString(
    this.string, {
    this.attributes = const <StringAttribute>[],
  }) : assert(string.isNotEmpty || attributes.isEmpty),
       assert(() {
        for (final StringAttribute attribute in attributes) {
          assert(
            string.length >= attribute.range.start &&
            string.length >= attribute.range.end,
            'The range in $attribute is outside of the string $string',
          );
        }
        return true;
      }());

  final String string;

  final List<StringAttribute> attributes;

  AttributedString operator +(AttributedString other) {
    if (string.isEmpty) {
      return other;
    }
    if (other.string.isEmpty) {
      return this;
    }

    // None of the strings is empty.
    final String newString = string + other.string;
    final List<StringAttribute> newAttributes = List<StringAttribute>.of(attributes);
    if (other.attributes.isNotEmpty) {
      final int offset = string.length;
      for (final StringAttribute attribute in other.attributes) {
        final TextRange newRange = TextRange(
          start: attribute.range.start + offset,
          end: attribute.range.end + offset,
        );
        final StringAttribute adjustedAttribute = attribute.copy(range: newRange);
        newAttributes.add(adjustedAttribute);
      }
    }
    return AttributedString(newString, attributes: newAttributes);
  }

  @override
  bool operator ==(Object other) {
    return other.runtimeType == runtimeType
        && other is AttributedString
        && other.string == string
        && listEquals<StringAttribute>(other.attributes, attributes);
  }

  @override
  int get hashCode => Object.hash(string, attributes);

  @override
  String toString() {
    return "${objectRuntimeType(this, 'AttributedString')}('$string', attributes: $attributes)";
  }
}

class AttributedStringProperty extends DiagnosticsProperty<AttributedString> {
  AttributedStringProperty(
    String super.name,
    super.value, {
    super.showName,
    this.showWhenEmpty = false,
    super.defaultValue,
    super.level,
    super.description,
  });

  final bool showWhenEmpty;

  @override
  bool get isInteresting => super.isInteresting && (showWhenEmpty || (value != null && value!.string.isNotEmpty));

  @override
  String valueToString({TextTreeConfiguration? parentConfiguration}) {
    if (value == null) {
      return 'null';
    }
    String text = value!.string;
    if (parentConfiguration != null &&
        !parentConfiguration.lineBreakProperties) {
      // This follows a similar pattern to StringProperty.
      text = text.replaceAll('\n', r'\n');
    }
    if (value!.attributes.isEmpty) {
      return '"$text"';
    }
    return '"$text" ${value!.attributes}'; // the attributes will be in square brackets since they're a list
  }
}

@immutable
class SemanticsData with Diagnosticable {
  SemanticsData({
    required this.flags,
    required this.actions,
    required this.attributedLabel,
    required this.attributedValue,
    required this.attributedIncreasedValue,
    required this.attributedDecreasedValue,
    required this.attributedHint,
    required this.tooltip,
    required this.textDirection,
    required this.rect,
    required this.elevation,
    required this.thickness,
    required this.textSelection,
    required this.scrollIndex,
    required this.scrollChildCount,
    required this.scrollPosition,
    required this.scrollExtentMax,
    required this.scrollExtentMin,
    required this.platformViewId,
    required this.maxValueLength,
    required this.currentValueLength,
    this.tags,
    this.transform,
    this.customSemanticsActionIds,
  }) : assert(tooltip == '' || textDirection != null, 'A SemanticsData object with tooltip "$tooltip" had a null textDirection.'),
       assert(attributedLabel.string == '' || textDirection != null, 'A SemanticsData object with label "${attributedLabel.string}" had a null textDirection.'),
       assert(attributedValue.string == '' || textDirection != null, 'A SemanticsData object with value "${attributedValue.string}" had a null textDirection.'),
       assert(attributedDecreasedValue.string == '' || textDirection != null, 'A SemanticsData object with decreasedValue "${attributedDecreasedValue.string}" had a null textDirection.'),
       assert(attributedIncreasedValue.string == '' || textDirection != null, 'A SemanticsData object with increasedValue "${attributedIncreasedValue.string}" had a null textDirection.'),
       assert(attributedHint.string == '' || textDirection != null, 'A SemanticsData object with hint "${attributedHint.string}" had a null textDirection.');

  final int flags;

  final int actions;

  String get label => attributedLabel.string;

  final AttributedString attributedLabel;

  String get value => attributedValue.string;

  final AttributedString attributedValue;

  String get increasedValue => attributedIncreasedValue.string;

  final AttributedString attributedIncreasedValue;

  String get decreasedValue => attributedDecreasedValue.string;

  final AttributedString attributedDecreasedValue;

  String get hint => attributedHint.string;

  final AttributedString attributedHint;

  final String tooltip;

  final TextDirection? textDirection;

  final TextSelection? textSelection;

  final int? scrollChildCount;

  final int? scrollIndex;

  final double? scrollPosition;

  final double? scrollExtentMax;

  final double? scrollExtentMin;

  final int? platformViewId;

  final int? maxValueLength;

  final int? currentValueLength;

  final Rect rect;

  final Set<SemanticsTag>? tags;

  final Matrix4? transform;

  final double elevation;

  final double thickness;

  final List<int>? customSemanticsActionIds;

  bool hasFlag(SemanticsFlag flag) => (flags & flag.index) != 0;

  bool hasAction(SemanticsAction action) => (actions & action.index) != 0;

  @override
  String toStringShort() => objectRuntimeType(this, 'SemanticsData');

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Rect>('rect', rect, showName: false));
    properties.add(TransformProperty('transform', transform, showName: false, defaultValue: null));
    properties.add(DoubleProperty('elevation', elevation, defaultValue: 0.0));
    properties.add(DoubleProperty('thickness', thickness, defaultValue: 0.0));
    final List<String> actionSummary = <String>[
      for (final SemanticsAction action in SemanticsAction.values)
        if ((actions & action.index) != 0)
          action.name,
    ];
    final List<String?> customSemanticsActionSummary = customSemanticsActionIds!
      .map<String?>((int actionId) => CustomSemanticsAction.getAction(actionId)!.label)
      .toList();
    properties.add(IterableProperty<String>('actions', actionSummary, ifEmpty: null));
    properties.add(IterableProperty<String?>('customActions', customSemanticsActionSummary, ifEmpty: null));

    final List<String> flagSummary = <String>[
      for (final SemanticsFlag flag in SemanticsFlag.values)
        if ((flags & flag.index) != 0)
          flag.name,
    ];
    properties.add(IterableProperty<String>('flags', flagSummary, ifEmpty: null));
    properties.add(AttributedStringProperty('label', attributedLabel));
    properties.add(AttributedStringProperty('value', attributedValue));
    properties.add(AttributedStringProperty('increasedValue', attributedIncreasedValue));
    properties.add(AttributedStringProperty('decreasedValue', attributedDecreasedValue));
    properties.add(AttributedStringProperty('hint', attributedHint));
    properties.add(StringProperty('tooltip', tooltip, defaultValue: ''));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection, defaultValue: null));
    if (textSelection?.isValid ?? false) {
      properties.add(MessageProperty('textSelection', '[${textSelection!.start}, ${textSelection!.end}]'));
    }
    properties.add(IntProperty('platformViewId', platformViewId, defaultValue: null));
    properties.add(IntProperty('maxValueLength', maxValueLength, defaultValue: null));
    properties.add(IntProperty('currentValueLength', currentValueLength, defaultValue: null));
    properties.add(IntProperty('scrollChildren', scrollChildCount, defaultValue: null));
    properties.add(IntProperty('scrollIndex', scrollIndex, defaultValue: null));
    properties.add(DoubleProperty('scrollExtentMin', scrollExtentMin, defaultValue: null));
    properties.add(DoubleProperty('scrollPosition', scrollPosition, defaultValue: null));
    properties.add(DoubleProperty('scrollExtentMax', scrollExtentMax, defaultValue: null));
  }

  @override
  bool operator ==(Object other) {
    return other is SemanticsData
        && other.flags == flags
        && other.actions == actions
        && other.attributedLabel == attributedLabel
        && other.attributedValue == attributedValue
        && other.attributedIncreasedValue == attributedIncreasedValue
        && other.attributedDecreasedValue == attributedDecreasedValue
        && other.attributedHint == attributedHint
        && other.tooltip == tooltip
        && other.textDirection == textDirection
        && other.rect == rect
        && setEquals(other.tags, tags)
        && other.scrollChildCount == scrollChildCount
        && other.scrollIndex == scrollIndex
        && other.textSelection == textSelection
        && other.scrollPosition == scrollPosition
        && other.scrollExtentMax == scrollExtentMax
        && other.scrollExtentMin == scrollExtentMin
        && other.platformViewId == platformViewId
        && other.maxValueLength == maxValueLength
        && other.currentValueLength == currentValueLength
        && other.transform == transform
        && other.elevation == elevation
        && other.thickness == thickness
        && _sortedListsEqual(other.customSemanticsActionIds, customSemanticsActionIds);
  }

  @override
  int get hashCode => Object.hash(
    flags,
    actions,
    attributedLabel,
    attributedValue,
    attributedIncreasedValue,
    attributedDecreasedValue,
    attributedHint,
    tooltip,
    textDirection,
    rect,
    tags,
    textSelection,
    scrollChildCount,
    scrollIndex,
    scrollPosition,
    scrollExtentMax,
    scrollExtentMin,
    platformViewId,
    maxValueLength,
    Object.hash(
      currentValueLength,
      transform,
      elevation,
      thickness,
      customSemanticsActionIds == null ? null : Object.hashAll(customSemanticsActionIds!),
    ),
  );

  static bool _sortedListsEqual(List<int>? left, List<int>? right) {
    if (left == null && right == null) {
      return true;
    }
    if (left != null && right != null) {
      if (left.length != right.length) {
        return false;
      }
      for (int i = 0; i < left.length; i++) {
        if (left[i] != right[i]) {
          return false;
      }
        }
      return true;
    }
    return false;
  }
}

class _SemanticsDiagnosticableNode extends DiagnosticableNode<SemanticsNode> {
  _SemanticsDiagnosticableNode({
    super.name,
    required super.value,
    required super.style,
    required this.childOrder,
  });

  final DebugSemanticsDumpOrder childOrder;

  @override
  List<DiagnosticsNode> getChildren() => value.debugDescribeChildren(childOrder: childOrder);
}

@immutable
class SemanticsHintOverrides extends DiagnosticableTree {
  const SemanticsHintOverrides({
    this.onTapHint,
    this.onLongPressHint,
  }) : assert(onTapHint != ''),
       assert(onLongPressHint != '');

  final String? onTapHint;

  final String? onLongPressHint;

  bool get isNotEmpty => onTapHint != null || onLongPressHint != null;

  @override
  int get hashCode => Object.hash(onTapHint, onLongPressHint);

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is SemanticsHintOverrides
        && other.onTapHint == onTapHint
        && other.onLongPressHint == onLongPressHint;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('onTapHint', onTapHint, defaultValue: null));
    properties.add(StringProperty('onLongPressHint', onLongPressHint, defaultValue: null));
  }
}

@immutable
class SemanticsProperties extends DiagnosticableTree {
  const SemanticsProperties({
    this.enabled,
    this.checked,
    this.mixed,
    this.expanded,
    this.selected,
    this.toggled,
    this.button,
    this.link,
    this.header,
    this.textField,
    this.slider,
    this.keyboardKey,
    this.readOnly,
    this.focusable,
    this.focused,
    this.inMutuallyExclusiveGroup,
    this.hidden,
    this.obscured,
    this.multiline,
    this.scopesRoute,
    this.namesRoute,
    this.image,
    this.liveRegion,
    this.maxValueLength,
    this.currentValueLength,
    this.label,
    this.attributedLabel,
    this.value,
    this.attributedValue,
    this.increasedValue,
    this.attributedIncreasedValue,
    this.decreasedValue,
    this.attributedDecreasedValue,
    this.hint,
    this.tooltip,
    this.attributedHint,
    this.hintOverrides,
    this.textDirection,
    this.sortKey,
    this.tagForChildren,
    this.onTap,
    this.onLongPress,
    this.onScrollLeft,
    this.onScrollRight,
    this.onScrollUp,
    this.onScrollDown,
    this.onIncrease,
    this.onDecrease,
    this.onCopy,
    this.onCut,
    this.onPaste,
    this.onMoveCursorForwardByCharacter,
    this.onMoveCursorBackwardByCharacter,
    this.onMoveCursorForwardByWord,
    this.onMoveCursorBackwardByWord,
    this.onSetSelection,
    this.onSetText,
    this.onDidGainAccessibilityFocus,
    this.onDidLoseAccessibilityFocus,
    this.onDismiss,
    this.customSemanticsActions,
  }) : assert(label == null || attributedLabel == null, 'Only one of label or attributedLabel should be provided'),
       assert(value == null || attributedValue == null, 'Only one of value or attributedValue should be provided'),
       assert(increasedValue == null || attributedIncreasedValue == null, 'Only one of increasedValue or attributedIncreasedValue should be provided'),
       assert(decreasedValue == null || attributedDecreasedValue == null, 'Only one of decreasedValue or attributedDecreasedValue should be provided'),
       assert(hint == null || attributedHint == null, 'Only one of hint or attributedHint should be provided');

  final bool? enabled;

  final bool? checked;

  final bool? mixed;

  final bool? expanded;

  final bool? toggled;

  final bool? selected;

  final bool? button;

  final bool? link;

  final bool? header;

  final bool? textField;

  final bool? slider;

  final bool? keyboardKey;

  final bool? readOnly;

  final bool? focusable;

  final bool? focused;

  final bool? inMutuallyExclusiveGroup;

  final bool? hidden;

  final bool? obscured;

  final bool? multiline;

  final bool? scopesRoute;

  final bool? namesRoute;

  final bool? image;

  final bool? liveRegion;

  final int? maxValueLength;

  final int? currentValueLength;

  final String? label;

  final AttributedString? attributedLabel;

  final String? value;

  final AttributedString? attributedValue;

  final String? increasedValue;

  final AttributedString? attributedIncreasedValue;

  final String? decreasedValue;

  final AttributedString? attributedDecreasedValue;

  final String? hint;

  final AttributedString? attributedHint;

  final String? tooltip;

  final SemanticsHintOverrides? hintOverrides;

  final TextDirection? textDirection;

  final SemanticsSortKey? sortKey;

  final SemanticsTag? tagForChildren;

  final VoidCallback? onTap;

  final VoidCallback? onLongPress;

  final VoidCallback? onScrollLeft;

  final VoidCallback? onScrollRight;

  final VoidCallback? onScrollUp;

  final VoidCallback? onScrollDown;

  final VoidCallback? onIncrease;

  final VoidCallback? onDecrease;

  final VoidCallback? onCopy;

  final VoidCallback? onCut;

  final VoidCallback? onPaste;

  final MoveCursorHandler? onMoveCursorForwardByCharacter;

  final MoveCursorHandler? onMoveCursorBackwardByCharacter;

  final MoveCursorHandler? onMoveCursorForwardByWord;

  final MoveCursorHandler? onMoveCursorBackwardByWord;

  final SetSelectionHandler? onSetSelection;

  final SetTextHandler? onSetText;

  final VoidCallback? onDidGainAccessibilityFocus;

  final VoidCallback? onDidLoseAccessibilityFocus;

  final VoidCallback? onDismiss;

  final Map<CustomSemanticsAction, VoidCallback>? customSemanticsActions;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<bool>('checked', checked, defaultValue: null));
    properties.add(DiagnosticsProperty<bool>('mixed', mixed, defaultValue: null));
    properties.add(DiagnosticsProperty<bool>('expanded', expanded, defaultValue: null));
    properties.add(DiagnosticsProperty<bool>('selected', selected, defaultValue: null));
    properties.add(StringProperty('label', label, defaultValue: null));
    properties.add(AttributedStringProperty('attributedLabel', attributedLabel, defaultValue: null));
    properties.add(StringProperty('value', value, defaultValue: null));
    properties.add(AttributedStringProperty('attributedValue', attributedValue, defaultValue: null));
    properties.add(StringProperty('increasedValue', value, defaultValue: null));
    properties.add(AttributedStringProperty('attributedIncreasedValue', attributedIncreasedValue, defaultValue: null));
    properties.add(StringProperty('decreasedValue', value, defaultValue: null));
    properties.add(AttributedStringProperty('attributedDecreasedValue', attributedDecreasedValue, defaultValue: null));
    properties.add(StringProperty('hint', hint, defaultValue: null));
    properties.add(AttributedStringProperty('attributedHint', attributedHint, defaultValue: null));
    properties.add(StringProperty('tooltip', tooltip));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection, defaultValue: null));
    properties.add(DiagnosticsProperty<SemanticsSortKey>('sortKey', sortKey, defaultValue: null));
    properties.add(DiagnosticsProperty<SemanticsHintOverrides>('hintOverrides', hintOverrides, defaultValue: null));
  }

  @override
  String toStringShort() => objectRuntimeType(this, 'SemanticsProperties'); // the hashCode isn't important since we're immutable
}

void debugResetSemanticsIdCounter() {
  SemanticsNode._lastIdentifier = 0;
}

class SemanticsNode with DiagnosticableTreeMixin {
  SemanticsNode({
    this.key,
    VoidCallback? showOnScreen,
  }) : _id = _generateNewId(),
       _showOnScreen = showOnScreen;

  SemanticsNode.root({
    this.key,
    VoidCallback? showOnScreen,
    required SemanticsOwner owner,
  }) : _id = 0,
       _showOnScreen = showOnScreen {
    attach(owner);
  }


  // The maximal semantic node identifier generated by the framework.
  //
  // The identifier range for semantic node IDs is split into 2, the least significant 16 bits are
  // reserved for framework generated IDs(generated with _generateNewId), and most significant 32
  // bits are reserved for engine generated IDs.
  static const int _maxFrameworkAccessibilityIdentifier = (1<<16) - 1;

  static int _lastIdentifier = 0;
  static int _generateNewId() {
    _lastIdentifier = (_lastIdentifier + 1) % _maxFrameworkAccessibilityIdentifier;
    return _lastIdentifier;
  }

  final Key? key;

  int get id => _id;
  int _id;

  final VoidCallback? _showOnScreen;

  // GEOMETRY

  Matrix4? get transform => _transform;
  Matrix4? _transform;
  set transform(Matrix4? value) {
    if (!MatrixUtils.matrixEquals(_transform, value)) {
      _transform = value == null || MatrixUtils.isIdentity(value) ? null : value;
      _markDirty();
    }
  }

  Rect get rect => _rect;
  Rect _rect = Rect.zero;
  set rect(Rect value) {
    assert(value.isFinite, '$this (with $owner) tried to set a non-finite rect.');
    if (_rect != value) {
      _rect = value;
      _markDirty();
    }
  }

  Rect? parentSemanticsClipRect;

  Rect? parentPaintClipRect;

  double? elevationAdjustment;

  int? indexInParent;

  bool get isInvisible => !isMergedIntoParent && rect.isEmpty;

  // MERGING

  bool get isMergedIntoParent => _isMergedIntoParent;
  bool _isMergedIntoParent = false;
  set isMergedIntoParent(bool value) {
    if (_isMergedIntoParent == value) {
      return;
    }
    _isMergedIntoParent = value;
    _markDirty();
  }

  bool get areUserActionsBlocked => _areUserActionsBlocked;
  bool _areUserActionsBlocked = false;
  set areUserActionsBlocked(bool value) {
    if (_areUserActionsBlocked == value) {
      return;
    }
    _areUserActionsBlocked = value;
    _markDirty();
  }

  bool get isPartOfNodeMerging => mergeAllDescendantsIntoThisNode || isMergedIntoParent;

  bool get mergeAllDescendantsIntoThisNode => _mergeAllDescendantsIntoThisNode;
  bool _mergeAllDescendantsIntoThisNode = _kEmptyConfig.isMergingSemanticsOfDescendants;


  // CHILDREN

  List<SemanticsNode>? _children;

  late List<SemanticsNode> _debugPreviousSnapshot;

  void _replaceChildren(List<SemanticsNode> newChildren) {
    assert(!newChildren.any((SemanticsNode child) => child == this));
    assert(() {
      if (identical(newChildren, _children)) {
        final List<DiagnosticsNode> mutationErrors = <DiagnosticsNode>[];
        if (newChildren.length != _debugPreviousSnapshot.length) {
          mutationErrors.add(ErrorDescription(
            "The list's length has changed from ${_debugPreviousSnapshot.length} "
            'to ${newChildren.length}.',
          ));
        } else {
          for (int i = 0; i < newChildren.length; i++) {
            if (!identical(newChildren[i], _debugPreviousSnapshot[i])) {
              if (mutationErrors.isNotEmpty) {
                mutationErrors.add(ErrorSpacer());
              }
              mutationErrors.add(ErrorDescription('Child node at position $i was replaced:'));
              mutationErrors.add(newChildren[i].toDiagnosticsNode(name: 'Previous child', style: DiagnosticsTreeStyle.singleLine));
              mutationErrors.add(_debugPreviousSnapshot[i].toDiagnosticsNode(name: 'New child', style: DiagnosticsTreeStyle.singleLine));
            }
          }
        }
        if (mutationErrors.isNotEmpty) {
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary('Failed to replace child semantics nodes because the list of `SemanticsNode`s was mutated.'),
            ErrorHint('Instead of mutating the existing list, create a new list containing the desired `SemanticsNode`s.'),
            ErrorDescription('Error details:'),
            ...mutationErrors,
          ]);
        }
      }
      assert(!newChildren.any((SemanticsNode node) => node.isMergedIntoParent) || isPartOfNodeMerging);

      _debugPreviousSnapshot = List<SemanticsNode>.of(newChildren);

      SemanticsNode ancestor = this;
      while (ancestor.parent is SemanticsNode) {
        ancestor = ancestor.parent!;
      }
      assert(!newChildren.any((SemanticsNode child) => child == ancestor));
      return true;
    }());
    assert(() {
      final Set<SemanticsNode> seenChildren = <SemanticsNode>{};
      for (final SemanticsNode child in newChildren) {
        assert(seenChildren.add(child));
      } // check for duplicate adds
      return true;
    }());

    // The goal of this function is updating sawChange.
    if (_children != null) {
      for (final SemanticsNode child in _children!) {
        child._dead = true;
      }
    }
    for (final SemanticsNode child in newChildren) {
      assert(!child.isInvisible, 'Child $child is invisible and should not be added as a child of $this.');
      child._dead = false;
    }
    bool sawChange = false;
    if (_children != null) {
      for (final SemanticsNode child in _children!) {
        if (child._dead) {
          if (child.parent == this) {
            // we might have already had our child stolen from us by
            // another node that is deeper in the tree.
            _dropChild(child);
          }
          sawChange = true;
        }
      }
    }
    for (final SemanticsNode child in newChildren) {
      if (child.parent != this) {
        if (child.parent != null) {
          // we're rebuilding the tree from the bottom up, so it's possible
          // that our child was, in the last pass, a child of one of our
          // ancestors. In that case, we drop the child eagerly here.
          // TODO(ianh): Find a way to assert that the same node didn't
          // actually appear in the tree in two places.
          child.parent?._dropChild(child);
        }
        assert(!child.attached);
        _adoptChild(child);
        sawChange = true;
      }
    }
    if (!sawChange && _children != null) {
      assert(newChildren.length == _children!.length);
      // Did the order change?
      for (int i = 0; i < _children!.length; i++) {
        if (_children![i].id != newChildren[i].id) {
          sawChange = true;
          break;
        }
      }
    }
    _children = newChildren;
    if (sawChange) {
      _markDirty();
    }
  }

  bool get hasChildren => _children?.isNotEmpty ?? false;
  bool _dead = false;

  int get childrenCount => hasChildren ? _children!.length : 0;

  void visitChildren(SemanticsNodeVisitor visitor) {
    if (_children != null) {
      for (final SemanticsNode child in _children!) {
        if (!visitor(child)) {
          return;
        }
      }
    }
  }

  bool _visitDescendants(SemanticsNodeVisitor visitor) {
    if (_children != null) {
      for (final SemanticsNode child in _children!) {
        if (!visitor(child) || !child._visitDescendants(visitor)) {
          return false;
        }
      }
    }
    return true;
  }

  SemanticsOwner? get owner => _owner;
  SemanticsOwner? _owner;

  bool get attached => _owner != null;

  SemanticsNode? get parent => _parent;
  SemanticsNode? _parent;

  int get depth => _depth;
  int _depth = 0;

  void _redepthChild(SemanticsNode child) {
    assert(child.owner == owner);
    if (child._depth <= _depth) {
      child._depth = _depth + 1;
      child._redepthChildren();
    }
  }

  void _redepthChildren() {
    _children?.forEach(_redepthChild);
  }

  void _adoptChild(SemanticsNode child) {
    assert(child._parent == null);
    assert(() {
      SemanticsNode node = this;
      while (node.parent != null) {
        node = node.parent!;
      }
      assert(node != child); // indicates we are about to create a cycle
      return true;
    }());
    child._parent = this;
    if (attached) {
      child.attach(_owner!);
    }
    _redepthChild(child);
  }

  void _dropChild(SemanticsNode child) {
    assert(child._parent == this);
    assert(child.attached == attached);
    child._parent = null;
    if (attached) {
      child.detach();
    }
  }

  @visibleForTesting
  void attach(SemanticsOwner owner) {
    assert(_owner == null);
    _owner = owner;
    while (owner._nodes.containsKey(id)) {
      // Ids may repeat if the Flutter has generated > 2^16 ids. We need to keep
      // regenerating the id until we found an id that is not used.
      _id = _generateNewId();
    }
    owner._nodes[id] = this;
    owner._detachedNodes.remove(this);
    if (_dirty) {
      _dirty = false;
      _markDirty();
    }
    if (_children != null) {
      for (final SemanticsNode child in _children!) {
        child.attach(owner);
      }
    }
  }

  @visibleForTesting
  void detach() {
    assert(_owner != null);
    assert(owner!._nodes.containsKey(id));
    assert(!owner!._detachedNodes.contains(this));
    owner!._nodes.remove(id);
    owner!._detachedNodes.add(this);
    _owner = null;
    assert(parent == null || attached == parent!.attached);
    if (_children != null) {
      for (final SemanticsNode child in _children!) {
        // The list of children may be stale and may contain nodes that have
        // been assigned to a different parent.
        if (child.parent == this) {
          child.detach();
        }
      }
    }
    // The other side will have forgotten this node if we ever send
    // it again, so make sure to mark it dirty so that it'll get
    // sent if it is resurrected.
    _markDirty();
  }

  // DIRTY MANAGEMENT

  bool _dirty = false;
  void _markDirty() {
    if (_dirty) {
      return;
    }
    _dirty = true;
    if (attached) {
      assert(!owner!._detachedNodes.contains(this));
      owner!._dirtyNodes.add(this);
    }
  }

  bool _isDifferentFromCurrentSemanticAnnotation(SemanticsConfiguration config) {
    return _attributedLabel != config.attributedLabel
        || _attributedHint != config.attributedHint
        || _elevation != config.elevation
        || _thickness != config.thickness
        || _attributedValue != config.attributedValue
        || _attributedIncreasedValue != config.attributedIncreasedValue
        || _attributedDecreasedValue != config.attributedDecreasedValue
        || _tooltip != config.tooltip
        || _flags != config._flags
        || _textDirection != config.textDirection
        || _sortKey != config._sortKey
        || _textSelection != config._textSelection
        || _scrollPosition != config._scrollPosition
        || _scrollExtentMax != config._scrollExtentMax
        || _scrollExtentMin != config._scrollExtentMin
        || _actionsAsBits != config._actionsAsBits
        || indexInParent != config.indexInParent
        || platformViewId != config.platformViewId
        || _maxValueLength != config._maxValueLength
        || _currentValueLength != config._currentValueLength
        || _mergeAllDescendantsIntoThisNode != config.isMergingSemanticsOfDescendants
        || _areUserActionsBlocked != config.isBlockingUserActions;
  }

  // TAGS, LABELS, ACTIONS

  Map<SemanticsAction, SemanticsActionHandler> _actions = _kEmptyConfig._actions;
  Map<CustomSemanticsAction, VoidCallback> _customSemanticsActions = _kEmptyConfig._customSemanticsActions;

  int get _effectiveActionsAsBits => _areUserActionsBlocked ? _actionsAsBits & _kUnblockedUserActions : _actionsAsBits;
  int _actionsAsBits = _kEmptyConfig._actionsAsBits;

  Set<SemanticsTag>? tags;

  bool isTagged(SemanticsTag tag) => tags != null && tags!.contains(tag);

  int _flags = _kEmptyConfig._flags;

  bool hasFlag(SemanticsFlag flag) => _flags & flag.index != 0;

  String get label => _attributedLabel.string;

  AttributedString get attributedLabel => _attributedLabel;
  AttributedString _attributedLabel = _kEmptyConfig.attributedLabel;

  String get value => _attributedValue.string;

  AttributedString get attributedValue => _attributedValue;
  AttributedString _attributedValue = _kEmptyConfig.attributedValue;

  String get increasedValue => _attributedIncreasedValue.string;

  AttributedString get attributedIncreasedValue => _attributedIncreasedValue;
  AttributedString _attributedIncreasedValue = _kEmptyConfig.attributedIncreasedValue;

  String get decreasedValue => _attributedDecreasedValue.string;

  AttributedString get attributedDecreasedValue => _attributedDecreasedValue;
  AttributedString _attributedDecreasedValue = _kEmptyConfig.attributedDecreasedValue;

  String get hint => _attributedHint.string;

  AttributedString get attributedHint => _attributedHint;
  AttributedString _attributedHint = _kEmptyConfig.attributedHint;

  String get tooltip => _tooltip;
  String _tooltip = _kEmptyConfig.tooltip;

  double get elevation => _elevation;
  double _elevation = _kEmptyConfig.elevation;

  double get thickness => _thickness;
  double _thickness = _kEmptyConfig.thickness;

  SemanticsHintOverrides? get hintOverrides => _hintOverrides;
  SemanticsHintOverrides? _hintOverrides;

  TextDirection? get textDirection => _textDirection;
  TextDirection? _textDirection = _kEmptyConfig.textDirection;

  SemanticsSortKey? get sortKey => _sortKey;
  SemanticsSortKey? _sortKey;

  TextSelection? get textSelection => _textSelection;
  TextSelection? _textSelection;

  bool? get isMultiline => _isMultiline;
  bool? _isMultiline;

  int? get scrollChildCount => _scrollChildCount;
  int? _scrollChildCount;

  int? get scrollIndex => _scrollIndex;
  int? _scrollIndex;

  double? get scrollPosition => _scrollPosition;
  double? _scrollPosition;

  double? get scrollExtentMax => _scrollExtentMax;
  double? _scrollExtentMax;

  double? get scrollExtentMin => _scrollExtentMin;
  double? _scrollExtentMin;

  int? get platformViewId => _platformViewId;
  int? _platformViewId;

  int? get maxValueLength => _maxValueLength;
  int? _maxValueLength;

  int? get currentValueLength => _currentValueLength;
  int? _currentValueLength;

  bool _canPerformAction(SemanticsAction action) => _actions.containsKey(action);

  static final SemanticsConfiguration _kEmptyConfig = SemanticsConfiguration();

  void updateWith({
    required SemanticsConfiguration? config,
    List<SemanticsNode>? childrenInInversePaintOrder,
  }) {
    config ??= _kEmptyConfig;
    if (_isDifferentFromCurrentSemanticAnnotation(config)) {
      _markDirty();
    }

    assert(
      config.platformViewId == null || childrenInInversePaintOrder == null || childrenInInversePaintOrder.isEmpty,
      'SemanticsNodes with children must not specify a platformViewId.',
    );

    _attributedLabel = config.attributedLabel;
    _attributedValue = config.attributedValue;
    _attributedIncreasedValue = config.attributedIncreasedValue;
    _attributedDecreasedValue = config.attributedDecreasedValue;
    _attributedHint = config.attributedHint;
    _tooltip = config.tooltip;
    _hintOverrides = config.hintOverrides;
    _elevation = config.elevation;
    _thickness = config.thickness;
    _flags = config._flags;
    _textDirection = config.textDirection;
    _sortKey = config.sortKey;
    _actions = Map<SemanticsAction, SemanticsActionHandler>.of(config._actions);
    _customSemanticsActions = Map<CustomSemanticsAction, VoidCallback>.of(config._customSemanticsActions);
    _actionsAsBits = config._actionsAsBits;
    _textSelection = config._textSelection;
    _isMultiline = config.isMultiline;
    _scrollPosition = config._scrollPosition;
    _scrollExtentMax = config._scrollExtentMax;
    _scrollExtentMin = config._scrollExtentMin;
    _mergeAllDescendantsIntoThisNode = config.isMergingSemanticsOfDescendants;
    _scrollChildCount = config.scrollChildCount;
    _scrollIndex = config.scrollIndex;
    indexInParent = config.indexInParent;
    _platformViewId = config._platformViewId;
    _maxValueLength = config._maxValueLength;
    _currentValueLength = config._currentValueLength;
    _areUserActionsBlocked = config.isBlockingUserActions;
    _replaceChildren(childrenInInversePaintOrder ?? const <SemanticsNode>[]);

    assert(
      !_canPerformAction(SemanticsAction.increase) || (value == '') == (increasedValue == ''),
      'A SemanticsNode with action "increase" needs to be annotated with either both "value" and "increasedValue" or neither',
    );
    assert(
      !_canPerformAction(SemanticsAction.decrease) || (value == '') == (decreasedValue == ''),
      'A SemanticsNode with action "decrease" needs to be annotated with either both "value" and "decreasedValue" or neither',
    );
  }


  SemanticsData getSemanticsData() {
    int flags = _flags;
    // Can't use _effectiveActionsAsBits here. The filtering of action bits
    // must be done after the merging the its descendants.
    int actions = _actionsAsBits;
    AttributedString attributedLabel = _attributedLabel;
    AttributedString attributedValue = _attributedValue;
    AttributedString attributedIncreasedValue = _attributedIncreasedValue;
    AttributedString attributedDecreasedValue = _attributedDecreasedValue;
    AttributedString attributedHint = _attributedHint;
    String tooltip = _tooltip;
    TextDirection? textDirection = _textDirection;
    Set<SemanticsTag>? mergedTags = tags == null ? null : Set<SemanticsTag>.of(tags!);
    TextSelection? textSelection = _textSelection;
    int? scrollChildCount = _scrollChildCount;
    int? scrollIndex = _scrollIndex;
    double? scrollPosition = _scrollPosition;
    double? scrollExtentMax = _scrollExtentMax;
    double? scrollExtentMin = _scrollExtentMin;
    int? platformViewId = _platformViewId;
    int? maxValueLength = _maxValueLength;
    int? currentValueLength = _currentValueLength;
    final double elevation = _elevation;
    double thickness = _thickness;
    final Set<int> customSemanticsActionIds = <int>{};
    for (final CustomSemanticsAction action in _customSemanticsActions.keys) {
      customSemanticsActionIds.add(CustomSemanticsAction.getIdentifier(action));
    }
    if (hintOverrides != null) {
      if (hintOverrides!.onTapHint != null) {
        final CustomSemanticsAction action = CustomSemanticsAction.overridingAction(
          hint: hintOverrides!.onTapHint!,
          action: SemanticsAction.tap,
        );
        customSemanticsActionIds.add(CustomSemanticsAction.getIdentifier(action));
      }
      if (hintOverrides!.onLongPressHint != null) {
        final CustomSemanticsAction action = CustomSemanticsAction.overridingAction(
          hint: hintOverrides!.onLongPressHint!,
          action: SemanticsAction.longPress,
        );
        customSemanticsActionIds.add(CustomSemanticsAction.getIdentifier(action));
      }
    }

    if (mergeAllDescendantsIntoThisNode) {
      _visitDescendants((SemanticsNode node) {
        assert(node.isMergedIntoParent);
        flags |= node._flags;
        actions |= node._effectiveActionsAsBits;

        textDirection ??= node._textDirection;
        textSelection ??= node._textSelection;
        scrollChildCount ??= node._scrollChildCount;
        scrollIndex ??= node._scrollIndex;
        scrollPosition ??= node._scrollPosition;
        scrollExtentMax ??= node._scrollExtentMax;
        scrollExtentMin ??= node._scrollExtentMin;
        platformViewId ??= node._platformViewId;
        maxValueLength ??= node._maxValueLength;
        currentValueLength ??= node._currentValueLength;
        if (attributedValue.string == '') {
          attributedValue = node._attributedValue;
        }
        if (attributedIncreasedValue.string == '') {
          attributedIncreasedValue = node._attributedIncreasedValue;
        }
        if (attributedDecreasedValue.string == '') {
          attributedDecreasedValue = node._attributedDecreasedValue;
        }
        if (tooltip == '') {
          tooltip = node._tooltip;
        }
        if (node.tags != null) {
          mergedTags ??= <SemanticsTag>{};
          mergedTags!.addAll(node.tags!);
        }
        for (final CustomSemanticsAction action in _customSemanticsActions.keys) {
          customSemanticsActionIds.add(CustomSemanticsAction.getIdentifier(action));
        }
        if (node.hintOverrides != null) {
          if (node.hintOverrides!.onTapHint != null) {
            final CustomSemanticsAction action = CustomSemanticsAction.overridingAction(
              hint: node.hintOverrides!.onTapHint!,
              action: SemanticsAction.tap,
            );
            customSemanticsActionIds.add(CustomSemanticsAction.getIdentifier(action));
          }
          if (node.hintOverrides!.onLongPressHint != null) {
            final CustomSemanticsAction action = CustomSemanticsAction.overridingAction(
              hint: node.hintOverrides!.onLongPressHint!,
              action: SemanticsAction.longPress,
            );
            customSemanticsActionIds.add(CustomSemanticsAction.getIdentifier(action));
          }
        }
        attributedLabel = _concatAttributedString(
          thisAttributedString: attributedLabel,
          thisTextDirection: textDirection,
          otherAttributedString: node._attributedLabel,
          otherTextDirection: node._textDirection,
        );
        attributedHint = _concatAttributedString(
          thisAttributedString: attributedHint,
          thisTextDirection: textDirection,
          otherAttributedString: node._attributedHint,
          otherTextDirection: node._textDirection,
        );

        thickness = math.max(thickness, node._thickness + node._elevation);

        return true;
      });
    }

    return SemanticsData(
      flags: flags,
      actions: _areUserActionsBlocked ? actions & _kUnblockedUserActions : actions,
      attributedLabel: attributedLabel,
      attributedValue: attributedValue,
      attributedIncreasedValue: attributedIncreasedValue,
      attributedDecreasedValue: attributedDecreasedValue,
      attributedHint: attributedHint,
      tooltip: tooltip,
      textDirection: textDirection,
      rect: rect,
      transform: transform,
      elevation: elevation,
      thickness: thickness,
      tags: mergedTags,
      textSelection: textSelection,
      scrollChildCount: scrollChildCount,
      scrollIndex: scrollIndex,
      scrollPosition: scrollPosition,
      scrollExtentMax: scrollExtentMax,
      scrollExtentMin: scrollExtentMin,
      platformViewId: platformViewId,
      maxValueLength: maxValueLength,
      currentValueLength: currentValueLength,
      customSemanticsActionIds: customSemanticsActionIds.toList()..sort(),
    );
  }

  static Float64List _initIdentityTransform() {
    return Matrix4.identity().storage;
  }

  static final Int32List _kEmptyChildList = Int32List(0);
  static final Int32List _kEmptyCustomSemanticsActionsList = Int32List(0);
  static final Float64List _kIdentityTransform = _initIdentityTransform();

  void _addToUpdate(SemanticsUpdateBuilder builder, Set<int> customSemanticsActionIdsUpdate) {
    assert(_dirty);
    final SemanticsData data = getSemanticsData();
    final Int32List childrenInTraversalOrder;
    final Int32List childrenInHitTestOrder;
    if (!hasChildren || mergeAllDescendantsIntoThisNode) {
      childrenInTraversalOrder = _kEmptyChildList;
      childrenInHitTestOrder = _kEmptyChildList;
    } else {
      final int childCount = _children!.length;
      final List<SemanticsNode> sortedChildren = _childrenInTraversalOrder();
      childrenInTraversalOrder = Int32List(childCount);
      for (int i = 0; i < childCount; i += 1) {
        childrenInTraversalOrder[i] = sortedChildren[i].id;
      }
      // _children is sorted in paint order, so we invert it to get the hit test
      // order.
      childrenInHitTestOrder = Int32List(childCount);
      for (int i = childCount - 1; i >= 0; i -= 1) {
        childrenInHitTestOrder[i] = _children![childCount - i - 1].id;
      }
    }
    Int32List? customSemanticsActionIds;
    if (data.customSemanticsActionIds?.isNotEmpty ?? false) {
      customSemanticsActionIds = Int32List(data.customSemanticsActionIds!.length);
      for (int i = 0; i < data.customSemanticsActionIds!.length; i++) {
        customSemanticsActionIds[i] = data.customSemanticsActionIds![i];
        customSemanticsActionIdsUpdate.add(data.customSemanticsActionIds![i]);
      }
    }
    builder.updateNode(
      id: id,
      flags: data.flags,
      actions: data.actions,
      rect: data.rect,
      label: data.attributedLabel.string,
      labelAttributes: data.attributedLabel.attributes,
      value: data.attributedValue.string,
      valueAttributes: data.attributedValue.attributes,
      increasedValue: data.attributedIncreasedValue.string,
      increasedValueAttributes: data.attributedIncreasedValue.attributes,
      decreasedValue: data.attributedDecreasedValue.string,
      decreasedValueAttributes: data.attributedDecreasedValue.attributes,
      hint: data.attributedHint.string,
      hintAttributes: data.attributedHint.attributes,
      tooltip: data.tooltip,
      textDirection: data.textDirection,
      textSelectionBase: data.textSelection != null ? data.textSelection!.baseOffset : -1,
      textSelectionExtent: data.textSelection != null ? data.textSelection!.extentOffset : -1,
      platformViewId: data.platformViewId ?? -1,
      maxValueLength: data.maxValueLength ?? -1,
      currentValueLength: data.currentValueLength ?? -1,
      scrollChildren: data.scrollChildCount ?? 0,
      scrollIndex: data.scrollIndex ?? 0 ,
      scrollPosition: data.scrollPosition ?? double.nan,
      scrollExtentMax: data.scrollExtentMax ?? double.nan,
      scrollExtentMin: data.scrollExtentMin ?? double.nan,
      transform: data.transform?.storage ?? _kIdentityTransform,
      elevation: data.elevation,
      thickness: data.thickness,
      childrenInTraversalOrder: childrenInTraversalOrder,
      childrenInHitTestOrder: childrenInHitTestOrder,
      additionalActions: customSemanticsActionIds ?? _kEmptyCustomSemanticsActionsList,
    );
    _dirty = false;
  }

  List<SemanticsNode> _childrenInTraversalOrder() {
    TextDirection? inheritedTextDirection = textDirection;
    SemanticsNode? ancestor = parent;
    while (inheritedTextDirection == null && ancestor != null) {
      inheritedTextDirection = ancestor.textDirection;
      ancestor = ancestor.parent;
    }

    List<SemanticsNode>? childrenInDefaultOrder;
    if (inheritedTextDirection != null) {
      childrenInDefaultOrder = _childrenInDefaultOrder(_children!, inheritedTextDirection);
    } else {
      // In the absence of text direction default to paint order.
      childrenInDefaultOrder = _children;
    }

    // List.sort does not guarantee stable sort order. Therefore, children are
    // first partitioned into groups that have compatible sort keys, i.e. keys
    // in the same group can be compared to each other. These groups stay in
    // the same place. Only children within the same group are sorted.
    final List<_TraversalSortNode> everythingSorted = <_TraversalSortNode>[];
    final List<_TraversalSortNode> sortNodes = <_TraversalSortNode>[];
    SemanticsSortKey? lastSortKey;
    for (int position = 0; position < childrenInDefaultOrder!.length; position += 1) {
      final SemanticsNode child = childrenInDefaultOrder[position];
      final SemanticsSortKey? sortKey = child.sortKey;
      lastSortKey = position > 0
          ? childrenInDefaultOrder[position - 1].sortKey
          : null;
      final bool isCompatibleWithPreviousSortKey = position == 0 ||
          sortKey.runtimeType == lastSortKey.runtimeType &&
          (sortKey == null || sortKey.name == lastSortKey!.name);
      if (!isCompatibleWithPreviousSortKey && sortNodes.isNotEmpty) {
        // Do not sort groups with null sort keys. List.sort does not guarantee
        // a stable sort order.
        if (lastSortKey != null) {
          sortNodes.sort();
        }
        everythingSorted.addAll(sortNodes);
        sortNodes.clear();
      }

      sortNodes.add(_TraversalSortNode(
        node: child,
        sortKey: sortKey,
        position: position,
      ));
    }

    // Do not sort groups with null sort keys. List.sort does not guarantee
    // a stable sort order.
    if (lastSortKey != null) {
      sortNodes.sort();
    }
    everythingSorted.addAll(sortNodes);

    return everythingSorted
      .map<SemanticsNode>((_TraversalSortNode sortNode) => sortNode.node)
      .toList();
  }

  void sendEvent(SemanticsEvent event) {
    if (!attached) {
      return;
    }
    SystemChannels.accessibility.send(event.toMap(nodeId: id));
  }

  bool _debugIsActionBlocked(SemanticsAction action) {
    bool result = false;
    assert((){
      result = (_effectiveActionsAsBits & action.index) == 0;
      return true;
    }());
    return result;
  }

  @override
  String toStringShort() => '${objectRuntimeType(this, 'SemanticsNode')}#$id';

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    bool hideOwner = true;
    if (_dirty) {
      final bool inDirtyNodes = owner != null && owner!._dirtyNodes.contains(this);
      properties.add(FlagProperty('inDirtyNodes', value: inDirtyNodes, ifTrue: 'dirty', ifFalse: 'STALE'));
      hideOwner = inDirtyNodes;
    }
    properties.add(DiagnosticsProperty<SemanticsOwner>('owner', owner, level: hideOwner ? DiagnosticLevel.hidden : DiagnosticLevel.info));
    properties.add(FlagProperty('isMergedIntoParent', value: isMergedIntoParent, ifTrue: 'merged up ⬆️'));
    properties.add(FlagProperty('mergeAllDescendantsIntoThisNode', value: mergeAllDescendantsIntoThisNode, ifTrue: 'merge boundary ⛔️'));
    final Offset? offset = transform != null ? MatrixUtils.getAsTranslation(transform!) : null;
    if (offset != null) {
      properties.add(DiagnosticsProperty<Rect>('rect', rect.shift(offset), showName: false));
    } else {
      final double? scale = transform != null ? MatrixUtils.getAsScale(transform!) : null;
      String? description;
      if (scale != null) {
        description = '$rect scaled by ${scale.toStringAsFixed(1)}x';
      } else if (transform != null && !MatrixUtils.isIdentity(transform!)) {
        final String matrix = transform.toString().split('\n').take(4).map<String>((String line) => line.substring(4)).join('; ');
        description = '$rect with transform [$matrix]';
      }
      properties.add(DiagnosticsProperty<Rect>('rect', rect, description: description, showName: false));
    }
    properties.add(IterableProperty<String>('tags', tags?.map((SemanticsTag tag) => tag.name), defaultValue: null));
    final List<String> actions = _actions.keys.map<String>((SemanticsAction action) => '${action.name}${_debugIsActionBlocked(action) ? '🚫️' : ''}').toList()..sort();
    final List<String?> customSemanticsActions = _customSemanticsActions.keys
      .map<String?>((CustomSemanticsAction action) => action.label)
      .toList();
    properties.add(IterableProperty<String>('actions', actions, ifEmpty: null));
    properties.add(IterableProperty<String?>('customActions', customSemanticsActions, ifEmpty: null));
    final List<String> flags = SemanticsFlag.values.where((SemanticsFlag flag) => hasFlag(flag)).map((SemanticsFlag flag) => flag.name).toList();
    properties.add(IterableProperty<String>('flags', flags, ifEmpty: null));
    properties.add(FlagProperty('isInvisible', value: isInvisible, ifTrue: 'invisible'));
    properties.add(FlagProperty('isHidden', value: hasFlag(SemanticsFlag.isHidden), ifTrue: 'HIDDEN'));
    properties.add(AttributedStringProperty('label', _attributedLabel));
    properties.add(AttributedStringProperty('value', _attributedValue));
    properties.add(AttributedStringProperty('increasedValue', _attributedIncreasedValue));
    properties.add(AttributedStringProperty('decreasedValue', _attributedDecreasedValue));
    properties.add(AttributedStringProperty('hint', _attributedHint));
    properties.add(StringProperty('tooltip', _tooltip, defaultValue: ''));
    properties.add(EnumProperty<TextDirection>('textDirection', _textDirection, defaultValue: null));
    properties.add(DiagnosticsProperty<SemanticsSortKey>('sortKey', sortKey, defaultValue: null));
    if (_textSelection?.isValid ?? false) {
      properties.add(MessageProperty('text selection', '[${_textSelection!.start}, ${_textSelection!.end}]'));
    }
    properties.add(IntProperty('platformViewId', platformViewId, defaultValue: null));
    properties.add(IntProperty('maxValueLength', maxValueLength, defaultValue: null));
    properties.add(IntProperty('currentValueLength', currentValueLength, defaultValue: null));
    properties.add(IntProperty('scrollChildren', scrollChildCount, defaultValue: null));
    properties.add(IntProperty('scrollIndex', scrollIndex, defaultValue: null));
    properties.add(DoubleProperty('scrollExtentMin', scrollExtentMin, defaultValue: null));
    properties.add(DoubleProperty('scrollPosition', scrollPosition, defaultValue: null));
    properties.add(DoubleProperty('scrollExtentMax', scrollExtentMax, defaultValue: null));
    properties.add(DoubleProperty('elevation', elevation, defaultValue: 0.0));
    properties.add(DoubleProperty('thickness', thickness, defaultValue: 0.0));
  }

  @override
  String toStringDeep({
    String prefixLineOne = '',
    String? prefixOtherLines,
    DiagnosticLevel minLevel = DiagnosticLevel.debug,
    DebugSemanticsDumpOrder childOrder = DebugSemanticsDumpOrder.traversalOrder,
  }) {
    return toDiagnosticsNode(childOrder: childOrder).toStringDeep(prefixLineOne: prefixLineOne, prefixOtherLines: prefixOtherLines, minLevel: minLevel);
  }

  @override
  DiagnosticsNode toDiagnosticsNode({
    String? name,
    DiagnosticsTreeStyle? style = DiagnosticsTreeStyle.sparse,
    DebugSemanticsDumpOrder childOrder = DebugSemanticsDumpOrder.traversalOrder,
  }) {
    return _SemanticsDiagnosticableNode(
      name: name,
      value: this,
      style: style,
      childOrder: childOrder,
    );
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren({ DebugSemanticsDumpOrder childOrder = DebugSemanticsDumpOrder.inverseHitTest }) {
    return debugListChildrenInOrder(childOrder)
      .map<DiagnosticsNode>((SemanticsNode node) => node.toDiagnosticsNode(childOrder: childOrder))
      .toList();
  }

  List<SemanticsNode> debugListChildrenInOrder(DebugSemanticsDumpOrder childOrder) {
    if (_children == null) {
      return const <SemanticsNode>[];
    }

    switch (childOrder) {
      case DebugSemanticsDumpOrder.inverseHitTest:
        return _children!;
      case DebugSemanticsDumpOrder.traversalOrder:
        return _childrenInTraversalOrder();
    }
  }
}

class _BoxEdge implements Comparable<_BoxEdge> {
  _BoxEdge({
    required this.isLeadingEdge,
    required this.offset,
    required this.node,
  }) : assert(offset.isFinite);

  final bool isLeadingEdge;

  final double offset;

  final SemanticsNode node;

  @override
  int compareTo(_BoxEdge other) {
    return offset.compareTo(other.offset);
  }
}

class _SemanticsSortGroup implements Comparable<_SemanticsSortGroup> {
  _SemanticsSortGroup({
    required this.startOffset,
    required this.textDirection,
  });

  final double startOffset;

  final TextDirection textDirection;

  final List<SemanticsNode> nodes = <SemanticsNode>[];

  @override
  int compareTo(_SemanticsSortGroup other) {
    return startOffset.compareTo(other.startOffset);
  }

  List<SemanticsNode> sortedWithinVerticalGroup() {
    final List<_BoxEdge> edges = <_BoxEdge>[];
    for (final SemanticsNode child in nodes) {
      // Using a small delta to shrink child rects removes overlapping cases.
      final Rect childRect = child.rect.deflate(0.1);
      edges.add(_BoxEdge(
        isLeadingEdge: true,
        offset: _pointInParentCoordinates(child, childRect.topLeft).dx,
        node: child,
      ));
      edges.add(_BoxEdge(
        isLeadingEdge: false,
        offset: _pointInParentCoordinates(child, childRect.bottomRight).dx,
        node: child,
      ));
    }
    edges.sort();

    List<_SemanticsSortGroup> horizontalGroups = <_SemanticsSortGroup>[];
    _SemanticsSortGroup? group;
    int depth = 0;
    for (final _BoxEdge edge in edges) {
      if (edge.isLeadingEdge) {
        depth += 1;
        group ??= _SemanticsSortGroup(
          startOffset: edge.offset,
          textDirection: textDirection,
        );
        group.nodes.add(edge.node);
      } else {
        depth -= 1;
      }
      if (depth == 0) {
        horizontalGroups.add(group!);
        group = null;
      }
    }
    horizontalGroups.sort();

    if (textDirection == TextDirection.rtl) {
      horizontalGroups = horizontalGroups.reversed.toList();
    }

    return horizontalGroups
      .expand((_SemanticsSortGroup group) => group.sortedWithinKnot())
      .toList();
  }

  List<SemanticsNode> sortedWithinKnot() {
    if (nodes.length <= 1) {
      // Trivial knot. Nothing to do.
      return nodes;
    }
    final Map<int, SemanticsNode> nodeMap = <int, SemanticsNode>{};
    final Map<int, int> edges = <int, int>{};
    for (final SemanticsNode node in nodes) {
      nodeMap[node.id] = node;
      final Offset center = _pointInParentCoordinates(node, node.rect.center);
      for (final SemanticsNode nextNode in nodes) {
        if (identical(node, nextNode) || edges[nextNode.id] == node.id) {
          // Skip self or when we've already established that the next node
          // points to current node.
          continue;
        }

        final Offset nextCenter = _pointInParentCoordinates(nextNode, nextNode.rect.center);
        final Offset centerDelta = nextCenter - center;
        // When centers coincide, direction is 0.0.
        final double direction = centerDelta.direction;
        final bool isLtrAndForward = textDirection == TextDirection.ltr &&
            -math.pi / 4 < direction && direction < 3 * math.pi / 4;
        final bool isRtlAndForward = textDirection == TextDirection.rtl &&
            (direction < -3 * math.pi / 4 || direction > 3 * math.pi / 4);
        if (isLtrAndForward || isRtlAndForward) {
          edges[node.id] = nextNode.id;
        }
      }
    }

    final List<int> sortedIds = <int>[];
    final Set<int> visitedIds = <int>{};
    final List<SemanticsNode> startNodes = nodes.toList()..sort((SemanticsNode a, SemanticsNode b) {
      final Offset aTopLeft = _pointInParentCoordinates(a, a.rect.topLeft);
      final Offset bTopLeft = _pointInParentCoordinates(b, b.rect.topLeft);
      final int verticalDiff = aTopLeft.dy.compareTo(bTopLeft.dy);
      if (verticalDiff != 0) {
        return -verticalDiff;
      }
      return -aTopLeft.dx.compareTo(bTopLeft.dx);
    });

    void search(int id) {
      if (visitedIds.contains(id)) {
        return;
      }
      visitedIds.add(id);
      if (edges.containsKey(id)) {
        search(edges[id]!);
      }
      sortedIds.add(id);
    }

    startNodes.map<int>((SemanticsNode node) => node.id).forEach(search);
    return sortedIds.map<SemanticsNode>((int id) => nodeMap[id]!).toList().reversed.toList();
  }
}

Offset _pointInParentCoordinates(SemanticsNode node, Offset point) {
  if (node.transform == null) {
    return point;
  }
  final Vector3 vector = Vector3(point.dx, point.dy, 0.0);
  node.transform!.transform3(vector);
  return Offset(vector.x, vector.y);
}

List<SemanticsNode> _childrenInDefaultOrder(List<SemanticsNode> children, TextDirection textDirection) {
  final List<_BoxEdge> edges = <_BoxEdge>[];
  for (final SemanticsNode child in children) {
    assert(child.rect.isFinite);
    // Using a small delta to shrink child rects removes overlapping cases.
    final Rect childRect = child.rect.deflate(0.1);
    edges.add(_BoxEdge(
      isLeadingEdge: true,
      offset: _pointInParentCoordinates(child, childRect.topLeft).dy,
      node: child,
    ));
    edges.add(_BoxEdge(
      isLeadingEdge: false,
      offset: _pointInParentCoordinates(child, childRect.bottomRight).dy,
      node: child,
    ));
  }
  edges.sort();

  final List<_SemanticsSortGroup> verticalGroups = <_SemanticsSortGroup>[];
  _SemanticsSortGroup? group;
  int depth = 0;
  for (final _BoxEdge edge in edges) {
    if (edge.isLeadingEdge) {
      depth += 1;
      group ??= _SemanticsSortGroup(
        startOffset: edge.offset,
        textDirection: textDirection,
      );
      group.nodes.add(edge.node);
    } else {
      depth -= 1;
    }
    if (depth == 0) {
      verticalGroups.add(group!);
      group = null;
    }
  }
  verticalGroups.sort();

  return verticalGroups
    .expand((_SemanticsSortGroup group) => group.sortedWithinVerticalGroup())
    .toList();
}

class _TraversalSortNode implements Comparable<_TraversalSortNode> {
  _TraversalSortNode({
    required this.node,
    this.sortKey,
    required this.position,
  });

  final SemanticsNode node;

  final SemanticsSortKey? sortKey;

  final int position;

  @override
  int compareTo(_TraversalSortNode other) {
    if (sortKey == null || other.sortKey == null) {
      return position - other.position;
    }
    return sortKey!.compareTo(other.sortKey!);
  }
}

class SemanticsOwner extends ChangeNotifier {
  SemanticsOwner({
    required this.onSemanticsUpdate,
  });

  final SemanticsUpdateCallback onSemanticsUpdate;
  final Set<SemanticsNode> _dirtyNodes = <SemanticsNode>{};
  final Map<int, SemanticsNode> _nodes = <int, SemanticsNode>{};
  final Set<SemanticsNode> _detachedNodes = <SemanticsNode>{};

  SemanticsNode? get rootSemanticsNode => _nodes[0];

  @override
  void dispose() {
    _dirtyNodes.clear();
    _nodes.clear();
    _detachedNodes.clear();
    super.dispose();
  }

  void sendSemanticsUpdate() {
    if (_dirtyNodes.isEmpty) {
      return;
    }
    final Set<int> customSemanticsActionIds = <int>{};
    final List<SemanticsNode> visitedNodes = <SemanticsNode>[];
    while (_dirtyNodes.isNotEmpty) {
      final List<SemanticsNode> localDirtyNodes = _dirtyNodes.where((SemanticsNode node) => !_detachedNodes.contains(node)).toList();
      _dirtyNodes.clear();
      _detachedNodes.clear();
      localDirtyNodes.sort((SemanticsNode a, SemanticsNode b) => a.depth - b.depth);
      visitedNodes.addAll(localDirtyNodes);
      for (final SemanticsNode node in localDirtyNodes) {
        assert(node._dirty);
        assert(node.parent == null || !node.parent!.isPartOfNodeMerging || node.isMergedIntoParent);
        if (node.isPartOfNodeMerging) {
          assert(node.mergeAllDescendantsIntoThisNode || node.parent != null);
          // if we're merged into our parent, make sure our parent is added to the dirty list
          if (node.parent != null && node.parent!.isPartOfNodeMerging) {
            node.parent!._markDirty(); // this can add the node to the dirty list
            node._dirty = false; // We don't want to send update for this node.
          }
        }
      }
    }
    visitedNodes.sort((SemanticsNode a, SemanticsNode b) => a.depth - b.depth);
    final SemanticsUpdateBuilder builder = SemanticsBinding.instance.createSemanticsUpdateBuilder();
    for (final SemanticsNode node in visitedNodes) {
      assert(node.parent?._dirty != true); // could be null (no parent) or false (not dirty)
      // The _serialize() method marks the node as not dirty, and
      // recurses through the tree to do a deep serialization of all
      // contiguous dirty nodes. This means that when we return here,
      // it's quite possible that subsequent nodes are no longer
      // dirty. We skip these here.
      // We also skip any nodes that were reset and subsequently
      // dropped entirely (RenderObject.markNeedsSemanticsUpdate()
      // calls reset() on its SemanticsNode if onlyChanges isn't set,
      // which happens e.g. when the node is no longer contributing
      // semantics).
      if (node._dirty && node.attached) {
        node._addToUpdate(builder, customSemanticsActionIds);
      }
    }
    _dirtyNodes.clear();
    for (final int actionId in customSemanticsActionIds) {
      final CustomSemanticsAction action = CustomSemanticsAction.getAction(actionId)!;
      builder.updateCustomAction(id: actionId, label: action.label, hint: action.hint, overrideId: action.action?.index ?? -1);
    }
    onSemanticsUpdate(builder.build());
    notifyListeners();
  }

  SemanticsActionHandler? _getSemanticsActionHandlerForId(int id, SemanticsAction action) {
    SemanticsNode? result = _nodes[id];
    if (result != null && result.isPartOfNodeMerging && !result._canPerformAction(action)) {
      result._visitDescendants((SemanticsNode node) {
        if (node._canPerformAction(action)) {
          result = node;
          return false; // found node, abort walk
        }
        return true; // continue walk
      });
    }
    if (result == null || !result!._canPerformAction(action)) {
      return null;
    }
    return result!._actions[action];
  }

  void performAction(int id, SemanticsAction action, [ Object? args ]) {
    final SemanticsActionHandler? handler = _getSemanticsActionHandlerForId(id, action);
    if (handler != null) {
      handler(args);
      return;
    }

    // Default actions if no [handler] was provided.
    if (action == SemanticsAction.showOnScreen && _nodes[id]?._showOnScreen != null) {
      _nodes[id]!._showOnScreen!();
    }
  }

  SemanticsActionHandler? _getSemanticsActionHandlerForPosition(SemanticsNode node, Offset position, SemanticsAction action) {
    if (node.transform != null) {
      final Matrix4 inverse = Matrix4.identity();
      if (inverse.copyInverse(node.transform!) == 0.0) {
        return null;
      }
      position = MatrixUtils.transformPoint(inverse, position);
    }
    if (!node.rect.contains(position)) {
      return null;
    }
    if (node.mergeAllDescendantsIntoThisNode) {
      SemanticsNode? result;
      node._visitDescendants((SemanticsNode child) {
        if (child._canPerformAction(action)) {
          result = child;
          return false;
        }
        return true;
      });
      return result?._actions[action];
    }
    if (node.hasChildren) {
      for (final SemanticsNode child in node._children!.reversed) {
        final SemanticsActionHandler? handler = _getSemanticsActionHandlerForPosition(child, position, action);
        if (handler != null) {
          return handler;
        }
      }
    }
    return node._actions[action];
  }

  void performActionAt(Offset position, SemanticsAction action, [ Object? args ]) {
    final SemanticsNode? node = rootSemanticsNode;
    if (node == null) {
      return;
    }
    final SemanticsActionHandler? handler = _getSemanticsActionHandlerForPosition(node, position, action);
    if (handler != null) {
      handler(args);
    }
  }

  @override
  String toString() => describeIdentity(this);
}

class SemanticsConfiguration {

  // SEMANTIC BOUNDARY BEHAVIOR

  bool get isSemanticBoundary => _isSemanticBoundary;
  bool _isSemanticBoundary = false;
  set isSemanticBoundary(bool value) {
    assert(!isMergingSemanticsOfDescendants || value);
    _isSemanticBoundary = value;
  }

  bool isBlockingUserActions = false;

  bool explicitChildNodes = false;

  bool isBlockingSemanticsOfPreviouslyPaintedNodes = false;

  // SEMANTIC ANNOTATIONS
  // These will end up on [SemanticsNode]s generated from
  // [SemanticsConfiguration]s.

  bool get hasBeenAnnotated => _hasBeenAnnotated;
  bool _hasBeenAnnotated = false;

  final Map<SemanticsAction, SemanticsActionHandler> _actions = <SemanticsAction, SemanticsActionHandler>{};

  int get _effectiveActionsAsBits => isBlockingUserActions ? _actionsAsBits & _kUnblockedUserActions : _actionsAsBits;
  int _actionsAsBits = 0;

  void _addAction(SemanticsAction action, SemanticsActionHandler handler) {
    _actions[action] = handler;
    _actionsAsBits |= action.index;
    _hasBeenAnnotated = true;
  }

  void _addArgumentlessAction(SemanticsAction action, VoidCallback handler) {
    _addAction(action, (Object? args) {
      assert(args == null);
      handler();
    });
  }

  VoidCallback? get onTap => _onTap;
  VoidCallback? _onTap;
  set onTap(VoidCallback? value) {
    _addArgumentlessAction(SemanticsAction.tap, value!);
    _onTap = value;
  }

  VoidCallback? get onLongPress => _onLongPress;
  VoidCallback? _onLongPress;
  set onLongPress(VoidCallback? value) {
    _addArgumentlessAction(SemanticsAction.longPress, value!);
    _onLongPress = value;
  }

  VoidCallback? get onScrollLeft => _onScrollLeft;
  VoidCallback? _onScrollLeft;
  set onScrollLeft(VoidCallback? value) {
    _addArgumentlessAction(SemanticsAction.scrollLeft, value!);
    _onScrollLeft = value;
  }

  VoidCallback? get onDismiss => _onDismiss;
  VoidCallback? _onDismiss;
  set onDismiss(VoidCallback? value) {
    _addArgumentlessAction(SemanticsAction.dismiss, value!);
    _onDismiss = value;
  }

  VoidCallback? get onScrollRight => _onScrollRight;
  VoidCallback? _onScrollRight;
  set onScrollRight(VoidCallback? value) {
    _addArgumentlessAction(SemanticsAction.scrollRight, value!);
    _onScrollRight = value;
  }

  VoidCallback? get onScrollUp => _onScrollUp;
  VoidCallback? _onScrollUp;
  set onScrollUp(VoidCallback? value) {
    _addArgumentlessAction(SemanticsAction.scrollUp, value!);
    _onScrollUp = value;
  }

  VoidCallback? get onScrollDown => _onScrollDown;
  VoidCallback? _onScrollDown;
  set onScrollDown(VoidCallback? value) {
    _addArgumentlessAction(SemanticsAction.scrollDown, value!);
    _onScrollDown = value;
  }

  VoidCallback? get onIncrease => _onIncrease;
  VoidCallback? _onIncrease;
  set onIncrease(VoidCallback? value) {
    _addArgumentlessAction(SemanticsAction.increase, value!);
    _onIncrease = value;
  }

  VoidCallback? get onDecrease => _onDecrease;
  VoidCallback? _onDecrease;
  set onDecrease(VoidCallback? value) {
    _addArgumentlessAction(SemanticsAction.decrease, value!);
    _onDecrease = value;
  }

  VoidCallback? get onCopy => _onCopy;
  VoidCallback? _onCopy;
  set onCopy(VoidCallback? value) {
    _addArgumentlessAction(SemanticsAction.copy, value!);
    _onCopy = value;
  }

  VoidCallback? get onCut => _onCut;
  VoidCallback? _onCut;
  set onCut(VoidCallback? value) {
    _addArgumentlessAction(SemanticsAction.cut, value!);
    _onCut = value;
  }

  VoidCallback? get onPaste => _onPaste;
  VoidCallback? _onPaste;
  set onPaste(VoidCallback? value) {
    _addArgumentlessAction(SemanticsAction.paste, value!);
    _onPaste = value;
  }

  VoidCallback? get onShowOnScreen => _onShowOnScreen;
  VoidCallback? _onShowOnScreen;
  set onShowOnScreen(VoidCallback? value) {
    _addArgumentlessAction(SemanticsAction.showOnScreen, value!);
    _onShowOnScreen = value;
  }

  MoveCursorHandler? get onMoveCursorForwardByCharacter => _onMoveCursorForwardByCharacter;
  MoveCursorHandler? _onMoveCursorForwardByCharacter;
  set onMoveCursorForwardByCharacter(MoveCursorHandler? value) {
    assert(value != null);
    _addAction(SemanticsAction.moveCursorForwardByCharacter, (Object? args) {
      final bool extendSelection = args! as bool;
      value!(extendSelection);
    });
    _onMoveCursorForwardByCharacter = value;
  }

  MoveCursorHandler? get onMoveCursorBackwardByCharacter => _onMoveCursorBackwardByCharacter;
  MoveCursorHandler? _onMoveCursorBackwardByCharacter;
  set onMoveCursorBackwardByCharacter(MoveCursorHandler? value) {
    assert(value != null);
    _addAction(SemanticsAction.moveCursorBackwardByCharacter, (Object? args) {
      final bool extendSelection = args! as bool;
      value!(extendSelection);
    });
    _onMoveCursorBackwardByCharacter = value;
  }

  MoveCursorHandler? get onMoveCursorForwardByWord => _onMoveCursorForwardByWord;
  MoveCursorHandler? _onMoveCursorForwardByWord;
  set onMoveCursorForwardByWord(MoveCursorHandler? value) {
    assert(value != null);
    _addAction(SemanticsAction.moveCursorForwardByWord, (Object? args) {
      final bool extendSelection = args! as bool;
      value!(extendSelection);
    });
    _onMoveCursorForwardByCharacter = value;
  }

  MoveCursorHandler? get onMoveCursorBackwardByWord => _onMoveCursorBackwardByWord;
  MoveCursorHandler? _onMoveCursorBackwardByWord;
  set onMoveCursorBackwardByWord(MoveCursorHandler? value) {
    assert(value != null);
    _addAction(SemanticsAction.moveCursorBackwardByWord, (Object? args) {
      final bool extendSelection = args! as bool;
      value!(extendSelection);
    });
    _onMoveCursorBackwardByCharacter = value;
  }

  SetSelectionHandler? get onSetSelection => _onSetSelection;
  SetSelectionHandler? _onSetSelection;
  set onSetSelection(SetSelectionHandler? value) {
    assert(value != null);
    _addAction(SemanticsAction.setSelection, (Object? args) {
      assert(args != null && args is Map);
      final Map<String, int> selection = (args! as Map<dynamic, dynamic>).cast<String, int>();
      assert(selection['base'] != null && selection['extent'] != null);
      value!(TextSelection(
        baseOffset: selection['base']!,
        extentOffset: selection['extent']!,
      ));
    });
    _onSetSelection = value;
  }

  SetTextHandler? get onSetText => _onSetText;
  SetTextHandler? _onSetText;
  set onSetText(SetTextHandler? value) {
    assert(value != null);
    _addAction(SemanticsAction.setText, (Object? args) {
      assert(args != null && args is String);
      final String text = args! as String;
      value!(text);
    });
    _onSetText = value;
  }

  VoidCallback? get onDidGainAccessibilityFocus => _onDidGainAccessibilityFocus;
  VoidCallback? _onDidGainAccessibilityFocus;
  set onDidGainAccessibilityFocus(VoidCallback? value) {
    _addArgumentlessAction(SemanticsAction.didGainAccessibilityFocus, value!);
    _onDidGainAccessibilityFocus = value;
  }

  VoidCallback? get onDidLoseAccessibilityFocus => _onDidLoseAccessibilityFocus;
  VoidCallback? _onDidLoseAccessibilityFocus;
  set onDidLoseAccessibilityFocus(VoidCallback? value) {
    _addArgumentlessAction(SemanticsAction.didLoseAccessibilityFocus, value!);
    _onDidLoseAccessibilityFocus = value;
  }

  ChildSemanticsConfigurationsDelegate? get childConfigurationsDelegate => _childConfigurationsDelegate;
  ChildSemanticsConfigurationsDelegate? _childConfigurationsDelegate;
  set childConfigurationsDelegate(ChildSemanticsConfigurationsDelegate? value) {
    assert(value != null);
    _childConfigurationsDelegate = value;
    // Setting the childConfigsDelegate does not annotate any meaningful
    // semantics information of the config.
  }

  SemanticsActionHandler? getActionHandler(SemanticsAction action) => _actions[action];

  SemanticsSortKey? get sortKey => _sortKey;
  SemanticsSortKey? _sortKey;
  set sortKey(SemanticsSortKey? value) {
    assert(value != null);
    _sortKey = value;
    _hasBeenAnnotated = true;
  }

  int? get indexInParent => _indexInParent;
  int? _indexInParent;
  set indexInParent(int? value) {
    _indexInParent = value;
    _hasBeenAnnotated = true;
  }

  int? get scrollChildCount => _scrollChildCount;
  int? _scrollChildCount;
  set scrollChildCount(int? value) {
    if (value == scrollChildCount) {
      return;
    }
    _scrollChildCount = value;
    _hasBeenAnnotated = true;
  }

  int? get scrollIndex => _scrollIndex;
  int? _scrollIndex;
  set scrollIndex(int? value) {
    if (value == scrollIndex) {
      return;
    }
    _scrollIndex = value;
    _hasBeenAnnotated = true;
  }

  int? get platformViewId => _platformViewId;
  int? _platformViewId;
  set platformViewId(int? value) {
    if (value == platformViewId) {
      return;
    }
    _platformViewId = value;
    _hasBeenAnnotated = true;
  }

  int? get maxValueLength => _maxValueLength;
  int? _maxValueLength;
  set maxValueLength(int? value) {
    if (value == maxValueLength) {
      return;
    }
    _maxValueLength = value;
    _hasBeenAnnotated = true;
  }

  int? get currentValueLength => _currentValueLength;
  int? _currentValueLength;
  set currentValueLength(int? value) {
    if (value == currentValueLength) {
      return;
    }
    _currentValueLength = value;
    _hasBeenAnnotated = true;
  }

  bool get isMergingSemanticsOfDescendants => _isMergingSemanticsOfDescendants;
  bool _isMergingSemanticsOfDescendants = false;
  set isMergingSemanticsOfDescendants(bool value) {
    assert(isSemanticBoundary);
    _isMergingSemanticsOfDescendants = value;
    _hasBeenAnnotated = true;
  }

  Map<CustomSemanticsAction, VoidCallback> get customSemanticsActions => _customSemanticsActions;
  Map<CustomSemanticsAction, VoidCallback> _customSemanticsActions = <CustomSemanticsAction, VoidCallback>{};
  set customSemanticsActions(Map<CustomSemanticsAction, VoidCallback> value) {
    _hasBeenAnnotated = true;
    _actionsAsBits |= SemanticsAction.customAction.index;
    _customSemanticsActions = value;
    _actions[SemanticsAction.customAction] = _onCustomSemanticsAction;
  }

  void _onCustomSemanticsAction(Object? args) {
    final CustomSemanticsAction? action = CustomSemanticsAction.getAction(args! as int);
    if (action == null) {
      return;
    }
    final VoidCallback? callback = _customSemanticsActions[action];
    if (callback != null) {
      callback();
    }
  }

  String get label => _attributedLabel.string;
  set label(String label) {
    _attributedLabel = AttributedString(label);
    _hasBeenAnnotated = true;
  }

  AttributedString get attributedLabel => _attributedLabel;
  AttributedString _attributedLabel = AttributedString('');
  set attributedLabel(AttributedString attributedLabel) {
    _attributedLabel = attributedLabel;
    _hasBeenAnnotated = true;
  }

  String get value => _attributedValue.string;
  set value(String value) {
    _attributedValue = AttributedString(value);
    _hasBeenAnnotated = true;
  }

  AttributedString get attributedValue => _attributedValue;
  AttributedString _attributedValue = AttributedString('');
  set attributedValue(AttributedString attributedValue) {
    _attributedValue = attributedValue;
    _hasBeenAnnotated = true;
  }

  String get increasedValue => _attributedIncreasedValue.string;
  set increasedValue(String increasedValue) {
    _attributedIncreasedValue = AttributedString(increasedValue);
    _hasBeenAnnotated = true;
  }

  AttributedString get attributedIncreasedValue => _attributedIncreasedValue;
  AttributedString _attributedIncreasedValue = AttributedString('');
  set attributedIncreasedValue(AttributedString attributedIncreasedValue) {
    _attributedIncreasedValue = attributedIncreasedValue;
    _hasBeenAnnotated = true;
  }

  String get decreasedValue => _attributedDecreasedValue.string;
  set decreasedValue(String decreasedValue) {
    _attributedDecreasedValue = AttributedString(decreasedValue);
    _hasBeenAnnotated = true;
  }

  AttributedString get attributedDecreasedValue => _attributedDecreasedValue;
  AttributedString _attributedDecreasedValue = AttributedString('');
  set attributedDecreasedValue(AttributedString attributedDecreasedValue) {
    _attributedDecreasedValue = attributedDecreasedValue;
    _hasBeenAnnotated = true;
  }

  String get hint => _attributedHint.string;
  set hint(String hint) {
    _attributedHint = AttributedString(hint);
    _hasBeenAnnotated = true;
  }

  AttributedString get attributedHint => _attributedHint;
  AttributedString _attributedHint = AttributedString('');
  set attributedHint(AttributedString attributedHint) {
    _attributedHint = attributedHint;
    _hasBeenAnnotated = true;
  }

  String get tooltip => _tooltip;
  String _tooltip = '';
  set tooltip(String tooltip) {
    _tooltip = tooltip;
    _hasBeenAnnotated = true;
  }

  SemanticsHintOverrides? get hintOverrides => _hintOverrides;
  SemanticsHintOverrides? _hintOverrides;
  set hintOverrides(SemanticsHintOverrides? value) {
    if (value == null) {
      return;
    }
    _hintOverrides = value;
    _hasBeenAnnotated = true;
  }

  double get elevation => _elevation;
  double _elevation = 0.0;
  set elevation(double value) {
    assert(value >= 0.0);
    if (value == _elevation) {
      return;
    }
    _elevation = value;
    _hasBeenAnnotated = true;
  }

  double get thickness => _thickness;
  double _thickness = 0.0;
  set thickness(double value) {
    assert(value >= 0.0);
    if (value == _thickness) {
      return;
    }
    _thickness = value;
    _hasBeenAnnotated = true;
  }

  bool get scopesRoute => _hasFlag(SemanticsFlag.scopesRoute);
  set scopesRoute(bool value) {
    _setFlag(SemanticsFlag.scopesRoute, value);
  }

  bool get namesRoute => _hasFlag(SemanticsFlag.namesRoute);
  set namesRoute(bool value) {
    _setFlag(SemanticsFlag.namesRoute, value);
  }

  bool get isImage => _hasFlag(SemanticsFlag.isImage);
  set isImage(bool value) {
    _setFlag(SemanticsFlag.isImage, value);
  }

  bool get liveRegion => _hasFlag(SemanticsFlag.isLiveRegion);
  set liveRegion(bool value) {
    _setFlag(SemanticsFlag.isLiveRegion, value);
  }

  TextDirection? get textDirection => _textDirection;
  TextDirection? _textDirection;
  set textDirection(TextDirection? textDirection) {
    _textDirection = textDirection;
    _hasBeenAnnotated = true;
  }

  bool get isSelected => _hasFlag(SemanticsFlag.isSelected);
  set isSelected(bool value) {
    _setFlag(SemanticsFlag.isSelected, value);
  }

  bool? get isExpanded => _hasFlag(SemanticsFlag.hasExpandedState) ? _hasFlag(SemanticsFlag.isExpanded) : null;
  set isExpanded(bool? value) {
    _setFlag(SemanticsFlag.hasExpandedState, true);
    _setFlag(SemanticsFlag.isExpanded, value!);
  }

  bool? get isEnabled => _hasFlag(SemanticsFlag.hasEnabledState) ? _hasFlag(SemanticsFlag.isEnabled) : null;
  set isEnabled(bool? value) {
    _setFlag(SemanticsFlag.hasEnabledState, true);
    _setFlag(SemanticsFlag.isEnabled, value!);
  }

  bool? get isChecked => _hasFlag(SemanticsFlag.hasCheckedState) ? _hasFlag(SemanticsFlag.isChecked) : null;
  set isChecked(bool? value) {
    assert(value != true || isCheckStateMixed != true);
    _setFlag(SemanticsFlag.hasCheckedState, true);
    _setFlag(SemanticsFlag.isChecked, value!);
  }

  bool? get isCheckStateMixed => _hasFlag(SemanticsFlag.hasCheckedState) ? _hasFlag(SemanticsFlag.isCheckStateMixed) : null;
  set isCheckStateMixed(bool? value) {
    assert(value != true || isChecked != true);
    _setFlag(SemanticsFlag.hasCheckedState, true);
    _setFlag(SemanticsFlag.isCheckStateMixed, value!);
  }

  bool? get isToggled => _hasFlag(SemanticsFlag.hasToggledState) ? _hasFlag(SemanticsFlag.isToggled) : null;
  set isToggled(bool? value) {
    _setFlag(SemanticsFlag.hasToggledState, true);
    _setFlag(SemanticsFlag.isToggled, value!);
  }

  bool get isInMutuallyExclusiveGroup => _hasFlag(SemanticsFlag.isInMutuallyExclusiveGroup);
  set isInMutuallyExclusiveGroup(bool value) {
    _setFlag(SemanticsFlag.isInMutuallyExclusiveGroup, value);
  }

  bool get isFocusable => _hasFlag(SemanticsFlag.isFocusable);
  set isFocusable(bool value) {
    _setFlag(SemanticsFlag.isFocusable, value);
  }

  bool get isFocused => _hasFlag(SemanticsFlag.isFocused);
  set isFocused(bool value) {
    _setFlag(SemanticsFlag.isFocused, value);
  }

  bool get isButton => _hasFlag(SemanticsFlag.isButton);
  set isButton(bool value) {
    _setFlag(SemanticsFlag.isButton, value);
  }

  bool get isLink => _hasFlag(SemanticsFlag.isLink);
  set isLink(bool value) {
    _setFlag(SemanticsFlag.isLink, value);
  }

  bool get isHeader => _hasFlag(SemanticsFlag.isHeader);
  set isHeader(bool value) {
    _setFlag(SemanticsFlag.isHeader, value);
  }

  bool get isSlider => _hasFlag(SemanticsFlag.isSlider);
  set isSlider(bool value) {
    _setFlag(SemanticsFlag.isSlider, value);
  }

  //(false).
  bool get isKeyboardKey => _hasFlag(SemanticsFlag.isKeyboardKey);
  set isKeyboardKey(bool value) {
    _setFlag(SemanticsFlag.isKeyboardKey, value);
  }

  bool get isHidden => _hasFlag(SemanticsFlag.isHidden);
  set isHidden(bool value) {
    _setFlag(SemanticsFlag.isHidden, value);
  }

  bool get isTextField => _hasFlag(SemanticsFlag.isTextField);
  set isTextField(bool value) {
    _setFlag(SemanticsFlag.isTextField, value);
  }

  bool get isReadOnly => _hasFlag(SemanticsFlag.isReadOnly);
  set isReadOnly(bool value) {
    _setFlag(SemanticsFlag.isReadOnly, value);
  }

  bool get isObscured => _hasFlag(SemanticsFlag.isObscured);
  set isObscured(bool value) {
    _setFlag(SemanticsFlag.isObscured, value);
  }

  bool get isMultiline => _hasFlag(SemanticsFlag.isMultiline);
  set isMultiline(bool value) {
    _setFlag(SemanticsFlag.isMultiline, value);
  }

  bool get hasImplicitScrolling => _hasFlag(SemanticsFlag.hasImplicitScrolling);
  set hasImplicitScrolling(bool value) {
    _setFlag(SemanticsFlag.hasImplicitScrolling, value);
  }

  TextSelection? get textSelection => _textSelection;
  TextSelection? _textSelection;
  set textSelection(TextSelection? value) {
    assert(value != null);
    _textSelection = value;
    _hasBeenAnnotated = true;
  }

  double? get scrollPosition => _scrollPosition;
  double? _scrollPosition;
  set scrollPosition(double? value) {
    assert(value != null);
    _scrollPosition = value;
    _hasBeenAnnotated = true;
  }

  double? get scrollExtentMax => _scrollExtentMax;
  double? _scrollExtentMax;
  set scrollExtentMax(double? value) {
    assert(value != null);
    _scrollExtentMax = value;
    _hasBeenAnnotated = true;
  }

  double? get scrollExtentMin => _scrollExtentMin;
  double? _scrollExtentMin;
  set scrollExtentMin(double? value) {
    assert(value != null);
    _scrollExtentMin = value;
    _hasBeenAnnotated = true;
  }

  // TAGS

  Iterable<SemanticsTag>? get tagsForChildren => _tagsForChildren;

  bool tagsChildrenWith(SemanticsTag tag) => _tagsForChildren?.contains(tag) ?? false;

  Set<SemanticsTag>? _tagsForChildren;

  void addTagForChildren(SemanticsTag tag) {
    _tagsForChildren ??= <SemanticsTag>{};
    _tagsForChildren!.add(tag);
  }

  // INTERNAL FLAG MANAGEMENT

  int _flags = 0;
  void _setFlag(SemanticsFlag flag, bool value) {
    if (value) {
      _flags |= flag.index;
    } else {
      _flags &= ~flag.index;
    }
    _hasBeenAnnotated = true;
  }

  bool _hasFlag(SemanticsFlag flag) => (_flags & flag.index) != 0;

  // CONFIGURATION COMBINATION LOGIC

  bool isCompatibleWith(SemanticsConfiguration? other) {
    if (other == null || !other.hasBeenAnnotated || !hasBeenAnnotated) {
      return true;
    }
    if (_actionsAsBits & other._actionsAsBits != 0) {
      return false;
    }
    if ((_flags & other._flags) != 0) {
      return false;
    }
    if (_platformViewId != null && other._platformViewId != null) {
      return false;
    }
    if (_maxValueLength != null && other._maxValueLength != null) {
      return false;
    }
    if (_currentValueLength != null && other._currentValueLength != null) {
      return false;
    }
    if (_attributedValue.string.isNotEmpty && other._attributedValue.string.isNotEmpty) {
      return false;
    }
    return true;
  }

  void absorb(SemanticsConfiguration child) {
    assert(!explicitChildNodes);

    if (!child.hasBeenAnnotated) {
      return;
    }
    if (child.isBlockingUserActions) {
      child._actions.forEach((SemanticsAction key, SemanticsActionHandler value) {
        if (_kUnblockedUserActions & key.index > 0) {
          _actions[key] = value;
        }
      });
    } else {
      _actions.addAll(child._actions);
    }
    _actionsAsBits |= child._effectiveActionsAsBits;
    _customSemanticsActions.addAll(child._customSemanticsActions);
    _flags |= child._flags;
    _textSelection ??= child._textSelection;
    _scrollPosition ??= child._scrollPosition;
    _scrollExtentMax ??= child._scrollExtentMax;
    _scrollExtentMin ??= child._scrollExtentMin;
    _hintOverrides ??= child._hintOverrides;
    _indexInParent ??= child.indexInParent;
    _scrollIndex ??= child._scrollIndex;
    _scrollChildCount ??= child._scrollChildCount;
    _platformViewId ??= child._platformViewId;
    _maxValueLength ??= child._maxValueLength;
    _currentValueLength ??= child._currentValueLength;

    textDirection ??= child.textDirection;
    _sortKey ??= child._sortKey;
    _attributedLabel = _concatAttributedString(
      thisAttributedString: _attributedLabel,
      thisTextDirection: textDirection,
      otherAttributedString: child._attributedLabel,
      otherTextDirection: child.textDirection,
    );
    if (_attributedValue.string == '') {
      _attributedValue = child._attributedValue;
    }
    if (_attributedIncreasedValue.string == '') {
      _attributedIncreasedValue = child._attributedIncreasedValue;
    }
    if (_attributedDecreasedValue.string == '') {
      _attributedDecreasedValue = child._attributedDecreasedValue;
    }
    _attributedHint = _concatAttributedString(
      thisAttributedString: _attributedHint,
      thisTextDirection: textDirection,
      otherAttributedString: child._attributedHint,
      otherTextDirection: child.textDirection,
    );
    if (_tooltip == '') {
      _tooltip = child._tooltip;
    }

    _thickness = math.max(_thickness, child._thickness + child._elevation);

    _hasBeenAnnotated = _hasBeenAnnotated || child._hasBeenAnnotated;
  }

  SemanticsConfiguration copy() {
    return SemanticsConfiguration()
      .._isSemanticBoundary = _isSemanticBoundary
      ..explicitChildNodes = explicitChildNodes
      ..isBlockingSemanticsOfPreviouslyPaintedNodes = isBlockingSemanticsOfPreviouslyPaintedNodes
      .._hasBeenAnnotated = _hasBeenAnnotated
      .._isMergingSemanticsOfDescendants = _isMergingSemanticsOfDescendants
      .._textDirection = _textDirection
      .._sortKey = _sortKey
      .._attributedLabel = _attributedLabel
      .._attributedIncreasedValue = _attributedIncreasedValue
      .._attributedValue = _attributedValue
      .._attributedDecreasedValue = _attributedDecreasedValue
      .._attributedHint = _attributedHint
      .._hintOverrides = _hintOverrides
      .._tooltip = _tooltip
      .._elevation = _elevation
      .._thickness = _thickness
      .._flags = _flags
      .._tagsForChildren = _tagsForChildren
      .._textSelection = _textSelection
      .._scrollPosition = _scrollPosition
      .._scrollExtentMax = _scrollExtentMax
      .._scrollExtentMin = _scrollExtentMin
      .._actionsAsBits = _actionsAsBits
      .._indexInParent = indexInParent
      .._scrollIndex = _scrollIndex
      .._scrollChildCount = _scrollChildCount
      .._platformViewId = _platformViewId
      .._maxValueLength = _maxValueLength
      .._currentValueLength = _currentValueLength
      .._actions.addAll(_actions)
      .._customSemanticsActions.addAll(_customSemanticsActions)
      ..isBlockingUserActions = isBlockingUserActions;
  }
}

enum DebugSemanticsDumpOrder {
  inverseHitTest,

  traversalOrder,
}

AttributedString _concatAttributedString({
  required AttributedString thisAttributedString,
  required AttributedString otherAttributedString,
  required TextDirection? thisTextDirection,
  required TextDirection? otherTextDirection,
}) {
  if (otherAttributedString.string.isEmpty) {
    return thisAttributedString;
  }
  if (thisTextDirection != otherTextDirection && otherTextDirection != null) {
    switch (otherTextDirection) {
      case TextDirection.rtl:
        otherAttributedString = AttributedString(Unicode.RLE) + otherAttributedString + AttributedString(Unicode.PDF);
      case TextDirection.ltr:
        otherAttributedString = AttributedString(Unicode.LRE) + otherAttributedString + AttributedString(Unicode.PDF);
    }
  }
  if (thisAttributedString.string.isEmpty) {
    return otherAttributedString;
  }

  return thisAttributedString + AttributedString('\n') + otherAttributedString;
}

abstract class SemanticsSortKey with Diagnosticable implements Comparable<SemanticsSortKey> {
  const SemanticsSortKey({this.name});

  final String? name;

  @override
  int compareTo(SemanticsSortKey other) {
    // Sort by name first and then subclass ordering.
    assert(runtimeType == other.runtimeType, 'Semantics sort keys can only be compared to other sort keys of the same type.');

    // Defer to the subclass implementation for ordering only if the names are
    // identical (or both null).
    if (name == other.name) {
      return doCompare(other);
    }

    // Keys that don't have a name are sorted together and come before those with
    // a name.
    if (name == null && other.name != null) {
      return -1;
    } else if (name != null && other.name == null) {
      return 1;
    }

    return name!.compareTo(other.name!);
  }

  @protected
  int doCompare(covariant SemanticsSortKey other);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('name', name, defaultValue: null));
  }
}

class OrdinalSortKey extends SemanticsSortKey {
  const OrdinalSortKey(
    this.order, {
    super.name,
  }) : assert(order > double.negativeInfinity),
       assert(order < double.infinity);

  final double order;

  @override
  int doCompare(OrdinalSortKey other) {
    if (other.order == order) {
      return 0;
    }
    return order.compareTo(other.order);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('order', order, defaultValue: null));
  }
}