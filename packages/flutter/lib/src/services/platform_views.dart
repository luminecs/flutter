
import 'dart:async';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import 'message_codec.dart';
import 'system_channels.dart';

export 'dart:ui' show Offset, Size, TextDirection, VoidCallback;

export 'package:flutter/gestures.dart' show PointerEvent;

export 'message_codec.dart' show MessageCodec;

typedef PointTransformer = Offset Function(Offset position);

final PlatformViewsRegistry platformViewsRegistry = PlatformViewsRegistry._instance();

class PlatformViewsRegistry {
  PlatformViewsRegistry._instance();

  // Always non-negative. The id value -1 is used in the accessibility bridge
  // to indicate the absence of a platform view.
  int _nextPlatformViewId = 0;

  int getNextPlatformViewId() {
    // On the Android side, the interface exposed to users uses 32-bit integers.
    // See https://github.com/flutter/engine/pull/39476 for more details.

    // We can safely assume that a Flutter application will not require more
    // than MAX_INT32 platform views during its lifetime.
    const int MAX_INT32 = 0x7FFFFFFF;
    assert(_nextPlatformViewId <= MAX_INT32);
    return _nextPlatformViewId++;
  }
}

typedef PlatformViewCreatedCallback = void Function(int id);

class PlatformViewsService {
  PlatformViewsService._() {
    SystemChannels.platform_views.setMethodCallHandler(_onMethodCall);
  }

  static final PlatformViewsService _instance = PlatformViewsService._();

  Future<void> _onMethodCall(MethodCall call) {
    switch (call.method) {
      case 'viewFocused':
        final int id = call.arguments as int;
        if (_focusCallbacks.containsKey(id)) {
          _focusCallbacks[id]!();
        }
      default:
        throw UnimplementedError("${call.method} was invoked but isn't implemented by PlatformViewsService");
    }
    return Future<void>.value();
  }

  final Map<int, VoidCallback> _focusCallbacks = <int, VoidCallback>{};

  static AndroidViewController initAndroidView({
    required int id,
    required String viewType,
    required TextDirection layoutDirection,
    dynamic creationParams,
    MessageCodec<dynamic>? creationParamsCodec,
    VoidCallback? onFocus,
  }) {
    assert(creationParams == null || creationParamsCodec != null);

    final TextureAndroidViewController controller = TextureAndroidViewController._(
      viewId: id,
      viewType: viewType,
      layoutDirection: layoutDirection,
      creationParams: creationParams,
      creationParamsCodec: creationParamsCodec,
    );

    _instance._focusCallbacks[id] = onFocus ?? () {};
    return controller;
  }

  static SurfaceAndroidViewController initSurfaceAndroidView({
    required int id,
    required String viewType,
    required TextDirection layoutDirection,
    dynamic creationParams,
    MessageCodec<dynamic>? creationParamsCodec,
    VoidCallback? onFocus,
  }) {
    assert(creationParams == null || creationParamsCodec != null);

    final SurfaceAndroidViewController controller = SurfaceAndroidViewController._(
      viewId: id,
      viewType: viewType,
      layoutDirection: layoutDirection,
      creationParams: creationParams,
      creationParamsCodec: creationParamsCodec,
    );
    _instance._focusCallbacks[id] = onFocus ?? () {};
    return controller;
  }

  static ExpensiveAndroidViewController initExpensiveAndroidView({
    required int id,
    required String viewType,
    required TextDirection layoutDirection,
    dynamic creationParams,
    MessageCodec<dynamic>? creationParamsCodec,
    VoidCallback? onFocus,
  }) {
    final ExpensiveAndroidViewController controller = ExpensiveAndroidViewController._(
      viewId: id,
      viewType: viewType,
      layoutDirection: layoutDirection,
      creationParams: creationParams,
      creationParamsCodec: creationParamsCodec,
    );

    _instance._focusCallbacks[id] = onFocus ?? () {};
    return controller;
  }

