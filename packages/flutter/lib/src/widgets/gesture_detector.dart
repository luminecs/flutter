import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

import 'basic.dart';
import 'framework.dart';
import 'media_query.dart';

export 'package:flutter/gestures.dart'
    show
        DragDownDetails,
        DragEndDetails,
        DragStartDetails,
        DragUpdateDetails,
        ForcePressDetails,
        GestureDragCancelCallback,
        GestureDragDownCallback,
        GestureDragEndCallback,
        GestureDragStartCallback,
        GestureDragUpdateCallback,
        GestureForcePressEndCallback,
        GestureForcePressPeakCallback,
        GestureForcePressStartCallback,
        GestureForcePressUpdateCallback,
        GestureLongPressCallback,
        GestureLongPressEndCallback,
        GestureLongPressMoveUpdateCallback,
        GestureLongPressStartCallback,
        GestureLongPressUpCallback,
        GestureScaleEndCallback,
        GestureScaleStartCallback,
        GestureScaleUpdateCallback,
        GestureTapCallback,
        GestureTapCancelCallback,
        GestureTapDownCallback,
        GestureTapUpCallback,
        LongPressEndDetails,
        LongPressMoveUpdateDetails,
        LongPressStartDetails,
        ScaleEndDetails,
        ScaleStartDetails,
        ScaleUpdateDetails,
        TapDownDetails,
        TapUpDetails,
        Velocity;
export 'package:flutter/rendering.dart' show RenderSemanticsGestureHandler;

// Examples can assume:
// late bool _lights;
// void setState(VoidCallback fn) { }
// late String _last;
// late Color _color;

@optionalTypeArgs
abstract class GestureRecognizerFactory<T extends GestureRecognizer> {
  const GestureRecognizerFactory();

  T constructor();

  void initializer(T instance);

  bool _debugAssertTypeMatches(Type type) {
    assert(type == T,
        'GestureRecognizerFactory of type $T was used where type $type was specified.');
    return true;
  }
}

typedef GestureRecognizerFactoryConstructor<T extends GestureRecognizer> = T
    Function();

typedef GestureRecognizerFactoryInitializer<T extends GestureRecognizer> = void
    Function(T instance);

class GestureRecognizerFactoryWithHandlers<T extends GestureRecognizer>
    extends GestureRecognizerFactory<T> {
  const GestureRecognizerFactoryWithHandlers(
      this._constructor, this._initializer);

  final GestureRecognizerFactoryConstructor<T> _constructor;

  final GestureRecognizerFactoryInitializer<T> _initializer;

  @override
  T constructor() => _constructor();

  @override
  void initializer(T instance) => _initializer(instance);
}

