import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';

import 'basic.dart';
import 'framework.dart';
import 'notification_listener.dart';
import 'scroll_configuration.dart';
import 'scroll_context.dart';
import 'scroll_controller.dart';
import 'scroll_metrics.dart';
import 'scroll_notification.dart';
import 'scroll_physics.dart';
import 'scroll_position.dart';
import 'scroll_position_with_single_context.dart';
import 'scrollable.dart';

abstract class ListWheelChildDelegate {
  Widget? build(BuildContext context, int index);

  int? get estimatedChildCount;

  int trueIndexOf(int index) => index;

  bool shouldRebuild(covariant ListWheelChildDelegate oldDelegate);
}

class ListWheelChildListDelegate extends ListWheelChildDelegate {
  ListWheelChildListDelegate({required this.children});

  final List<Widget> children;

  @override
  int get estimatedChildCount => children.length;

  @override
  Widget? build(BuildContext context, int index) {
    if (index < 0 || index >= children.length) {
      return null;
    }
    return IndexedSemantics(index: index, child: children[index]);
  }

  @override
  bool shouldRebuild(covariant ListWheelChildListDelegate oldDelegate) {
    return children != oldDelegate.children;
  }
}

class ListWheelChildLoopingListDelegate extends ListWheelChildDelegate {
  ListWheelChildLoopingListDelegate({required this.children});

  final List<Widget> children;

  @override
  int? get estimatedChildCount => null;

  @override
  int trueIndexOf(int index) => index % children.length;

  @override
  Widget? build(BuildContext context, int index) {
    if (children.isEmpty) {
      return null;
    }
    return IndexedSemantics(index: index, child: children[index % children.length]);
  }

  @override
  bool shouldRebuild(covariant ListWheelChildLoopingListDelegate oldDelegate) {
    return children != oldDelegate.children;
  }
}

class ListWheelChildBuilderDelegate extends ListWheelChildDelegate {
  ListWheelChildBuilderDelegate({
    required this.builder,
    this.childCount,
  });

  final NullableIndexedWidgetBuilder builder;

  final int? childCount;

  @override
  int? get estimatedChildCount => childCount;

  @override
  Widget? build(BuildContext context, int index) {
    if (childCount == null) {
      final Widget? child = builder(context, index);
      return child == null ? null : IndexedSemantics(index: index, child: child);
    }
    if (index < 0 || index >= childCount!) {
      return null;
    }
    return IndexedSemantics(index: index, child: builder(context, index));
  }

  @override
  bool shouldRebuild(covariant ListWheelChildBuilderDelegate oldDelegate) {
    return builder != oldDelegate.builder || childCount != oldDelegate.childCount;
  }
}

class FixedExtentScrollController extends ScrollController {
  FixedExtentScrollController({
    this.initialItem = 0,
  });

  final int initialItem;

  int get selectedItem {
    assert(
      positions.isNotEmpty,
      'FixedExtentScrollController.selectedItem cannot be accessed before a '
      'scroll view is built with it.',
    );
    assert(
      positions.length == 1,
      'The selectedItem property cannot be read when multiple scroll views are '
      'attached to the same FixedExtentScrollController.',
    );
    final _FixedExtentScrollPosition position = this.position as _FixedExtentScrollPosition;
    return position.itemIndex;
  }

  Future<void> animateToItem(
    int itemIndex, {
    required Duration duration,
    required Curve curve,
  }) async {
    if (!hasClients) {
      return;
    }

    await Future.wait<void>(<Future<void>>[
      for (final _FixedExtentScrollPosition position in positions.cast<_FixedExtentScrollPosition>())
        position.animateTo(
          itemIndex * position.itemExtent,
          duration: duration,
          curve: curve,
        ),
    ]);
  }

  void jumpToItem(int itemIndex) {
    for (final _FixedExtentScrollPosition position in positions.cast<_FixedExtentScrollPosition>()) {
      position.jumpTo(itemIndex * position.itemExtent);
    }
  }

