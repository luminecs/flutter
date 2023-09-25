// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/rendering.dart';

import 'basic.dart';
import 'framework.dart';
import 'sliver.dart';
import 'ticker_provider.dart';

class Visibility extends StatelessWidget {
  const Visibility({
    super.key,
    required this.child,
    this.replacement = const SizedBox.shrink(),
    this.visible = true,
    this.maintainState = false,
    this.maintainAnimation = false,
    this.maintainSize = false,
    this.maintainSemantics = false,
    this.maintainInteractivity = false,
  }) : assert(
         maintainState || !maintainAnimation,
         'Cannot maintain animations if the state is not also maintained.',
       ),
       assert(
         maintainAnimation || !maintainSize,
         'Cannot maintain size if animations are not maintained.',
       ),
       assert(
         maintainSize || !maintainSemantics,
         'Cannot maintain semantics if size is not maintained.',
       ),
       assert(
         maintainSize || !maintainInteractivity,
         'Cannot maintain interactivity if size is not maintained.',
       );

  const Visibility.maintain({
    super.key,
    required this.child,
    this.visible = true,
  }) :  maintainState = true,
        maintainAnimation = true,
        maintainSize = true,
        maintainSemantics = true,
        maintainInteractivity = true,
        replacement = const SizedBox.shrink(); // Unused since maintainState is always true.

  final Widget child;

  final Widget replacement;

  final bool visible;

  final bool maintainState;

  final bool maintainAnimation;

  final bool maintainSize;

  final bool maintainSemantics;

  final bool maintainInteractivity;

  static bool of(BuildContext context) {
    bool isVisible = true;
    BuildContext ancestorContext = context;
    InheritedElement? ancestor = ancestorContext.getElementForInheritedWidgetOfExactType<_VisibilityScope>();
    while (isVisible && ancestor != null) {
      final _VisibilityScope scope = context.dependOnInheritedElement(ancestor) as _VisibilityScope;
      isVisible = scope.isVisible;
      ancestor.visitAncestorElements((Element parent) {
        ancestorContext = parent;
        return false;
      });
      ancestor = ancestorContext.getElementForInheritedWidgetOfExactType<_VisibilityScope>();
    }
    return isVisible;
  }

  @override
  Widget build(BuildContext context) {
    Widget result = child;
    if (maintainSize) {
      result = _Visibility(
        visible: visible,
        maintainSemantics: maintainSemantics,
        child: IgnorePointer(
          ignoring: !visible && !maintainInteractivity,
          child: result,
        ),
      );
    } else {
      assert(!maintainInteractivity);
      assert(!maintainSemantics);
      assert(!maintainSize);
      if (maintainState) {
        if (!maintainAnimation) {
          result = TickerMode(enabled: visible, child: result);
        }
        result = Offstage(
          offstage: !visible,
          child: result,
        );
      } else {
        assert(!maintainAnimation);
        assert(!maintainState);
        result = visible ? child : replacement;
      }
    }
    return _VisibilityScope(isVisible: visible, child: result);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('visible', value: visible, ifFalse: 'hidden', ifTrue: 'visible'));
    properties.add(FlagProperty('maintainState', value: maintainState, ifFalse: 'maintainState'));
    properties.add(FlagProperty('maintainAnimation', value: maintainAnimation, ifFalse: 'maintainAnimation'));
    properties.add(FlagProperty('maintainSize', value: maintainSize, ifFalse: 'maintainSize'));
    properties.add(FlagProperty('maintainSemantics', value: maintainSemantics, ifFalse: 'maintainSemantics'));
    properties.add(FlagProperty('maintainInteractivity', value: maintainInteractivity, ifFalse: 'maintainInteractivity'));
  }
}

class _VisibilityScope extends InheritedWidget {
  const _VisibilityScope({required this.isVisible, required super.child});

  final bool isVisible;

  @override
  bool updateShouldNotify(_VisibilityScope old) {
    return isVisible != old.isVisible;
  }
}

class SliverVisibility extends StatelessWidget {
  const SliverVisibility({
    super.key,
    required this.sliver,
    this.replacementSliver = const SliverToBoxAdapter(),
    this.visible = true,
    this.maintainState = false,
    this.maintainAnimation = false,
    this.maintainSize = false,
    this.maintainSemantics = false,
    this.maintainInteractivity = false,
  }) : assert(
         maintainState || !maintainAnimation,
         'Cannot maintain animations if the state is not also maintained.',
       ),
       assert(
         maintainAnimation || !maintainSize,
         'Cannot maintain size if animations are not maintained.',
       ),
       assert(
         maintainSize || !maintainSemantics,
         'Cannot maintain semantics if size is not maintained.',
       ),
       assert(
         maintainSize || !maintainInteractivity,
         'Cannot maintain interactivity if size is not maintained.',
       );

  const SliverVisibility.maintain({
    super.key,
    required this.sliver,
    this.replacementSliver = const SliverToBoxAdapter(),
    this.visible = true,
  }) :  maintainState = true,
        maintainAnimation = true,
        maintainSize = true,
        maintainSemantics = true,
        maintainInteractivity = true;

