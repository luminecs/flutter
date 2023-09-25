
// Test sliver which always attempts to paint itself whether it is visible or not.
// Use for checking if slivers which take sliver children paints optimally.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class RenderMockSliverToBoxAdapter extends RenderSliverToBoxAdapter {
  RenderMockSliverToBoxAdapter({
    super.child,
    required this.incrementCounter,
  });
  final void Function() incrementCounter;

  @override
  void paint(PaintingContext context, Offset offset) {
    incrementCounter();
  }
}

class MockSliverToBoxAdapter extends SingleChildRenderObjectWidget {
  const MockSliverToBoxAdapter({
    super.key,
    super.child,
    required this.incrementCounter,
  });

  final void Function() incrementCounter;

  @override
  RenderMockSliverToBoxAdapter createRenderObject(BuildContext context) =>
    RenderMockSliverToBoxAdapter(incrementCounter: incrementCounter);
}