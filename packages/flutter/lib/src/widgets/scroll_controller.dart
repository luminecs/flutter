import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import 'scroll_context.dart';
import 'scroll_physics.dart';
import 'scroll_position.dart';
import 'scroll_position_with_single_context.dart';

// Examples can assume:
// TrackingScrollController _trackingScrollController = TrackingScrollController();

typedef ScrollControllerCallback = void Function(ScrollPosition position);

class ScrollController extends ChangeNotifier {
  ScrollController({
    double initialScrollOffset = 0.0,
    this.keepScrollOffset = true,
    this.debugLabel,
    this.onAttach,
    this.onDetach,
  }) : _initialScrollOffset = initialScrollOffset {
    if (kFlutterMemoryAllocationsEnabled) {
      ChangeNotifier.maybeDispatchObjectCreation(this);
    }
  }

  double get initialScrollOffset => _initialScrollOffset;
  final double _initialScrollOffset;

  final bool keepScrollOffset;

  final ScrollControllerCallback? onAttach;

  final ScrollControllerCallback? onDetach;

  final String? debugLabel;

  Iterable<ScrollPosition> get positions => _positions;
  final List<ScrollPosition> _positions = <ScrollPosition>[];

  bool get hasClients => _positions.isNotEmpty;

  ScrollPosition get position {
    assert(_positions.isNotEmpty, 'ScrollController not attached to any scroll views.');
    assert(_positions.length == 1, 'ScrollController attached to multiple scroll views.');
    return _positions.single;
  }

  double get offset => position.pixels;

  Future<void> animateTo(
    double offset, {
    required Duration duration,
    required Curve curve,
  }) async {
    assert(_positions.isNotEmpty, 'ScrollController not attached to any scroll views.');
    await Future.wait<void>(<Future<void>>[
      for (int i = 0; i < _positions.length; i += 1) _positions[i].animateTo(offset, duration: duration, curve: curve),
    ]);
  }

  void jumpTo(double value) {
    assert(_positions.isNotEmpty, 'ScrollController not attached to any scroll views.');
    for (final ScrollPosition position in List<ScrollPosition>.of(_positions)) {
      position.jumpTo(value);
    }
  }

  void attach(ScrollPosition position) {
    assert(!_positions.contains(position));
    _positions.add(position);
    position.addListener(notifyListeners);
    if (onAttach != null) {
      onAttach!(position);
    }
  }

  void detach(ScrollPosition position) {
    assert(_positions.contains(position));
    if (onDetach != null) {
      onDetach!(position);
    }
    position.removeListener(notifyListeners);
    _positions.remove(position);
  }

  @override
  void dispose() {
    for (final ScrollPosition position in _positions) {
      position.removeListener(notifyListeners);
    }
    super.dispose();
  }

  ScrollPosition createScrollPosition(
    ScrollPhysics physics,
    ScrollContext context,
    ScrollPosition? oldPosition,
  ) {
    return ScrollPositionWithSingleContext(
      physics: physics,
      context: context,
      initialPixels: initialScrollOffset,
      keepScrollOffset: keepScrollOffset,
      oldPosition: oldPosition,
      debugLabel: debugLabel,
    );
  }

  @override
  String toString() {
    final List<String> description = <String>[];
    debugFillDescription(description);
    return '${describeIdentity(this)}(${description.join(", ")})';
  }

  @mustCallSuper
  void debugFillDescription(List<String> description) {
    if (debugLabel != null) {
      description.add(debugLabel!);
    }
    if (initialScrollOffset != 0.0) {
      description.add('initialScrollOffset: ${initialScrollOffset.toStringAsFixed(1)}, ');
    }
    if (_positions.isEmpty) {
      description.add('no clients');
    } else if (_positions.length == 1) {
      // Don't actually list the client itself, since its toString may refer to us.
      description.add('one client, offset ${offset.toStringAsFixed(1)}');
    } else {
      description.add('${_positions.length} clients');
    }
  }
}

// Examples can assume:
// TrackingScrollController? _trackingScrollController;

class TrackingScrollController extends ScrollController {
  TrackingScrollController({
    super.initialScrollOffset,
    super.keepScrollOffset,
    super.debugLabel,
  });

  final Map<ScrollPosition, VoidCallback> _positionToListener = <ScrollPosition, VoidCallback>{};
  ScrollPosition? _lastUpdated;
  double? _lastUpdatedOffset;

  ScrollPosition? get mostRecentlyUpdatedPosition => _lastUpdated;

  @override
  double get initialScrollOffset => _lastUpdatedOffset ?? super.initialScrollOffset;

  @override
  void attach(ScrollPosition position) {
    super.attach(position);
    assert(!_positionToListener.containsKey(position));
    _positionToListener[position] = () {
      _lastUpdated = position;
      _lastUpdatedOffset = position.pixels;
    };
    position.addListener(_positionToListener[position]!);
  }

  @override
  void detach(ScrollPosition position) {
    super.detach(position);
    assert(_positionToListener.containsKey(position));
    position.removeListener(_positionToListener[position]!);
    _positionToListener.remove(position);
    if (_lastUpdated == position) {
      _lastUpdated = null;
    }
    if (_positionToListener.isEmpty) {
      _lastUpdatedOffset = null;
    }
  }

  @override
  void dispose() {
    for (final ScrollPosition position in positions) {
      assert(_positionToListener.containsKey(position));
      position.removeListener(_positionToListener[position]!);
    }
    super.dispose();
  }
}