// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:ui' as ui show Codec, FrameInfo, Image;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

@immutable
class ImageInfo {
  const ImageInfo({ required this.image, this.scale = 1.0, this.debugLabel });

  ImageInfo clone() {
    return ImageInfo(
      image: image.clone(),
      scale: scale,
      debugLabel: debugLabel,
    );
  }

  bool isCloneOf(ImageInfo other) {
    return other.image.isCloneOf(image)
        && scale == scale
        && other.debugLabel == debugLabel;
  }

  final ui.Image image;

  int get sizeBytes => image.height * image.width * 4;

  final double scale;

  final String? debugLabel;

  void dispose() {
    assert((image.debugGetOpenHandleStackTraces()?.length ?? 1) > 0);
    image.dispose();
  }

  @override
  String toString() => '${debugLabel != null ? '$debugLabel ' : ''}$image @ ${debugFormatDouble(scale)}x';

  @override
  int get hashCode => Object.hash(image, scale, debugLabel);

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ImageInfo
        && other.image == image
        && other.scale == scale
        && other.debugLabel == debugLabel;
  }
}

@immutable
class ImageStreamListener {
  const ImageStreamListener(
    this.onImage, {
    this.onChunk,
    this.onError,
  });

  final ImageListener onImage;

  final ImageChunkListener? onChunk;

  final ImageErrorListener? onError;

  @override
  int get hashCode => Object.hash(onImage, onChunk, onError);

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ImageStreamListener
        && other.onImage == onImage
        && other.onChunk == onChunk
        && other.onError == onError;
  }
}

typedef ImageListener = void Function(ImageInfo image, bool synchronousCall);

typedef ImageChunkListener = void Function(ImageChunkEvent event);

typedef ImageErrorListener = void Function(Object exception, StackTrace? stackTrace);

@immutable
class ImageChunkEvent with Diagnosticable {
  const ImageChunkEvent({
    required this.cumulativeBytesLoaded,
    required this.expectedTotalBytes,
  }) : assert(cumulativeBytesLoaded >= 0),
       assert(expectedTotalBytes == null || expectedTotalBytes >= 0);

  final int cumulativeBytesLoaded;

  final int? expectedTotalBytes;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('cumulativeBytesLoaded', cumulativeBytesLoaded));
    properties.add(IntProperty('expectedTotalBytes', expectedTotalBytes));
  }
}

class ImageStream with Diagnosticable {
  ImageStream();

  ImageStreamCompleter? get completer => _completer;
  ImageStreamCompleter? _completer;

  List<ImageStreamListener>? _listeners;

  void setCompleter(ImageStreamCompleter value) {
    assert(_completer == null);
    _completer = value;
    if (_listeners != null) {
      final List<ImageStreamListener> initialListeners = _listeners!;
      _listeners = null;
      _completer!._addingInitialListeners = true;
      initialListeners.forEach(_completer!.addListener);
      _completer!._addingInitialListeners = false;
    }
  }

  void addListener(ImageStreamListener listener) {
    if (_completer != null) {
      return _completer!.addListener(listener);
    }
    _listeners ??= <ImageStreamListener>[];
    _listeners!.add(listener);
  }

  void removeListener(ImageStreamListener listener) {
    if (_completer != null) {
      return _completer!.removeListener(listener);
    }
    assert(_listeners != null);
    for (int i = 0; i < _listeners!.length; i += 1) {
      if (_listeners![i] == listener) {
        _listeners!.removeAt(i);
        break;
      }
    }
  }

  Object get key => _completer ?? this;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ObjectFlagProperty<ImageStreamCompleter>(
      'completer',
      _completer,
      ifPresent: _completer?.toStringShort(),
      ifNull: 'unresolved',
    ));
    properties.add(ObjectFlagProperty<List<ImageStreamListener>>(
      'listeners',
      _listeners,
      ifPresent: '${_listeners?.length} listener${_listeners?.length == 1 ? "" : "s" }',
      ifNull: 'no listeners',
      level: _completer != null ? DiagnosticLevel.hidden : DiagnosticLevel.info,
    ));
    _completer?.debugFillProperties(properties);
  }
}

class ImageStreamCompleterHandle {
  ImageStreamCompleterHandle._(ImageStreamCompleter this._completer) {
    _completer!._keepAliveHandles += 1;
  }

  ImageStreamCompleter? _completer;

