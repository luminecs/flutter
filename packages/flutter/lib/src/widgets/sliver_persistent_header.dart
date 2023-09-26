import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart' show TickerProvider;

import 'framework.dart';
import 'scroll_position.dart';
import 'scrollable.dart';

abstract class SliverPersistentHeaderDelegate {
  const SliverPersistentHeaderDelegate();

  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent);

  double get minExtent;

  double get maxExtent;

  TickerProvider? get vsync => null;

  FloatingHeaderSnapConfiguration? get snapConfiguration => null;

  OverScrollHeaderStretchConfiguration? get stretchConfiguration => null;

  PersistentHeaderShowOnScreenConfiguration? get showOnScreenConfiguration =>
      null;

  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate);
}

class SliverPersistentHeader extends StatelessWidget {
  const SliverPersistentHeader({
    super.key,
    required this.delegate,
    this.pinned = false,
    this.floating = false,
  });

  final SliverPersistentHeaderDelegate delegate;

  final bool pinned;

  final bool floating;

  @override
  Widget build(BuildContext context) {
    if (floating && pinned) {
      return _SliverFloatingPinnedPersistentHeader(delegate: delegate);
    }
    if (pinned) {
      return _SliverPinnedPersistentHeader(delegate: delegate);
    }
    if (floating) {
      return _SliverFloatingPersistentHeader(delegate: delegate);
    }
    return _SliverScrollingPersistentHeader(delegate: delegate);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
      DiagnosticsProperty<SliverPersistentHeaderDelegate>(
        'delegate',
        delegate,
      ),
    );
    final List<String> flags = <String>[
      if (pinned) 'pinned',
      if (floating) 'floating',
    ];
    if (flags.isEmpty) {
      flags.add('normal');
    }
    properties.add(IterableProperty<String>('mode', flags));
  }
}

class _FloatingHeader extends StatefulWidget {
  const _FloatingHeader({required this.child});

  final Widget child;

  @override
  _FloatingHeaderState createState() => _FloatingHeaderState();
}

