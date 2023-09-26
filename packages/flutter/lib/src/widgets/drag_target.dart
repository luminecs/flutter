import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'basic.dart';
import 'binding.dart';
import 'debug.dart';
import 'framework.dart';
import 'media_query.dart';
import 'overlay.dart';
import 'view.dart';

typedef DragTargetWillAccept<T> = bool Function(T? data);

typedef DragTargetWillAcceptWithDetails<T> = bool Function(
    DragTargetDetails<T> details);

typedef DragTargetAccept<T> = void Function(T data);

typedef DragTargetAcceptWithDetails<T> = void Function(
    DragTargetDetails<T> details);

typedef DragTargetBuilder<T> = Widget Function(
    BuildContext context, List<T?> candidateData, List<dynamic> rejectedData);

typedef DragUpdateCallback = void Function(DragUpdateDetails details);

typedef DraggableCanceledCallback = void Function(
    Velocity velocity, Offset offset);

typedef DragEndCallback = void Function(DraggableDetails details);

typedef DragTargetLeave<T> = void Function(T? data);

typedef DragTargetMove<T> = void Function(DragTargetDetails<T> details);

typedef DragAnchorStrategy = Offset Function(
    Draggable<Object> draggable, BuildContext context, Offset position);

Offset childDragAnchorStrategy(
    Draggable<Object> draggable, BuildContext context, Offset position) {
  final RenderBox renderObject = context.findRenderObject()! as RenderBox;
  return renderObject.globalToLocal(position);
}

Offset pointerDragAnchorStrategy(
    Draggable<Object> draggable, BuildContext context, Offset position) {
  return Offset.zero;
}

class Draggable<T extends Object> extends StatefulWidget {
  const Draggable({
    super.key,
    required this.child,
    required this.feedback,
    this.data,
    this.axis,
    this.childWhenDragging,
    this.feedbackOffset = Offset.zero,
    this.dragAnchorStrategy = childDragAnchorStrategy,
    this.affinity,
    this.maxSimultaneousDrags,
    this.onDragStarted,
    this.onDragUpdate,
    this.onDraggableCanceled,
    this.onDragEnd,
    this.onDragCompleted,
    this.ignoringFeedbackSemantics = true,
    this.ignoringFeedbackPointer = true,
    this.rootOverlay = false,
    this.hitTestBehavior = HitTestBehavior.deferToChild,
    this.allowedButtonsFilter,
  }) : assert(maxSimultaneousDrags == null || maxSimultaneousDrags >= 0);

  final T? data;

  final Axis? axis;

  final Widget child;

  final Widget? childWhenDragging;

  final Widget feedback;

  final Offset feedbackOffset;

  final DragAnchorStrategy dragAnchorStrategy;

  final bool ignoringFeedbackSemantics;

  final bool ignoringFeedbackPointer;

  final Axis? affinity;

  final int? maxSimultaneousDrags;

  final VoidCallback? onDragStarted;

  final DragUpdateCallback? onDragUpdate;

  final DraggableCanceledCallback? onDraggableCanceled;

  final VoidCallback? onDragCompleted;

  final DragEndCallback? onDragEnd;

  final bool rootOverlay;

  final HitTestBehavior hitTestBehavior;

  final AllowedButtonsFilter? allowedButtonsFilter;

  @protected
  MultiDragGestureRecognizer createRecognizer(
      GestureMultiDragStartCallback onStart) {
    switch (affinity) {
      case Axis.horizontal:
        return HorizontalMultiDragGestureRecognizer(
            allowedButtonsFilter: allowedButtonsFilter)
          ..onStart = onStart;
      case Axis.vertical:
        return VerticalMultiDragGestureRecognizer(
            allowedButtonsFilter: allowedButtonsFilter)
          ..onStart = onStart;
      case null:
        return ImmediateMultiDragGestureRecognizer(
            allowedButtonsFilter: allowedButtonsFilter)
          ..onStart = onStart;
    }
  }

