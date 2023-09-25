// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart';

import 'layer.dart';
import 'object.dart';

enum SelectionResult {
  next,
  previous,
  end,
  // See `_SelectableRegionState._triggerSelectionEndEdgeUpdate` for how this
  // result affects the selection.
  pending,
  none,
}

abstract class SelectionHandler implements ValueListenable<SelectionGeometry> {
  void pushHandleLayers(LayerLink? startHandle, LayerLink? endHandle);

  SelectedContent? getSelectedContent();

  SelectionResult dispatchSelectionEvent(SelectionEvent event);
}

// TODO(chunhtai): Add more support for rich content.
// https://github.com/flutter/flutter/issues/104206.
class SelectedContent {
  const SelectedContent({required this.plainText});

  final String plainText;
}

mixin Selectable implements SelectionHandler {
  Matrix4 getTransformTo(RenderObject? ancestor);

  Size get size;

  void dispose();
}

mixin SelectionRegistrant on Selectable {
  SelectionRegistrar? get registrar => _registrar;
  SelectionRegistrar? _registrar;
  set registrar(SelectionRegistrar? value) {
    if (value == _registrar) {
      return;
    }
    if (value == null) {
      // When registrar goes from non-null to null;
      removeListener(_updateSelectionRegistrarSubscription);
    } else if (_registrar == null) {
      // When registrar goes from null to non-null;
      addListener(_updateSelectionRegistrarSubscription);
    }
    _removeSelectionRegistrarSubscription();
    _registrar = value;
    _updateSelectionRegistrarSubscription();
  }

  @override
  void dispose() {
    _removeSelectionRegistrarSubscription();
    super.dispose();
  }

  bool _subscribedToSelectionRegistrar = false;
  void _updateSelectionRegistrarSubscription() {
    if (_registrar == null) {
      _subscribedToSelectionRegistrar = false;
      return;
    }
    if (_subscribedToSelectionRegistrar && !value.hasContent) {
      _registrar!.remove(this);
      _subscribedToSelectionRegistrar = false;
    } else if (!_subscribedToSelectionRegistrar && value.hasContent) {
      _registrar!.add(this);
      _subscribedToSelectionRegistrar = true;
    }
  }

  void _removeSelectionRegistrarSubscription() {
    if (_subscribedToSelectionRegistrar) {
      _registrar!.remove(this);
      _subscribedToSelectionRegistrar = false;
    }
  }
}

abstract final class SelectionUtils {
  static SelectionResult getResultBasedOnRect(Rect targetRect, Offset point) {
    if (targetRect.contains(point)) {
      return SelectionResult.end;
    }
    if (point.dy < targetRect.top) {
      return SelectionResult.previous;
    }
    if (point.dy > targetRect.bottom) {
      return SelectionResult.next;
    }
    return point.dx >= targetRect.right
        ? SelectionResult.next
        : SelectionResult.previous;
  }

  static Offset adjustDragOffset(Rect targetRect, Offset point, {TextDirection direction = TextDirection.ltr}) {
    if (targetRect.contains(point)) {
      return point;
    }
    if (point.dy <= targetRect.top ||
        point.dy <= targetRect.bottom && point.dx <= targetRect.left) {
      // Area 1
      return direction == TextDirection.ltr ? targetRect.topLeft : targetRect.topRight;
    } else {
      // Area 2
      return direction == TextDirection.ltr ? targetRect.bottomRight : targetRect.bottomLeft;
    }
  }
}

enum SelectionEventType {
  startEdgeUpdate,

  endEdgeUpdate,

  clear,

  selectAll,

  selectWord,

  granularlyExtendSelection,

  directionallyExtendSelection,
}

enum TextGranularity {
  character,

  word,

  line,

  document,
}

abstract class SelectionEvent {
  const SelectionEvent._(this.type);

  final SelectionEventType type;
}

class SelectAllSelectionEvent extends SelectionEvent {
  const SelectAllSelectionEvent(): super._(SelectionEventType.selectAll);
}

class ClearSelectionEvent extends SelectionEvent {
  const ClearSelectionEvent(): super._(SelectionEventType.clear);
}

class SelectWordSelectionEvent extends SelectionEvent {
  const SelectWordSelectionEvent({required this.globalPosition}): super._(SelectionEventType.selectWord);

  final Offset globalPosition;
}