  void dispose() {
    assert(_completer != null);
    assert(_completer!._keepAliveHandles > 0);
    assert(!_completer!._disposed);

    _completer!._keepAliveHandles -= 1;
    _completer!._maybeDispose();
    _completer = null;
  }
}

abstract class ImageStreamCompleter with Diagnosticable {
  final List<ImageStreamListener> _listeners = <ImageStreamListener>[];
  final List<ImageErrorListener> _ephemeralErrorListeners = <ImageErrorListener>[];
  ImageInfo? _currentImage;
  FlutterErrorDetails? _currentError;

  String? debugLabel;

  @protected
  @visibleForTesting
  bool get hasListeners => _listeners.isNotEmpty;

  bool _hadAtLeastOneListener = false;

  bool _addingInitialListeners = false;

  void addListener(ImageStreamListener listener) {
    _checkDisposed();
    _hadAtLeastOneListener = true;
    _listeners.add(listener);
    if (_currentImage != null) {
      try {
        listener.onImage(_currentImage!.clone(), !_addingInitialListeners);
      } catch (exception, stack) {
        reportError(
          context: ErrorDescription('by a synchronously-called image listener'),
          exception: exception,
          stack: stack,
        );
      }
    }
    if (_currentError != null && listener.onError != null) {
      try {
        listener.onError!(_currentError!.exception, _currentError!.stack);
      } catch (newException, newStack) {
        if (newException != _currentError!.exception) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: newException,
              library: 'image resource service',
              context: ErrorDescription('by a synchronously-called image error listener'),
              stack: newStack,
            ),
          );
        }
      }
    }
  }

  void addEphemeralErrorListener(ImageErrorListener listener) {
    _checkDisposed();
    if (_currentError != null) {
      // immediately fire the listener, and no need to add to _ephemeralErrorListeners
      try {
        listener(_currentError!.exception, _currentError!.stack);
      } catch (newException, newStack) {
        if (newException != _currentError!.exception) {
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: newException,
              library: 'image resource service',
              context: ErrorDescription('by a synchronously-called image error listener'),
              stack: newStack,
            ),
          );
        }
      }
    } else if (_currentImage == null) {
      // add to _ephemeralErrorListeners to wait for the error,
      // only if no image has been loaded
      _ephemeralErrorListeners.add(listener);
    }
  }

  int _keepAliveHandles = 0;
  ImageStreamCompleterHandle keepAlive() {
    _checkDisposed();
    return ImageStreamCompleterHandle._(this);
  }

  void removeListener(ImageStreamListener listener) {
    _checkDisposed();
    for (int i = 0; i < _listeners.length; i += 1) {
      if (_listeners[i] == listener) {
        _listeners.removeAt(i);
        break;
      }
    }
    if (_listeners.isEmpty) {
      final List<VoidCallback> callbacks = _onLastListenerRemovedCallbacks.toList();
      for (final VoidCallback callback in callbacks) {
        callback();
      }
      _onLastListenerRemovedCallbacks.clear();
      _maybeDispose();
    }
  }

  bool _disposed = false;

  @mustCallSuper
  void _maybeDispose() {
    if (!_hadAtLeastOneListener || _disposed || _listeners.isNotEmpty || _keepAliveHandles != 0) {
      return;
    }

    _ephemeralErrorListeners.clear();
    _currentImage?.dispose();
    _currentImage = null;
    _disposed = true;
  }

  void _checkDisposed() {
    if (_disposed) {
      throw StateError(
        'Stream has been disposed.\n'
        'An ImageStream is considered disposed once at least one listener has '
        'been added and subsequently all listeners have been removed and no '
        'handles are outstanding from the keepAlive method.\n'
        'To resolve this error, maintain at least one listener on the stream, '
        'or create an ImageStreamCompleterHandle from the keepAlive '
        'method, or create a new stream for the image.',
      );
    }
  }

  final List<VoidCallback> _onLastListenerRemovedCallbacks = <VoidCallback>[];

  void addOnLastListenerRemovedCallback(VoidCallback callback) {
    _checkDisposed();
    _onLastListenerRemovedCallbacks.add(callback);
  }

  void removeOnLastListenerRemovedCallback(VoidCallback callback) {
    _checkDisposed();
    _onLastListenerRemovedCallbacks.remove(callback);
  }

  @protected
  @pragma('vm:notify-debugger-on-exception')
  void setImage(ImageInfo image) {
    _checkDisposed();
    _currentImage?.dispose();
    _currentImage = image;

    _ephemeralErrorListeners.clear();

    if (_listeners.isEmpty) {
      return;
    }
    // Make a copy to allow for concurrent modification.
    final List<ImageStreamListener> localListeners =
        List<ImageStreamListener>.of(_listeners);
    for (final ImageStreamListener listener in localListeners) {
      try {
        listener.onImage(image.clone(), false);
      } catch (exception, stack) {
        reportError(
          context: ErrorDescription('by an image listener'),
          exception: exception,
          stack: stack,
        );
      }
    }
  }

  @pragma('vm:notify-debugger-on-exception')
  void reportError({
    DiagnosticsNode? context,
    required Object exception,
    StackTrace? stack,
    InformationCollector? informationCollector,
    bool silent = false,
  }) {
    _currentError = FlutterErrorDetails(
      exception: exception,
      stack: stack,
      library: 'image resource service',
      context: context,
      informationCollector: informationCollector,
      silent: silent,
    );

    // Make a copy to allow for concurrent modification.
    final List<ImageErrorListener> localErrorListeners = <ImageErrorListener>[
      ..._listeners
          .map<ImageErrorListener?>((ImageStreamListener listener) => listener.onError)
          .whereType<ImageErrorListener>(),
      ..._ephemeralErrorListeners,
    ];

    _ephemeralErrorListeners.clear();

    bool handled = false;
    for (final ImageErrorListener errorListener in localErrorListeners) {
      try {
        errorListener(exception, stack);
        handled = true;
      } catch (newException, newStack) {
        if (newException != exception) {
          FlutterError.reportError(
            FlutterErrorDetails(
              context: ErrorDescription('when reporting an error to an image listener'),
              library: 'image resource service',
              exception: newException,
              stack: newStack,
            ),
          );
        }
      }
    }
    if (!handled) {
      FlutterError.reportError(_currentError!);
    }
  }

  @protected
  void reportImageChunkEvent(ImageChunkEvent event) {
    _checkDisposed();
    if (hasListeners) {
      // Make a copy to allow for concurrent modification.
      final List<ImageChunkListener> localListeners = _listeners
          .map<ImageChunkListener?>((ImageStreamListener listener) => listener.onChunk)
          .whereType<ImageChunkListener>()
          .toList();
      for (final ImageChunkListener listener in localListeners) {
        listener(event);
      }
    }
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder description) {
    super.debugFillProperties(description);
    description.add(DiagnosticsProperty<ImageInfo>('current', _currentImage, ifNull: 'unresolved', showName: false));
    description.add(ObjectFlagProperty<List<ImageStreamListener>>(
      'listeners',
      _listeners,
      ifPresent: '${_listeners.length} listener${_listeners.length == 1 ? "" : "s" }',
    ));
    description.add(ObjectFlagProperty<List<ImageErrorListener>>(
      'ephemeralErrorListeners',
      _ephemeralErrorListeners,
      ifPresent: '${_ephemeralErrorListeners.length} ephemeralErrorListener${_ephemeralErrorListeners.length == 1 ? "" : "s" }',
    ));
    description.add(FlagProperty('disposed', value: _disposed, ifTrue: '<disposed>'));
  }
}