  static Future<UiKitViewController> initUiKitView({
    required int id,
    required String viewType,
    required TextDirection layoutDirection,
    dynamic creationParams,
    MessageCodec<dynamic>? creationParamsCodec,
    VoidCallback? onFocus,
  }) async {
    assert(creationParams == null || creationParamsCodec != null);

    // TODO(amirh): pass layoutDirection once the system channel supports it.
    // https://github.com/flutter/flutter/issues/133682
    final Map<String, dynamic> args = <String, dynamic>{
      'id': id,
      'viewType': viewType,
    };
    if (creationParams != null) {
      final ByteData paramsByteData = creationParamsCodec!.encodeMessage(creationParams)!;
      args['params'] = Uint8List.view(
        paramsByteData.buffer,
        0,
        paramsByteData.lengthInBytes,
      );
    }
    await SystemChannels.platform_views.invokeMethod<void>('create', args);
    if (onFocus != null) {
      _instance._focusCallbacks[id] = onFocus;
    }
    return UiKitViewController._(id, layoutDirection);
  }

  // TODO(cbracken): Write and link website docs. https://github.com/flutter/website/issues/9424.
  //
  static Future<AppKitViewController> initAppKitView({
    required int id,
    required String viewType,
    required TextDirection layoutDirection,
    dynamic creationParams,
    MessageCodec<dynamic>? creationParamsCodec,
    VoidCallback? onFocus,
  }) async {
    assert(creationParams == null || creationParamsCodec != null);

    // TODO(amirh): pass layoutDirection once the system channel supports it.
    // https://github.com/flutter/flutter/issues/133682
    final Map<String, dynamic> args = <String, dynamic>{
      'id': id,
      'viewType': viewType,
    };
    if (creationParams != null) {
      final ByteData paramsByteData = creationParamsCodec!.encodeMessage(creationParams)!;
      args['params'] = Uint8List.view(
        paramsByteData.buffer,
        0,
        paramsByteData.lengthInBytes,
      );
    }
    await SystemChannels.platform_views.invokeMethod<void>('create', args);
    if (onFocus != null) {
      _instance._focusCallbacks[id] = onFocus;
    }
    return AppKitViewController._(id, layoutDirection);
  }
}

class AndroidPointerProperties {
  const AndroidPointerProperties({
    required this.id,
    required this.toolType,
  });

  final int id;

  final int toolType;

  static const int kToolTypeUnknown = 0;

  static const int kToolTypeFinger = 1;

  static const int kToolTypeStylus = 2;

  static const int kToolTypeMouse = 3;

  static const int kToolTypeEraser = 4;

  List<int> _asList() => <int>[id, toolType];

  @override
  String toString() {
    return '${objectRuntimeType(this, 'AndroidPointerProperties')}(id: $id, toolType: $toolType)';
  }
}

class AndroidPointerCoords {
  const AndroidPointerCoords({
    required this.orientation,
    required this.pressure,
    required this.size,
    required this.toolMajor,
    required this.toolMinor,
    required this.touchMajor,
    required this.touchMinor,
    required this.x,
    required this.y,
  });

  final double orientation;

  final double pressure;

  final double size;

  final double toolMajor;

  final double toolMinor;

  final double touchMajor;

  final double touchMinor;

  final double x;

  final double y;

  List<double> _asList() {
    return <double>[
      orientation,
      pressure,
      size,
      toolMajor,
      toolMinor,
      touchMajor,
      touchMinor,
      x,
      y,
    ];
  }

  @override
  String toString() {
    return '${objectRuntimeType(this, 'AndroidPointerCoords')}(orientation: $orientation, pressure: $pressure, size: $size, toolMajor: $toolMajor, toolMinor: $toolMinor, touchMajor: $touchMajor, touchMinor: $touchMinor, x: $x, y: $y)';
  }
}

class AndroidMotionEvent {
  AndroidMotionEvent({
    required this.downTime,
    required this.eventTime,
    required this.action,
    required this.pointerCount,
    required this.pointerProperties,
    required this.pointerCoords,
    required this.metaState,
    required this.buttonState,
    required this.xPrecision,
    required this.yPrecision,
    required this.deviceId,
    required this.edgeFlags,
    required this.source,
    required this.flags,
    required this.motionEventId,
  }) : assert(pointerProperties.length == pointerCount),
       assert(pointerCoords.length == pointerCount);

