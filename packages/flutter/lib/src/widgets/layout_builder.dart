// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'debug.dart';
import 'framework.dart';

typedef LayoutWidgetBuilder = Widget Function(BuildContext context, BoxConstraints constraints);

abstract class ConstrainedLayoutBuilder<ConstraintType extends Constraints> extends RenderObjectWidget {
  const ConstrainedLayoutBuilder({
    super.key,
    required this.builder,
  });

  @override
  RenderObjectElement createElement() => _LayoutBuilderElement<ConstraintType>(this);

  final Widget Function(BuildContext context, ConstraintType constraints) builder;

  // updateRenderObject is redundant with the logic in the LayoutBuilderElement below.
}

class _LayoutBuilderElement<ConstraintType extends Constraints> extends RenderObjectElement {
  _LayoutBuilderElement(ConstrainedLayoutBuilder<ConstraintType> super.widget);

  @override
  RenderConstrainedLayoutBuilder<ConstraintType, RenderObject> get renderObject => super.renderObject as RenderConstrainedLayoutBuilder<ConstraintType, RenderObject>;

  Element? _child;

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
    super.mount(parent, newSlot); // Creates the renderObject.
    renderObject.updateCallback(_layout);
  }

  @override
  void update(ConstrainedLayoutBuilder<ConstraintType> newWidget) {
    assert(widget != newWidget);
    super.update(newWidget);
    assert(widget == newWidget);

    renderObject.updateCallback(_layout);
    // Force the callback to be called, even if the layout constraints are the
    // same, because the logic in the callback might have changed.
    renderObject.markNeedsBuild();
  }

  @override
  void performRebuild() {
    // This gets called if markNeedsBuild() is called on us.
    // That might happen if, e.g., our builder uses Inherited widgets.

    // Force the callback to be called, even if the layout constraints are the
    // same. This is because that callback may depend on the updated widget
    // configuration, or an inherited widget.
    renderObject.markNeedsBuild();
    super.performRebuild(); // Calls widget.updateRenderObject (a no-op in this case).
  }

  @override
  void unmount() {
    renderObject.updateCallback(null);
    super.unmount();
  }

  void _layout(ConstraintType constraints) {
    @pragma('vm:notify-debugger-on-exception')
    void layoutCallback() {
      Widget built;
      try {
        built = (widget as ConstrainedLayoutBuilder<ConstraintType>).builder(this, constraints);
        debugWidgetBuilderValue(widget, built);
      } catch (e, stack) {
        built = ErrorWidget.builder(
          _reportException(
            ErrorDescription('building $widget'),
            e,
            stack,
            informationCollector: () => <DiagnosticsNode>[
              if (kDebugMode)
                DiagnosticsDebugCreator(DebugCreator(this)),
            ],
          ),
        );
      }
      try {
        _child = updateChild(_child, built, null);
        assert(_child != null);
      } catch (e, stack) {
        built = ErrorWidget.builder(
          _reportException(
            ErrorDescription('building $widget'),
            e,
            stack,
            informationCollector: () => <DiagnosticsNode>[
              if (kDebugMode)
                DiagnosticsDebugCreator(DebugCreator(this)),
            ],
          ),
        );
        _child = updateChild(null, built, slot);
      }
    }

    owner!.buildScope(this, layoutCallback);
  }

  @override
  void insertRenderObjectChild(RenderObject child, Object? slot) {
    final RenderObjectWithChildMixin<RenderObject> renderObject = this.renderObject;
    assert(slot == null);
    assert(renderObject.debugValidateChild(child));
    renderObject.child = child;
    assert(renderObject == this.renderObject);
  }

  @override
  void moveRenderObjectChild(RenderObject child, Object? oldSlot, Object? newSlot) {
    assert(false);
  }

  @override
  void removeRenderObjectChild(RenderObject child, Object? slot) {
    final RenderConstrainedLayoutBuilder<ConstraintType, RenderObject> renderObject = this.renderObject;
    assert(renderObject.child == child);
    renderObject.child = null;
    assert(renderObject == this.renderObject);
  }
}

mixin RenderConstrainedLayoutBuilder<ConstraintType extends Constraints, ChildType extends RenderObject> on RenderObjectWithChildMixin<ChildType> {
  LayoutCallback<ConstraintType>? _callback;
  void updateCallback(LayoutCallback<ConstraintType>? value) {
    if (value == _callback) {
      return;
    }
    _callback = value;
    markNeedsLayout();
  }

  bool _needsBuild = true;

  void markNeedsBuild() {
    // Do not call the callback directly. It must be called during the layout
    // phase, when parent constraints are available. Calling `markNeedsLayout`
    // will cause it to be called at the right time.
    _needsBuild = true;
    markNeedsLayout();
  }

  // The constraints that were passed to this class last time it was laid out.
  // These constraints are compared to the new constraints to determine whether
  // [ConstrainedLayoutBuilder.builder] needs to be called.
  Constraints? _previousConstraints;

  void rebuildIfNecessary() {
    assert(_callback != null);
    if (_needsBuild || constraints != _previousConstraints) {
      _previousConstraints = constraints;
      _needsBuild = false;
      invokeLayoutCallback(_callback!);
    }
  }
}

class LayoutBuilder extends ConstrainedLayoutBuilder<BoxConstraints> {
  const LayoutBuilder({
    super.key,
    required super.builder,
  });

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderLayoutBuilder();
}

class _RenderLayoutBuilder extends RenderBox with RenderObjectWithChildMixin<RenderBox>, RenderConstrainedLayoutBuilder<BoxConstraints, RenderBox> {
  @override
  double computeMinIntrinsicWidth(double height) {
    assert(_debugThrowIfNotCheckingIntrinsics());
    return 0.0;
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    assert(_debugThrowIfNotCheckingIntrinsics());
    return 0.0;
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    assert(_debugThrowIfNotCheckingIntrinsics());
    return 0.0;
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    assert(_debugThrowIfNotCheckingIntrinsics());
    return 0.0;
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    assert(debugCannotComputeDryLayout(reason:
      'Calculating the dry layout would require running the layout callback '
      'speculatively, which might mutate the live render object tree.',
    ));
    return Size.zero;
  }

  @override
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    rebuildIfNecessary();
    if (child != null) {
      child!.layout(constraints, parentUsesSize: true);
      size = constraints.constrain(child!.size);
    } else {
      size = constraints.biggest;
    }
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    if (child != null) {
      return child!.getDistanceToActualBaseline(baseline);
    }
    return super.computeDistanceToActualBaseline(baseline);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, { required Offset position }) {
    return child?.hitTest(result, position: position) ?? false;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (child != null) {
      context.paintChild(child!, offset);
    }
  }

  bool _debugThrowIfNotCheckingIntrinsics() {
    assert(() {
      if (!RenderObject.debugCheckingIntrinsics) {
        throw FlutterError(
          'LayoutBuilder does not support returning intrinsic dimensions.\n'
          'Calculating the intrinsic dimensions would require running the layout '
          'callback speculatively, which might mutate the live render object tree.',
        );
      }
      return true;
    }());

    return true;
  }
}

FlutterErrorDetails _reportException(
  DiagnosticsNode context,
  Object exception,
  StackTrace stack, {
  InformationCollector? informationCollector,
}) {
  final FlutterErrorDetails details = FlutterErrorDetails(
    exception: exception,
    stack: stack,
    library: 'widgets library',
    context: context,
    informationCollector: informationCollector,
  );
  FlutterError.reportError(details);
  return details;
}