class OneFrameImageStreamCompleter extends ImageStreamCompleter {
  OneFrameImageStreamCompleter(Future<ImageInfo> image, { InformationCollector? informationCollector }) {
    image.then<void>(setImage, onError: (Object error, StackTrace stack) {
      reportError(
        context: ErrorDescription('resolving a single-frame image stream'),
        exception: error,
        stack: stack,
        informationCollector: informationCollector,
        silent: true,
      );
    });
  }
}

class MultiFrameImageStreamCompleter extends ImageStreamCompleter {
  MultiFrameImageStreamCompleter({
    required Future<ui.Codec> codec,
    required double scale,
    String? debugLabel,
    Stream<ImageChunkEvent>? chunkEvents,
    InformationCollector? informationCollector,
  }) : _informationCollector = informationCollector,
       _scale = scale {
    this.debugLabel = debugLabel;
    codec.then<void>(_handleCodecReady, onError: (Object error, StackTrace stack) {
      reportError(
        context: ErrorDescription('resolving an image codec'),
        exception: error,
        stack: stack,
        informationCollector: informationCollector,
        silent: true,
      );
    });
    if (chunkEvents != null) {
      _chunkSubscription = chunkEvents.listen(reportImageChunkEvent,
        onError: (Object error, StackTrace stack) {
          reportError(
            context: ErrorDescription('loading an image'),
            exception: error,
            stack: stack,
            informationCollector: informationCollector,
            silent: true,
          );
        },
      );
    }
  }