class GestureDetector extends StatelessWidget {
  GestureDetector({
    super.key,
    this.child,
    this.onTapDown,
    this.onTapUp,
    this.onTap,
    this.onTapCancel,
    this.onSecondaryTap,
    this.onSecondaryTapDown,
    this.onSecondaryTapUp,
    this.onSecondaryTapCancel,
    this.onTertiaryTapDown,
    this.onTertiaryTapUp,
    this.onTertiaryTapCancel,
    this.onDoubleTapDown,
    this.onDoubleTap,
    this.onDoubleTapCancel,
    this.onLongPressDown,
    this.onLongPressCancel,
    this.onLongPress,
    this.onLongPressStart,
    this.onLongPressMoveUpdate,
    this.onLongPressUp,
    this.onLongPressEnd,
    this.onSecondaryLongPressDown,
    this.onSecondaryLongPressCancel,
    this.onSecondaryLongPress,
    this.onSecondaryLongPressStart,
    this.onSecondaryLongPressMoveUpdate,
    this.onSecondaryLongPressUp,
    this.onSecondaryLongPressEnd,
    this.onTertiaryLongPressDown,
    this.onTertiaryLongPressCancel,
    this.onTertiaryLongPress,
    this.onTertiaryLongPressStart,
    this.onTertiaryLongPressMoveUpdate,
    this.onTertiaryLongPressUp,
    this.onTertiaryLongPressEnd,
    this.onVerticalDragDown,
    this.onVerticalDragStart,
    this.onVerticalDragUpdate,
    this.onVerticalDragEnd,
    this.onVerticalDragCancel,
    this.onHorizontalDragDown,
    this.onHorizontalDragStart,
    this.onHorizontalDragUpdate,
    this.onHorizontalDragEnd,
    this.onHorizontalDragCancel,
    this.onForcePressStart,
    this.onForcePressPeak,
    this.onForcePressUpdate,
    this.onForcePressEnd,
    this.onPanDown,
    this.onPanStart,
    this.onPanUpdate,
    this.onPanEnd,
    this.onPanCancel,
    this.onScaleStart,
    this.onScaleUpdate,
    this.onScaleEnd,
    this.behavior,
    this.excludeFromSemantics = false,
    this.dragStartBehavior = DragStartBehavior.start,
    this.trackpadScrollCausesScale = false,
    this.trackpadScrollToScaleFactor = kDefaultTrackpadScrollToScaleFactor,
    this.supportedDevices,
  }) : assert(() {
          final bool haveVerticalDrag = onVerticalDragStart != null ||
              onVerticalDragUpdate != null ||
              onVerticalDragEnd != null;
          final bool haveHorizontalDrag = onHorizontalDragStart != null ||
              onHorizontalDragUpdate != null ||
              onHorizontalDragEnd != null;
          final bool havePan =
              onPanStart != null || onPanUpdate != null || onPanEnd != null;
          final bool haveScale = onScaleStart != null ||
              onScaleUpdate != null ||
              onScaleEnd != null;
          if (havePan || haveScale) {
            if (havePan && haveScale) {
              throw FlutterError.fromParts(<DiagnosticsNode>[
                ErrorSummary('Incorrect GestureDetector arguments.'),
                ErrorDescription(
                  'Having both a pan gesture recognizer and a scale gesture recognizer is redundant; scale is a superset of pan.',
                ),
                ErrorHint('Just use the scale gesture recognizer.'),
              ]);
            }
            final String recognizer = havePan ? 'pan' : 'scale';
            if (haveVerticalDrag && haveHorizontalDrag) {
              throw FlutterError(
                'Incorrect GestureDetector arguments.\n'
                'Simultaneously having a vertical drag gesture recognizer, a horizontal drag gesture recognizer, and a $recognizer gesture recognizer '
                'will result in the $recognizer gesture recognizer being ignored, since the other two will catch all drags.',
              );
            }
          }
          return true;
        }());

  final Widget? child;

  final GestureTapDownCallback? onTapDown;

  final GestureTapUpCallback? onTapUp;

  final GestureTapCallback? onTap;

  final GestureTapCancelCallback? onTapCancel;

  final GestureTapCallback? onSecondaryTap;

  final GestureTapDownCallback? onSecondaryTapDown;

  final GestureTapUpCallback? onSecondaryTapUp;

  final GestureTapCancelCallback? onSecondaryTapCancel;

  final GestureTapDownCallback? onTertiaryTapDown;

  final GestureTapUpCallback? onTertiaryTapUp;

  final GestureTapCancelCallback? onTertiaryTapCancel;

  final GestureTapDownCallback? onDoubleTapDown;

  final GestureTapCallback? onDoubleTap;

  final GestureTapCancelCallback? onDoubleTapCancel;

  final GestureLongPressDownCallback? onLongPressDown;

  final GestureLongPressCancelCallback? onLongPressCancel;

  final GestureLongPressCallback? onLongPress;

  final GestureLongPressStartCallback? onLongPressStart;

  final GestureLongPressMoveUpdateCallback? onLongPressMoveUpdate;

  final GestureLongPressUpCallback? onLongPressUp;

  final GestureLongPressEndCallback? onLongPressEnd;

  final GestureLongPressDownCallback? onSecondaryLongPressDown;

  final GestureLongPressCancelCallback? onSecondaryLongPressCancel;

  final GestureLongPressCallback? onSecondaryLongPress;