// A wrapper for the widget created by _SliverPersistentHeaderElement that
// starts and stops the floating app bar's snap-into-view or snap-out-of-view
// animation. It also informs the float when pointer scrolling by updating the
// last known ScrollDirection when scrolling began.
class _FloatingHeaderState extends State<_FloatingHeader> {
  ScrollPosition? _position;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_position != null) {
      _position!.isScrollingNotifier.removeListener(_isScrollingListener);
    }
    _position = Scrollable.maybeOf(context)?.position;
    if (_position != null) {
      _position!.isScrollingNotifier.addListener(_isScrollingListener);
    }
  }

  @override
  void dispose() {
    if (_position != null) {
      _position!.isScrollingNotifier.removeListener(_isScrollingListener);
    }
    super.dispose();
  }

  RenderSliverFloatingPersistentHeader? _headerRenderer() {
    return context
        .findAncestorRenderObjectOfType<RenderSliverFloatingPersistentHeader>();
  }

  void _isScrollingListener() {
    assert(_position != null);

    // When a scroll stops, then maybe snap the app bar into view.
    // Similarly, when a scroll starts, then maybe stop the snap animation.
    // Update the scrolling direction as well for pointer scrolling updates.
    final RenderSliverFloatingPersistentHeader? header = _headerRenderer();
    if (_position!.isScrollingNotifier.value) {
      header?.updateScrollStartDirection(_position!.userScrollDirection);
      // Only SliverAppBars support snapping, headers will not snap.
      header?.maybeStopSnapAnimation(_position!.userScrollDirection);
    } else {
      // Only SliverAppBars support snapping, headers will not snap.
      header?.maybeStartSnapAnimation(_position!.userScrollDirection);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _SliverPersistentHeaderElement extends RenderObjectElement {
  _SliverPersistentHeaderElement(
    _SliverPersistentHeaderRenderObjectWidget super.widget, {
    this.floating = false,
  });

  final bool floating;

  @override
  _RenderSliverPersistentHeaderForWidgetsMixin get renderObject =>
      super.renderObject as _RenderSliverPersistentHeaderForWidgetsMixin;

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    renderObject._element = this;
  }

  @override
  void unmount() {
    renderObject._element = null;
    super.unmount();
  }

  @override
  void update(_SliverPersistentHeaderRenderObjectWidget newWidget) {
    final _SliverPersistentHeaderRenderObjectWidget oldWidget =
        widget as _SliverPersistentHeaderRenderObjectWidget;
    super.update(newWidget);
    final SliverPersistentHeaderDelegate newDelegate = newWidget.delegate;
    final SliverPersistentHeaderDelegate oldDelegate = oldWidget.delegate;
    if (newDelegate != oldDelegate &&
        (newDelegate.runtimeType != oldDelegate.runtimeType ||
            newDelegate.shouldRebuild(oldDelegate))) {
      renderObject.triggerRebuild();
    }
  }

  @override
  void performRebuild() {
    super.performRebuild();
    renderObject.triggerRebuild();
  }

  Element? child;

  void _build(double shrinkOffset, bool overlapsContent) {
    owner!.buildScope(this, () {
      final _SliverPersistentHeaderRenderObjectWidget
          sliverPersistentHeaderRenderObjectWidget =
          widget as _SliverPersistentHeaderRenderObjectWidget;
      child = updateChild(
        child,
        floating
            ? _FloatingHeader(
                child: sliverPersistentHeaderRenderObjectWidget.delegate
                    .build(this, shrinkOffset, overlapsContent))
            : sliverPersistentHeaderRenderObjectWidget.delegate
                .build(this, shrinkOffset, overlapsContent),
        null,
      );
    });
  }

  @override
  void forgetChild(Element child) {
    assert(child == this.child);
    this.child = null;
    super.forgetChild(child);
  }

  @override
  void insertRenderObjectChild(covariant RenderBox child, Object? slot) {
    assert(renderObject.debugValidateChild(child));
    renderObject.child = child;
  }

  @override
  void moveRenderObjectChild(
      covariant RenderObject child, Object? oldSlot, Object? newSlot) {
    assert(false);
  }

  @override
  void removeRenderObjectChild(covariant RenderObject child, Object? slot) {
    renderObject.child = null;
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    if (child != null) {
      visitor(child!);
    }
  }
}

abstract class _SliverPersistentHeaderRenderObjectWidget
    extends RenderObjectWidget {
  const _SliverPersistentHeaderRenderObjectWidget({
    required this.delegate,
    this.floating = false,
  });

  final SliverPersistentHeaderDelegate delegate;
  final bool floating;

  @override
  _SliverPersistentHeaderElement createElement() =>
      _SliverPersistentHeaderElement(this, floating: floating);

  @override
  _RenderSliverPersistentHeaderForWidgetsMixin createRenderObject(
      BuildContext context);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(
      DiagnosticsProperty<SliverPersistentHeaderDelegate>(
        'delegate',
        delegate,
      ),
    );
  }
}

mixin _RenderSliverPersistentHeaderForWidgetsMixin
    on RenderSliverPersistentHeader {
  _SliverPersistentHeaderElement? _element;

  @override
  double get minExtent =>
      (_element!.widget as _SliverPersistentHeaderRenderObjectWidget)
          .delegate
          .minExtent;

  @override
  double get maxExtent =>
      (_element!.widget as _SliverPersistentHeaderRenderObjectWidget)
          .delegate
          .maxExtent;

  @override
  void updateChild(double shrinkOffset, bool overlapsContent) {
    assert(_element != null);
    _element!._build(shrinkOffset, overlapsContent);
  }

  @protected
  void triggerRebuild() {
    markNeedsLayout();
  }
}

class _SliverScrollingPersistentHeader
    extends _SliverPersistentHeaderRenderObjectWidget {
  const _SliverScrollingPersistentHeader({
    required super.delegate,
  });

  @override
  _RenderSliverPersistentHeaderForWidgetsMixin createRenderObject(
      BuildContext context) {
    return _RenderSliverScrollingPersistentHeaderForWidgets(
      stretchConfiguration: delegate.stretchConfiguration,
    );
  }

  @override
  void updateRenderObject(BuildContext context,
      covariant _RenderSliverScrollingPersistentHeaderForWidgets renderObject) {
    renderObject.stretchConfiguration = delegate.stretchConfiguration;
  }
}

class _RenderSliverScrollingPersistentHeaderForWidgets
    extends RenderSliverScrollingPersistentHeader
    with _RenderSliverPersistentHeaderForWidgetsMixin {
  _RenderSliverScrollingPersistentHeaderForWidgets({
    super.stretchConfiguration,
  });
}