  @override
  State<Draggable<T>> createState() => _DraggableState<T>();
}

class LongPressDraggable<T extends Object> extends Draggable<T> {
  const LongPressDraggable({
    super.key,
    required super.child,
    required super.feedback,
    super.data,
    super.axis,
    super.childWhenDragging,
    super.feedbackOffset,
    super.dragAnchorStrategy,
    super.maxSimultaneousDrags,
    super.onDragStarted,
    super.onDragUpdate,
    super.onDraggableCanceled,
    super.onDragEnd,
    super.onDragCompleted,
    this.hapticFeedbackOnStart = true,
    super.ignoringFeedbackSemantics,
    super.ignoringFeedbackPointer,
    this.delay = kLongPressTimeout,
    super.allowedButtonsFilter,
  });

  final bool hapticFeedbackOnStart;

  final Duration delay;

  @override
  DelayedMultiDragGestureRecognizer createRecognizer(
      GestureMultiDragStartCallback onStart) {
    return DelayedMultiDragGestureRecognizer(
        delay: delay, allowedButtonsFilter: allowedButtonsFilter)
      ..onStart = (Offset position) {
        final Drag? result = onStart(position);
        if (result != null && hapticFeedbackOnStart) {
          HapticFeedback.selectionClick();
        }
        return result;
      };
  }
}

class _DraggableState<T extends Object> extends State<Draggable<T>> {
  @override
  void initState() {
    super.initState();
    _recognizer = widget.createRecognizer(_startDrag);
  }

  @override
  void dispose() {
    _disposeRecognizerIfInactive();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    _recognizer!.gestureSettings = MediaQuery.maybeGestureSettingsOf(context);
    super.didChangeDependencies();
  }

  // This gesture recognizer has an unusual lifetime. We want to support the use
  // case of removing the Draggable from the tree in the middle of a drag. That
  // means we need to keep this recognizer alive after this state object has
  // been disposed because it's the one listening to the pointer events that are
  // driving the drag.
  //
  // We achieve that by keeping count of the number of active drags and only
  // disposing the gesture recognizer after (a) this state object has been
  // disposed and (b) there are no more active drags.
  GestureRecognizer? _recognizer;
  int _activeCount = 0;

  void _disposeRecognizerIfInactive() {
    if (_activeCount > 0) {
      return;
    }
    _recognizer!.dispose();
    _recognizer = null;
  }

  void _routePointer(PointerDownEvent event) {
    if (widget.maxSimultaneousDrags != null &&
        _activeCount >= widget.maxSimultaneousDrags!) {
      return;
    }
    _recognizer!.addPointer(event);
  }

  _DragAvatar<T>? _startDrag(Offset position) {
    if (widget.maxSimultaneousDrags != null &&
        _activeCount >= widget.maxSimultaneousDrags!) {
      return null;
    }
    final Offset dragStartPoint;
    dragStartPoint = widget.dragAnchorStrategy(widget, context, position);
    setState(() {
      _activeCount += 1;
    });
    final _DragAvatar<T> avatar = _DragAvatar<T>(
      overlayState: Overlay.of(context,
          debugRequiredFor: widget, rootOverlay: widget.rootOverlay),
      data: widget.data,
      axis: widget.axis,
      initialPosition: position,
      dragStartPoint: dragStartPoint,
      feedback: widget.feedback,
      feedbackOffset: widget.feedbackOffset,
      ignoringFeedbackSemantics: widget.ignoringFeedbackSemantics,
      ignoringFeedbackPointer: widget.ignoringFeedbackPointer,
      viewId: View.of(context).viewId,
      onDragUpdate: (DragUpdateDetails details) {
        if (mounted && widget.onDragUpdate != null) {
          widget.onDragUpdate!(details);
        }
      },
      onDragEnd: (Velocity velocity, Offset offset, bool wasAccepted) {
        if (mounted) {
          setState(() {
            _activeCount -= 1;
          });
        } else {
          _activeCount -= 1;
          _disposeRecognizerIfInactive();
        }
        if (mounted && widget.onDragEnd != null) {
          widget.onDragEnd!(DraggableDetails(
            wasAccepted: wasAccepted,
            velocity: velocity,
            offset: offset,
          ));
        }
        if (wasAccepted && widget.onDragCompleted != null) {
          widget.onDragCompleted!();
        }
        if (!wasAccepted && widget.onDraggableCanceled != null) {
          widget.onDraggableCanceled!(velocity, offset);
        }
      },
    );
    widget.onDragStarted?.call();
    return avatar;
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasOverlay(context));
    final bool canDrag = widget.maxSimultaneousDrags == null ||
        _activeCount < widget.maxSimultaneousDrags!;
    final bool showChild =
        _activeCount == 0 || widget.childWhenDragging == null;
    return Listener(
      behavior: widget.hitTestBehavior,
      onPointerDown: canDrag ? _routePointer : null,
      child: showChild ? widget.child : widget.childWhenDragging,
    );
  }
}

