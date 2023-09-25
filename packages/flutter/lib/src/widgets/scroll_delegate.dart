
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'automatic_keep_alive.dart';
import 'basic.dart';
import 'framework.dart';
import 'selection_container.dart';
import 'two_dimensional_viewport.dart';

export 'package:flutter/rendering.dart' show
  SliverGridDelegate,
  SliverGridDelegateWithFixedCrossAxisCount,
  SliverGridDelegateWithMaxCrossAxisExtent;

// Examples can assume:
// late SliverGridDelegateWithMaxCrossAxisExtent _gridDelegate;
// abstract class SomeWidget extends StatefulWidget { const SomeWidget({super.key}); }
// typedef ChildWidget = Placeholder;

typedef SemanticIndexCallback = int? Function(Widget widget, int localIndex);

int _kDefaultSemanticIndexCallback(Widget _, int localIndex) => localIndex;

abstract class SliverChildDelegate {
  const SliverChildDelegate();

  Widget? build(BuildContext context, int index);

  int? get estimatedChildCount => null;

  double? estimateMaxScrollOffset(
    int firstIndex,
    int lastIndex,
    double leadingScrollOffset,
    double trailingScrollOffset,
  ) => null;

  void didFinishLayout(int firstIndex, int lastIndex) { }

  bool shouldRebuild(covariant SliverChildDelegate oldDelegate);

  int? findIndexByKey(Key key) => null;

  @override
  String toString() {
    final List<String> description = <String>[];
    debugFillDescription(description);
    return '${describeIdentity(this)}(${description.join(", ")})';
  }

  @protected
  @mustCallSuper
  void debugFillDescription(List<String> description) {
    try {
      final int? children = estimatedChildCount;
      if (children != null) {
        description.add('estimated child count: $children');
      }
    } catch (e) {
      // The exception is forwarded to widget inspector.
      description.add('estimated child count: EXCEPTION (${e.runtimeType})');
    }
  }
}

class _SaltedValueKey extends ValueKey<Key> {
  const _SaltedValueKey(super.value);
}

typedef ChildIndexGetter = int? Function(Key key);

class SliverChildBuilderDelegate extends SliverChildDelegate {
  const SliverChildBuilderDelegate(
    this.builder, {
    this.findChildIndexCallback,
    this.childCount,
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.semanticIndexCallback = _kDefaultSemanticIndexCallback,
    this.semanticIndexOffset = 0,
  });

  final NullableIndexedWidgetBuilder builder;

  final int? childCount;

  final bool addAutomaticKeepAlives;

  final bool addRepaintBoundaries;

  final bool addSemanticIndexes;

  final int semanticIndexOffset;

  final SemanticIndexCallback semanticIndexCallback;

  final ChildIndexGetter? findChildIndexCallback;

  @override
  int? findIndexByKey(Key key) {
    if (findChildIndexCallback == null) {
      return null;
    }
    final Key childKey;
    if (key is _SaltedValueKey) {
      final _SaltedValueKey saltedValueKey = key;
      childKey = saltedValueKey.value;
    } else {
      childKey = key;
    }
    return findChildIndexCallback!(childKey);
  }

  @override
  @pragma('vm:notify-debugger-on-exception')
  Widget? build(BuildContext context, int index) {
    if (index < 0 || (childCount != null && index >= childCount!)) {
      return null;
    }
    Widget? child;
    try {
      child = builder(context, index);
    } catch (exception, stackTrace) {
      child = _createErrorWidget(exception, stackTrace);
    }
    if (child == null) {
      return null;
    }
    final Key? key = child.key != null ? _SaltedValueKey(child.key!) : null;
    if (addRepaintBoundaries) {
      child = RepaintBoundary(child: child);
    }
    if (addSemanticIndexes) {
      final int? semanticIndex = semanticIndexCallback(child, index);
      if (semanticIndex != null) {
        child = IndexedSemantics(index: semanticIndex + semanticIndexOffset, child: child);
      }
    }
    if (addAutomaticKeepAlives) {
      child = AutomaticKeepAlive(child: _SelectionKeepAlive(child: child));
    }
    return KeyedSubtree(key: key, child: child);
  }

  @override
  int? get estimatedChildCount => childCount;

  @override
  bool shouldRebuild(covariant SliverChildBuilderDelegate oldDelegate) => true;
}

class SliverChildListDelegate extends SliverChildDelegate {
  SliverChildListDelegate(
    this.children, {
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.semanticIndexCallback = _kDefaultSemanticIndexCallback,
    this.semanticIndexOffset = 0,
  }) : _keyToIndex = <Key?, int>{null: 0};

  const SliverChildListDelegate.fixed(
    this.children, {
    this.addAutomaticKeepAlives = true,
    this.addRepaintBoundaries = true,
    this.addSemanticIndexes = true,
    this.semanticIndexCallback = _kDefaultSemanticIndexCallback,
    this.semanticIndexOffset = 0,
  }) : _keyToIndex = null;