  @override
  ScrollPosition createScrollPosition(ScrollPhysics physics, ScrollContext context, ScrollPosition? oldPosition) {
    return _FixedExtentScrollPosition(
      physics: physics,
      context: context,
      initialItem: initialItem,
      oldPosition: oldPosition,
    );
  }
}

class FixedExtentMetrics extends FixedScrollMetrics {
  FixedExtentMetrics({
    required super.minScrollExtent,
    required super.maxScrollExtent,
    required super.pixels,
    required super.viewportDimension,
    required super.axisDirection,
    required this.itemIndex,
    required super.devicePixelRatio,
  });

  @override
  FixedExtentMetrics copyWith({
    double? minScrollExtent,
    double? maxScrollExtent,
    double? pixels,
    double? viewportDimension,
    AxisDirection? axisDirection,
    int? itemIndex,
    double? devicePixelRatio,
  }) {
    return FixedExtentMetrics(
      minScrollExtent: minScrollExtent ?? (hasContentDimensions ? this.minScrollExtent : null),
      maxScrollExtent: maxScrollExtent ?? (hasContentDimensions ? this.maxScrollExtent : null),
      pixels: pixels ?? (hasPixels ? this.pixels : null),
      viewportDimension: viewportDimension ?? (hasViewportDimension ? this.viewportDimension : null),
      axisDirection: axisDirection ?? this.axisDirection,
      itemIndex: itemIndex ?? this.itemIndex,
      devicePixelRatio: devicePixelRatio ?? this.devicePixelRatio,
    );
  }

  final int itemIndex;
}

int _getItemFromOffset({
  required double offset,
  required double itemExtent,
  required double minScrollExtent,
  required double maxScrollExtent,
}) {
  return (_clipOffsetToScrollableRange(offset, minScrollExtent, maxScrollExtent) / itemExtent).round();
}

double _clipOffsetToScrollableRange(
  double offset,
  double minScrollExtent,
  double maxScrollExtent,
) {
  return math.min(math.max(offset, minScrollExtent), maxScrollExtent);
}

class _FixedExtentScrollPosition extends ScrollPositionWithSingleContext implements FixedExtentMetrics {
  _FixedExtentScrollPosition({
    required super.physics,
    required super.context,
    required int initialItem,
    super.oldPosition,
  }) : assert(
         context is _FixedExtentScrollableState,
         'FixedExtentScrollController can only be used with ListWheelScrollViews',
       ),
       super(
         initialPixels: _getItemExtentFromScrollContext(context) * initialItem,
       );

  static double _getItemExtentFromScrollContext(ScrollContext context) {
    final _FixedExtentScrollableState scrollable = context as _FixedExtentScrollableState;
    return scrollable.itemExtent;
  }

  double get itemExtent => _getItemExtentFromScrollContext(context);

  @override
  int get itemIndex {
    return _getItemFromOffset(
      offset: pixels,
      itemExtent: itemExtent,
      minScrollExtent: minScrollExtent,
      maxScrollExtent: maxScrollExtent,
    );
  }

  @override
  FixedExtentMetrics copyWith({
    double? minScrollExtent,
    double? maxScrollExtent,
    double? pixels,
    double? viewportDimension,
    AxisDirection? axisDirection,
    int? itemIndex,
    double? devicePixelRatio,
  }) {
    return FixedExtentMetrics(
      minScrollExtent: minScrollExtent ?? (hasContentDimensions ? this.minScrollExtent : null),
      maxScrollExtent: maxScrollExtent ?? (hasContentDimensions ? this.maxScrollExtent : null),
      pixels: pixels ?? (hasPixels ? this.pixels : null),
      viewportDimension: viewportDimension ?? (hasViewportDimension ? this.viewportDimension : null),
      axisDirection: axisDirection ?? this.axisDirection,
      itemIndex: itemIndex ?? this.itemIndex,
      devicePixelRatio: devicePixelRatio ?? this.devicePixelRatio,
    );
  }
}

class _FixedExtentScrollable extends Scrollable {
  const _FixedExtentScrollable({
    super.controller,
    super.physics,
    required this.itemExtent,
    required super.viewportBuilder,
    super.restorationId,
    super.scrollBehavior,
  });