class DraggableDetails {
  DraggableDetails({
    this.wasAccepted = false,
    required this.velocity,
    required this.offset,
  });

  final bool wasAccepted;

  final Velocity velocity;

  final Offset offset;
}

class DragTargetDetails<T> {
  DragTargetDetails({required this.data, required this.offset});

  final T data;

  final Offset offset;
}

class DragTarget<T extends Object> extends StatefulWidget {
  const DragTarget({
    super.key,
    required this.builder,
    this.onWillAccept,
    this.onWillAcceptWithDetails,
    this.onAccept,
    this.onAcceptWithDetails,
    this.onLeave,
    this.onMove,
    this.hitTestBehavior = HitTestBehavior.translucent,
  }) : assert(onWillAccept == null || onWillAcceptWithDetails == null,
            "Don't pass both onWillAccept and onWillAcceptWithDetails.");

  final DragTargetBuilder<T> builder;

  final DragTargetWillAccept<T>? onWillAccept;

  final DragTargetWillAcceptWithDetails<T>? onWillAcceptWithDetails;

  final DragTargetAccept<T>? onAccept;

  final DragTargetAcceptWithDetails<T>? onAcceptWithDetails;

  final DragTargetLeave<T>? onLeave;

  final DragTargetMove<T>? onMove;

  final HitTestBehavior hitTestBehavior;

  @override
  State<DragTarget<T>> createState() => _DragTargetState<T>();
}

List<T?> _mapAvatarsToData<T extends Object>(
    List<_DragAvatar<Object>> avatars) {
  return avatars
      .map<T?>((_DragAvatar<Object> avatar) => avatar.data as T?)
      .toList();
}

class _DragTargetState<T extends Object> extends State<DragTarget<T>> {
  final List<_DragAvatar<Object>> _candidateAvatars = <_DragAvatar<Object>>[];
  final List<_DragAvatar<Object>> _rejectedAvatars = <_DragAvatar<Object>>[];

  // On non-web platforms, checks if data Object is equal to type[T] or subtype of [T].
  // On web, it does the same, but requires a check for ints and doubles
  // because dart doubles and ints are backed by the same kind of object on web.
  // JavaScript does not support integers.
  bool isExpectedDataType(Object? data, Type type) {
    if (kIsWeb &&
        ((type == int && T == double) || (type == double && T == int))) {
      return false;
    }
    return data is T?;
  }

  bool didEnter(_DragAvatar<Object> avatar) {
    assert(!_candidateAvatars.contains(avatar));
    assert(!_rejectedAvatars.contains(avatar));
    final bool resolvedWillAccept = (widget.onWillAccept == null &&
            widget.onWillAcceptWithDetails == null) ||
        (widget.onWillAccept != null &&
            widget.onWillAccept!(avatar.data as T?)) ||
        (widget.onWillAcceptWithDetails != null &&
            widget.onWillAcceptWithDetails!(DragTargetDetails<T>(
                data: avatar.data! as T, offset: avatar._lastOffset!)));
    if (resolvedWillAccept) {
      setState(() {
        _candidateAvatars.add(avatar);
      });
      return true;
    } else {
      setState(() {
        _rejectedAvatars.add(avatar);
      });
      return false;
    }
  }

