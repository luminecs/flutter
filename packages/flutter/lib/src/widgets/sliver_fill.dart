// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'framework.dart';
import 'scroll_delegate.dart';
import 'sliver.dart';

class SliverFillViewport extends StatelessWidget {
  const SliverFillViewport({
    super.key,
    required this.delegate,
    this.viewportFraction = 1.0,
    this.padEnds = true,
  }) : assert(viewportFraction > 0.0);

  final double viewportFraction;

  final bool padEnds;

  final SliverChildDelegate delegate;

  @override
  Widget build(BuildContext context) {
    return _SliverFractionalPadding(
      viewportFraction: padEnds ? clampDouble(1 - viewportFraction, 0, 1) / 2 : 0,
      sliver: _SliverFillViewportRenderObjectWidget(
        viewportFraction: viewportFraction,
        delegate: delegate,
      ),
    );
  }
}

class _SliverFillViewportRenderObjectWidget extends SliverMultiBoxAdaptorWidget {
  const _SliverFillViewportRenderObjectWidget({
    required super.delegate,
    this.viewportFraction = 1.0,
  }) : assert(viewportFraction > 0.0);

  final double viewportFraction;

  @override
  RenderSliverFillViewport createRenderObject(BuildContext context) {
    final SliverMultiBoxAdaptorElement element = context as SliverMultiBoxAdaptorElement;
    return RenderSliverFillViewport(childManager: element, viewportFraction: viewportFraction);
  }

  @override
  void updateRenderObject(BuildContext context, RenderSliverFillViewport renderObject) {
    renderObject.viewportFraction = viewportFraction;
  }
}

class _SliverFractionalPadding extends SingleChildRenderObjectWidget {
  const _SliverFractionalPadding({
    this.viewportFraction = 0,
    Widget? sliver,
  }) : assert(viewportFraction >= 0),
      assert(viewportFraction <= 0.5),
      super(child: sliver);

  final double viewportFraction;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSliverFractionalPadding(viewportFraction: viewportFraction);

  @override
  void updateRenderObject(BuildContext context, _RenderSliverFractionalPadding renderObject) {
    renderObject.viewportFraction = viewportFraction;
  }
}

class _RenderSliverFractionalPadding extends RenderSliverEdgeInsetsPadding {
  _RenderSliverFractionalPadding({
    double viewportFraction = 0,
  }) : assert(viewportFraction <= 0.5),
      assert(viewportFraction >= 0),
      _viewportFraction = viewportFraction;

  SliverConstraints? _lastResolvedConstraints;

  double get viewportFraction => _viewportFraction;
  double _viewportFraction;
  set viewportFraction(double newValue) {
    if (_viewportFraction == newValue) {
      return;
    }
    _viewportFraction = newValue;
    _markNeedsResolution();
  }

  @override
  EdgeInsets? get resolvedPadding => _resolvedPadding;
  EdgeInsets? _resolvedPadding;

  void _markNeedsResolution() {
    _resolvedPadding = null;
    markNeedsLayout();
  }

  void _resolve() {
    if (_resolvedPadding != null && _lastResolvedConstraints == constraints) {
      return;
    }

    final double paddingValue = constraints.viewportMainAxisExtent * viewportFraction;
    _lastResolvedConstraints = constraints;
    switch (constraints.axis) {
      case Axis.horizontal:
        _resolvedPadding = EdgeInsets.symmetric(horizontal: paddingValue);
      case Axis.vertical:
        _resolvedPadding = EdgeInsets.symmetric(vertical: paddingValue);
    }

    return;
  }

  @override
  void performLayout() {
    _resolve();
    super.performLayout();
  }
}

class SliverFillRemaining extends StatelessWidget {
  const SliverFillRemaining({
    super.key,
    this.child,
    this.hasScrollBody = true,
    this.fillOverscroll = false,
  });

  final Widget? child;

  final bool hasScrollBody;

  final bool fillOverscroll;

  @override
  Widget build(BuildContext context) {
    if (hasScrollBody) {
      return _SliverFillRemainingWithScrollable(child: child);
    }
    if (!fillOverscroll) {
      return _SliverFillRemainingWithoutScrollable(child: child);
    }
    return _SliverFillRemainingAndOverscroll(child: child);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<Widget>(
        'child',
        child,
      ),
    );
    final List<String> flags = <String>[
      if (hasScrollBody) 'scrollable',
      if (fillOverscroll) 'fillOverscroll',
    ];
    if (flags.isEmpty) {
      flags.add('nonscrollable');
    }
    properties.add(IterableProperty<String>('mode', flags));
  }
}

class _SliverFillRemainingWithScrollable extends SingleChildRenderObjectWidget {
  const _SliverFillRemainingWithScrollable({
    super.child,
  });

  @override
  RenderSliverFillRemainingWithScrollable createRenderObject(BuildContext context) => RenderSliverFillRemainingWithScrollable();
}

class _SliverFillRemainingWithoutScrollable extends SingleChildRenderObjectWidget {
  const _SliverFillRemainingWithoutScrollable({
    super.child,
  });

  @override
  RenderSliverFillRemaining createRenderObject(BuildContext context) => RenderSliverFillRemaining();
}

class _SliverFillRemainingAndOverscroll extends SingleChildRenderObjectWidget {
  const _SliverFillRemainingAndOverscroll({
    super.child,
  });

  @override
  RenderSliverFillRemainingAndOverscroll createRenderObject(BuildContext context) => RenderSliverFillRemainingAndOverscroll();
}