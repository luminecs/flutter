// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/rendering.dart';

import 'basic.dart';
import 'debug.dart';
import 'framework.dart';
import 'scroll_notification.dart';

export 'package:flutter/rendering.dart' show
  AxisDirection,
  GrowthDirection;

class Viewport extends MultiChildRenderObjectWidget {
  Viewport({
    super.key,
    this.axisDirection = AxisDirection.down,
    this.crossAxisDirection,
    this.anchor = 0.0,
    required this.offset,
    this.center,
    this.cacheExtent,
    this.cacheExtentStyle = CacheExtentStyle.pixel,
    this.clipBehavior = Clip.hardEdge,
    List<Widget> slivers = const <Widget>[],
  }) : assert(center == null || slivers.where((Widget child) => child.key == center).length == 1),
       assert(cacheExtentStyle != CacheExtentStyle.viewport || cacheExtent != null),
       super(children: slivers);

  final AxisDirection axisDirection;

  final AxisDirection? crossAxisDirection;

  final double anchor;

  final ViewportOffset offset;

  final Key? center;

  final double? cacheExtent;

  final CacheExtentStyle cacheExtentStyle;

  final Clip clipBehavior;

  static AxisDirection getDefaultCrossAxisDirection(BuildContext context, AxisDirection axisDirection) {
    switch (axisDirection) {
      case AxisDirection.up:
        assert(debugCheckHasDirectionality(
          context,
          why: "to determine the cross-axis direction when the viewport has an 'up' axisDirection",
          alternative: "Alternatively, consider specifying the 'crossAxisDirection' argument on the Viewport.",
        ));
        return textDirectionToAxisDirection(Directionality.of(context));
      case AxisDirection.right:
        return AxisDirection.down;
      case AxisDirection.down:
        assert(debugCheckHasDirectionality(
          context,
          why: "to determine the cross-axis direction when the viewport has a 'down' axisDirection",
          alternative: "Alternatively, consider specifying the 'crossAxisDirection' argument on the Viewport.",
        ));
        return textDirectionToAxisDirection(Directionality.of(context));
      case AxisDirection.left:
        return AxisDirection.down;
    }
  }

  @override
  RenderViewport createRenderObject(BuildContext context) {
    return RenderViewport(
      axisDirection: axisDirection,
      crossAxisDirection: crossAxisDirection ?? Viewport.getDefaultCrossAxisDirection(context, axisDirection),
      anchor: anchor,
      offset: offset,
      cacheExtent: cacheExtent,
      cacheExtentStyle: cacheExtentStyle,
      clipBehavior: clipBehavior,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderViewport renderObject) {
    renderObject
      ..axisDirection = axisDirection
      ..crossAxisDirection = crossAxisDirection ?? Viewport.getDefaultCrossAxisDirection(context, axisDirection)
      ..anchor = anchor
      ..offset = offset
      ..cacheExtent = cacheExtent
      ..cacheExtentStyle = cacheExtentStyle
      ..clipBehavior = clipBehavior;
  }

  @override
  MultiChildRenderObjectElement createElement() => _ViewportElement(this);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<AxisDirection>('axisDirection', axisDirection));
    properties.add(EnumProperty<AxisDirection>('crossAxisDirection', crossAxisDirection, defaultValue: null));
    properties.add(DoubleProperty('anchor', anchor));
    properties.add(DiagnosticsProperty<ViewportOffset>('offset', offset));
    if (center != null) {
      properties.add(DiagnosticsProperty<Key>('center', center));
    } else if (children.isNotEmpty && children.first.key != null) {
      properties.add(DiagnosticsProperty<Key>('center', children.first.key, tooltip: 'implicit'));
    }
    properties.add(DiagnosticsProperty<double>('cacheExtent', cacheExtent));
    properties.add(DiagnosticsProperty<CacheExtentStyle>('cacheExtentStyle', cacheExtentStyle));
  }
}

class _ViewportElement extends MultiChildRenderObjectElement with NotifiableElementMixin, ViewportElementMixin {
  _ViewportElement(Viewport super.widget);