  final int downTime;

  final int eventTime;

  final int action;

  final int pointerCount;

  final List<AndroidPointerProperties> pointerProperties;

  final List<AndroidPointerCoords> pointerCoords;

  final int metaState;

  final int buttonState;

  final double xPrecision;

  final double yPrecision;

  final int deviceId;

  final int edgeFlags;

  final int source;

  final int flags;

  final int motionEventId;

  List<dynamic> _asList(int viewId) {
    return <dynamic>[
      viewId,
      downTime,
      eventTime,
      action,
      pointerCount,
      pointerProperties.map<List<int>>((AndroidPointerProperties p) => p._asList()).toList(),
      pointerCoords.map<List<double>>((AndroidPointerCoords p) => p._asList()).toList(),
      metaState,
      buttonState,
      xPrecision,
      yPrecision,
      deviceId,
      edgeFlags,
      source,
      flags,
      motionEventId,
    ];
  }

  @override
  String toString() {
    return 'AndroidPointerEvent(downTime: $downTime, eventTime: $eventTime, action: $action, pointerCount: $pointerCount, pointerProperties: $pointerProperties, pointerCoords: $pointerCoords, metaState: $metaState, buttonState: $buttonState, xPrecision: $xPrecision, yPrecision: $yPrecision, deviceId: $deviceId, edgeFlags: $edgeFlags, source: $source, flags: $flags, motionEventId: $motionEventId)';
  }
}

enum _AndroidViewState {
  waitingForSize,
  creating,
  created,
  disposed,
}

// Helper for converting PointerEvents into AndroidMotionEvents.
class _AndroidMotionEventConverter {
  _AndroidMotionEventConverter();

  final Map<int, AndroidPointerCoords> pointerPositions =
      <int, AndroidPointerCoords>{};
  final Map<int, AndroidPointerProperties> pointerProperties =
      <int, AndroidPointerProperties>{};
  final Set<int> usedAndroidPointerIds = <int>{};

  late PointTransformer pointTransformer;

  int? downTimeMillis;

  void handlePointerDownEvent(PointerDownEvent event) {
    if (pointerProperties.isEmpty) {
      downTimeMillis = event.timeStamp.inMilliseconds;
    }
    int androidPointerId = 0;
    while (usedAndroidPointerIds.contains(androidPointerId)) {
      androidPointerId++;
    }
    usedAndroidPointerIds.add(androidPointerId);
    pointerProperties[event.pointer] = propertiesFor(event, androidPointerId);
  }

  void updatePointerPositions(PointerEvent event) {
    final Offset position = pointTransformer(event.position);
    pointerPositions[event.pointer] = AndroidPointerCoords(
      orientation: event.orientation,
      pressure: event.pressure,
      size: event.size,
      toolMajor: event.radiusMajor,
      toolMinor: event.radiusMinor,
      touchMajor: event.radiusMajor,
      touchMinor: event.radiusMinor,
      x: position.dx,
      y: position.dy,
    );
  }

  void _remove(int pointer) {
    pointerPositions.remove(pointer);
    usedAndroidPointerIds.remove(pointerProperties[pointer]!.id);
    pointerProperties.remove(pointer);
    if (pointerProperties.isEmpty) {
      downTimeMillis = null;
    }
  }

  void handlePointerUpEvent(PointerUpEvent event) {
    _remove(event.pointer);
  }

  void handlePointerCancelEvent(PointerCancelEvent event) {
    // The pointer cancel event is handled like pointer up. Normally,
    // the difference is that pointer cancel doesn't perform any action,
    // but in this case neither up or cancel perform any action.
    _remove(event.pointer);
  }