  final Widget sliver;

  final Widget replacementSliver;

  final bool visible;

  final bool maintainState;

  final bool maintainAnimation;

  final bool maintainSize;

  final bool maintainSemantics;

  final bool maintainInteractivity;

  @override
  Widget build(BuildContext context) {
    if (maintainSize) {
      Widget result = sliver;
      result = SliverIgnorePointer(
        ignoring: !visible && !maintainInteractivity,
        sliver: result,
      );
      return _SliverVisibility(
        visible: visible,
        maintainSemantics: maintainSemantics,
        sliver: result,
      );
    }
    assert(!maintainInteractivity);
    assert(!maintainSemantics);
    assert(!maintainSize);
    if (maintainState) {
      Widget result = sliver;
      if (!maintainAnimation) {
        result = TickerMode(enabled: visible, child: sliver);
      }
      return SliverOffstage(
        sliver: result,
        offstage: !visible,
      );
    }
    assert(!maintainAnimation);
    assert(!maintainState);
    return visible ? sliver : replacementSliver;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('visible', value: visible, ifFalse: 'hidden', ifTrue: 'visible'));
    properties.add(FlagProperty('maintainState', value: maintainState, ifFalse: 'maintainState'));
    properties.add(FlagProperty('maintainAnimation', value: maintainAnimation, ifFalse: 'maintainAnimation'));
    properties.add(FlagProperty('maintainSize', value: maintainSize, ifFalse: 'maintainSize'));
    properties.add(FlagProperty('maintainSemantics', value: maintainSemantics, ifFalse: 'maintainSemantics'));
    properties.add(FlagProperty('maintainInteractivity', value: maintainInteractivity, ifFalse: 'maintainInteractivity'));
  }
}

// A widget that conditionally hides its child, but without the forced compositing of `Opacity`.
//
// A fully opaque `Opacity` widget is required to leave its opacity layer in the layer tree. This
// forces all parent render objects to also composite, which can break a simple scene into many
// different layers. This can be significantly more expensive, so the issue is avoided by a
// specialized render object that does not ever force compositing.
class _Visibility extends SingleChildRenderObjectWidget {
  const _Visibility({ required this.visible, required this.maintainSemantics, super.child });

  final bool visible;
  final bool maintainSemantics;

  @override
  _RenderVisibility createRenderObject(BuildContext context) {
    return _RenderVisibility(visible, maintainSemantics);
  }

  @override
  void updateRenderObject(BuildContext context, _RenderVisibility renderObject) {
    renderObject
      ..visible = visible
      ..maintainSemantics = maintainSemantics;
  }
}

class _RenderVisibility extends RenderProxyBox {
  _RenderVisibility(this._visible, this._maintainSemantics);

  bool get visible => _visible;
  bool _visible;
  set visible(bool value) {
    if (value == visible) {
      return;
    }
    _visible = value;
    markNeedsPaint();
  }

  bool get maintainSemantics => _maintainSemantics;
  bool _maintainSemantics;
  set maintainSemantics(bool value) {
    if (value == maintainSemantics) {
      return;
    }
    _maintainSemantics = value;
    markNeedsSemanticsUpdate();
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (maintainSemantics || visible) {
      super.visitChildrenForSemantics(visitor);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!visible) {
      return;
    }
    super.paint(context, offset);
  }
}

// A widget that conditionally hides its child, but without the forced compositing of `SliverOpacity`.
//
// A fully opaque `SliverOpacity` widget is required to leave its opacity layer in the layer tree.
// This forces all parent render objects to also composite, which can break a simple scene into many
// different layers. This can be significantly more expensive, so the issue is avoided by a
// specialized render object that does not ever force compositing.
class _SliverVisibility extends SingleChildRenderObjectWidget {
  const _SliverVisibility({ required this.visible, required this.maintainSemantics, Widget? sliver })
    : super(child: sliver);

  final bool visible;
  final bool maintainSemantics;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _RenderSliverVisibility(visible, maintainSemantics);
  }

  @override
  void updateRenderObject(BuildContext context, _RenderSliverVisibility renderObject) {
    renderObject
      ..visible = visible
      ..maintainSemantics = maintainSemantics;
  }
}

class _RenderSliverVisibility extends RenderProxySliver {
  _RenderSliverVisibility(this._visible, this._maintainSemantics);

  bool get visible => _visible;
  bool _visible;
  set visible(bool value) {
    if (value == visible) {
      return;
    }
    _visible = value;
    markNeedsPaint();
  }

  bool get maintainSemantics => _maintainSemantics;
  bool _maintainSemantics;
  set maintainSemantics(bool value) {
    if (value == maintainSemantics) {
      return;
    }
    _maintainSemantics = value;
    markNeedsSemanticsUpdate();
  }

  @override
  void visitChildrenForSemantics(RenderObjectVisitor visitor) {
    if (maintainSemantics || visible) {
      super.visitChildrenForSemantics(visitor);
    }
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (!visible) {
      return;
    }
    super.paint(context, offset);
  }
}