  final GestureLongPressStartCallback? onSecondaryLongPressStart;

  final GestureLongPressMoveUpdateCallback? onSecondaryLongPressMoveUpdate;

  final GestureLongPressUpCallback? onSecondaryLongPressUp;

  final GestureLongPressEndCallback? onSecondaryLongPressEnd;

  final GestureLongPressDownCallback? onTertiaryLongPressDown;

  final GestureLongPressCancelCallback? onTertiaryLongPressCancel;

  final GestureLongPressCallback? onTertiaryLongPress;

  final GestureLongPressStartCallback? onTertiaryLongPressStart;

  final GestureLongPressMoveUpdateCallback? onTertiaryLongPressMoveUpdate;

  final GestureLongPressUpCallback? onTertiaryLongPressUp;

  final GestureLongPressEndCallback? onTertiaryLongPressEnd;

  final GestureDragDownCallback? onVerticalDragDown;

  final GestureDragStartCallback? onVerticalDragStart;

  final GestureDragUpdateCallback? onVerticalDragUpdate;

  final GestureDragEndCallback? onVerticalDragEnd;

  final GestureDragCancelCallback? onVerticalDragCancel;

  final GestureDragDownCallback? onHorizontalDragDown;

  final GestureDragStartCallback? onHorizontalDragStart;

  final GestureDragUpdateCallback? onHorizontalDragUpdate;

  final GestureDragEndCallback? onHorizontalDragEnd;

  final GestureDragCancelCallback? onHorizontalDragCancel;

  final GestureDragDownCallback? onPanDown;

  final GestureDragStartCallback? onPanStart;

  final GestureDragUpdateCallback? onPanUpdate;

  final GestureDragEndCallback? onPanEnd;

  final GestureDragCancelCallback? onPanCancel;

  final GestureScaleStartCallback? onScaleStart;

  final GestureScaleUpdateCallback? onScaleUpdate;

  final GestureScaleEndCallback? onScaleEnd;

  final GestureForcePressStartCallback? onForcePressStart;

  final GestureForcePressPeakCallback? onForcePressPeak;

  final GestureForcePressUpdateCallback? onForcePressUpdate;

  final GestureForcePressEndCallback? onForcePressEnd;

  final HitTestBehavior? behavior;

  final bool excludeFromSemantics;

  final DragStartBehavior dragStartBehavior;

  final Set<PointerDeviceKind>? supportedDevices;

  final bool trackpadScrollCausesScale;

  final Offset trackpadScrollToScaleFactor;