  void didLeave(_DragAvatar<Object> avatar) {
    assert(_candidateAvatars.contains(avatar) ||
        _rejectedAvatars.contains(avatar));
    if (!mounted) {
      return;
    }
    setState(() {
      _candidateAvatars.remove(avatar);
      _rejectedAvatars.remove(avatar);
    });
    widget.onLeave?.call(avatar.data as T?);
  }

  void didDrop(_DragAvatar<Object> avatar) {
    assert(_candidateAvatars.contains(avatar));
    if (!mounted) {
      return;
    }
    setState(() {
      _candidateAvatars.remove(avatar);
    });
    widget.onAccept?.call(avatar.data! as T);
    widget.onAcceptWithDetails?.call(DragTargetDetails<T>(
        data: avatar.data! as T, offset: avatar._lastOffset!));
  }

  void didMove(_DragAvatar<Object> avatar) {
    if (!mounted) {
      return;
    }
    widget.onMove?.call(DragTargetDetails<T>(
        data: avatar.data! as T, offset: avatar._lastOffset!));
  }

  @override
  Widget build(BuildContext context) {
    return MetaData(
      metaData: this,
      behavior: widget.hitTestBehavior,
      child: widget.builder(context, _mapAvatarsToData<T>(_candidateAvatars),
          _mapAvatarsToData<Object>(_rejectedAvatars)),
    );
  }
}

enum _DragEndKind { dropped, canceled }

typedef _OnDragEnd = void Function(
    Velocity velocity, Offset offset, bool wasAccepted);

// The lifetime of this object is a little dubious right now. Specifically, it
// lives as long as the pointer is down. Arguably it should self-immolate if the
// overlay goes away. _DraggableState has some delicate logic to continue
// needing this object pointer events even after it has been disposed.
class _DragAvatar<T extends Object> extends Drag {
  _DragAvatar({
    required this.overlayState,
    this.data,
    this.axis,
    required Offset initialPosition,
    this.dragStartPoint = Offset.zero,
    this.feedback,
    this.feedbackOffset = Offset.zero,
    this.onDragUpdate,
    this.onDragEnd,
    required this.ignoringFeedbackSemantics,
    required this.ignoringFeedbackPointer,
    required this.viewId,
  }) : _position = initialPosition {
    _entry = OverlayEntry(builder: _build);
    overlayState.insert(_entry!);
    updateDrag(initialPosition);
  }

  final T? data;
  final Axis? axis;
  final Offset dragStartPoint;
  final Widget? feedback;
  final Offset feedbackOffset;
  final DragUpdateCallback? onDragUpdate;
  final _OnDragEnd? onDragEnd;
  final OverlayState overlayState;
  final bool ignoringFeedbackSemantics;
  final bool ignoringFeedbackPointer;
  final int viewId;

  _DragTargetState<Object>? _activeTarget;
  final List<_DragTargetState<Object>> _enteredTargets =
      <_DragTargetState<Object>>[];
  Offset _position;
  Offset? _lastOffset;
  OverlayEntry? _entry;

  @override
  void update(DragUpdateDetails details) {
    final Offset oldPosition = _position;
    _position += _restrictAxis(details.delta);
    updateDrag(_position);
    if (onDragUpdate != null && _position != oldPosition) {
      onDragUpdate!(details);
    }
  }

  @override
  void end(DragEndDetails details) {
    finishDrag(_DragEndKind.dropped, _restrictVelocityAxis(details.velocity));
  }

  @override
  void cancel() {
    finishDrag(_DragEndKind.canceled);
  }

