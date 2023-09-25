import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'image_stream.dart';

const int _kDefaultSize = 1000;
const int _kDefaultSizeBytes = 100 << 20; // 100 MiB

class ImageCache {
  final Map<Object, _PendingImage> _pendingImages = <Object, _PendingImage>{};
  final Map<Object, _CachedImage> _cache = <Object, _CachedImage>{};
  final Map<Object, _LiveImage> _liveImages = <Object, _LiveImage>{};

  int get maximumSize => _maximumSize;
  int _maximumSize = _kDefaultSize;
  set maximumSize(int value) {
    assert(value >= 0);
    if (value == maximumSize) {
      return;
    }
    TimelineTask? debugTimelineTask;
    if (!kReleaseMode) {
      debugTimelineTask = TimelineTask()..start(
        'ImageCache.setMaximumSize',
        arguments: <String, dynamic>{'value': value},
      );
    }
    _maximumSize = value;
    if (maximumSize == 0) {
      clear();
    } else {
      _checkCacheSize(debugTimelineTask);
    }
    if (!kReleaseMode) {
      debugTimelineTask!.finish();
    }
  }

  int get currentSize => _cache.length;

  int get maximumSizeBytes => _maximumSizeBytes;
  int _maximumSizeBytes = _kDefaultSizeBytes;
  set maximumSizeBytes(int value) {
    assert(value >= 0);
    if (value == _maximumSizeBytes) {
      return;
    }
    TimelineTask? debugTimelineTask;
    if (!kReleaseMode) {
      debugTimelineTask = TimelineTask()..start(
        'ImageCache.setMaximumSizeBytes',
        arguments: <String, dynamic>{'value': value},
      );
    }
    _maximumSizeBytes = value;
    if (_maximumSizeBytes == 0) {
      clear();
    } else {
      _checkCacheSize(debugTimelineTask);
    }
    if (!kReleaseMode) {
      debugTimelineTask!.finish();
    }
  }

  int get currentSizeBytes => _currentSizeBytes;
  int _currentSizeBytes = 0;

  void clear() {
    if (!kReleaseMode) {
      Timeline.instantSync(
        'ImageCache.clear',
        arguments: <String, dynamic>{
          'pendingImages': _pendingImages.length,
          'keepAliveImages': _cache.length,
          'liveImages': _liveImages.length,
          'currentSizeInBytes': _currentSizeBytes,
        },
      );
    }
    for (final _CachedImage image in _cache.values) {
      image.dispose();
    }
    _cache.clear();
    for (final _PendingImage pendingImage in _pendingImages.values) {
      pendingImage.removeListener();
    }
    _pendingImages.clear();
    _currentSizeBytes = 0;
  }

  bool evict(Object key, { bool includeLive = true }) {
    if (includeLive) {
      // Remove from live images - the cache will not be able to mark
      // it as complete, and it might be getting evicted because it
      // will never complete, e.g. it was loaded in a FakeAsync zone.
      // In such a case, we need to make sure subsequent calls to
      // putIfAbsent don't return this image that may never complete.
      final _LiveImage? image = _liveImages.remove(key);
      image?.dispose();
    }
    final _PendingImage? pendingImage = _pendingImages.remove(key);
    if (pendingImage != null) {
      if (!kReleaseMode) {
        Timeline.instantSync('ImageCache.evict', arguments: <String, dynamic>{
          'type': 'pending',
        });
      }
      pendingImage.removeListener();
      return true;
    }
    final _CachedImage? image = _cache.remove(key);
    if (image != null) {
      if (!kReleaseMode) {
        Timeline.instantSync('ImageCache.evict', arguments: <String, dynamic>{
          'type': 'keepAlive',
          'sizeInBytes': image.sizeBytes,
        });
      }
      _currentSizeBytes -= image.sizeBytes!;
      image.dispose();
      return true;
    }
    if (!kReleaseMode) {
      Timeline.instantSync('ImageCache.evict', arguments: <String, dynamic>{
        'type': 'miss',
      });
    }
    return false;
  }

  void _touch(Object key, _CachedImage image, TimelineTask? timelineTask) {
    if (image.sizeBytes != null && image.sizeBytes! <= maximumSizeBytes && maximumSize > 0) {
      _currentSizeBytes += image.sizeBytes!;
      _cache[key] = image;
      _checkCacheSize(timelineTask);
    } else {
      image.dispose();
    }
  }