  @override
  Widget build(BuildContext context) {
    final Map<Type, GestureRecognizerFactory> gestures =
        <Type, GestureRecognizerFactory>{};
    final DeviceGestureSettings? gestureSettings =
        MediaQuery.maybeGestureSettingsOf(context);

    if (onTapDown != null ||
        onTapUp != null ||
        onTap != null ||
        onTapCancel != null ||
        onSecondaryTap != null ||
        onSecondaryTapDown != null ||
        onSecondaryTapUp != null ||
        onSecondaryTapCancel != null ||
        onTertiaryTapDown != null ||
        onTertiaryTapUp != null ||
        onTertiaryTapCancel != null) {
      gestures[TapGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
        () => TapGestureRecognizer(
            debugOwner: this, supportedDevices: supportedDevices),
        (TapGestureRecognizer instance) {
          instance
            ..onTapDown = onTapDown
            ..onTapUp = onTapUp
            ..onTap = onTap
            ..onTapCancel = onTapCancel
            ..onSecondaryTap = onSecondaryTap
            ..onSecondaryTapDown = onSecondaryTapDown
            ..onSecondaryTapUp = onSecondaryTapUp
            ..onSecondaryTapCancel = onSecondaryTapCancel
            ..onTertiaryTapDown = onTertiaryTapDown
            ..onTertiaryTapUp = onTertiaryTapUp
            ..onTertiaryTapCancel = onTertiaryTapCancel
            ..gestureSettings = gestureSettings
            ..supportedDevices = supportedDevices;
        },
      );
    }

    if (onDoubleTap != null ||
        onDoubleTapDown != null ||
        onDoubleTapCancel != null) {
      gestures[DoubleTapGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<DoubleTapGestureRecognizer>(
        () => DoubleTapGestureRecognizer(
            debugOwner: this, supportedDevices: supportedDevices),
        (DoubleTapGestureRecognizer instance) {
          instance
            ..onDoubleTapDown = onDoubleTapDown
            ..onDoubleTap = onDoubleTap
            ..onDoubleTapCancel = onDoubleTapCancel
            ..gestureSettings = gestureSettings
            ..supportedDevices = supportedDevices;
        },
      );
    }

    if (onLongPressDown != null ||
        onLongPressCancel != null ||
        onLongPress != null ||
        onLongPressStart != null ||
        onLongPressMoveUpdate != null ||
        onLongPressUp != null ||
        onLongPressEnd != null ||
        onSecondaryLongPressDown != null ||
        onSecondaryLongPressCancel != null ||
        onSecondaryLongPress != null ||
        onSecondaryLongPressStart != null ||
        onSecondaryLongPressMoveUpdate != null ||
        onSecondaryLongPressUp != null ||
        onSecondaryLongPressEnd != null ||
        onTertiaryLongPressDown != null ||
        onTertiaryLongPressCancel != null ||
        onTertiaryLongPress != null ||
        onTertiaryLongPressStart != null ||
        onTertiaryLongPressMoveUpdate != null ||
        onTertiaryLongPressUp != null ||
        onTertiaryLongPressEnd != null) {
      gestures[LongPressGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
        () => LongPressGestureRecognizer(
            debugOwner: this, supportedDevices: supportedDevices),
        (LongPressGestureRecognizer instance) {
          instance
            ..onLongPressDown = onLongPressDown
            ..onLongPressCancel = onLongPressCancel
            ..onLongPress = onLongPress
            ..onLongPressStart = onLongPressStart
            ..onLongPressMoveUpdate = onLongPressMoveUpdate
            ..onLongPressUp = onLongPressUp
            ..onLongPressEnd = onLongPressEnd
            ..onSecondaryLongPressDown = onSecondaryLongPressDown
            ..onSecondaryLongPressCancel = onSecondaryLongPressCancel
            ..onSecondaryLongPress = onSecondaryLongPress
            ..onSecondaryLongPressStart = onSecondaryLongPressStart
            ..onSecondaryLongPressMoveUpdate = onSecondaryLongPressMoveUpdate
            ..onSecondaryLongPressUp = onSecondaryLongPressUp
            ..onSecondaryLongPressEnd = onSecondaryLongPressEnd
            ..onTertiaryLongPressDown = onTertiaryLongPressDown
            ..onTertiaryLongPressCancel = onTertiaryLongPressCancel
            ..onTertiaryLongPress = onTertiaryLongPress
            ..onTertiaryLongPressStart = onTertiaryLongPressStart
            ..onTertiaryLongPressMoveUpdate = onTertiaryLongPressMoveUpdate
            ..onTertiaryLongPressUp = onTertiaryLongPressUp
            ..onTertiaryLongPressEnd = onTertiaryLongPressEnd
            ..gestureSettings = gestureSettings
            ..supportedDevices = supportedDevices;
        },
      );
    }

    if (onVerticalDragDown != null ||
        onVerticalDragStart != null ||
        onVerticalDragUpdate != null ||
        onVerticalDragEnd != null ||
        onVerticalDragCancel != null) {
      gestures[VerticalDragGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<VerticalDragGestureRecognizer>(
        () => VerticalDragGestureRecognizer(
            debugOwner: this, supportedDevices: supportedDevices),
        (VerticalDragGestureRecognizer instance) {
          instance
            ..onDown = onVerticalDragDown
            ..onStart = onVerticalDragStart
            ..onUpdate = onVerticalDragUpdate
            ..onEnd = onVerticalDragEnd
            ..onCancel = onVerticalDragCancel
            ..dragStartBehavior = dragStartBehavior
            ..gestureSettings = gestureSettings
            ..supportedDevices = supportedDevices;
        },
      );
    }

    if (onHorizontalDragDown != null ||
        onHorizontalDragStart != null ||
        onHorizontalDragUpdate != null ||
        onHorizontalDragEnd != null ||
        onHorizontalDragCancel != null) {
      gestures[HorizontalDragGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<HorizontalDragGestureRecognizer>(
        () => HorizontalDragGestureRecognizer(
            debugOwner: this, supportedDevices: supportedDevices),
        (HorizontalDragGestureRecognizer instance) {
          instance
            ..onDown = onHorizontalDragDown
            ..onStart = onHorizontalDragStart
            ..onUpdate = onHorizontalDragUpdate
            ..onEnd = onHorizontalDragEnd
            ..onCancel = onHorizontalDragCancel
            ..dragStartBehavior = dragStartBehavior
            ..gestureSettings = gestureSettings
            ..supportedDevices = supportedDevices;
        },
      );
    }

    if (onPanDown != null ||
        onPanStart != null ||
        onPanUpdate != null ||
        onPanEnd != null ||
        onPanCancel != null) {
      gestures[PanGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
        () => PanGestureRecognizer(
            debugOwner: this, supportedDevices: supportedDevices),
        (PanGestureRecognizer instance) {
          instance
            ..onDown = onPanDown
            ..onStart = onPanStart
            ..onUpdate = onPanUpdate
            ..onEnd = onPanEnd
            ..onCancel = onPanCancel
            ..dragStartBehavior = dragStartBehavior
            ..gestureSettings = gestureSettings
            ..supportedDevices = supportedDevices;
        },
      );
    }

    if (onScaleStart != null || onScaleUpdate != null || onScaleEnd != null) {
      gestures[ScaleGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<ScaleGestureRecognizer>(
        () => ScaleGestureRecognizer(
            debugOwner: this, supportedDevices: supportedDevices),
        (ScaleGestureRecognizer instance) {
          instance
            ..onStart = onScaleStart
            ..onUpdate = onScaleUpdate
            ..onEnd = onScaleEnd
            ..dragStartBehavior = dragStartBehavior
            ..gestureSettings = gestureSettings
            ..trackpadScrollCausesScale = trackpadScrollCausesScale
            ..trackpadScrollToScaleFactor = trackpadScrollToScaleFactor
            ..supportedDevices = supportedDevices;
        },
      );
    }

    if (onForcePressStart != null ||
        onForcePressPeak != null ||
        onForcePressUpdate != null ||
        onForcePressEnd != null) {
      gestures[ForcePressGestureRecognizer] =
          GestureRecognizerFactoryWithHandlers<ForcePressGestureRecognizer>(
        () => ForcePressGestureRecognizer(
            debugOwner: this, supportedDevices: supportedDevices),
        (ForcePressGestureRecognizer instance) {
          instance
            ..onStart = onForcePressStart
            ..onPeak = onForcePressPeak
            ..onUpdate = onForcePressUpdate
            ..onEnd = onForcePressEnd
            ..gestureSettings = gestureSettings
            ..supportedDevices = supportedDevices;
        },
      );
    }

    return RawGestureDetector(
      gestures: gestures,
      behavior: behavior,
      excludeFromSemantics: excludeFromSemantics,
      child: child,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
        EnumProperty<DragStartBehavior>('startBehavior', dragStartBehavior));
  }
}

class RawGestureDetector extends StatefulWidget {
  const RawGestureDetector({
    super.key,
    this.child,
    this.gestures = const <Type, GestureRecognizerFactory>{},
    this.behavior,
    this.excludeFromSemantics = false,
    this.semantics,
  });

  final Widget? child;

  final Map<Type, GestureRecognizerFactory> gestures;

  final HitTestBehavior? behavior;

  final bool excludeFromSemantics;

  final SemanticsGestureDelegate? semantics;

  @override
  RawGestureDetectorState createState() => RawGestureDetectorState();
}

class RawGestureDetectorState extends State<RawGestureDetector> {
  Map<Type, GestureRecognizer>? _recognizers =
      const <Type, GestureRecognizer>{};
  SemanticsGestureDelegate? _semantics;

  @override
  void initState() {
    super.initState();
    _semantics = widget.semantics ?? _DefaultSemanticsGestureDelegate(this);
    _syncAll(widget.gestures);
  }

  @override
  void didUpdateWidget(RawGestureDetector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!(oldWidget.semantics == null && widget.semantics == null)) {
      _semantics = widget.semantics ?? _DefaultSemanticsGestureDelegate(this);
    }
    _syncAll(widget.gestures);
  }

  void replaceGestureRecognizers(Map<Type, GestureRecognizerFactory> gestures) {
    assert(() {
      if (!context.findRenderObject()!.owner!.debugDoingLayout) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
              'Unexpected call to replaceGestureRecognizers() method of RawGestureDetectorState.'),
          ErrorDescription(
              'The replaceGestureRecognizers() method can only be called during the layout phase.'),
          ErrorHint(
            'To set the gesture recognizers at other times, trigger a new build using setState() '
            'and provide the new gesture recognizers as constructor arguments to the corresponding '
            'RawGestureDetector or GestureDetector object.',
          ),
        ]);
      }
      return true;
    }());
    _syncAll(gestures);
    if (!widget.excludeFromSemantics) {
      final RenderSemanticsGestureHandler semanticsGestureHandler =
          context.findRenderObject()! as RenderSemanticsGestureHandler;
      _updateSemanticsForRenderObject(semanticsGestureHandler);
    }
  }

  void replaceSemanticsActions(Set<SemanticsAction> actions) {
    if (widget.excludeFromSemantics) {
      return;
    }

    final RenderSemanticsGestureHandler? semanticsGestureHandler =
        context.findRenderObject() as RenderSemanticsGestureHandler?;
    assert(() {
      if (semanticsGestureHandler == null) {
        throw FlutterError(
          'Unexpected call to replaceSemanticsActions() method of RawGestureDetectorState.\n'
          'The replaceSemanticsActions() method can only be called after the RenderSemanticsGestureHandler has been created.',
        );
      }
      return true;
    }());

    semanticsGestureHandler!.validActions =
        actions; // will call _markNeedsSemanticsUpdate(), if required.
  }

  @override
  void dispose() {
    for (final GestureRecognizer recognizer in _recognizers!.values) {
      recognizer.dispose();
    }
    _recognizers = null;
    super.dispose();
  }

  void _syncAll(Map<Type, GestureRecognizerFactory> gestures) {
    assert(_recognizers != null);
    final Map<Type, GestureRecognizer> oldRecognizers = _recognizers!;
    _recognizers = <Type, GestureRecognizer>{};
    for (final Type type in gestures.keys) {
      assert(gestures[type] != null);
      assert(gestures[type]!._debugAssertTypeMatches(type));
      assert(!_recognizers!.containsKey(type));
      _recognizers![type] =
          oldRecognizers[type] ?? gestures[type]!.constructor();
      assert(_recognizers![type].runtimeType == type,
          'GestureRecognizerFactory of type $type created a GestureRecognizer of type ${_recognizers![type].runtimeType}. The GestureRecognizerFactory must be specialized with the type of the class that it returns from its constructor method.');
      gestures[type]!.initializer(_recognizers![type]!);
    }
    for (final Type type in oldRecognizers.keys) {
      if (!_recognizers!.containsKey(type)) {
        oldRecognizers[type]!.dispose();
      }
    }
  }

  void _handlePointerDown(PointerDownEvent event) {
    assert(_recognizers != null);
    for (final GestureRecognizer recognizer in _recognizers!.values) {
      recognizer.addPointer(event);
    }
  }

  void _handlePointerPanZoomStart(PointerPanZoomStartEvent event) {
    assert(_recognizers != null);
    for (final GestureRecognizer recognizer in _recognizers!.values) {
      recognizer.addPointerPanZoom(event);
    }
  }

  HitTestBehavior get _defaultBehavior {
    return widget.child == null
        ? HitTestBehavior.translucent
        : HitTestBehavior.deferToChild;
  }

  void _updateSemanticsForRenderObject(
      RenderSemanticsGestureHandler renderObject) {
    assert(!widget.excludeFromSemantics);
    assert(_semantics != null);
    _semantics!.assignSemantics(renderObject);
  }

  @override
  Widget build(BuildContext context) {
    Widget result = Listener(
      onPointerDown: _handlePointerDown,
      onPointerPanZoomStart: _handlePointerPanZoomStart,
      behavior: widget.behavior ?? _defaultBehavior,
      child: widget.child,
    );
    if (!widget.excludeFromSemantics) {
      result = _GestureSemantics(
        behavior: widget.behavior ?? _defaultBehavior,
        assignSemantics: _updateSemanticsForRenderObject,
        child: result,
      );
    }
    return result;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    if (_recognizers == null) {
      properties.add(DiagnosticsNode.message('DISPOSED'));
    } else {
      final List<String> gestures = _recognizers!.values
          .map<String>(
              (GestureRecognizer recognizer) => recognizer.debugDescription)
          .toList();
      properties.add(
          IterableProperty<String>('gestures', gestures, ifEmpty: '<none>'));
      properties.add(IterableProperty<GestureRecognizer>(
          'recognizers', _recognizers!.values,
          level: DiagnosticLevel.fine));
      properties.add(DiagnosticsProperty<bool>(
          'excludeFromSemantics', widget.excludeFromSemantics,
          defaultValue: false));
      if (!widget.excludeFromSemantics) {
        properties.add(DiagnosticsProperty<SemanticsGestureDelegate>(
            'semantics', widget.semantics,
            defaultValue: null));
      }
    }
    properties.add(EnumProperty<HitTestBehavior>('behavior', widget.behavior,
        defaultValue: null));
  }
}