  final double itemExtent;

  @override
  _FixedExtentScrollableState createState() => _FixedExtentScrollableState();
}

class _FixedExtentScrollableState extends ScrollableState {
  double get itemExtent {
    // Downcast because only _FixedExtentScrollable can make _FixedExtentScrollableState.
    final _FixedExtentScrollable actualWidget = widget as _FixedExtentScrollable;
    return actualWidget.itemExtent;
  }
}

class FixedExtentScrollPhysics extends ScrollPhysics {
  const FixedExtentScrollPhysics({ super.parent });

  @override
  FixedExtentScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return FixedExtentScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    assert(
      position is _FixedExtentScrollPosition,
      'FixedExtentScrollPhysics can only be used with Scrollables that uses '
      'the FixedExtentScrollController',
    );

    final _FixedExtentScrollPosition metrics = position as _FixedExtentScrollPosition;

    // Scenario 1:
    // If we're out of range and not headed back in range, defer to the parent
    // ballistics, which should put us back in range at the scrollable's boundary.
    if ((velocity <= 0.0 && metrics.pixels <= metrics.minScrollExtent) ||
        (velocity >= 0.0 && metrics.pixels >= metrics.maxScrollExtent)) {
      return super.createBallisticSimulation(metrics, velocity);
    }

    // Create a test simulation to see where it would have ballistically fallen
    // naturally without settling onto items.
    final Simulation? testFrictionSimulation =
        super.createBallisticSimulation(metrics, velocity);

    // Scenario 2:
    // If it was going to end up past the scroll extent, defer back to the
    // parent physics' ballistics again which should put us on the scrollable's
    // boundary.
    if (testFrictionSimulation != null
        && (testFrictionSimulation.x(double.infinity) == metrics.minScrollExtent
            || testFrictionSimulation.x(double.infinity) == metrics.maxScrollExtent)) {
      return super.createBallisticSimulation(metrics, velocity);
    }

    // From the natural final position, find the nearest item it should have
    // settled to.
    final int settlingItemIndex = _getItemFromOffset(
      offset: testFrictionSimulation?.x(double.infinity) ?? metrics.pixels,
      itemExtent: metrics.itemExtent,
      minScrollExtent: metrics.minScrollExtent,
      maxScrollExtent: metrics.maxScrollExtent,
    );

    final double settlingPixels = settlingItemIndex * metrics.itemExtent;

    // Scenario 3:
    // If there's no velocity and we're already at where we intend to land,
    // do nothing.
    if (velocity.abs() < toleranceFor(position).velocity
        && (settlingPixels - metrics.pixels).abs() < toleranceFor(position).distance) {
      return null;
    }

    // Scenario 4:
    // If we're going to end back at the same item because initial velocity
    // is too low to break past it, use a spring simulation to get back.
    if (settlingItemIndex == metrics.itemIndex) {
      return SpringSimulation(
        spring,
        metrics.pixels,
        settlingPixels,
        velocity,
        tolerance: toleranceFor(position),
      );
    }

    // Scenario 5:
    // Create a new friction simulation except the drag will be tweaked to land
    // exactly on the item closest to the natural stopping point.
    return FrictionSimulation.through(
      metrics.pixels,
      settlingPixels,
      velocity,
      toleranceFor(position).velocity * velocity.sign,
    );
  }
}

class ListWheelScrollView extends StatefulWidget {
  ListWheelScrollView({
    super.key,
    this.controller,
    this.physics,
    this.diameterRatio = RenderListWheelViewport.defaultDiameterRatio,
    this.perspective = RenderListWheelViewport.defaultPerspective,
    this.offAxisFraction = 0.0,
    this.useMagnifier = false,
    this.magnification = 1.0,
    this.overAndUnderCenterOpacity = 1.0,
    required this.itemExtent,
    this.squeeze = 1.0,
    this.onSelectedItemChanged,
    this.renderChildrenOutsideViewport = false,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
    this.scrollBehavior,
    required List<Widget> children,
  }) : assert(diameterRatio > 0.0, RenderListWheelViewport.diameterRatioZeroMessage),
       assert(perspective > 0),
       assert(perspective <= 0.01, RenderListWheelViewport.perspectiveTooHighMessage),
       assert(magnification > 0),
       assert(overAndUnderCenterOpacity >= 0 && overAndUnderCenterOpacity <= 1),
       assert(itemExtent > 0),
       assert(squeeze > 0),
       assert(
         !renderChildrenOutsideViewport || clipBehavior == Clip.none,
         RenderListWheelViewport.clipBehaviorAndRenderChildrenOutsideViewportConflict,
       ),
       childDelegate = ListWheelChildListDelegate(children: children);

