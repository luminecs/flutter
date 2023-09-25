// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';

import 'basic.dart';
import 'framework.dart';
import 'media_query.dart';
import 'scroll_controller.dart';
import 'scroll_delegate.dart';
import 'scroll_physics.dart';
import 'scroll_view.dart';
import 'sliver.dart';
import 'ticker_provider.dart';

class AnimatedList extends _AnimatedScrollView {
  const AnimatedList({
    super.key,
    required super.itemBuilder,
    super.initialItemCount = 0,
    super.scrollDirection = Axis.vertical,
    super.reverse = false,
    super.controller,
    super.primary,
    super.physics,
    super.shrinkWrap = false,
    super.padding,
    super.clipBehavior = Clip.hardEdge,
  }) : assert(initialItemCount >= 0);

  static AnimatedListState of(BuildContext context) {
    final AnimatedListState? result = AnimatedList.maybeOf(context);
    assert(() {
      if (result == null) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('AnimatedList.of() called with a context that does not contain an AnimatedList.'),
          ErrorDescription(
            'No AnimatedList ancestor could be found starting from the context that was passed to AnimatedList.of().',
          ),
          ErrorHint(
            'This can happen when the context provided is from the same StatefulWidget that '
                'built the AnimatedList. Please see the AnimatedList documentation for examples '
                'of how to refer to an AnimatedListState object:\n'
                '  https://api.flutter.dev/flutter/widgets/AnimatedListState-class.html',
          ),
          context.describeElement('The context used was'),
        ]);
      }
      return true;
    }());
    return result!;
  }

  static AnimatedListState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<AnimatedListState>();
  }

  @override
  AnimatedListState createState() => AnimatedListState();
}

class AnimatedListState extends _AnimatedScrollViewState<AnimatedList> {

  @override
  Widget build(BuildContext context) {
    return _wrap(
      SliverAnimatedList(
        key: _sliverAnimatedMultiBoxKey,
        itemBuilder: widget.itemBuilder,
        initialItemCount: widget.initialItemCount,
      ),
      widget.scrollDirection,
    );
  }
}

class AnimatedGrid extends _AnimatedScrollView {
  const AnimatedGrid({
    super.key,
    required super.itemBuilder,
    required this.gridDelegate,
    super.initialItemCount = 0,
    super.scrollDirection = Axis.vertical,
    super.reverse = false,
    super.controller,
    super.primary,
    super.physics,
    super.padding,
    super.clipBehavior = Clip.hardEdge,
  })  : assert(initialItemCount >= 0);

  final SliverGridDelegate gridDelegate;

  static AnimatedGridState of(BuildContext context) {
    final AnimatedGridState? result = AnimatedGrid.maybeOf(context);
    assert(() {
      if (result == null) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('AnimatedGrid.of() called with a context that does not contain an AnimatedGrid.'),
          ErrorDescription(
            'No AnimatedGrid ancestor could be found starting from the context that was passed to AnimatedGrid.of().',
          ),
          ErrorHint(
            'This can happen when the context provided is from the same StatefulWidget that '
            'built the AnimatedGrid. Please see the AnimatedGrid documentation for examples '
            'of how to refer to an AnimatedGridState object:\n'
            '  https://api.flutter.dev/flutter/widgets/AnimatedGridState-class.html',
          ),
          context.describeElement('The context used was'),
        ]);
      }
      return true;
    }());
    return result!;
  }

  static AnimatedGridState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<AnimatedGridState>();
  }

  @override
  AnimatedGridState createState() => AnimatedGridState();
}

class AnimatedGridState extends _AnimatedScrollViewState<AnimatedGrid> {

  @override
  Widget build(BuildContext context) {
    return _wrap(
      SliverAnimatedGrid(
        key: _sliverAnimatedMultiBoxKey,
        gridDelegate: widget.gridDelegate,
        itemBuilder: widget.itemBuilder,
        initialItemCount: widget.initialItemCount,
      ),
      widget.scrollDirection,
    );
  }
}

abstract class _AnimatedScrollView extends StatefulWidget {
  const _AnimatedScrollView({
    super.key,
    required this.itemBuilder,
    this.initialItemCount = 0,
    this.scrollDirection = Axis.vertical,
    this.reverse = false,
    this.controller,
    this.primary,
    this.physics,
    this.shrinkWrap = false,
    this.padding,
    this.clipBehavior = Clip.hardEdge,
  }) : assert(initialItemCount >= 0);

  final AnimatedItemBuilder itemBuilder;

  final int initialItemCount;

  final Axis scrollDirection;

  final bool reverse;

  final ScrollController? controller;

  final bool? primary;

  final ScrollPhysics? physics;