typedef _AssignSemantics = void Function(RenderSemanticsGestureHandler);

class _GestureSemantics extends SingleChildRenderObjectWidget {
  const _GestureSemantics({
    super.child,
    required this.behavior,
    required this.assignSemantics,
  });

  final HitTestBehavior behavior;
  final _AssignSemantics assignSemantics;

  @override
  RenderSemanticsGestureHandler createRenderObject(BuildContext context) {
    final RenderSemanticsGestureHandler renderObject =
        RenderSemanticsGestureHandler()..behavior = behavior;
    assignSemantics(renderObject);
    return renderObject;
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderSemanticsGestureHandler renderObject) {
    renderObject.behavior = behavior;
    assignSemantics(renderObject);
  }
}

abstract class SemanticsGestureDelegate {
  const SemanticsGestureDelegate();

  void assignSemantics(RenderSemanticsGestureHandler renderObject);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'SemanticsGestureDelegate')}()';
}

// The default semantics delegate of [RawGestureDetector]. Its behavior is
// described in [RawGestureDetector.semantics].
//
// For readers who come here to learn how to write custom semantics delegates:
// this is not a proper sample code. It has access to the detector state as well
// as its private properties, which are inaccessible normally. It is designed
// this way in order to work independently in a [RawGestureRecognizer] to
// preserve existing behavior.
//
// Instead, a normal delegate will store callbacks as properties, and use them
// in `assignSemantics`.
class _DefaultSemanticsGestureDelegate extends SemanticsGestureDelegate {
  _DefaultSemanticsGestureDelegate(this.detectorState);