  const ListWheelScrollView.useDelegate({
    super.key,
    this.controller,
    this.physics,
    this.diameterRatio = RenderListWheelViewport.defaultDiameterRatio,
    this.perspective = RenderListWheelViewport.defaultPerspective,
    this.offAxisFraction = 0.0,
    this.useMagnifier = false,
    this.magnification = 1.0,
    this.overAndUnderCenterOpacity = 1.0,
    required this.itemExtent,
    this.squeeze = 1.0,
    this.onSelectedItemChanged,
    this.renderChildrenOutsideViewport = false,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
    this.scrollBehavior,
    required this.childDelegate,
  }) : assert(diameterRatio > 0.0, RenderListWheelViewport.diameterRatioZeroMessage),
       assert(perspective > 0),
       assert(perspective <= 0.01, RenderListWheelViewport.perspectiveTooHighMessage),
       assert(magnification > 0),
       assert(overAndUnderCenterOpacity >= 0 && overAndUnderCenterOpacity <= 1),
       assert(itemExtent > 0),
       assert(squeeze > 0),
       assert(
         !renderChildrenOutsideViewport || clipBehavior == Clip.none,
         RenderListWheelViewport.clipBehaviorAndRenderChildrenOutsideViewportConflict,
       );

  final ScrollController? controller;

  final ScrollPhysics? physics;

  final double diameterRatio;

  final double perspective;

  final double offAxisFraction;

  final bool useMagnifier;

  final double magnification;

  final double overAndUnderCenterOpacity;

  final double itemExtent;

  final double squeeze;

  final ValueChanged<int>? onSelectedItemChanged;

  final bool renderChildrenOutsideViewport;

  final ListWheelChildDelegate childDelegate;

  final Clip clipBehavior;

  final String? restorationId;

  final ScrollBehavior? scrollBehavior;

  @override
  State<ListWheelScrollView> createState() => _ListWheelScrollViewState();
}

class _ListWheelScrollViewState extends State<ListWheelScrollView> {
  int _lastReportedItemIndex = 0;
  ScrollController? _backupController;

  ScrollController get _effectiveController =>
    widget.controller ?? (_backupController ??= FixedExtentScrollController());

  @override
  void initState() {
    super.initState();
    if (widget.controller is FixedExtentScrollController) {
      final FixedExtentScrollController controller = widget.controller! as FixedExtentScrollController;
      _lastReportedItemIndex = controller.initialItem;
    }
  }

  @override
  void dispose() {
    _backupController?.dispose();
    super.dispose();
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.depth == 0
        && widget.onSelectedItemChanged != null
        && notification is ScrollUpdateNotification
        && notification.metrics is FixedExtentMetrics) {
      final FixedExtentMetrics metrics = notification.metrics as FixedExtentMetrics;
      final int currentItemIndex = metrics.itemIndex;
      if (currentItemIndex != _lastReportedItemIndex) {
        _lastReportedItemIndex = currentItemIndex;
        final int trueIndex = widget.childDelegate.trueIndexOf(currentItemIndex);
        widget.onSelectedItemChanged!(trueIndex);
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: _FixedExtentScrollable(
        controller: _effectiveController,
        physics: widget.physics,
        itemExtent: widget.itemExtent,
        restorationId: widget.restorationId,
        scrollBehavior: widget.scrollBehavior ?? ScrollConfiguration.of(context).copyWith(scrollbars: false),
        viewportBuilder: (BuildContext context, ViewportOffset offset) {
          return ListWheelViewport(
            diameterRatio: widget.diameterRatio,
            perspective: widget.perspective,
            offAxisFraction: widget.offAxisFraction,
            useMagnifier: widget.useMagnifier,
            magnification: widget.magnification,
            overAndUnderCenterOpacity: widget.overAndUnderCenterOpacity,
            itemExtent: widget.itemExtent,
            squeeze: widget.squeeze,
            renderChildrenOutsideViewport: widget.renderChildrenOutsideViewport,
            offset: offset,
            childDelegate: widget.childDelegate,
            clipBehavior: widget.clipBehavior,
          );
        },
      ),
    );
  }
}