  AndroidMotionEvent? toAndroidMotionEvent(PointerEvent event) {
    final List<int> pointers = pointerPositions.keys.toList();
    final int pointerIdx = pointers.indexOf(event.pointer);
    final int numPointers = pointers.length;

    // This value must match the value in engine's FlutterView.java.
    // This flag indicates whether the original Android pointer events were batched together.
    const int kPointerDataFlagBatched = 1;

    // Android MotionEvent objects can batch information on multiple pointers.
    // Flutter breaks these such batched events into multiple PointerEvent objects.
    // When there are multiple active pointers we accumulate the information for all pointers
    // as we get PointerEvents, and only send it to the embedded Android view when
    // we see the last pointer. This way we achieve the same batching as Android.
    if (event.platformData == kPointerDataFlagBatched ||
        (isSinglePointerAction(event) && pointerIdx < numPointers - 1)) {
      return null;
    }

    final int action;
    if (event is PointerDownEvent) {
      action = numPointers == 1
          ? AndroidViewController.kActionDown
          : AndroidViewController.pointerAction(pointerIdx, AndroidViewController.kActionPointerDown);
    } else if (event is PointerUpEvent) {
      action = numPointers == 1
          ? AndroidViewController.kActionUp
          : AndroidViewController.pointerAction(pointerIdx, AndroidViewController.kActionPointerUp);
    } else if (event is PointerMoveEvent) {
      action = AndroidViewController.kActionMove;
    } else if (event is PointerCancelEvent) {
      action = AndroidViewController.kActionCancel;
    } else {
      return null;
    }

    return AndroidMotionEvent(
      downTime: downTimeMillis!,
      eventTime: event.timeStamp.inMilliseconds,
      action: action,
      pointerCount: pointerPositions.length,
      pointerProperties: pointers
          .map<AndroidPointerProperties>((int i) => pointerProperties[i]!)
          .toList(),
      pointerCoords: pointers
          .map<AndroidPointerCoords>((int i) => pointerPositions[i]!)
          .toList(),
      metaState: 0,
      buttonState: 0,
      xPrecision: 1.0,
      yPrecision: 1.0,
      deviceId: 0,
      edgeFlags: 0,
      source: 0,
      flags: 0,
      motionEventId: event.embedderId,
    );
  }

  AndroidPointerProperties propertiesFor(PointerEvent event, int pointerId) {
    int toolType = AndroidPointerProperties.kToolTypeUnknown;
    switch (event.kind) {
      case PointerDeviceKind.touch:
      case PointerDeviceKind.trackpad:
        toolType = AndroidPointerProperties.kToolTypeFinger;
      case PointerDeviceKind.mouse:
        toolType = AndroidPointerProperties.kToolTypeMouse;
      case PointerDeviceKind.stylus:
        toolType = AndroidPointerProperties.kToolTypeStylus;
      case PointerDeviceKind.invertedStylus:
        toolType = AndroidPointerProperties.kToolTypeEraser;
      case PointerDeviceKind.unknown:
        toolType = AndroidPointerProperties.kToolTypeUnknown;
    }
    return AndroidPointerProperties(id: pointerId, toolType: toolType);
  }

  bool isSinglePointerAction(PointerEvent event) =>
      event is! PointerDownEvent && event is! PointerUpEvent;
}

class _CreationParams {
  const _CreationParams(this.data, this.codec);
  final dynamic data;
  final MessageCodec<dynamic> codec;
}

// TODO(bparrishMines): Remove abstract methods that are not required by all subclasses.
abstract class AndroidViewController extends PlatformViewController {
  AndroidViewController._({
    required this.viewId,
    required String viewType,
    required TextDirection layoutDirection,
    dynamic creationParams,
    MessageCodec<dynamic>? creationParamsCodec,
  })  : assert(creationParams == null || creationParamsCodec != null),
        _viewType = viewType,
        _layoutDirection = layoutDirection,
        _creationParams = creationParams == null ? null : _CreationParams(creationParams, creationParamsCodec!);

  static const int kActionDown = 0;

  static const int kActionUp = 1;

  static const int kActionMove = 2;

  static const int kActionCancel = 3;

  static const int kActionPointerDown = 5;

  static const int kActionPointerUp = 6;

  static const int kAndroidLayoutDirectionLtr = 0;

  static const int kAndroidLayoutDirectionRtl = 1;

  @override
  final int viewId;

  final String _viewType;

  // Helps convert PointerEvents to AndroidMotionEvents.
  final _AndroidMotionEventConverter _motionEventConverter =
      _AndroidMotionEventConverter();

