import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'debug.dart';
import 'icons.dart';
import 'material.dart';
import 'theme.dart';

class ReorderableListView extends StatefulWidget {
  ReorderableListView({
    super.key,
    required List<Widget> children,
    required this.onReorder,
    this.onReorderStart,
    this.onReorderEnd,
    this.itemExtent,
    this.itemExtentBuilder,
    this.prototypeItem,
    this.proxyDecorator,
    this.buildDefaultDragHandles = true,
    this.padding,
    this.header,
    this.footer,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.scrollController,
    this.primary,
    this.physics,
    this.shrinkWrap = false,
    this.anchor = 0.0,
    this.cacheExtent,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.autoScrollerVelocityScalar,
  })  : assert(
          (itemExtent == null && prototypeItem == null) ||
              (itemExtent == null && itemExtentBuilder == null) ||
              (prototypeItem == null && itemExtentBuilder == null),
          'You can only pass one of itemExtent, prototypeItem and itemExtentBuilder.',
        ),
        assert(
          children.every((Widget w) => w.key != null),
          'All children of this widget must have a key.',
        ),
        itemBuilder = ((BuildContext context, int index) => children[index]),
        itemCount = children.length;

  const ReorderableListView.builder({
    super.key,
    required this.itemBuilder,
    required this.itemCount,
    required this.onReorder,
    this.onReorderStart,
    this.onReorderEnd,
    this.itemExtent,
    this.itemExtentBuilder,
    this.prototypeItem,
    this.proxyDecorator,
    this.buildDefaultDragHandles = true,
    this.padding,
    this.header,
    this.footer,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.scrollController,
    this.primary,
    this.physics,
    this.shrinkWrap = false,
    this.anchor = 0.0,
    this.cacheExtent,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.restorationId,
    this.clipBehavior = Clip.hardEdge,
    this.autoScrollerVelocityScalar,
  })  : assert(itemCount >= 0),
        assert(
          (itemExtent == null && prototypeItem == null) ||
              (itemExtent == null && itemExtentBuilder == null) ||
              (prototypeItem == null && itemExtentBuilder == null),
          'You can only pass one of itemExtent, prototypeItem and itemExtentBuilder.',
        );

  final IndexedWidgetBuilder itemBuilder;

  final int itemCount;

  final ReorderCallback onReorder;

  final void Function(int index)? onReorderStart;

  final void Function(int index)? onReorderEnd;

  final ReorderItemProxyDecorator? proxyDecorator;

  final bool buildDefaultDragHandles;

  final EdgeInsets? padding;

  final Widget? header;

  final Widget? footer;

  final Axis scrollDirection;

  final bool reverse;

  final ScrollController? scrollController;

  final bool? primary;

  final ScrollPhysics? physics;

  final bool shrinkWrap;

  final double anchor;

  final double? cacheExtent;

  final DragStartBehavior dragStartBehavior;

  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  final String? restorationId;

  final Clip clipBehavior;

  final double? itemExtent;

  final ItemExtentBuilder? itemExtentBuilder;

  final Widget? prototypeItem;

  final double? autoScrollerVelocityScalar;

  @override
  State<ReorderableListView> createState() => _ReorderableListViewState();
}

class _ReorderableListViewState extends State<ReorderableListView> {
  Widget _itemBuilder(BuildContext context, int index) {
    final Widget item = widget.itemBuilder(context, index);
    assert(() {
      if (item.key == null) {
        throw FlutterError(
          'Every item of ReorderableListView must have a key.',
        );
      }
      return true;
    }());

    final Key itemGlobalKey =
        _ReorderableListViewChildGlobalKey(item.key!, this);

    if (widget.buildDefaultDragHandles) {
      switch (Theme.of(context).platform) {
        case TargetPlatform.linux:
        case TargetPlatform.windows:
        case TargetPlatform.macOS:
          switch (widget.scrollDirection) {
            case Axis.horizontal:
              return Stack(
                key: itemGlobalKey,
                children: <Widget>[
                  item,
                  Positioned.directional(
                    textDirection: Directionality.of(context),
                    start: 0,
                    end: 0,
                    bottom: 8,
                    child: Align(
                      alignment: AlignmentDirectional.bottomCenter,
                      child: ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_handle),
                      ),
                    ),
                  ),
                ],
              );
            case Axis.vertical:
              return Stack(
                key: itemGlobalKey,
                children: <Widget>[
                  item,
                  Positioned.directional(
                    textDirection: Directionality.of(context),
                    top: 0,
                    bottom: 0,
                    end: 8,
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: ReorderableDragStartListener(
                        index: index,
                        child: const Icon(Icons.drag_handle),
                      ),
                    ),
                  ),
                ],
              );
          }