  final bool addAutomaticKeepAlives;

  final bool addRepaintBoundaries;

  final bool addSemanticIndexes;

  final int semanticIndexOffset;

  final SemanticIndexCallback semanticIndexCallback;

  final List<Widget> children;

  final Map<Key?, int>? _keyToIndex;

  bool get _isConstantInstance => _keyToIndex == null;

  int? _findChildIndex(Key key) {
    if (_isConstantInstance) {
      return null;
    }
    // Lazily fill the [_keyToIndex].
    if (!_keyToIndex!.containsKey(key)) {
      int index = _keyToIndex[null]!;
      while (index < children.length) {
        final Widget child = children[index];
        if (child.key != null) {
          _keyToIndex[child.key] = index;
        }
        if (child.key == key) {
          // Record current index for next function call.
          _keyToIndex[null] = index + 1;
          return index;
        }
        index += 1;
      }
      _keyToIndex[null] = index;
    } else {
      return _keyToIndex[key];
    }
    return null;
  }

  @override
  int? findIndexByKey(Key key) {
    final Key childKey;
    if (key is _SaltedValueKey) {
      final _SaltedValueKey saltedValueKey = key;
      childKey = saltedValueKey.value;
    } else {
      childKey = key;
    }
    return _findChildIndex(childKey);
  }

  @override
  Widget? build(BuildContext context, int index) {
    if (index < 0 || index >= children.length) {
      return null;
    }
    Widget child = children[index];
    final Key? key = child.key != null? _SaltedValueKey(child.key!) : null;
    if (addRepaintBoundaries) {
      child = RepaintBoundary(child: child);
    }
    if (addSemanticIndexes) {
      final int? semanticIndex = semanticIndexCallback(child, index);
      if (semanticIndex != null) {
        child = IndexedSemantics(index: semanticIndex + semanticIndexOffset, child: child);
      }
    }
    if (addAutomaticKeepAlives) {
      child = AutomaticKeepAlive(child: _SelectionKeepAlive(child: child));
    }

    return KeyedSubtree(key: key, child: child);
  }

  @override
  int? get estimatedChildCount => children.length;

  @override
  bool shouldRebuild(covariant SliverChildListDelegate oldDelegate) {
    return children != oldDelegate.children;
  }
}

class _SelectionKeepAlive extends StatefulWidget {
  const _SelectionKeepAlive({
    required this.child,
  });

  final Widget child;

  @override
  State<_SelectionKeepAlive> createState() => _SelectionKeepAliveState();
}

class _SelectionKeepAliveState extends State<_SelectionKeepAlive> with AutomaticKeepAliveClientMixin implements SelectionRegistrar {
  Set<Selectable>? _selectablesWithSelections;
  Map<Selectable, VoidCallback>? _selectableAttachments;
  SelectionRegistrar? _registrar;

  @override
  bool get wantKeepAlive => _wantKeepAlive;
  bool _wantKeepAlive = false;
  set wantKeepAlive(bool value) {
    if (_wantKeepAlive != value) {
      _wantKeepAlive = value;
      updateKeepAlive();
    }
  }

  VoidCallback listensTo(Selectable selectable) {
    return () {
      if (selectable.value.hasSelection) {
        _updateSelectablesWithSelections(selectable, add: true);
      } else {
        _updateSelectablesWithSelections(selectable, add: false);
      }
    };
  }

  void _updateSelectablesWithSelections(Selectable selectable, {required bool add}) {
    if (add) {
      assert(selectable.value.hasSelection);
      _selectablesWithSelections ??= <Selectable>{};
      _selectablesWithSelections!.add(selectable);
    } else {
      _selectablesWithSelections?.remove(selectable);
    }
    wantKeepAlive = _selectablesWithSelections?.isNotEmpty ?? false;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final SelectionRegistrar? newRegistrar = SelectionContainer.maybeOf(context);
    if (_registrar != newRegistrar) {
      if (_registrar != null) {
        _selectableAttachments?.keys.forEach(_registrar!.remove);
      }
      _registrar = newRegistrar;
      if (_registrar != null) {
        _selectableAttachments?.keys.forEach(_registrar!.add);
      }
    }
  }

  @override
  void add(Selectable selectable) {
    final VoidCallback attachment = listensTo(selectable);
    selectable.addListener(attachment);
    _selectableAttachments ??= <Selectable, VoidCallback>{};
    _selectableAttachments![selectable] = attachment;
    _registrar!.add(selectable);
    if (selectable.value.hasSelection) {
      _updateSelectablesWithSelections(selectable, add: true);
    }
  }