  final bool shrinkWrap;

  final EdgeInsetsGeometry? padding;

  final Clip clipBehavior;
}

abstract class _AnimatedScrollViewState<T extends _AnimatedScrollView> extends State<T> with TickerProviderStateMixin {
  final GlobalKey<_SliverAnimatedMultiBoxAdaptorState<_SliverAnimatedMultiBoxAdaptor>> _sliverAnimatedMultiBoxKey = GlobalKey();

  void insertItem(int index, { Duration duration = _kDuration }) {
    _sliverAnimatedMultiBoxKey.currentState!.insertItem(index, duration: duration);
  }

  void insertAllItems(int index, int length, { Duration duration = _kDuration, bool isAsync = false }) {
    _sliverAnimatedMultiBoxKey.currentState!.insertAllItems(index, length, duration: duration);
  }

  void removeItem(int index, AnimatedRemovedItemBuilder builder, { Duration duration = _kDuration }) {
    _sliverAnimatedMultiBoxKey.currentState!.removeItem(index, builder, duration: duration);
  }

  void removeAllItems(AnimatedRemovedItemBuilder builder, { Duration duration = _kDuration }) {
    _sliverAnimatedMultiBoxKey.currentState!.removeAllItems(builder, duration: duration);
  }

  Widget _wrap(Widget sliver, Axis direction) {
    EdgeInsetsGeometry? effectivePadding = widget.padding;
    if (widget.padding == null) {
      final MediaQueryData? mediaQuery = MediaQuery.maybeOf(context);
      if (mediaQuery != null) {
        // Automatically pad sliver with padding from MediaQuery.
        final EdgeInsets mediaQueryHorizontalPadding =
            mediaQuery.padding.copyWith(top: 0.0, bottom: 0.0);
        final EdgeInsets mediaQueryVerticalPadding =
            mediaQuery.padding.copyWith(left: 0.0, right: 0.0);
        // Consume the main axis padding with SliverPadding.
        effectivePadding = direction == Axis.vertical
            ? mediaQueryVerticalPadding
            : mediaQueryHorizontalPadding;
        // Leave behind the cross axis padding.
        sliver = MediaQuery(
          data: mediaQuery.copyWith(
            padding: direction == Axis.vertical
                ? mediaQueryHorizontalPadding
                : mediaQueryVerticalPadding,
          ),
          child: sliver,
        );
      }
    }

    if (effectivePadding != null) {
      sliver = SliverPadding(padding: effectivePadding, sliver: sliver);
    }
    return CustomScrollView(
      scrollDirection: widget.scrollDirection,
      reverse: widget.reverse,
      controller: widget.controller,
      primary: widget.primary,
      physics: widget.physics,
      clipBehavior: widget.clipBehavior,
      shrinkWrap: widget.shrinkWrap,
      slivers: <Widget>[ sliver ],
    );
  }
}

@Deprecated(
  'Use AnimatedItemBuilder instead. '
  'This feature was deprecated after v3.5.0-4.0.pre.',
)
typedef AnimatedListItemBuilder = Widget Function(BuildContext context, int index, Animation<double> animation);

typedef AnimatedItemBuilder = Widget Function(BuildContext context, int index, Animation<double> animation);

@Deprecated(
  'Use AnimatedRemovedItemBuilder instead. '
  'This feature was deprecated after v3.5.0-4.0.pre.',
)
typedef AnimatedListRemovedItemBuilder = Widget Function(BuildContext context, Animation<double> animation);

typedef AnimatedRemovedItemBuilder = Widget Function(BuildContext context, Animation<double> animation);

// The default insert/remove animation duration.
const Duration _kDuration = Duration(milliseconds: 300);

// Incoming and outgoing animated items.
class _ActiveItem implements Comparable<_ActiveItem> {
  _ActiveItem.incoming(this.controller, this.itemIndex) : removedItemBuilder = null;
  _ActiveItem.outgoing(this.controller, this.itemIndex, this.removedItemBuilder);
  _ActiveItem.index(this.itemIndex)
      : controller = null,
        removedItemBuilder = null;

  final AnimationController? controller;
  final AnimatedRemovedItemBuilder? removedItemBuilder;
  int itemIndex;

  @override
  int compareTo(_ActiveItem other) => itemIndex - other.itemIndex;
}

class SliverAnimatedList extends _SliverAnimatedMultiBoxAdaptor {
  const SliverAnimatedList({
    super.key,
    required super.itemBuilder,
    super.findChildIndexCallback,
    super.initialItemCount = 0,
  }) : assert(initialItemCount >= 0);

  @override
  SliverAnimatedListState createState() => SliverAnimatedListState();