class SelectionEdgeUpdateEvent extends SelectionEvent {
  const SelectionEdgeUpdateEvent.forStart({
    required this.globalPosition,
    TextGranularity? granularity
  }) : granularity = granularity ?? TextGranularity.character, super._(SelectionEventType.startEdgeUpdate);

  const SelectionEdgeUpdateEvent.forEnd({
    required this.globalPosition,
    TextGranularity? granularity
  }) : granularity = granularity ?? TextGranularity.character, super._(SelectionEventType.endEdgeUpdate);

  final Offset globalPosition;

  final TextGranularity granularity;
}

class GranularlyExtendSelectionEvent extends SelectionEvent {
  const GranularlyExtendSelectionEvent({
    required this.forward,
    required this.isEnd,
    required this.granularity,
  }) : super._(SelectionEventType.granularlyExtendSelection);

  final bool forward;

  final bool isEnd;

  final TextGranularity granularity;
}

enum SelectionExtendDirection {
  previousLine,

  nextLine,

  forward,

  backward,
}

class DirectionallyExtendSelectionEvent extends SelectionEvent {
  const DirectionallyExtendSelectionEvent({
    required this.dx,
    required this.isEnd,
    required this.direction,
  }) : super._(SelectionEventType.directionallyExtendSelection);

  final double dx;

  final bool isEnd;

  final SelectionExtendDirection direction;

  DirectionallyExtendSelectionEvent copyWith({
    double? dx,
    bool? isEnd,
    SelectionExtendDirection? direction,
  }) {
    return DirectionallyExtendSelectionEvent(
      dx: dx ?? this.dx,
      isEnd: isEnd ?? this.isEnd,
      direction: direction ?? this.direction,
    );
  }
}

abstract class SelectionRegistrar {
  void add(Selectable selectable);

  void remove(Selectable selectable);
}

enum SelectionStatus {
  uncollapsed,

  collapsed,

  none,
}

@immutable
class SelectionGeometry {
  const SelectionGeometry({
    this.startSelectionPoint,
    this.endSelectionPoint,
    this.selectionRects = const <Rect>[],
    required this.status,
    required this.hasContent,
  }) : assert((startSelectionPoint == null && endSelectionPoint == null) || status != SelectionStatus.none);

  final SelectionPoint? startSelectionPoint;

  final SelectionPoint? endSelectionPoint;

  final SelectionStatus status;

  final List<Rect> selectionRects;

  final bool hasContent;

  bool get hasSelection => status != SelectionStatus.none;

  SelectionGeometry copyWith({
    SelectionPoint? startSelectionPoint,
    SelectionPoint? endSelectionPoint,
    List<Rect>? selectionRects,
    SelectionStatus? status,
    bool? hasContent,
  }) {
    return SelectionGeometry(
      startSelectionPoint: startSelectionPoint ?? this.startSelectionPoint,
      endSelectionPoint: endSelectionPoint ?? this.endSelectionPoint,
      selectionRects: selectionRects ?? this.selectionRects,
      status: status ?? this.status,
      hasContent: hasContent ?? this.hasContent,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is SelectionGeometry
        && other.startSelectionPoint == startSelectionPoint
        && other.endSelectionPoint == endSelectionPoint
        && other.selectionRects == selectionRects
        && other.status == status
        && other.hasContent == hasContent;
  }

  @override
  int get hashCode {
    return Object.hash(
      startSelectionPoint,
      endSelectionPoint,
      selectionRects,
      status,
      hasContent,
    );
  }
}

@immutable
class SelectionPoint with Diagnosticable {
  const SelectionPoint({
    required this.localPosition,
    required this.lineHeight,
    required this.handleType,
  });

  final Offset localPosition;

  final double lineHeight;

  final TextSelectionHandleType handleType;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is SelectionPoint
        && other.localPosition == localPosition
        && other.lineHeight == lineHeight
        && other.handleType == handleType;
  }

  @override
  int get hashCode {
    return Object.hash(
      localPosition,
      lineHeight,
      handleType,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Offset>('localPosition', localPosition));
    properties.add(DoubleProperty('lineHeight', lineHeight));
    properties.add(EnumProperty<TextSelectionHandleType>('handleType', handleType));
  }
}

enum TextSelectionHandleType {
  left,

  right,

  collapsed,
}