class _SliverPinnedPersistentHeader
    extends _SliverPersistentHeaderRenderObjectWidget {
  const _SliverPinnedPersistentHeader({
    required super.delegate,
  });

  @override
  _RenderSliverPersistentHeaderForWidgetsMixin createRenderObject(
      BuildContext context) {
    return _RenderSliverPinnedPersistentHeaderForWidgets(
      stretchConfiguration: delegate.stretchConfiguration,
      showOnScreenConfiguration: delegate.showOnScreenConfiguration,
    );
  }

  @override
  void updateRenderObject(BuildContext context,
      covariant _RenderSliverPinnedPersistentHeaderForWidgets renderObject) {
    renderObject
      ..stretchConfiguration = delegate.stretchConfiguration
      ..showOnScreenConfiguration = delegate.showOnScreenConfiguration;
  }
}

class _RenderSliverPinnedPersistentHeaderForWidgets
    extends RenderSliverPinnedPersistentHeader
    with _RenderSliverPersistentHeaderForWidgetsMixin {
  _RenderSliverPinnedPersistentHeaderForWidgets({
    super.stretchConfiguration,
    super.showOnScreenConfiguration,
  });
}

class _SliverFloatingPersistentHeader
    extends _SliverPersistentHeaderRenderObjectWidget {
  const _SliverFloatingPersistentHeader({
    required super.delegate,
  }) : super(
          floating: true,
        );

  @override
  _RenderSliverPersistentHeaderForWidgetsMixin createRenderObject(
      BuildContext context) {
    return _RenderSliverFloatingPersistentHeaderForWidgets(
      vsync: delegate.vsync,
      snapConfiguration: delegate.snapConfiguration,
      stretchConfiguration: delegate.stretchConfiguration,
      showOnScreenConfiguration: delegate.showOnScreenConfiguration,
    );
  }

  @override
  void updateRenderObject(BuildContext context,
      _RenderSliverFloatingPersistentHeaderForWidgets renderObject) {
    renderObject.vsync = delegate.vsync;
    renderObject.snapConfiguration = delegate.snapConfiguration;
    renderObject.stretchConfiguration = delegate.stretchConfiguration;
    renderObject.showOnScreenConfiguration = delegate.showOnScreenConfiguration;
  }
}

class _RenderSliverFloatingPinnedPersistentHeaderForWidgets
    extends RenderSliverFloatingPinnedPersistentHeader
    with _RenderSliverPersistentHeaderForWidgetsMixin {
  _RenderSliverFloatingPinnedPersistentHeaderForWidgets({
    required super.vsync,
    super.snapConfiguration,
    super.stretchConfiguration,
    super.showOnScreenConfiguration,
  });
}

class _SliverFloatingPinnedPersistentHeader
    extends _SliverPersistentHeaderRenderObjectWidget {
  const _SliverFloatingPinnedPersistentHeader({
    required super.delegate,
  }) : super(
          floating: true,
        );

  @override
  _RenderSliverPersistentHeaderForWidgetsMixin createRenderObject(
      BuildContext context) {
    return _RenderSliverFloatingPinnedPersistentHeaderForWidgets(
      vsync: delegate.vsync,
      snapConfiguration: delegate.snapConfiguration,
      stretchConfiguration: delegate.stretchConfiguration,
      showOnScreenConfiguration: delegate.showOnScreenConfiguration,
    );
  }

  @override
  void updateRenderObject(BuildContext context,
      _RenderSliverFloatingPinnedPersistentHeaderForWidgets renderObject) {
    renderObject.vsync = delegate.vsync;
    renderObject.snapConfiguration = delegate.snapConfiguration;
    renderObject.stretchConfiguration = delegate.stretchConfiguration;
    renderObject.showOnScreenConfiguration = delegate.showOnScreenConfiguration;
  }
}

class _RenderSliverFloatingPersistentHeaderForWidgets
    extends RenderSliverFloatingPersistentHeader
    with _RenderSliverPersistentHeaderForWidgetsMixin {
  _RenderSliverFloatingPersistentHeaderForWidgets({
    required super.vsync,
    super.snapConfiguration,
    super.stretchConfiguration,
    super.showOnScreenConfiguration,
  });
}