class ListWheelElement extends RenderObjectElement implements ListWheelChildManager {
  ListWheelElement(ListWheelViewport super.widget);

  @override
  RenderListWheelViewport get renderObject => super.renderObject as RenderListWheelViewport;

  // We inflate widgets at two different times:
  //  1. When we ourselves are told to rebuild (see performRebuild).
  //  2. When our render object needs a new child (see createChild).
  // In both cases, we cache the results of calling into our delegate to get the
  // widget, so that if we do case 2 later, we don't call the builder again.
  // Any time we do case 1, though, we reset the cache.

  final Map<int, Widget?> _childWidgets = HashMap<int, Widget?>();

  final SplayTreeMap<int, Element> _childElements = SplayTreeMap<int, Element>();

  @override
  void update(ListWheelViewport newWidget) {
    final ListWheelViewport oldWidget = widget as ListWheelViewport;
    super.update(newWidget);
    final ListWheelChildDelegate newDelegate = newWidget.childDelegate;
    final ListWheelChildDelegate oldDelegate = oldWidget.childDelegate;
    if (newDelegate != oldDelegate &&
        (newDelegate.runtimeType != oldDelegate.runtimeType || newDelegate.shouldRebuild(oldDelegate))) {
      performRebuild();
      renderObject.markNeedsLayout();
    }
  }

  @override
  int? get childCount => (widget as ListWheelViewport).childDelegate.estimatedChildCount;

  @override
  void performRebuild() {
    _childWidgets.clear();
    super.performRebuild();
    if (_childElements.isEmpty) {
      return;
    }

    final int firstIndex = _childElements.firstKey()!;
    final int lastIndex = _childElements.lastKey()!;

    for (int index = firstIndex; index <= lastIndex; ++index) {
      final Element? newChild = updateChild(_childElements[index], retrieveWidget(index), index);
      if (newChild != null) {
        _childElements[index] = newChild;
      } else {
        _childElements.remove(index);
      }
    }
  }

  Widget? retrieveWidget(int index) {
    return _childWidgets.putIfAbsent(index, () => (widget as ListWheelViewport).childDelegate.build(this, index));
  }

  @override
  bool childExistsAt(int index) => retrieveWidget(index) != null;

  @override
  void createChild(int index, { required RenderBox? after }) {
    owner!.buildScope(this, () {
      final bool insertFirst = after == null;
      assert(insertFirst || _childElements[index - 1] != null);
      final Element? newChild =
        updateChild(_childElements[index], retrieveWidget(index), index);
      if (newChild != null) {
        _childElements[index] = newChild;
      } else {
        _childElements.remove(index);
      }
    });
  }

  @override
  void removeChild(RenderBox child) {
    final int index = renderObject.indexOf(child);
    owner!.buildScope(this, () {
      assert(_childElements.containsKey(index));
      final Element? result = updateChild(_childElements[index], null, index);
      assert(result == null);
      _childElements.remove(index);
      assert(!_childElements.containsKey(index));
    });
  }

  @override
  Element? updateChild(Element? child, Widget? newWidget, Object? newSlot) {
    final ListWheelParentData? oldParentData = child?.renderObject?.parentData as ListWheelParentData?;
    final Element? newChild = super.updateChild(child, newWidget, newSlot);
    final ListWheelParentData? newParentData = newChild?.renderObject?.parentData as ListWheelParentData?;
    if (newParentData != null) {
      newParentData.index = newSlot! as int;
      if (oldParentData != null) {
        newParentData.offset = oldParentData.offset;
      }
    }

    return newChild;
  }