  TextDirection _layoutDirection;

  _AndroidViewState _state = _AndroidViewState.waitingForSize;

  final _CreationParams? _creationParams;

  final List<PlatformViewCreatedCallback> _platformViewCreatedCallbacks =
      <PlatformViewCreatedCallback>[];

  static int _getAndroidDirection(TextDirection direction) {
    switch (direction) {
      case TextDirection.ltr:
        return kAndroidLayoutDirectionLtr;
      case TextDirection.rtl:
        return kAndroidLayoutDirectionRtl;
    }
  }

  static int pointerAction(int pointerId, int action) {
    return ((pointerId << 8) & 0xff00) | (action & 0xff);
  }

  Future<void> _sendDisposeMessage();

  bool get _createRequiresSize;

  Future<void> _sendCreateMessage({required covariant Size? size, Offset? position});

  Future<Size> _sendResizeMessage(Size size);

  @override
  bool get awaitingCreation => _state == _AndroidViewState.waitingForSize;

  @override
  Future<void> create({Size? size, Offset? position}) async {
    assert(_state != _AndroidViewState.disposed, 'trying to create a disposed Android view');
    assert(_state == _AndroidViewState.waitingForSize, 'Android view is already sized. View id: $viewId');

    if (_createRequiresSize && size == null) {
      // Wait for a setSize call.
      return;
    }

    _state = _AndroidViewState.creating;
    await _sendCreateMessage(size: size, position: position);
    _state = _AndroidViewState.created;

    for (final PlatformViewCreatedCallback callback in _platformViewCreatedCallbacks) {
      callback(viewId);
    }
  }

  Future<Size> setSize(Size size) async {
    assert(_state != _AndroidViewState.disposed, 'Android view is disposed. View id: $viewId');
    if (_state == _AndroidViewState.waitingForSize) {
      // Either `create` hasn't been called, or it couldn't run due to missing
      // size information, so create the view now.
      await create(size: size);
      return size;
    } else {
      return _sendResizeMessage(size);
    }
  }

  Future<void> setOffset(Offset off);

  int? get textureId;

  bool get requiresViewComposition => false;

  Future<void> sendMotionEvent(AndroidMotionEvent event) async {
    await SystemChannels.platform_views.invokeMethod<dynamic>(
      'touch',
      event._asList(viewId),
    );
  }

  PointTransformer get pointTransformer => _motionEventConverter.pointTransformer;
  set pointTransformer(PointTransformer transformer) {
    _motionEventConverter.pointTransformer = transformer;
  }

  bool get isCreated => _state == _AndroidViewState.created;

  void addOnPlatformViewCreatedListener(PlatformViewCreatedCallback listener) {
    assert(_state != _AndroidViewState.disposed);
    _platformViewCreatedCallbacks.add(listener);
  }

  void removeOnPlatformViewCreatedListener(PlatformViewCreatedCallback listener) {
    assert(_state != _AndroidViewState.disposed);
    _platformViewCreatedCallbacks.remove(listener);
  }

  @visibleForTesting
  List<PlatformViewCreatedCallback> get createdCallbacks => _platformViewCreatedCallbacks;

  Future<void> setLayoutDirection(TextDirection layoutDirection) async {
    assert(
      _state != _AndroidViewState.disposed,
      'trying to set a layout direction for a disposed Android view. View id: $viewId',
    );

    if (layoutDirection == _layoutDirection) {
      return;
    }

    _layoutDirection = layoutDirection;

    // If the view was not yet created we just update _layoutDirection and return, as the new
    // direction will be used in _create.
    if (_state == _AndroidViewState.waitingForSize) {
      return;
    }

    await SystemChannels.platform_views
        .invokeMethod<void>('setDirection', <String, dynamic>{
      'id': viewId,
      'direction': _getAndroidDirection(layoutDirection),
    });
  }