  final RawGestureDetectorState detectorState;

  @override
  void assignSemantics(RenderSemanticsGestureHandler renderObject) {
    assert(!detectorState.widget.excludeFromSemantics);
    final Map<Type, GestureRecognizer> recognizers =
        detectorState._recognizers!;
    renderObject
      ..onTap = _getTapHandler(recognizers)
      ..onLongPress = _getLongPressHandler(recognizers)
      ..onHorizontalDragUpdate = _getHorizontalDragUpdateHandler(recognizers)
      ..onVerticalDragUpdate = _getVerticalDragUpdateHandler(recognizers);
  }

  GestureTapCallback? _getTapHandler(Map<Type, GestureRecognizer> recognizers) {
    final TapGestureRecognizer? tap =
        recognizers[TapGestureRecognizer] as TapGestureRecognizer?;
    if (tap == null) {
      return null;
    }

    return () {
      tap.onTapDown?.call(TapDownDetails());
      tap.onTapUp?.call(TapUpDetails(kind: PointerDeviceKind.unknown));
      tap.onTap?.call();
    };
  }

  GestureLongPressCallback? _getLongPressHandler(
      Map<Type, GestureRecognizer> recognizers) {
    final LongPressGestureRecognizer? longPress =
        recognizers[LongPressGestureRecognizer] as LongPressGestureRecognizer?;
    if (longPress == null) {
      return null;
    }

    return () {
      longPress.onLongPressDown?.call(const LongPressDownDetails());
      longPress.onLongPressStart?.call(const LongPressStartDetails());
      longPress.onLongPress?.call();
      longPress.onLongPressEnd?.call(const LongPressEndDetails());
      longPress.onLongPressUp?.call();
    };
  }