  bool _doingMountOrUpdate = false;
  int? _centerSlotIndex;

  @override
  RenderViewport get renderObject => super.renderObject as RenderViewport;

  @override
  void mount(Element? parent, Object? newSlot) {
    assert(!_doingMountOrUpdate);
    _doingMountOrUpdate = true;
    super.mount(parent, newSlot);
    _updateCenter();
    assert(_doingMountOrUpdate);
    _doingMountOrUpdate = false;
  }

  @override
  void update(MultiChildRenderObjectWidget newWidget) {
    assert(!_doingMountOrUpdate);
    _doingMountOrUpdate = true;
    super.update(newWidget);
    _updateCenter();
    assert(_doingMountOrUpdate);
    _doingMountOrUpdate = false;
  }

  void _updateCenter() {
    // TODO(ianh): cache the keys to make this faster
    final Viewport viewport = widget as Viewport;
    if (viewport.center != null) {
      int elementIndex = 0;
      for (final Element e in children) {
        if (e.widget.key == viewport.center) {
          renderObject.center = e.renderObject as RenderSliver?;
          break;
        }
        elementIndex++;
      }
      assert(elementIndex < children.length);
      _centerSlotIndex = elementIndex;
    } else if (children.isNotEmpty) {
      renderObject.center = children.first.renderObject as RenderSliver?;
      _centerSlotIndex = 0;
    } else {
      renderObject.center = null;
      _centerSlotIndex = null;
    }
  }

  @override
  void insertRenderObjectChild(RenderObject child, IndexedSlot<Element?> slot) {
    super.insertRenderObjectChild(child, slot);
    // Once [mount]/[update] are done, the `renderObject.center` will be updated
    // in [_updateCenter].
    if (!_doingMountOrUpdate && slot.index == _centerSlotIndex) {
      renderObject.center = child as RenderSliver?;
    }
  }

  @override
  void moveRenderObjectChild(RenderObject child, IndexedSlot<Element?> oldSlot, IndexedSlot<Element?> newSlot) {
    super.moveRenderObjectChild(child, oldSlot, newSlot);
    assert(_doingMountOrUpdate);
  }

  @override
  void removeRenderObjectChild(RenderObject child, Object? slot) {
    super.removeRenderObjectChild(child, slot);
    if (!_doingMountOrUpdate && renderObject.center == child) {
      renderObject.center = null;
    }
  }

  @override
  void debugVisitOnstageChildren(ElementVisitor visitor) {
    children.where((Element e) {
      final RenderSliver renderSliver = e.renderObject! as RenderSliver;
      return renderSliver.geometry!.visible;
    }).forEach(visitor);
  }
}

class ShrinkWrappingViewport extends MultiChildRenderObjectWidget {
  const ShrinkWrappingViewport({
    super.key,
    this.axisDirection = AxisDirection.down,
    this.crossAxisDirection,
    required this.offset,
    this.clipBehavior = Clip.hardEdge,
    List<Widget> slivers = const <Widget>[],
  }) : super(children: slivers);

  final AxisDirection axisDirection;

  final AxisDirection? crossAxisDirection;

  final ViewportOffset offset;

  final Clip clipBehavior;

  @override
  RenderShrinkWrappingViewport createRenderObject(BuildContext context) {
    return RenderShrinkWrappingViewport(
      axisDirection: axisDirection,
      crossAxisDirection: crossAxisDirection ?? Viewport.getDefaultCrossAxisDirection(context, axisDirection),
      offset: offset,
      clipBehavior: clipBehavior,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderShrinkWrappingViewport renderObject) {
    renderObject
      ..axisDirection = axisDirection
      ..crossAxisDirection = crossAxisDirection ?? Viewport.getDefaultCrossAxisDirection(context, axisDirection)
      ..offset = offset
      ..clipBehavior = clipBehavior;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<AxisDirection>('axisDirection', axisDirection));
    properties.add(EnumProperty<AxisDirection>('crossAxisDirection', crossAxisDirection, defaultValue: null));
    properties.add(DiagnosticsProperty<ViewportOffset>('offset', offset));
  }
}