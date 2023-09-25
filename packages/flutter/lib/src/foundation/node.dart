
import 'package:meta/meta.dart';

// This file gets mutated by //dev/devicelab/bin/tasks/flutter_test_performance.dart
// during device lab performance tests. When editing this file, check to make sure
// that it didn't break that test.

@Deprecated(
  'If needed, inline any required functionality of AbstractNode in your class directly. '
  'This feature was deprecated after v3.12.0-4.0.pre.',
)
class AbstractNode {
  int get depth => _depth;
  int _depth = 0;

  @protected
  void redepthChild(AbstractNode child) {
    assert(child.owner == owner);
    if (child._depth <= _depth) {
      child._depth = _depth + 1;
      child.redepthChildren();
    }
  }

  void redepthChildren() { }

  Object? get owner => _owner;
  Object? _owner;

  bool get attached => _owner != null;

  @mustCallSuper
  void attach(covariant Object owner) {
    assert(_owner == null);
    _owner = owner;
  }

  @mustCallSuper
  void detach() {
    assert(_owner != null);
    _owner = null;
    assert(parent == null || attached == parent!.attached);
  }

  AbstractNode? get parent => _parent;
  AbstractNode? _parent;

  @protected
  @mustCallSuper
  void adoptChild(covariant AbstractNode child) {
    assert(child._parent == null);
    assert(() {
      AbstractNode node = this;
      while (node.parent != null) {
        node = node.parent!;
      }
      assert(node != child); // indicates we are about to create a cycle
      return true;
    }());
    child._parent = this;
    if (attached) {
      child.attach(_owner!);
    }
    redepthChild(child);
  }

  @protected
  @mustCallSuper
  void dropChild(covariant AbstractNode child) {
    assert(child._parent == this);
    assert(child.attached == attached);
    child._parent = null;
    if (attached) {
      child.detach();
    }
  }
}