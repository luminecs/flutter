import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';

Iterable<Element> collectAllElementsFrom(
  Element rootElement, {
  required bool skipOffstage,
}) {
  return CachingIterable<Element>(
      _DepthFirstElementTreeIterator(rootElement, !skipOffstage));
}

Iterable<SemanticsNode> collectAllSemanticsNodesFrom(
  SemanticsNode root, {
  DebugSemanticsDumpOrder order = DebugSemanticsDumpOrder.traversalOrder,
}) {
  return CachingIterable<SemanticsNode>(
      _DepthFirstSemanticsTreeIterator(root, order));
}

abstract class _DepthFirstTreeIterator<ItemType> implements Iterator<ItemType> {
  _DepthFirstTreeIterator(ItemType root) {
    _fillStack(_collectChildren(root));
  }

  @override
  ItemType get current => _current!;
  late ItemType _current;

  final List<ItemType> _stack = <ItemType>[];

  @override
  bool moveNext() {
    if (_stack.isEmpty) {
      return false;
    }

    _current = _stack.removeLast();
    _fillStack(_collectChildren(_current));
    return true;
  }

  void _fillStack(List<ItemType> children) {
    // We reverse the list of children so we don't have to do use expensive
    // `insert` or `remove` operations, and so the order of the traversal
    // is depth first when built lazily through the iterator.
    //
    // This is faster than `_stack.addAll(children.reversed)`, presumably since
    // we don't actually care about maintaining an iteration pointer.
    while (children.isNotEmpty) {
      _stack.add(children.removeLast());
    }
  }

  List<ItemType> _collectChildren(ItemType root);
}

class _DepthFirstElementTreeIterator extends _DepthFirstTreeIterator<Element> {
  _DepthFirstElementTreeIterator(super.root, this.includeOffstage);

  final bool includeOffstage;

  @override
  List<Element> _collectChildren(Element root) {
    final List<Element> children = <Element>[];
    if (includeOffstage) {
      root.visitChildren(children.add);
    } else {
      root.debugVisitOnstageChildren(children.add);
    }

    return children;
  }
}

class _DepthFirstSemanticsTreeIterator
    extends _DepthFirstTreeIterator<SemanticsNode> {
  _DepthFirstSemanticsTreeIterator(super.root, this.order);

  final DebugSemanticsDumpOrder order;

  @override
  List<SemanticsNode> _collectChildren(SemanticsNode root) {
    return root.debugListChildrenInOrder(order);
  }
}