  @override
  Future<void> dispatchPointerEvent(PointerEvent event) async {
    if (event is PointerHoverEvent) {
      return;
    }

    if (event is PointerDownEvent) {
      _motionEventConverter.handlePointerDownEvent(event);
    }

    _motionEventConverter.updatePointerPositions(event);

    final AndroidMotionEvent? androidEvent =
        _motionEventConverter.toAndroidMotionEvent(event);

    if (event is PointerUpEvent) {
      _motionEventConverter.handlePointerUpEvent(event);
    } else if (event is PointerCancelEvent) {
      _motionEventConverter.handlePointerCancelEvent(event);
    }

    if (androidEvent != null) {
      await sendMotionEvent(androidEvent);
    }
  }

  @override
  Future<void> clearFocus() {
    if (_state != _AndroidViewState.created) {
      return Future<void>.value();
    }
    return SystemChannels.platform_views.invokeMethod<void>('clearFocus', viewId);
  }

  @override
  Future<void> dispose() async {
    final _AndroidViewState state = _state;
    _state = _AndroidViewState.disposed;
    _platformViewCreatedCallbacks.clear();
    PlatformViewsService._instance._focusCallbacks.remove(viewId);
    if (state == _AndroidViewState.creating || state == _AndroidViewState.created) {
      await _sendDisposeMessage();
    }
  }
}

class SurfaceAndroidViewController extends AndroidViewController {
    SurfaceAndroidViewController._({
    required super.viewId,
    required super.viewType,
    required super.layoutDirection,
    super.creationParams,
    super.creationParamsCodec,
  })  : super._();

  // By default, assume the implementation will be texture-based.
  _AndroidViewControllerInternals _internals = _TextureAndroidViewControllerInternals();

  @override
  bool get _createRequiresSize => true;

  @override
  Future<bool> _sendCreateMessage({required Size size, Offset? position}) async {
    assert(!size.isEmpty, 'trying to create $TextureAndroidViewController without setting a valid size.');

    final dynamic response = await _AndroidViewControllerInternals.sendCreateMessage(
      viewId: viewId,
      viewType: _viewType,
      hybrid: false,
      hybridFallback: true,
      layoutDirection: _layoutDirection,
      creationParams: _creationParams,
      size: size,
      position: position,
    );
    if (response is int) {
      (_internals as _TextureAndroidViewControllerInternals).textureId = response;
    } else {
      // A null response indicates fallback to Hybrid Composition, so swap out
      // the implementation.
      _internals = _HybridAndroidViewControllerInternals();
    }
    return true;
  }

  @override
  int? get textureId {
    return _internals.textureId;
  }

  @override
  bool get requiresViewComposition {
    return _internals.requiresViewComposition;
  }

  @override
  Future<void> _sendDisposeMessage() {
    return _internals.sendDisposeMessage(viewId: viewId);
  }

  @override
  Future<Size> _sendResizeMessage(Size size) {
    return _internals.setSize(size, viewId: viewId, viewState: _state);
  }

  @override
  Future<void> setOffset(Offset off) {
    return _internals.setOffset(off, viewId: viewId, viewState: _state);
  }
}

class ExpensiveAndroidViewController extends AndroidViewController {
  ExpensiveAndroidViewController._({
    required super.viewId,
    required super.viewType,
    required super.layoutDirection,
    super.creationParams,
    super.creationParamsCodec,
  })  : super._();

  final _AndroidViewControllerInternals _internals = _HybridAndroidViewControllerInternals();

  @override
  bool get _createRequiresSize => false;

  @override
  Future<void> _sendCreateMessage({required Size? size, Offset? position}) async {
    await _AndroidViewControllerInternals.sendCreateMessage(
      viewId: viewId,
      viewType: _viewType,
      hybrid: true,
      layoutDirection: _layoutDirection,
      creationParams: _creationParams,
      position: position,
    );
  }

  @override
  int? get textureId {
    return _internals.textureId;
  }

  @override
  bool get requiresViewComposition {
    return _internals.requiresViewComposition;
  }

  @override
  Future<void> _sendDisposeMessage() {
    return _internals.sendDisposeMessage(viewId: viewId);
  }

  @override
  Future<Size> _sendResizeMessage(Size size) {
    return _internals.setSize(size, viewId: viewId, viewState: _state);
  }

  @override
  Future<void> setOffset(Offset off) {
    return _internals.setOffset(off, viewId: viewId, viewState: _state);
  }
}

