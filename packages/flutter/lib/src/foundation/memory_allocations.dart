
import 'dart:ui' as ui;

import 'assertions.dart';
import 'constants.dart';
import 'diagnostics.dart';

const bool _kMemoryAllocations = bool.fromEnvironment('flutter.memory_allocations');

const bool kFlutterMemoryAllocationsEnabled = _kMemoryAllocations || kDebugMode;

const String _dartUiLibrary = 'dart:ui';

class _FieldNames {
  static const String eventType = 'eventType';
  static const String libraryName = 'libraryName';
  static const String className = 'className';
}

abstract class ObjectEvent{
  ObjectEvent({
    required this.object,
  });

  final Object object;

  Map<Object, Map<String, Object>> toMap();
}

typedef ObjectEventListener = void Function(ObjectEvent);

class ObjectCreated extends ObjectEvent {
  ObjectCreated({
    required this.library,
    required this.className,
    required super.object,
  });

  final String library;

  final String className;

  @override
  Map<Object, Map<String, Object>> toMap() {
    return <Object, Map<String, Object>>{object: <String, Object>{
      _FieldNames.libraryName: library,
      _FieldNames.className: className,
      _FieldNames.eventType: 'created',
    }};
  }
}

class ObjectDisposed extends ObjectEvent {
  ObjectDisposed({
    required super.object,
  });

  @override
  Map<Object, Map<String, Object>> toMap() {
    return <Object, Map<String, Object>>{object: <String, Object>{
      _FieldNames.eventType: 'disposed',
    }};
  }
}

class MemoryAllocations {
  MemoryAllocations._();

  static final MemoryAllocations instance = MemoryAllocations._();

  List<ObjectEventListener?>? _listeners;

  void addListener(ObjectEventListener listener){
    if (!kFlutterMemoryAllocationsEnabled) {
      return;
    }
    if (_listeners == null) {
      _listeners = <ObjectEventListener?>[];
      _subscribeToSdkObjects();
    }
    _listeners!.add(listener);
  }

  int _activeDispatchLoops = 0;

  bool _listenersContainNulls = false;

  void removeListener(ObjectEventListener listener){
    if (!kFlutterMemoryAllocationsEnabled) {
      return;
    }
    final List<ObjectEventListener?>? listeners = _listeners;
    if (listeners == null) {
      return;
    }

    if (_activeDispatchLoops > 0) {
      // If there are active dispatch loops, listeners.remove
      // should not be invoked, as it will
      // break the dispatch loops correctness.
      for (int i = 0; i < listeners.length; i++) {
        if (listeners[i] == listener) {
          listeners[i] = null;
          _listenersContainNulls = true;
        }
      }
    } else {
      listeners.removeWhere((ObjectEventListener? l) => l == listener);
      _checkListenersForEmptiness();
    }
  }

  void _tryDefragmentListeners() {
    if (_activeDispatchLoops > 0 || !_listenersContainNulls) {
      return;
    }
    _listeners?.removeWhere((ObjectEventListener? e) => e == null);
    _listenersContainNulls = false;
    _checkListenersForEmptiness();
  }

  void _checkListenersForEmptiness() {
    if (_listeners?.isEmpty ?? false) {
      _listeners = null;
      _unSubscribeFromSdkObjects();
    }
  }

  bool get hasListeners {
    if (!kFlutterMemoryAllocationsEnabled) {
      return false;
    }
    if (_listenersContainNulls) {
      return _listeners?.firstWhere((ObjectEventListener? l) => l != null) != null;
    }
    return _listeners?.isNotEmpty ?? false;
  }

  void dispatchObjectEvent(ObjectEvent event) {
    if (!kFlutterMemoryAllocationsEnabled) {
      return;
    }
    final List<ObjectEventListener?>? listeners = _listeners;
    if (listeners == null || listeners.isEmpty) {
      return;
    }

    _activeDispatchLoops++;
    final int end = listeners.length;
    for (int i = 0; i < end; i++) {
      try {
        listeners[i]?.call(event);
      } catch (exception, stack) {
        final String type = event.object.runtimeType.toString();
        FlutterError.reportError(FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'foundation library',
          context: ErrorDescription('MemoryAllocations while '
          'dispatching notifications for $type'),
          informationCollector: () => <DiagnosticsNode>[
            DiagnosticsProperty<Object>(
              'The $type sending notification was',
              event.object,
              style: DiagnosticsTreeStyle.errorProperty,
            ),
          ],
        ));
      }
    }
    _activeDispatchLoops--;
    _tryDefragmentListeners();
  }

  void dispatchObjectCreated({
    required String library,
    required String className,
    required Object object,
  }) {
    if (!hasListeners) {
      return;
    }
    dispatchObjectEvent(ObjectCreated(
      library: library,
      className: className,
      object: object,
    ));
  }

  void dispatchObjectDisposed({required Object object}) {
    if (!hasListeners) {
      return;
    }
    dispatchObjectEvent(ObjectDisposed(object: object));
  }

  void _subscribeToSdkObjects() {
    assert(ui.Image.onCreate == null);
    assert(ui.Image.onDispose == null);
    assert(ui.Picture.onCreate == null);
    assert(ui.Picture.onDispose == null);
    ui.Image.onCreate = _imageOnCreate;
    ui.Image.onDispose = _imageOnDispose;
    ui.Picture.onCreate = _pictureOnCreate;
    ui.Picture.onDispose = _pictureOnDispose;
  }

  void _unSubscribeFromSdkObjects() {
    assert(ui.Image.onCreate == _imageOnCreate);
    assert(ui.Image.onDispose == _imageOnDispose);
    assert(ui.Picture.onCreate == _pictureOnCreate);
    assert(ui.Picture.onDispose == _pictureOnDispose);
    ui.Image.onCreate = null;
    ui.Image.onDispose = null;
    ui.Picture.onCreate = null;
    ui.Picture.onDispose = null;
  }

  void _imageOnCreate(ui.Image image) {
    dispatchObjectEvent(ObjectCreated(
      library: _dartUiLibrary,
      className: '${ui.Image}',
      object: image,
    ));
  }

  void _pictureOnCreate(ui.Picture picture) {
    dispatchObjectEvent(ObjectCreated(
      library: _dartUiLibrary,
      className: '${ui.Picture}',
      object: picture,
    ));
  }

  void _imageOnDispose(ui.Image image) {
    dispatchObjectEvent(ObjectDisposed(
      object: image,
    ));
  }

  void _pictureOnDispose(ui.Picture picture) {
    dispatchObjectEvent(ObjectDisposed(
      object: picture,
    ));
  }
}