        case TargetPlatform.iOS:
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
          return ReorderableDelayedDragStartListener(
            key: itemGlobalKey,
            index: index,
            child: item,
          );
      }
    }

    return KeyedSubtree(
      key: itemGlobalKey,
      child: item,
    );
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double animValue = Curves.easeInOut.transform(animation.value);
        final double elevation = lerpDouble(0, 6, animValue)!;
        return Material(
          elevation: elevation,
          child: child,
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterialLocalizations(context));
    assert(debugCheckHasOverlay(context));

    // If there is a header or footer we can't just apply the padding to the list,
    // so we break it up into padding for the header, footer and padding for the list.
    final EdgeInsets padding = widget.padding ?? EdgeInsets.zero;
    late final EdgeInsets headerPadding;
    late final EdgeInsets footerPadding;
    late final EdgeInsets listPadding;

    if (widget.header == null && widget.footer == null) {
      headerPadding = EdgeInsets.zero;
      footerPadding = EdgeInsets.zero;
      listPadding = padding;
    } else if (widget.header != null || widget.footer != null) {
      switch (widget.scrollDirection) {
        case Axis.horizontal:
          if (widget.reverse) {
            headerPadding = EdgeInsets.fromLTRB(
                0, padding.top, padding.right, padding.bottom);
            listPadding = EdgeInsets.fromLTRB(
                widget.footer != null ? 0 : padding.left,
                padding.top,
                widget.header != null ? 0 : padding.right,
                padding.bottom);
            footerPadding = EdgeInsets.fromLTRB(
                padding.left, padding.top, 0, padding.bottom);
          } else {
            headerPadding = EdgeInsets.fromLTRB(
                padding.left, padding.top, 0, padding.bottom);
            listPadding = EdgeInsets.fromLTRB(
                widget.header != null ? 0 : padding.left,
                padding.top,
                widget.footer != null ? 0 : padding.right,
                padding.bottom);
            footerPadding = EdgeInsets.fromLTRB(
                0, padding.top, padding.right, padding.bottom);
          }
        case Axis.vertical:
          if (widget.reverse) {
            headerPadding = EdgeInsets.fromLTRB(
                padding.left, 0, padding.right, padding.bottom);
            listPadding = EdgeInsets.fromLTRB(
                padding.left,
                widget.footer != null ? 0 : padding.top,
                padding.right,
                widget.header != null ? 0 : padding.bottom);
            footerPadding = EdgeInsets.fromLTRB(
                padding.left, padding.top, padding.right, 0);
          } else {
            headerPadding = EdgeInsets.fromLTRB(
                padding.left, padding.top, padding.right, 0);
            listPadding = EdgeInsets.fromLTRB(
                padding.left,
                widget.header != null ? 0 : padding.top,
                padding.right,
                widget.footer != null ? 0 : padding.bottom);
            footerPadding = EdgeInsets.fromLTRB(
                padding.left, 0, padding.right, padding.bottom);
          }
      }
    }

    return CustomScrollView(
      scrollDirection: widget.scrollDirection,
      reverse: widget.reverse,
      controller: widget.scrollController,
      primary: widget.primary,
      physics: widget.physics,
      shrinkWrap: widget.shrinkWrap,
      anchor: widget.anchor,
      cacheExtent: widget.cacheExtent,
      dragStartBehavior: widget.dragStartBehavior,
      keyboardDismissBehavior: widget.keyboardDismissBehavior,
      restorationId: widget.restorationId,
      clipBehavior: widget.clipBehavior,
      slivers: <Widget>[
        if (widget.header != null)
          SliverPadding(
            padding: headerPadding,
            sliver: SliverToBoxAdapter(child: widget.header),
          ),
        SliverPadding(
          padding: listPadding,
          sliver: SliverReorderableList(
            itemBuilder: _itemBuilder,
            itemExtent: widget.itemExtent,
            itemExtentBuilder: widget.itemExtentBuilder,
            prototypeItem: widget.prototypeItem,
            itemCount: widget.itemCount,
            onReorder: widget.onReorder,
            onReorderStart: widget.onReorderStart,
            onReorderEnd: widget.onReorderEnd,
            proxyDecorator: widget.proxyDecorator ?? _proxyDecorator,
            autoScrollerVelocityScalar: widget.autoScrollerVelocityScalar,
          ),
        ),
        if (widget.footer != null)
          SliverPadding(
            padding: footerPadding,
            sliver: SliverToBoxAdapter(child: widget.footer),
          ),
      ],
    );
  }
}

// A global key that takes its identity from the object and uses a value of a
// particular type to identify itself.
//
// The difference with GlobalObjectKey is that it uses [==] instead of [identical]
// of the objects used to generate widgets.
@optionalTypeArgs
class _ReorderableListViewChildGlobalKey extends GlobalObjectKey {
  const _ReorderableListViewChildGlobalKey(this.subKey, this.state)
      : super(subKey);

  final Key subKey;
  final State state;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is _ReorderableListViewChildGlobalKey &&
        other.subKey == subKey &&
        other.state == state;
  }

  @override
  int get hashCode => Object.hash(subKey, state);
}
