
import 'tween.dart';

export 'tween.dart' show Animatable;

// Examples can assume:
// late AnimationController myAnimationController;

class TweenSequence<T> extends Animatable<T> {
  TweenSequence(List<TweenSequenceItem<T>> items)
      : assert(items.isNotEmpty) {
    _items.addAll(items);

    double totalWeight = 0.0;
    for (final TweenSequenceItem<T> item in _items) {
      totalWeight += item.weight;
    }
    assert(totalWeight > 0.0);

    double start = 0.0;
    for (int i = 0; i < _items.length; i += 1) {
      final double end = i == _items.length - 1 ? 1.0 : start + _items[i].weight / totalWeight;
      _intervals.add(_Interval(start, end));
      start = end;
    }
  }

  final List<TweenSequenceItem<T>> _items = <TweenSequenceItem<T>>[];
  final List<_Interval> _intervals = <_Interval>[];

  T _evaluateAt(double t, int index) {
    final TweenSequenceItem<T> element = _items[index];
    final double tInterval = _intervals[index].value(t);
    return element.tween.transform(tInterval);
  }

  @override
  T transform(double t) {
    assert(t >= 0.0 && t <= 1.0);
    if (t == 1.0) {
      return _evaluateAt(t, _items.length - 1);
    }
    for (int index = 0; index < _items.length; index++) {
      if (_intervals[index].contains(t)) {
        return _evaluateAt(t, index);
      }
    }
    // Should be unreachable.
    throw StateError('TweenSequence.evaluate() could not find an interval for $t');
  }

  @override
  String toString() => 'TweenSequence(${_items.length} items)';
}

class FlippedTweenSequence extends TweenSequence<double> {
  FlippedTweenSequence(super.items);

  @override
  double transform(double t) => 1 - super.transform(1 - t);
}

class TweenSequenceItem<T> {
  const TweenSequenceItem({
    required this.tween,
    required this.weight,
  }) : assert(weight > 0.0);

  final Animatable<T> tween;

  final double weight;
}

class _Interval {
  const _Interval(this.start, this.end) : assert(end > start);

  final double start;
  final double end;

  bool contains(double t) => t >= start && t < end;

  double value(double t) => (t - start) / (end - start);

  @override
  String toString() => '<$start, $end>';
}