  GestureDragUpdateCallback? _getHorizontalDragUpdateHandler(
      Map<Type, GestureRecognizer> recognizers) {
    final HorizontalDragGestureRecognizer? horizontal =
        recognizers[HorizontalDragGestureRecognizer]
            as HorizontalDragGestureRecognizer?;
    final PanGestureRecognizer? pan =
        recognizers[PanGestureRecognizer] as PanGestureRecognizer?;

    final GestureDragUpdateCallback? horizontalHandler = horizontal == null
        ? null
        : (DragUpdateDetails details) {
            horizontal.onDown?.call(DragDownDetails());
            horizontal.onStart?.call(DragStartDetails());
            horizontal.onUpdate?.call(details);
            horizontal.onEnd?.call(DragEndDetails(primaryVelocity: 0.0));
          };

    final GestureDragUpdateCallback? panHandler = pan == null
        ? null
        : (DragUpdateDetails details) {
            pan.onDown?.call(DragDownDetails());
            pan.onStart?.call(DragStartDetails());
            pan.onUpdate?.call(details);
            pan.onEnd?.call(DragEndDetails());
          };

    if (horizontalHandler == null && panHandler == null) {
      return null;
    }
    return (DragUpdateDetails details) {
      if (horizontalHandler != null) {
        horizontalHandler(details);
      }
      if (panHandler != null) {
        panHandler(details);
      }
    };
  }