class TextureAndroidViewController extends AndroidViewController {
  TextureAndroidViewController._({
    required super.viewId,
    required super.viewType,
    required super.layoutDirection,
    super.creationParams,
    super.creationParamsCodec,
  }) : super._();

  final _TextureAndroidViewControllerInternals _internals = _TextureAndroidViewControllerInternals();

  @override
  bool get _createRequiresSize => true;

  @override
  Future<void> _sendCreateMessage({required Size size, Offset? position}) async {
    assert(!size.isEmpty, 'trying to create $TextureAndroidViewController without setting a valid size.');

    _internals.textureId = await _AndroidViewControllerInternals.sendCreateMessage(
      viewId: viewId,
      viewType: _viewType,
      hybrid: false,
      layoutDirection: _layoutDirection,
      creationParams: _creationParams,
      size: size,
      position: position,
    ) as int;
  }

  @override
  int? get textureId {
    return _internals.textureId;
  }

  @override
  bool get requiresViewComposition {
    return _internals.requiresViewComposition;
  }

  @override
  Future<void> _sendDisposeMessage() {
    return _internals.sendDisposeMessage(viewId: viewId);
  }

  @override
  Future<Size> _sendResizeMessage(Size size) {
    return _internals.setSize(size, viewId: viewId, viewState: _state);
  }

  @override
  Future<void> setOffset(Offset off) {
    return _internals.setOffset(off, viewId: viewId, viewState: _state);
  }
}

// The base class for an implementation of AndroidViewController.
//
// Subclasses should correspond to different rendering modes for platform
// views, and match different mode logic on the engine side.
abstract class _AndroidViewControllerInternals {
  // Sends a create message with the given parameters, and returns the result
  // if any.
  //
  // This uses a dynamic return because depending on the mode that is selected
  // on the native side, the return type is different. Callers should cast
  // depending on the possible return types for their arguments.
  static Future<dynamic> sendCreateMessage({
      required int viewId,
      required String viewType,
      required TextDirection layoutDirection,
      required bool hybrid,
      bool hybridFallback = false,
      _CreationParams? creationParams,
      Size? size,
      Offset? position}) {
    final Map<String, dynamic> args = <String, dynamic>{
      'id': viewId,
      'viewType': viewType,
      'direction': AndroidViewController._getAndroidDirection(layoutDirection),
      if (hybrid) 'hybrid': hybrid,
      if (size != null) 'width': size.width,
      if (size != null) 'height': size.height,
      if (hybridFallback) 'hybridFallback': hybridFallback,
      if (position != null) 'left': position.dx,
      if (position != null) 'top': position.dy,
    };
    if (creationParams != null) {
      final ByteData paramsByteData = creationParams.codec.encodeMessage(creationParams.data)!;
      args['params'] = Uint8List.view(
        paramsByteData.buffer,
        0,
        paramsByteData.lengthInBytes,
      );
    }
    return SystemChannels.platform_views.invokeMethod<dynamic>('create', args);
  }

  int? get textureId;

  bool get requiresViewComposition;

  Future<Size> setSize(
    Size size, {
    required int viewId,
    required _AndroidViewState viewState,
  });

  Future<void> setOffset(
    Offset offset, {
    required int viewId,
    required _AndroidViewState viewState,
  });

  Future<void> sendDisposeMessage({required int viewId});
}

// An AndroidViewController implementation for views whose contents are
// displayed via a texture rather than directly in a native view.
//
// This is used for both Virtual Display and Texture Layer Hybrid Composition.
class _TextureAndroidViewControllerInternals extends _AndroidViewControllerInternals {
  _TextureAndroidViewControllerInternals();

  Offset _offset = Offset.zero;

  @override
  int? textureId;

  @override
  bool get requiresViewComposition => false;