  static SliverAnimatedListState of(BuildContext context) {
    final SliverAnimatedListState? result = SliverAnimatedList.maybeOf(context);
    assert(() {
      if (result == null) {
        throw FlutterError(
          'SliverAnimatedList.of() called with a context that does not contain a SliverAnimatedList.\n'
              'No SliverAnimatedListState ancestor could be found starting from the '
              'context that was passed to SliverAnimatedListState.of(). This can '
              'happen when the context provided is from the same StatefulWidget that '
              'built the AnimatedList. Please see the SliverAnimatedList documentation '
              'for examples of how to refer to an AnimatedListState object: '
              'https://api.flutter.dev/flutter/widgets/SliverAnimatedListState-class.html\n'
              'The context used was:\n'
              '  $context',
        );
      }
      return true;
    }());
    return result!;
  }

  static SliverAnimatedListState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<SliverAnimatedListState>();
  }
}

class SliverAnimatedListState extends _SliverAnimatedMultiBoxAdaptorState<SliverAnimatedList> {

  @override
  Widget build(BuildContext context) {
    return SliverList(
      delegate: _createDelegate(),
    );
  }
}

class SliverAnimatedGrid extends _SliverAnimatedMultiBoxAdaptor {
  const SliverAnimatedGrid({
    super.key,
    required super.itemBuilder,
    required this.gridDelegate,
    super.findChildIndexCallback,
    super.initialItemCount = 0,
  })  : assert(initialItemCount >= 0);

  @override
  SliverAnimatedGridState createState() => SliverAnimatedGridState();

  final SliverGridDelegate gridDelegate;

  static SliverAnimatedGridState of(BuildContext context) {
    final SliverAnimatedGridState? result = context.findAncestorStateOfType<SliverAnimatedGridState>();
    assert(() {
      if (result == null) {
        throw FlutterError(
          'SliverAnimatedGrid.of() called with a context that does not contain a SliverAnimatedGrid.\n'
          'No SliverAnimatedGridState ancestor could be found starting from the '
          'context that was passed to SliverAnimatedGridState.of(). This can '
          'happen when the context provided is from the same StatefulWidget that '
          'built the AnimatedGrid. Please see the SliverAnimatedGrid documentation '
          'for examples of how to refer to an AnimatedGridState object: '
          'https://api.flutter.dev/flutter/widgets/SliverAnimatedGridState-class.html\n'
          'The context used was:\n'
          '  $context',
        );
      }
      return true;
    }());
    return result!;
  }

  static SliverAnimatedGridState? maybeOf(BuildContext context) {
    return context.findAncestorStateOfType<SliverAnimatedGridState>();
  }
}

class SliverAnimatedGridState extends _SliverAnimatedMultiBoxAdaptorState<SliverAnimatedGrid> {

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: widget.gridDelegate,
      delegate: _createDelegate(),
    );
  }
}

abstract class _SliverAnimatedMultiBoxAdaptor extends StatefulWidget {
  const _SliverAnimatedMultiBoxAdaptor({
    super.key,
    required this.itemBuilder,
    this.findChildIndexCallback,
    this.initialItemCount = 0,
  })  : assert(initialItemCount >= 0);

  final AnimatedItemBuilder itemBuilder;

  final ChildIndexGetter? findChildIndexCallback;

  final int initialItemCount;
}

abstract class _SliverAnimatedMultiBoxAdaptorState<T extends _SliverAnimatedMultiBoxAdaptor> extends State<T> with TickerProviderStateMixin {

  @override
  void initState() {
    super.initState();
    _itemsCount = widget.initialItemCount;
  }

  @override
  void dispose() {
    for (final _ActiveItem item in _incomingItems.followedBy(_outgoingItems)) {
      item.controller!.dispose();
    }
    super.dispose();
  }

  final List<_ActiveItem> _incomingItems = <_ActiveItem>[];
  final List<_ActiveItem> _outgoingItems = <_ActiveItem>[];
  int _itemsCount = 0;

  _ActiveItem? _removeActiveItemAt(List<_ActiveItem> items, int itemIndex) {
    final int i = binarySearch(items, _ActiveItem.index(itemIndex));
    return i == -1 ? null : items.removeAt(i);
  }

  _ActiveItem? _activeItemAt(List<_ActiveItem> items, int itemIndex) {
    final int i = binarySearch(items, _ActiveItem.index(itemIndex));
    return i == -1 ? null : items[i];
  }

  // The insertItem() and removeItem() index parameters are defined as if the
  // removeItem() operation removed the corresponding list/grid entry
  // immediately. The entry is only actually removed from the
  // ListView/GridView when the remove animation finishes. The entry is added
  // to _outgoingItems when removeItem is called and removed from
  // _outgoingItems when the remove animation finishes.