  GestureDragUpdateCallback? _getVerticalDragUpdateHandler(
      Map<Type, GestureRecognizer> recognizers) {
    final VerticalDragGestureRecognizer? vertical =
        recognizers[VerticalDragGestureRecognizer]
            as VerticalDragGestureRecognizer?;
    final PanGestureRecognizer? pan =
        recognizers[PanGestureRecognizer] as PanGestureRecognizer?;

    final GestureDragUpdateCallback? verticalHandler = vertical == null
        ? null
        : (DragUpdateDetails details) {
            vertical.onDown?.call(DragDownDetails());
            vertical.onStart?.call(DragStartDetails());
            vertical.onUpdate?.call(details);
            vertical.onEnd?.call(DragEndDetails(primaryVelocity: 0.0));
          };

    final GestureDragUpdateCallback? panHandler = pan == null
        ? null
        : (DragUpdateDetails details) {
            pan.onDown?.call(DragDownDetails());
            pan.onStart?.call(DragStartDetails());
            pan.onUpdate?.call(details);
            pan.onEnd?.call(DragEndDetails());
          };

    if (verticalHandler == null && panHandler == null) {
      return null;
    }
    return (DragUpdateDetails details) {
      if (verticalHandler != null) {
        verticalHandler(details);
      }
      if (panHandler != null) {
        panHandler(details);
      }
    };
  }
}