  @override
  Future<Size> setSize(
    Size size, {
    required int viewId,
    required _AndroidViewState viewState,
  }) async {
    assert(viewState != _AndroidViewState.waitingForSize, 'Android view must have an initial size. View id: $viewId');
    assert(!size.isEmpty);

    final Map<Object?, Object?>? meta = await SystemChannels.platform_views.invokeMapMethod<Object?, Object?>(
      'resize',
      <String, dynamic>{
        'id': viewId,
        'width': size.width,
        'height': size.height,
      },
    );
    assert(meta != null);
    assert(meta!.containsKey('width'));
    assert(meta!.containsKey('height'));
    return Size(meta!['width']! as double, meta['height']! as double);
  }

  @override
  Future<void> setOffset(
    Offset offset, {
    required int viewId,
    required _AndroidViewState viewState,
  }) async {
    if (offset == _offset) {
      return;
    }

    // Don't set the offset unless the Android view has been created.
    // The implementation of this method channel throws if the Android view for this viewId
    // isn't addressable.
    if (viewState != _AndroidViewState.created) {
      return;
    }

    _offset = offset;

    await SystemChannels.platform_views.invokeMethod<void>(
      'offset',
      <String, dynamic>{
        'id': viewId,
        'top': offset.dy,
        'left': offset.dx,
      },
    );
  }

  @override
  Future<void> sendDisposeMessage({required int viewId}) {
    return SystemChannels
        .platform_views.invokeMethod<void>('dispose', <String, dynamic>{
      'id': viewId,
      'hybrid': false,
    });
  }
}

// An AndroidViewController implementation for views whose contents are
// displayed directly in a native view.
//
// This is used for Hybrid Composition.
class _HybridAndroidViewControllerInternals extends _AndroidViewControllerInternals {
  @override
  int get textureId {
    throw UnimplementedError('Not supported for hybrid composition.');
  }

  @override
  bool get requiresViewComposition => true;

  @override
  Future<Size> setSize(
    Size size, {
    required int viewId,
    required _AndroidViewState viewState,
  }) {
    throw UnimplementedError('Not supported for hybrid composition.');
  }

  @override
  Future<void> setOffset(
    Offset offset, {
    required int viewId,
    required _AndroidViewState viewState,
  }) {
    throw UnimplementedError('Not supported for hybrid composition.');
  }

  @override
  Future<void> sendDisposeMessage({required int viewId}) {
    return SystemChannels.platform_views.invokeMethod<void>('dispose', <String, dynamic>{
      'id': viewId,
      'hybrid': true,
    });
  }
}

abstract class DarwinPlatformViewController {
  DarwinPlatformViewController(
    this.id,
    TextDirection layoutDirection,
  ) : _layoutDirection = layoutDirection;

  final int id;

  bool _debugDisposed = false;

  TextDirection _layoutDirection;

  Future<void> setLayoutDirection(TextDirection layoutDirection) async {
    assert(!_debugDisposed, 'trying to set a layout direction for a disposed iOS UIView. View id: $id');

    if (layoutDirection == _layoutDirection) {
      return;
    }

    _layoutDirection = layoutDirection;

    // TODO(amirh): invoke the iOS platform views channel direction method once available.
  }

  Future<void> acceptGesture() {
    final Map<String, dynamic> args = <String, dynamic>{
      'id': id,
    };
    return SystemChannels.platform_views.invokeMethod('acceptGesture', args);
  }

  Future<void> rejectGesture() {
    final Map<String, dynamic> args = <String, dynamic>{
      'id': id,
    };
    return SystemChannels.platform_views.invokeMethod('rejectGesture', args);
  }

  Future<void> dispose() async {
    _debugDisposed = true;
    await SystemChannels.platform_views.invokeMethod<void>('dispose', id);
    PlatformViewsService._instance._focusCallbacks.remove(id);
  }
}

class UiKitViewController extends DarwinPlatformViewController {
  UiKitViewController._(
    super.id,
    super.layoutDirection,
  );
}

class AppKitViewController extends DarwinPlatformViewController {
  AppKitViewController._(
    super.id,
    super.layoutDirection,
  );
}

abstract class PlatformViewController {
  int get viewId;

  bool get awaitingCreation => false;

  Future<void> dispatchPointerEvent(PointerEvent event);

  Future<void> create({Size? size, Offset? position}) async {}

  Future<void> dispose();

  Future<void> clearFocus();
}