  void _trackLiveImage(Object key, ImageStreamCompleter completer, int? sizeBytes) {
    // Avoid adding unnecessary callbacks to the completer.
    _liveImages.putIfAbsent(key, () {
      // Even if no callers to ImageProvider.resolve have listened to the stream,
      // the cache is listening to the stream and will remove itself once the
      // image completes to move it from pending to keepAlive.
      // Even if the cache size is 0, we still add this tracker, which will add
      // a keep alive handle to the stream.
      return _LiveImage(
        completer,
        () {
          _liveImages.remove(key);
        },
      );
    }).sizeBytes ??= sizeBytes;
  }

  ImageStreamCompleter? putIfAbsent(Object key, ImageStreamCompleter Function() loader, { ImageErrorListener? onError }) {
    TimelineTask? debugTimelineTask;
    if (!kReleaseMode) {
      debugTimelineTask = TimelineTask()..start(
        'ImageCache.putIfAbsent',
        arguments: <String, dynamic>{
          'key': key.toString(),
        },
      );
    }
    ImageStreamCompleter? result = _pendingImages[key]?.completer;
    // Nothing needs to be done because the image hasn't loaded yet.
    if (result != null) {
      if (!kReleaseMode) {
        debugTimelineTask!.finish(arguments: <String, dynamic>{'result': 'pending'});
      }
      return result;
    }
    // Remove the provider from the list so that we can move it to the
    // recently used position below.
    // Don't use _touch here, which would trigger a check on cache size that is
    // not needed since this is just moving an existing cache entry to the head.
    final _CachedImage? image = _cache.remove(key);
    if (image != null) {
      if (!kReleaseMode) {
        debugTimelineTask!.finish(arguments: <String, dynamic>{'result': 'keepAlive'});
      }
      // The image might have been keptAlive but had no listeners (so not live).
      // Make sure the cache starts tracking it as live again.
      _trackLiveImage(
        key,
        image.completer,
        image.sizeBytes,
      );
      _cache[key] = image;
      return image.completer;
    }

    final _LiveImage? liveImage = _liveImages[key];
    if (liveImage != null) {
      _touch(
        key,
        _CachedImage(
          liveImage.completer,
          sizeBytes: liveImage.sizeBytes,
        ),
        debugTimelineTask,
      );
      if (!kReleaseMode) {
        debugTimelineTask!.finish(arguments: <String, dynamic>{'result': 'keepAlive'});
      }
      return liveImage.completer;
    }

    try {
      result = loader();
      _trackLiveImage(key, result, null);
    } catch (error, stackTrace) {
      if (!kReleaseMode) {
        debugTimelineTask!.finish(arguments: <String, dynamic>{
          'result': 'error',
          'error': error.toString(),
          'stackTrace': stackTrace.toString(),
        });
      }
      if (onError != null) {
        onError(error, stackTrace);
        return null;
      } else {
        rethrow;
      }
    }

    if (!kReleaseMode) {
      debugTimelineTask!.start('listener');
    }
    // A multi-frame provider may call the listener more than once. We need do make
    // sure that some cleanup works won't run multiple times, such as finishing the
    // tracing task or removing the listeners
    bool listenedOnce = false;

    // We shouldn't use the _pendingImages map if the cache is disabled, but we
    // will have to listen to the image at least once so we don't leak it in
    // the live image tracking.
    final bool trackPendingImage = maximumSize > 0 && maximumSizeBytes > 0;
    late _PendingImage pendingImage;
    void listener(ImageInfo? info, bool syncCall) {
      int? sizeBytes;
      if (info != null) {
        sizeBytes = info.sizeBytes;
        info.dispose();
      }
      final _CachedImage image = _CachedImage(
        result!,
        sizeBytes: sizeBytes,
      );

      _trackLiveImage(key, result, sizeBytes);

      // Only touch if the cache was enabled when resolve was initially called.
      if (trackPendingImage) {
        _touch(key, image, debugTimelineTask);
      } else {
        image.dispose();
      }

      _pendingImages.remove(key);
      if (!listenedOnce) {
        pendingImage.removeListener();
      }
      if (!kReleaseMode && !listenedOnce) {
        debugTimelineTask!
          ..finish(arguments: <String, dynamic>{
            'syncCall': syncCall,
            'sizeInBytes': sizeBytes,
          })
          ..finish(arguments: <String, dynamic>{
            'currentSizeBytes': currentSizeBytes,
            'currentSize': currentSize,
          });
      }
      listenedOnce = true;
    }

    final ImageStreamListener streamListener = ImageStreamListener(listener);
    pendingImage = _PendingImage(result, streamListener);
    if (trackPendingImage) {
      _pendingImages[key] = pendingImage;
    }
    // Listener is removed in [_PendingImage.removeListener].
    result.addListener(streamListener);

    return result;
  }