  void updateDrag(Offset globalPosition) {
    _lastOffset = globalPosition - dragStartPoint;
    _entry!.markNeedsBuild();
    final HitTestResult result = HitTestResult();
    WidgetsBinding.instance
        .hitTestInView(result, globalPosition + feedbackOffset, viewId);

    final List<_DragTargetState<Object>> targets =
        _getDragTargets(result.path).toList();

    bool listsMatch = false;
    if (targets.length >= _enteredTargets.length &&
        _enteredTargets.isNotEmpty) {
      listsMatch = true;
      final Iterator<_DragTargetState<Object>> iterator = targets.iterator;
      for (int i = 0; i < _enteredTargets.length; i += 1) {
        iterator.moveNext();
        if (iterator.current != _enteredTargets[i]) {
          listsMatch = false;
          break;
        }
      }
    }

    // If everything's the same, report moves, and bail early.
    if (listsMatch) {
      for (final _DragTargetState<Object> target in _enteredTargets) {
        target.didMove(this);
      }
      return;
    }

    // Leave old targets.
    _leaveAllEntered();

    // Enter new targets.
    final _DragTargetState<Object>? newTarget =
        targets.cast<_DragTargetState<Object>?>().firstWhere(
      (_DragTargetState<Object>? target) {
        if (target == null) {
          return false;
        }
        _enteredTargets.add(target);
        return target.didEnter(this);
      },
      orElse: () => null,
    );

    // Report moves to the targets.
    for (final _DragTargetState<Object> target in _enteredTargets) {
      target.didMove(this);
    }

    _activeTarget = newTarget;
  }

  Iterable<_DragTargetState<Object>> _getDragTargets(
      Iterable<HitTestEntry> path) {
    // Look for the RenderBoxes that corresponds to the hit target (the hit target
    // widgets build RenderMetaData boxes for us for this purpose).
    final List<_DragTargetState<Object>> targets = <_DragTargetState<Object>>[];
    for (final HitTestEntry entry in path) {
      final HitTestTarget target = entry.target;
      if (target is RenderMetaData) {
        final dynamic metaData = target.metaData;
        if (metaData is _DragTargetState &&
            metaData.isExpectedDataType(data, T)) {
          targets.add(metaData);
        }
      }
    }
    return targets;
  }

  void _leaveAllEntered() {
    for (int i = 0; i < _enteredTargets.length; i += 1) {
      _enteredTargets[i].didLeave(this);
    }
    _enteredTargets.clear();
  }

  void finishDrag(_DragEndKind endKind, [Velocity? velocity]) {
    bool wasAccepted = false;
    if (endKind == _DragEndKind.dropped && _activeTarget != null) {
      _activeTarget!.didDrop(this);
      wasAccepted = true;
      _enteredTargets.remove(_activeTarget);
    }
    _leaveAllEntered();
    _activeTarget = null;
    _entry!.remove();
    _entry!.dispose();
    _entry = null;
    // TODO(ianh): consider passing _entry as well so the client can perform an animation.
    onDragEnd?.call(velocity ?? Velocity.zero, _lastOffset!, wasAccepted);
  }

  Widget _build(BuildContext context) {
    final RenderBox box = overlayState.context.findRenderObject()! as RenderBox;
    final Offset overlayTopLeft = box.localToGlobal(Offset.zero);
    return Positioned(
      left: _lastOffset!.dx - overlayTopLeft.dx,
      top: _lastOffset!.dy - overlayTopLeft.dy,
      child: ExcludeSemantics(
        excluding: ignoringFeedbackSemantics,
        child: IgnorePointer(
          ignoring: ignoringFeedbackPointer,
          child: feedback,
        ),
      ),
    );
  }

  Velocity _restrictVelocityAxis(Velocity velocity) {
    if (axis == null) {
      return velocity;
    }
    return Velocity(
      pixelsPerSecond: _restrictAxis(velocity.pixelsPerSecond),
    );
  }

  Offset _restrictAxis(Offset offset) {
    if (axis == null) {
      return offset;
    }
    if (axis == Axis.horizontal) {
      return Offset(offset.dx, 0.0);
    }
    return Offset(0.0, offset.dy);
  }
}