  int _indexToItemIndex(int index) {
    int itemIndex = index;
    for (final _ActiveItem item in _outgoingItems) {
      if (item.itemIndex <= itemIndex) {
        itemIndex += 1;
      } else {
        break;
      }
    }
    return itemIndex;
  }

  int _itemIndexToIndex(int itemIndex) {
    int index = itemIndex;
    for (final _ActiveItem item in _outgoingItems) {
      assert(item.itemIndex != itemIndex);
      if (item.itemIndex < itemIndex) {
        index -= 1;
      } else {
        break;
      }
    }
    return index;
  }

  SliverChildDelegate _createDelegate() {
    return SliverChildBuilderDelegate(
      _itemBuilder,
      childCount: _itemsCount,
      findChildIndexCallback: widget.findChildIndexCallback == null
          ? null
          : (Key key) {
        final int? index = widget.findChildIndexCallback!(key);
        return index != null ? _indexToItemIndex(index) : null;
      },
    );
  }

  Widget _itemBuilder(BuildContext context, int itemIndex) {
    final _ActiveItem? outgoingItem = _activeItemAt(_outgoingItems, itemIndex);
    if (outgoingItem != null) {
      return outgoingItem.removedItemBuilder!(
        context,
        outgoingItem.controller!.view,
      );
    }

    final _ActiveItem? incomingItem = _activeItemAt(_incomingItems, itemIndex);
    final Animation<double> animation = incomingItem?.controller?.view ?? kAlwaysCompleteAnimation;
    return widget.itemBuilder(
      context,
      _itemIndexToIndex(itemIndex),
      animation,
    );
  }

  void insertItem(int index, { Duration duration = _kDuration }) {
    assert(index >= 0);

    final int itemIndex = _indexToItemIndex(index);
    assert(itemIndex >= 0 && itemIndex <= _itemsCount);

    // Increment the incoming and outgoing item indices to account
    // for the insertion.
    for (final _ActiveItem item in _incomingItems) {
      if (item.itemIndex >= itemIndex) {
        item.itemIndex += 1;
      }
    }
    for (final _ActiveItem item in _outgoingItems) {
      if (item.itemIndex >= itemIndex) {
        item.itemIndex += 1;
      }
    }

    final AnimationController controller = AnimationController(
      duration: duration,
      vsync: this,
    );
    final _ActiveItem incomingItem = _ActiveItem.incoming(
      controller,
      itemIndex,
    );
    setState(() {
      _incomingItems
        ..add(incomingItem)
        ..sort();
      _itemsCount += 1;
    });

    controller.forward().then<void>((_) {
      _removeActiveItemAt(_incomingItems, incomingItem.itemIndex)!.controller!.dispose();
    });
  }

  void insertAllItems(int index, int length, { Duration duration = _kDuration }) {
    for (int i = 0; i < length; i++) {
      insertItem(index + i, duration: duration);
    }
  }

  void removeItem(int index, AnimatedRemovedItemBuilder builder, { Duration duration = _kDuration }) {
    assert(index >= 0);

    final int itemIndex = _indexToItemIndex(index);
    assert(itemIndex >= 0 && itemIndex < _itemsCount);
    assert(_activeItemAt(_outgoingItems, itemIndex) == null);

    final _ActiveItem? incomingItem = _removeActiveItemAt(_incomingItems, itemIndex);
    final AnimationController controller =
        incomingItem?.controller ?? AnimationController(duration: duration, value: 1.0, vsync: this);
    final _ActiveItem outgoingItem = _ActiveItem.outgoing(controller, itemIndex, builder);
    setState(() {
      _outgoingItems
        ..add(outgoingItem)
        ..sort();
    });

    controller.reverse().then<void>((void value) {
      _removeActiveItemAt(_outgoingItems, outgoingItem.itemIndex)!.controller!.dispose();

      // Decrement the incoming and outgoing item indices to account
      // for the removal.
      for (final _ActiveItem item in _incomingItems) {
        if (item.itemIndex > outgoingItem.itemIndex) {
          item.itemIndex -= 1;
        }
      }
      for (final _ActiveItem item in _outgoingItems) {
        if (item.itemIndex > outgoingItem.itemIndex) {
          item.itemIndex -= 1;
        }
      }

      setState(() => _itemsCount -= 1);
    });
  }

  void removeAllItems(AnimatedRemovedItemBuilder builder, { Duration duration = _kDuration }) {
    for (int i = _itemsCount - 1 ; i >= 0; i--) {
      removeItem(i, builder, duration: duration);
    }
  }
}