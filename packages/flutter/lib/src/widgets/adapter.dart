// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'framework.dart';

class RenderObjectToWidgetAdapter<T extends RenderObject> extends RenderObjectWidget {
  RenderObjectToWidgetAdapter({
    this.child,
    required this.container,
    this.debugShortDescription,
  }) : super(key: GlobalObjectKey(container));

  final Widget? child;

  final RenderObjectWithChildMixin<T> container;

  final String? debugShortDescription;

  @override
  RenderObjectToWidgetElement<T> createElement() => RenderObjectToWidgetElement<T>(this);

  @override
  RenderObjectWithChildMixin<T> createRenderObject(BuildContext context) => container;

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) { }

  RenderObjectToWidgetElement<T> attachToRenderTree(BuildOwner owner, [ RenderObjectToWidgetElement<T>? element ]) {
    if (element == null) {
      owner.lockState(() {
        element = createElement();
        assert(element != null);
        element!.assignOwner(owner);
      });
      owner.buildScope(element!, () {
        element!.mount(null, null);
      });
    } else {
      element._newWidget = this;
      element.markNeedsBuild();
    }
    return element!;
  }

  @override
  String toStringShort() => debugShortDescription ?? super.toStringShort();
}

class RenderObjectToWidgetElement<T extends RenderObject> extends RenderTreeRootElement with RootElementMixin {
  RenderObjectToWidgetElement(RenderObjectToWidgetAdapter<T> super.widget);

  Element? _child;

  static const Object _rootChildSlot = Object();

  @override
  void visitChildren(ElementVisitor visitor) {
    if (_child != null) {
      visitor(_child!);
    }
  }

  @override
  void forgetChild(Element child) {
    assert(child == _child);
    _child = null;
    super.forgetChild(child);
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    assert(parent == null);
    super.mount(parent, newSlot);
    _rebuild();
    assert(_child != null);
  }

  @override
  void update(RenderObjectToWidgetAdapter<T> newWidget) {
    super.update(newWidget);
    assert(widget == newWidget);
    _rebuild();
  }

  // When we are assigned a new widget, we store it here
  // until we are ready to update to it.
  Widget? _newWidget;

  @override
  void performRebuild() {
    if (_newWidget != null) {
      // _newWidget can be null if, for instance, we were rebuilt
      // due to a reassemble.
      final Widget newWidget = _newWidget!;
      _newWidget = null;
      update(newWidget as RenderObjectToWidgetAdapter<T>);
    }
    super.performRebuild();
    assert(_newWidget == null);
  }

  @pragma('vm:notify-debugger-on-exception')
  void _rebuild() {
    try {
      _child = updateChild(_child, (widget as RenderObjectToWidgetAdapter<T>).child, _rootChildSlot);
    } catch (exception, stack) {
      final FlutterErrorDetails details = FlutterErrorDetails(
        exception: exception,
        stack: stack,
        library: 'widgets library',
        context: ErrorDescription('attaching to the render tree'),
      );
      FlutterError.reportError(details);
      final Widget error = ErrorWidget.builder(details);
      _child = updateChild(null, error, _rootChildSlot);
    }
  }

  @override
  RenderObjectWithChildMixin<T> get renderObject => super.renderObject as RenderObjectWithChildMixin<T>;

  @override
  void insertRenderObjectChild(RenderObject child, Object? slot) {
    assert(slot == _rootChildSlot);
    assert(renderObject.debugValidateChild(child));
    renderObject.child = child as T;
  }

  @override
  void moveRenderObjectChild(RenderObject child, Object? oldSlot, Object? newSlot) {
    assert(false);
  }

  @override
  void removeRenderObjectChild(RenderObject child, Object? slot) {
    assert(renderObject.child == child);
    renderObject.child = null;
  }
}