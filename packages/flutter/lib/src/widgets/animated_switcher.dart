import 'package:flutter/foundation.dart';

import 'basic.dart';
import 'framework.dart';
import 'ticker_provider.dart';
import 'transitions.dart';

// Internal representation of a child that, now or in the past, was set on the
// AnimatedSwitcher.child field, but is now in the process of
// transitioning. The internal representation includes fields that we don't want
// to expose to the public API (like the controller).
class _ChildEntry {
  _ChildEntry({
    required this.controller,
    required this.animation,
    required this.transition,
    required this.widgetChild,
  });

  // The animation controller for the child's transition.
  final AnimationController controller;

  // The (curved) animation being used to drive the transition.
  final Animation<double> animation;

  // The currently built transition for this child.
  Widget transition;

  // The widget's child at the time this entry was created or updated.
  // Used to rebuild the transition if necessary.
  Widget widgetChild;

  @override
  String toString() => 'Entry#${shortHash(this)}($widgetChild)';
}

typedef AnimatedSwitcherTransitionBuilder = Widget Function(
    Widget child, Animation<double> animation);

typedef AnimatedSwitcherLayoutBuilder = Widget Function(
    Widget? currentChild, List<Widget> previousChildren);

class AnimatedSwitcher extends StatefulWidget {
  const AnimatedSwitcher({
    super.key,
    this.child,
    required this.duration,
    this.reverseDuration,
    this.switchInCurve = Curves.linear,
    this.switchOutCurve = Curves.linear,
    this.transitionBuilder = AnimatedSwitcher.defaultTransitionBuilder,
    this.layoutBuilder = AnimatedSwitcher.defaultLayoutBuilder,
  });

  final Widget? child;

  final Duration duration;

  final Duration? reverseDuration;

  final Curve switchInCurve;

  final Curve switchOutCurve;

  final AnimatedSwitcherTransitionBuilder transitionBuilder;

  final AnimatedSwitcherLayoutBuilder layoutBuilder;

  @override
  State<AnimatedSwitcher> createState() => _AnimatedSwitcherState();

  static Widget defaultTransitionBuilder(
      Widget child, Animation<double> animation) {
    return FadeTransition(
      key: ValueKey<Key?>(child.key),
      opacity: animation,
      child: child,
    );
  }

  static Widget defaultLayoutBuilder(
      Widget? currentChild, List<Widget> previousChildren) {
    return Stack(
      alignment: Alignment.center,
      children: <Widget>[
        ...previousChildren,
        if (currentChild != null) currentChild,
      ],
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties
        .add(IntProperty('duration', duration.inMilliseconds, unit: 'ms'));
    properties.add(IntProperty(
        'reverseDuration', reverseDuration?.inMilliseconds,
        unit: 'ms', defaultValue: null));
  }
}

class _AnimatedSwitcherState extends State<AnimatedSwitcher>
    with TickerProviderStateMixin {
  _ChildEntry? _currentEntry;
  final Set<_ChildEntry> _outgoingEntries = <_ChildEntry>{};
  List<Widget>? _outgoingWidgets = const <Widget>[];
  int _childNumber = 0;

  @override
  void initState() {
    super.initState();
    _addEntryForNewChild(animate: false);
  }

  @override
  void didUpdateWidget(AnimatedSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the transition builder changed, then update all of the previous
    // transitions.
    if (widget.transitionBuilder != oldWidget.transitionBuilder) {
      _outgoingEntries.forEach(_updateTransitionForEntry);
      if (_currentEntry != null) {
        _updateTransitionForEntry(_currentEntry!);
      }
      _markChildWidgetCacheAsDirty();
    }

    final bool hasNewChild = widget.child != null;
    final bool hasOldChild = _currentEntry != null;
    if (hasNewChild != hasOldChild ||
        hasNewChild &&
            !Widget.canUpdate(widget.child!, _currentEntry!.widgetChild)) {
      // Child has changed, fade current entry out and add new entry.
      _childNumber += 1;
      _addEntryForNewChild(animate: true);
    } else if (_currentEntry != null) {
      assert(hasOldChild && hasNewChild);
      assert(Widget.canUpdate(widget.child!, _currentEntry!.widgetChild));
      // Child has been updated. Make sure we update the child widget and
      // transition in _currentEntry even though we're not going to start a new
      // animation, but keep the key from the previous transition so that we
      // update the transition instead of replacing it.
      _currentEntry!.widgetChild = widget.child!;
      _updateTransitionForEntry(_currentEntry!); // uses entry.widgetChild
      _markChildWidgetCacheAsDirty();
    }
  }

  void _addEntryForNewChild({required bool animate}) {
    assert(animate || _currentEntry == null);
    if (_currentEntry != null) {
      assert(animate);
      assert(!_outgoingEntries.contains(_currentEntry));
      _outgoingEntries.add(_currentEntry!);
      _currentEntry!.controller.reverse();
      _markChildWidgetCacheAsDirty();
      _currentEntry = null;
    }
    if (widget.child == null) {
      return;
    }
    final AnimationController controller = AnimationController(
      duration: widget.duration,
      reverseDuration: widget.reverseDuration,
      vsync: this,
    );
    final Animation<double> animation = CurvedAnimation(
      parent: controller,
      curve: widget.switchInCurve,
      reverseCurve: widget.switchOutCurve,
    );
    _currentEntry = _newEntry(
      child: widget.child!,
      controller: controller,
      animation: animation,
      builder: widget.transitionBuilder,
    );
    if (animate) {
      controller.forward();
    } else {
      assert(_outgoingEntries.isEmpty);
      controller.value = 1.0;
    }
  }

  _ChildEntry _newEntry({
    required Widget child,
    required AnimatedSwitcherTransitionBuilder builder,
    required AnimationController controller,
    required Animation<double> animation,
  }) {
    final _ChildEntry entry = _ChildEntry(
      widgetChild: child,
      transition: KeyedSubtree.wrap(builder(child, animation), _childNumber),
      animation: animation,
      controller: controller,
    );
    animation.addStatusListener((AnimationStatus status) {
      if (status == AnimationStatus.dismissed) {
        setState(() {
          assert(mounted);
          assert(_outgoingEntries.contains(entry));
          _outgoingEntries.remove(entry);
          _markChildWidgetCacheAsDirty();
        });
        controller.dispose();
      }
    });
    return entry;
  }

  void _markChildWidgetCacheAsDirty() {
    _outgoingWidgets = null;
  }

  void _updateTransitionForEntry(_ChildEntry entry) {
    entry.transition = KeyedSubtree(
      key: entry.transition.key,
      child: widget.transitionBuilder(entry.widgetChild, entry.animation),
    );
  }

  void _rebuildOutgoingWidgetsIfNeeded() {
    _outgoingWidgets ??= List<Widget>.unmodifiable(
      _outgoingEntries.map<Widget>((_ChildEntry entry) => entry.transition),
    );
    assert(_outgoingEntries.length == _outgoingWidgets!.length);
    assert(_outgoingEntries.isEmpty ||
        _outgoingEntries.last.transition == _outgoingWidgets!.last);
  }

  @override
  void dispose() {
    if (_currentEntry != null) {
      _currentEntry!.controller.dispose();
    }
    for (final _ChildEntry entry in _outgoingEntries) {
      entry.controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _rebuildOutgoingWidgetsIfNeeded();
    return widget.layoutBuilder(
        _currentEntry?.transition,
        _outgoingWidgets!
            .where((Widget outgoing) =>
                outgoing.key != _currentEntry?.transition.key)
            .toSet()
            .toList());
  }
}