  @override
  void insertRenderObjectChild(RenderObject child, int slot) {
    final RenderListWheelViewport renderObject = this.renderObject;
    assert(renderObject.debugValidateChild(child));
    renderObject.insert(child as RenderBox, after: _childElements[slot - 1]?.renderObject as RenderBox?);
    assert(renderObject == this.renderObject);
  }

  @override
  void moveRenderObjectChild(RenderObject child, int oldSlot, int newSlot) {
    const String moveChildRenderObjectErrorMessage =
        'Currently we maintain the list in contiguous increasing order, so '
        'moving children around is not allowed.';
    assert(false, moveChildRenderObjectErrorMessage);
  }

  @override
  void removeRenderObjectChild(RenderObject child, int slot) {
    assert(child.parent == renderObject);
    renderObject.remove(child as RenderBox);
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    _childElements.forEach((int key, Element child) {
      visitor(child);
    });
  }

  @override
  void forgetChild(Element child) {
    _childElements.remove(child.slot);
    super.forgetChild(child);
  }

}

class ListWheelViewport extends RenderObjectWidget {
  const ListWheelViewport({
    super.key,
    this.diameterRatio = RenderListWheelViewport.defaultDiameterRatio,
    this.perspective = RenderListWheelViewport.defaultPerspective,
    this.offAxisFraction = 0.0,
    this.useMagnifier = false,
    this.magnification = 1.0,
    this.overAndUnderCenterOpacity = 1.0,
    required this.itemExtent,
    this.squeeze = 1.0,
    this.renderChildrenOutsideViewport = false,
    required this.offset,
    required this.childDelegate,
    this.clipBehavior = Clip.hardEdge,
  }) : assert(diameterRatio > 0, RenderListWheelViewport.diameterRatioZeroMessage),
       assert(perspective > 0),
       assert(perspective <= 0.01, RenderListWheelViewport.perspectiveTooHighMessage),
       assert(overAndUnderCenterOpacity >= 0 && overAndUnderCenterOpacity <= 1),
       assert(itemExtent > 0),
       assert(squeeze > 0),
       assert(
         !renderChildrenOutsideViewport || clipBehavior == Clip.none,
         RenderListWheelViewport.clipBehaviorAndRenderChildrenOutsideViewportConflict,
       );

  final double diameterRatio;

  final double perspective;

  final double offAxisFraction;

  final bool useMagnifier;

  final double magnification;

  final double overAndUnderCenterOpacity;

  final double itemExtent;

  final double squeeze;

  final bool renderChildrenOutsideViewport;

  final ViewportOffset offset;

  final ListWheelChildDelegate childDelegate;

  final Clip clipBehavior;

  @override
  ListWheelElement createElement() => ListWheelElement(this);

  @override
  RenderListWheelViewport createRenderObject(BuildContext context) {
    final ListWheelElement childManager = context as ListWheelElement;
    return RenderListWheelViewport(
      childManager: childManager,
      offset: offset,
      diameterRatio: diameterRatio,
      perspective: perspective,
      offAxisFraction: offAxisFraction,
      useMagnifier: useMagnifier,
      magnification: magnification,
      overAndUnderCenterOpacity: overAndUnderCenterOpacity,
      itemExtent: itemExtent,
      squeeze: squeeze,
      renderChildrenOutsideViewport: renderChildrenOutsideViewport,
      clipBehavior: clipBehavior,
    );
  }

  @override
  void updateRenderObject(BuildContext context, RenderListWheelViewport renderObject) {
    renderObject
      ..offset = offset
      ..diameterRatio = diameterRatio
      ..perspective = perspective
      ..offAxisFraction = offAxisFraction
      ..useMagnifier = useMagnifier
      ..magnification = magnification
      ..overAndUnderCenterOpacity = overAndUnderCenterOpacity
      ..itemExtent = itemExtent
      ..squeeze = squeeze
      ..renderChildrenOutsideViewport = renderChildrenOutsideViewport
      ..clipBehavior = clipBehavior;
  }
}