  StreamSubscription<ImageChunkEvent>? _chunkSubscription;
  ui.Codec? _codec;
  final double _scale;
  final InformationCollector? _informationCollector;
  ui.FrameInfo? _nextFrame;
  // When the current was first shown.
  late Duration _shownTimestamp;
  // The requested duration for the current frame;
  Duration? _frameDuration;
  // How many frames have been emitted so far.
  int _framesEmitted = 0;
  Timer? _timer;

  // Used to guard against registering multiple _handleAppFrame callbacks for the same frame.
  bool _frameCallbackScheduled = false;

  void _handleCodecReady(ui.Codec codec) {
    _codec = codec;
    assert(_codec != null);

    if (hasListeners) {
      _decodeNextFrameAndSchedule();
    }
  }

  void _handleAppFrame(Duration timestamp) {
    _frameCallbackScheduled = false;
    if (!hasListeners) {
      return;
    }
    assert(_nextFrame != null);
    if (_isFirstFrame() || _hasFrameDurationPassed(timestamp)) {
      _emitFrame(ImageInfo(
        image: _nextFrame!.image.clone(),
        scale: _scale,
        debugLabel: debugLabel,
      ));
      _shownTimestamp = timestamp;
      _frameDuration = _nextFrame!.duration;
      _nextFrame!.image.dispose();
      _nextFrame = null;
      final int completedCycles = _framesEmitted ~/ _codec!.frameCount;
      if (_codec!.repetitionCount == -1 || completedCycles <= _codec!.repetitionCount) {
        _decodeNextFrameAndSchedule();
      }
      return;
    }
    final Duration delay = _frameDuration! - (timestamp - _shownTimestamp);
    _timer = Timer(delay * timeDilation, () {
      _scheduleAppFrame();
    });
  }

  bool _isFirstFrame() {
    return _frameDuration == null;
  }

  bool _hasFrameDurationPassed(Duration timestamp) {
    return timestamp - _shownTimestamp >= _frameDuration!;
  }

  Future<void> _decodeNextFrameAndSchedule() async {
    // This will be null if we gave it away. If not, it's still ours and it
    // must be disposed of.
    _nextFrame?.image.dispose();
    _nextFrame = null;
    try {
      _nextFrame = await _codec!.getNextFrame();
    } catch (exception, stack) {
      reportError(
        context: ErrorDescription('resolving an image frame'),
        exception: exception,
        stack: stack,
        informationCollector: _informationCollector,
        silent: true,
      );
      return;
    }
    if (_codec!.frameCount == 1) {
      // ImageStreamCompleter listeners removed while waiting for next frame to
      // be decoded.
      // There's no reason to emit the frame without active listeners.
      if (!hasListeners) {
        return;
      }
      // This is not an animated image, just return it and don't schedule more
      // frames.
      _emitFrame(ImageInfo(
        image: _nextFrame!.image.clone(),
        scale: _scale,
        debugLabel: debugLabel,
      ));
      _nextFrame!.image.dispose();
      _nextFrame = null;
      return;
    }
    _scheduleAppFrame();
  }

  void _scheduleAppFrame() {
    if (_frameCallbackScheduled) {
      return;
    }
    _frameCallbackScheduled = true;
    SchedulerBinding.instance.scheduleFrameCallback(_handleAppFrame);
  }

  void _emitFrame(ImageInfo imageInfo) {
    setImage(imageInfo);
    _framesEmitted += 1;
  }

  @override
  void addListener(ImageStreamListener listener) {
    if (!hasListeners && _codec != null && (_currentImage == null || _codec!.frameCount > 1)) {
      _decodeNextFrameAndSchedule();
    }
    super.addListener(listener);
  }

  @override
  void removeListener(ImageStreamListener listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void _maybeDispose() {
    super._maybeDispose();
    if (_disposed) {
      _chunkSubscription?.onData(null);
      _chunkSubscription?.cancel();
      _chunkSubscription = null;
    }
  }
}