  @override
  void remove(Selectable selectable) {
    if (_selectableAttachments == null) {
      return;
    }
    assert(_selectableAttachments!.containsKey(selectable));
    final VoidCallback attachment = _selectableAttachments!.remove(selectable)!;
    selectable.removeListener(attachment);
    _registrar!.remove(selectable);
    _updateSelectablesWithSelections(selectable, add: false);
  }

  @override
  void dispose() {
    if (_selectableAttachments != null) {
      for (final Selectable selectable in _selectableAttachments!.keys) {
        _registrar!.remove(selectable);
        selectable.removeListener(_selectableAttachments![selectable]!);
      }
      _selectableAttachments = null;
    }
    _selectablesWithSelections = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_registrar == null) {
      return widget.child;
    }
    return SelectionRegistrarScope(
      registrar: this,
      child: widget.child,
    );
  }
}

// Return a Widget for the given Exception
Widget _createErrorWidget(Object exception, StackTrace stackTrace) {
  final FlutterErrorDetails details = FlutterErrorDetails(
    exception: exception,
    stack: stackTrace,
    library: 'widgets library',
    context: ErrorDescription('building'),
  );
  FlutterError.reportError(details);
  return ErrorWidget.builder(details);
}

abstract class TwoDimensionalChildDelegate extends ChangeNotifier {
  Widget? build(BuildContext context, ChildVicinity vicinity);

  bool shouldRebuild(covariant TwoDimensionalChildDelegate oldDelegate);
}

class TwoDimensionalChildBuilderDelegate extends TwoDimensionalChildDelegate {
  TwoDimensionalChildBuilderDelegate({
    required this.builder,
    int? maxXIndex,
    int? maxYIndex,
    this.addRepaintBoundaries = true,
    this.addAutomaticKeepAlives = true,
  }) : assert(maxYIndex == null || maxYIndex >= -1),
       assert(maxXIndex == null || maxXIndex >= -1),
       _maxYIndex = maxYIndex,
       _maxXIndex = maxXIndex;

  final TwoDimensionalIndexedWidgetBuilder builder;

  int? get maxXIndex => _maxXIndex;
  int? _maxXIndex;
  set maxXIndex(int? value) {
    if (value == maxXIndex) {
      return;
    }
    assert(value == null || value >= -1);
    _maxXIndex = value;
    notifyListeners();
  }

  int? get maxYIndex => _maxYIndex;
  int? _maxYIndex;
  set maxYIndex(int? value) {
    if (maxYIndex == value) {
      return;
    }
    assert(value == null || value >= -1);
    _maxYIndex = value;
    notifyListeners();
  }

  final bool addRepaintBoundaries;

  final bool addAutomaticKeepAlives;

  @override
  Widget? build(BuildContext context, ChildVicinity vicinity) {
    // If we have exceeded explicit upper bounds, return null.
    if (vicinity.xIndex < 0 || (maxXIndex != null && vicinity.xIndex > maxXIndex!)) {
      return null;
    }
    if (vicinity.yIndex < 0 || (maxYIndex != null && vicinity.yIndex > maxYIndex!)) {
      return null;
    }

    Widget? child;
    try {
      child = builder(context, vicinity);
    } catch (exception, stackTrace) {
      child = _createErrorWidget(exception, stackTrace);
    }
    if (child == null) {
      return null;
    }
    if (addRepaintBoundaries) {
      child = RepaintBoundary(child: child);
    }
    if (addAutomaticKeepAlives) {
      child = AutomaticKeepAlive(child: _SelectionKeepAlive(child: child));
    }
    return child;
  }

  @override
  bool shouldRebuild(covariant TwoDimensionalChildDelegate oldDelegate) => true;
}

class TwoDimensionalChildListDelegate extends TwoDimensionalChildDelegate {
  TwoDimensionalChildListDelegate({
    this.addRepaintBoundaries = true,
    this.addAutomaticKeepAlives = true,
    required this.children,
  });

  final List<List<Widget>> children;

  final bool addRepaintBoundaries;

  final bool addAutomaticKeepAlives;

  @override
  Widget? build(BuildContext context, ChildVicinity vicinity) {
    // If we have exceeded explicit upper bounds, return null.
    if (vicinity.yIndex < 0 || vicinity.yIndex >= children.length) {
      return null;
    }
    if (vicinity.xIndex < 0 || vicinity.xIndex >= children[vicinity.yIndex].length) {
      return null;
    }

    Widget child = children[vicinity.yIndex][vicinity.xIndex];
    if (addRepaintBoundaries) {
      child = RepaintBoundary(child: child);
    }
    if (addAutomaticKeepAlives) {
      child = AutomaticKeepAlive(child: _SelectionKeepAlive(child: child));
    }
    return child;
  }

  @override
  bool shouldRebuild(covariant TwoDimensionalChildListDelegate oldDelegate) {
    return children != oldDelegate.children;
  }
}