  ImageCacheStatus statusForKey(Object key) {
    return ImageCacheStatus._(
      pending: _pendingImages.containsKey(key),
      keepAlive: _cache.containsKey(key),
      live: _liveImages.containsKey(key),
    );
  }

  bool containsKey(Object key) {
    return _pendingImages[key] != null || _cache[key] != null;
  }

  int get liveImageCount => _liveImages.length;

  int get pendingImageCount => _pendingImages.length;

  void clearLiveImages() {
    for (final _LiveImage image in _liveImages.values) {
      image.dispose();
    }
    _liveImages.clear();
  }

  // Remove images from the cache until both the length and bytes are below
  // maximum, or the cache is empty.
  void _checkCacheSize(TimelineTask? timelineTask) {
    final Map<String, dynamic> finishArgs = <String, dynamic>{};
    if (!kReleaseMode) {
      timelineTask!.start('checkCacheSize');
      finishArgs['evictedKeys'] = <String>[];
      finishArgs['currentSize'] = currentSize;
      finishArgs['currentSizeBytes'] = currentSizeBytes;
    }
    while (_currentSizeBytes > _maximumSizeBytes || _cache.length > _maximumSize) {
      final Object key = _cache.keys.first;
      final _CachedImage image = _cache[key]!;
      _currentSizeBytes -= image.sizeBytes!;
      image.dispose();
      _cache.remove(key);
      if (!kReleaseMode) {
        (finishArgs['evictedKeys'] as List<String>).add(key.toString());
      }
    }
    if (!kReleaseMode) {
      finishArgs['endSize'] = currentSize;
      finishArgs['endSizeBytes'] = currentSizeBytes;
      timelineTask!.finish(arguments: finishArgs);
    }
    assert(_currentSizeBytes >= 0);
    assert(_cache.length <= maximumSize);
    assert(_currentSizeBytes <= maximumSizeBytes);
  }
}

@immutable
class ImageCacheStatus {
  const ImageCacheStatus._({
    this.pending = false,
    this.keepAlive = false,
    this.live = false,
  }) : assert(!pending || !keepAlive);

  final bool pending;

  final bool keepAlive;

  final bool live;

  bool get tracked => pending || keepAlive || live;

  bool get untracked => !pending && !keepAlive && !live;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ImageCacheStatus
        && other.pending == pending
        && other.keepAlive == keepAlive
        && other.live == live;
  }

  @override
  int get hashCode => Object.hash(pending, keepAlive, live);

  @override
  String toString() => '${objectRuntimeType(this, 'ImageCacheStatus')}(pending: $pending, live: $live, keepAlive: $keepAlive)';
}

abstract class _CachedImageBase {
  _CachedImageBase(
    this.completer, {
    this.sizeBytes,
  }) : handle = completer.keepAlive();

  final ImageStreamCompleter completer;
  int? sizeBytes;
  ImageStreamCompleterHandle? handle;

  @mustCallSuper
  void dispose() {
    assert(handle != null);
    // Give any interested parties a chance to listen to the stream before we
    // potentially dispose it.
    SchedulerBinding.instance.addPostFrameCallback((Duration timeStamp) {
      assert(handle != null);
      handle?.dispose();
      handle = null;
    });
  }
}

class _CachedImage extends _CachedImageBase {
  _CachedImage(super.completer, {super.sizeBytes});
}

class _LiveImage extends _CachedImageBase {
  _LiveImage(ImageStreamCompleter completer, VoidCallback handleRemove, {int? sizeBytes})
      : super(completer, sizeBytes: sizeBytes) {
    _handleRemove = () {
      handleRemove();
      dispose();
    };
    completer.addOnLastListenerRemovedCallback(_handleRemove);
  }

  late VoidCallback _handleRemove;

  @override
  void dispose() {
    completer.removeOnLastListenerRemovedCallback(_handleRemove);
    super.dispose();
  }

  @override
  String toString() => describeIdentity(this);
}

class _PendingImage {
  _PendingImage(this.completer, this.listener);

  final ImageStreamCompleter completer;
  final ImageStreamListener listener;

  void removeListener() {
    completer.removeListener(listener);
  }
}