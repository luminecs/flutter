
import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '_network_image_io.dart'
  if (dart.library.js_util) '_network_image_web.dart' as network_image;
import 'binding.dart';
import 'image_cache.dart';
import 'image_stream.dart';

typedef _KeyAndErrorHandlerCallback<T> = void Function(T key, ImageErrorListener handleError);

typedef _AsyncKeyErrorHandler<T> = Future<void> Function(T key, Object exception, StackTrace? stack);

@immutable
class ImageConfiguration {
  const ImageConfiguration({
    this.bundle,
    this.devicePixelRatio,
    this.locale,
    this.textDirection,
    this.size,
    this.platform,
  });

  ImageConfiguration copyWith({
    AssetBundle? bundle,
    double? devicePixelRatio,
    ui.Locale? locale,
    TextDirection? textDirection,
    Size? size,
    TargetPlatform? platform,
  }) {
    return ImageConfiguration(
      bundle: bundle ?? this.bundle,
      devicePixelRatio: devicePixelRatio ?? this.devicePixelRatio,
      locale: locale ?? this.locale,
      textDirection: textDirection ?? this.textDirection,
      size: size ?? this.size,
      platform: platform ?? this.platform,
    );
  }

  final AssetBundle? bundle;

  final double? devicePixelRatio;

  final ui.Locale? locale;

  final TextDirection? textDirection;

  final Size? size;

  final TargetPlatform? platform;

  static const ImageConfiguration empty = ImageConfiguration();

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ImageConfiguration
        && other.bundle == bundle
        && other.devicePixelRatio == devicePixelRatio
        && other.locale == locale
        && other.textDirection == textDirection
        && other.size == size
        && other.platform == platform;
  }

  @override
  int get hashCode => Object.hash(bundle, devicePixelRatio, locale, size, platform);

  @override
  String toString() {
    final StringBuffer result = StringBuffer();
    result.write('ImageConfiguration(');
    bool hasArguments = false;
    if (bundle != null) {
      result.write('bundle: $bundle');
      hasArguments = true;
    }
    if (devicePixelRatio != null) {
      if (hasArguments) {
        result.write(', ');
      }
      result.write('devicePixelRatio: ${devicePixelRatio!.toStringAsFixed(1)}');
      hasArguments = true;
    }
    if (locale != null) {
      if (hasArguments) {
        result.write(', ');
      }
      result.write('locale: $locale');
      hasArguments = true;
    }
    if (textDirection != null) {
      if (hasArguments) {
        result.write(', ');
      }
      result.write('textDirection: $textDirection');
      hasArguments = true;
    }
    if (size != null) {
      if (hasArguments) {
        result.write(', ');
      }
      result.write('size: $size');
      hasArguments = true;
    }
    if (platform != null) {
      if (hasArguments) {
        result.write(', ');
      }
      result.write('platform: ${platform!.name}');
      hasArguments = true;
    }
    result.write(')');
    return result.toString();
  }
}

@Deprecated(
  'Use ImageDecoderCallback with ImageProvider.loadImage instead. '
  'This feature was deprecated after v3.7.0-1.4.pre.',
)
typedef DecoderBufferCallback = Future<ui.Codec> Function(ui.ImmutableBuffer buffer, {int? cacheWidth, int? cacheHeight, bool allowUpscaling});

// Method signature for _loadAsync decode callbacks.
typedef _SimpleDecoderCallback = Future<ui.Codec> Function(ui.ImmutableBuffer buffer);

typedef ImageDecoderCallback = Future<ui.Codec> Function(
  ui.ImmutableBuffer buffer, {
  ui.TargetImageSizeCallback? getTargetSize,
});

@optionalTypeArgs
abstract class ImageProvider<T extends Object> {
  const ImageProvider();

  @nonVirtual
  ImageStream resolve(ImageConfiguration configuration) {
    final ImageStream stream = createStream(configuration);
    // Load the key (potentially asynchronously), set up an error handling zone,
    // and call resolveStreamForKey.
    _createErrorHandlerAndKey(
      configuration,
      (T key, ImageErrorListener errorHandler) {
        resolveStreamForKey(configuration, stream, key, errorHandler);
      },
      (T? key, Object exception, StackTrace? stack) async {
        await null; // wait an event turn in case a listener has been added to the image stream.
        InformationCollector? collector;
        assert(() {
          collector = () => <DiagnosticsNode>[
            DiagnosticsProperty<ImageProvider>('Image provider', this),
            DiagnosticsProperty<ImageConfiguration>('Image configuration', configuration),
            DiagnosticsProperty<T>('Image key', key, defaultValue: null),
          ];
          return true;
        }());
        if (stream.completer == null) {
          stream.setCompleter(_ErrorImageCompleter());
        }
        stream.completer!.reportError(
          exception: exception,
          stack: stack,
          context: ErrorDescription('while resolving an image'),
          silent: true, // could be a network error or whatnot
          informationCollector: collector,
        );
      },
    );
    return stream;
  }

  @protected
  ImageStream createStream(ImageConfiguration configuration) {
    return ImageStream();
  }

  Future<ImageCacheStatus?> obtainCacheStatus({
    required ImageConfiguration configuration,
    ImageErrorListener? handleError,
  }) {
    final Completer<ImageCacheStatus?> completer = Completer<ImageCacheStatus?>();
    _createErrorHandlerAndKey(
      configuration,
      (T key, ImageErrorListener innerHandleError) {
        completer.complete(PaintingBinding.instance.imageCache.statusForKey(key));
      },
      (T? key, Object exception, StackTrace? stack) async {
        if (handleError != null) {
          handleError(exception, stack);
        } else {
          InformationCollector? collector;
          assert(() {
            collector = () => <DiagnosticsNode>[
              DiagnosticsProperty<ImageProvider>('Image provider', this),
              DiagnosticsProperty<ImageConfiguration>('Image configuration', configuration),
              DiagnosticsProperty<T>('Image key', key, defaultValue: null),
            ];
            return true;
          }());
          FlutterError.reportError(FlutterErrorDetails(
            context: ErrorDescription('while checking the cache location of an image'),
            informationCollector: collector,
            exception: exception,
            stack: stack,
          ));
          completer.complete();
        }
      },
    );
    return completer.future;
  }

  void _createErrorHandlerAndKey(
    ImageConfiguration configuration,
    _KeyAndErrorHandlerCallback<T> successCallback,
    _AsyncKeyErrorHandler<T?> errorCallback,
  ) {
    T? obtainedKey;
    bool didError = false;
    Future<void> handleError(Object exception, StackTrace? stack) async {
      if (didError) {
        return;
      }
      if (!didError) {
        didError = true;
        errorCallback(obtainedKey, exception, stack);
      }
    }

    Future<T> key;
    try {
      key = obtainKey(configuration);
    } catch (error, stackTrace) {
      handleError(error, stackTrace);
      return;
    }
    key.then<void>((T key) {
      obtainedKey = key;
      try {
        successCallback(key, handleError);
      } catch (error, stackTrace) {
        handleError(error, stackTrace);
      }
    }).catchError(handleError);
  }

  @protected
  void resolveStreamForKey(ImageConfiguration configuration, ImageStream stream, T key, ImageErrorListener handleError) {
    // This is an unusual edge case where someone has told us that they found
    // the image we want before getting to this method. We should avoid calling
    // load again, but still update the image cache with LRU information.
    if (stream.completer != null) {
      final ImageStreamCompleter? completer = PaintingBinding.instance.imageCache.putIfAbsent(
        key,
        () => stream.completer!,
        onError: handleError,
      );
      assert(identical(completer, stream.completer));
      return;
    }
    final ImageStreamCompleter? completer = PaintingBinding.instance.imageCache.putIfAbsent(
      key,
      () {
        ImageStreamCompleter result = loadImage(key, PaintingBinding.instance.instantiateImageCodecWithSize);
        // This check exists as a fallback for backwards compatibility until the
        // deprecated `loadBuffer()` method is removed. Until then, ImageProvider
        // subclasses may have only overridden `loadBuffer()`, in which case the
        // base implementation of `loadWithSize()` will return a sentinel value
        // of type `_AbstractImageStreamCompleter`.
        if (result is _AbstractImageStreamCompleter) {
          result = loadBuffer(key, PaintingBinding.instance.instantiateImageCodecFromBuffer);
        }
        return result;
      },
      onError: handleError,
    );
    if (completer != null) {
      stream.setCompleter(completer);
    }
  }

  Future<bool> evict({ ImageCache? cache, ImageConfiguration configuration = ImageConfiguration.empty }) async {
    cache ??= imageCache;
    final T key = await obtainKey(configuration);
    return cache.evict(key);
  }

  Future<T> obtainKey(ImageConfiguration configuration);

  @protected
  @Deprecated(
    'Implement loadImage for image loading. '
    'This feature was deprecated after v3.7.0-1.4.pre.',
  )
  ImageStreamCompleter loadBuffer(T key, DecoderBufferCallback decode) {
    return _AbstractImageStreamCompleter();
  }

  // TODO(tvolkert): make abstract (https://github.com/flutter/flutter/issues/119209)
  @protected
  ImageStreamCompleter loadImage(T key, ImageDecoderCallback decode) {
    return _AbstractImageStreamCompleter();
  }

  @override
  String toString() => '${objectRuntimeType(this, 'ImageConfiguration')}()';
}

class _AbstractImageStreamCompleter extends ImageStreamCompleter {}

@immutable
class AssetBundleImageKey {
  const AssetBundleImageKey({
    required this.bundle,
    required this.name,
    required this.scale,
  });

  final AssetBundle bundle;

  final String name;

  final double scale;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is AssetBundleImageKey
        && other.bundle == bundle
        && other.name == name
        && other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(bundle, name, scale);

  @override
  String toString() => '${objectRuntimeType(this, 'AssetBundleImageKey')}(bundle: $bundle, name: "$name", scale: $scale)';
}

abstract class AssetBundleImageProvider extends ImageProvider<AssetBundleImageKey> {
  const AssetBundleImageProvider();

  @override
  ImageStreamCompleter loadImage(AssetBundleImageKey key, ImageDecoderCallback decode) {
    InformationCollector? collector;
    assert(() {
      collector = () => <DiagnosticsNode>[
            DiagnosticsProperty<ImageProvider>('Image provider', this),
            DiagnosticsProperty<AssetBundleImageKey>('Image key', key),
          ];
      return true;
    }());
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode: decode),
      scale: key.scale,
      debugLabel: key.name,
      informationCollector: collector,
    );
  }

  @override
  ImageStreamCompleter loadBuffer(AssetBundleImageKey key, DecoderBufferCallback decode) {
    InformationCollector? collector;
    assert(() {
      collector = () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<AssetBundleImageKey>('Image key', key),
      ];
      return true;
    }());
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode: decode),
      scale: key.scale,
      debugLabel: key.name,
      informationCollector: collector,
    );
  }

  @protected
  Future<ui.Codec> _loadAsync(
    AssetBundleImageKey key, {
    required _SimpleDecoderCallback decode,
  }) async {
    final ui.ImmutableBuffer buffer;
    // Hot reload/restart could change whether an asset bundle or key in a
    // bundle are available, or if it is a network backed bundle.
    try {
      buffer = await key.bundle.loadBuffer(key.name);
    } on FlutterError {
      PaintingBinding.instance.imageCache.evict(key);
      rethrow;
    }
    return decode(buffer);
  }
}

@immutable
class ResizeImageKey {
  // Private constructor so nobody from the outside can poison the image cache
  // with this key. It's only accessible to [ResizeImage] internally.
  const ResizeImageKey._(this._providerCacheKey, this._policy, this._width, this._height, this._allowUpscaling);

  final Object _providerCacheKey;
  final ResizeImagePolicy _policy;
  final int? _width;
  final int? _height;
  final bool _allowUpscaling;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ResizeImageKey
        && other._providerCacheKey == _providerCacheKey
        && other._policy == _policy
        && other._width == _width
        && other._height == _height
        && other._allowUpscaling == _allowUpscaling;
  }

  @override
  int get hashCode => Object.hash(_providerCacheKey, _policy, _width, _height, _allowUpscaling);
}

enum ResizeImagePolicy {
  exact,

  fit,
}

class ResizeImage extends ImageProvider<ResizeImageKey> {
  const ResizeImage(
    this.imageProvider, {
    this.width,
    this.height,
    this.policy = ResizeImagePolicy.exact,
    this.allowUpscaling = false,
  }) : assert(width != null || height != null);

  final ImageProvider imageProvider;

  final int? width;

  final int? height;

  final ResizeImagePolicy policy;

  final bool allowUpscaling;

  static ImageProvider<Object> resizeIfNeeded(int? cacheWidth, int? cacheHeight, ImageProvider<Object> provider) {
    if (cacheWidth != null || cacheHeight != null) {
      return ResizeImage(provider, width: cacheWidth, height: cacheHeight);
    }
    return provider;
  }

  @override
  @Deprecated(
    'Implement loadImage for image loading. '
    'This feature was deprecated after v3.7.0-1.4.pre.',
  )
  ImageStreamCompleter loadBuffer(ResizeImageKey key, DecoderBufferCallback decode) {
    Future<ui.Codec> decodeResize(ui.ImmutableBuffer buffer, {int? cacheWidth, int? cacheHeight, bool? allowUpscaling}) {
      assert(
        cacheWidth == null && cacheHeight == null && allowUpscaling == null,
        'ResizeImage cannot be composed with another ImageProvider that applies '
        'cacheWidth, cacheHeight, or allowUpscaling.',
      );
      return decode(buffer, cacheWidth: width, cacheHeight: height, allowUpscaling: this.allowUpscaling);
    }

    final ImageStreamCompleter completer = imageProvider.loadBuffer(key._providerCacheKey, decodeResize);
    if (!kReleaseMode) {
      completer.debugLabel = '${completer.debugLabel} - Resized(${key._width}×${key._height})';
    }
    _configureErrorListener(completer, key);
    return completer;
  }

  @override
  ImageStreamCompleter loadImage(ResizeImageKey key, ImageDecoderCallback decode) {
    Future<ui.Codec> decodeResize(ui.ImmutableBuffer buffer, {ui.TargetImageSizeCallback? getTargetSize}) {
      assert(
        getTargetSize == null,
        'ResizeImage cannot be composed with another ImageProvider that applies '
        'getTargetSize.',
      );
      return decode(buffer, getTargetSize: (int intrinsicWidth, int intrinsicHeight) {
        switch (policy) {
          case ResizeImagePolicy.exact:
            int? targetWidth = width;
            int? targetHeight = height;

            if (!allowUpscaling) {
              if (targetWidth != null && targetWidth > intrinsicWidth) {
                targetWidth = intrinsicWidth;
              }
              if (targetHeight != null && targetHeight > intrinsicHeight) {
                targetHeight = intrinsicHeight;
              }
            }

            return ui.TargetImageSize(width: targetWidth, height: targetHeight);
          case ResizeImagePolicy.fit:
            final double aspectRatio = intrinsicWidth / intrinsicHeight;
            final int maxWidth = width ?? intrinsicWidth;
            final int maxHeight = height ?? intrinsicHeight;
            int targetWidth = intrinsicWidth;
            int targetHeight = intrinsicHeight;

            if (targetWidth > maxWidth) {
              targetWidth = maxWidth;
              targetHeight = targetWidth ~/ aspectRatio;
            }

            if (targetHeight > maxHeight) {
              targetHeight = maxHeight;
              targetWidth = (targetHeight * aspectRatio).floor();
            }

            if (allowUpscaling) {
              if (width == null) {
                assert(height != null);
                targetHeight = height!;
                targetWidth = (targetHeight * aspectRatio).floor();
              } else if (height == null) {
                targetWidth = width!;
                targetHeight = targetWidth ~/ aspectRatio;
              } else {
                final int derivedMaxWidth = (maxHeight * aspectRatio).floor();
                final int derivedMaxHeight = maxWidth ~/ aspectRatio;
                targetWidth = math.min(maxWidth, derivedMaxWidth);
                targetHeight = math.min(maxHeight, derivedMaxHeight);
              }
            }

            return ui.TargetImageSize(width: targetWidth, height: targetHeight);
        }
      });
    }

    final ImageStreamCompleter completer = imageProvider.loadImage(key._providerCacheKey, decodeResize);
    if (!kReleaseMode) {
      completer.debugLabel = '${completer.debugLabel} - Resized(${key._width}×${key._height})';
    }
    _configureErrorListener(completer, key);
    return completer;
  }

  void _configureErrorListener(ImageStreamCompleter completer, ResizeImageKey key) {
    completer.addEphemeralErrorListener((Object exception, StackTrace? stackTrace) {
      // The microtask is scheduled because of the same reason as NetworkImage:
      // Depending on where the exception was thrown, the image cache may not
      // have had a chance to track the key in the cache at all.
      // Schedule a microtask to give the cache a chance to add the key.
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
    });
  }

  @override
  Future<ResizeImageKey> obtainKey(ImageConfiguration configuration) {
    Completer<ResizeImageKey>? completer;
    // If the imageProvider.obtainKey future is synchronous, then we will be able to fill in result with
    // a value before completer is initialized below.
    SynchronousFuture<ResizeImageKey>? result;
    imageProvider.obtainKey(configuration).then((Object key) {
      if (completer == null) {
        // This future has completed synchronously (completer was never assigned),
        // so we can directly create the synchronous result to return.
        result = SynchronousFuture<ResizeImageKey>(ResizeImageKey._(key, policy, width, height, allowUpscaling));
      } else {
        // This future did not synchronously complete.
        completer.complete(ResizeImageKey._(key, policy, width, height, allowUpscaling));
      }
    });
    if (result != null) {
      return result!;
    }
    // If the code reaches here, it means the imageProvider.obtainKey was not
    // completed sync, so we initialize the completer for completion later.
    completer = Completer<ResizeImageKey>();
    return completer.future;
  }
}

// TODO(ianh): Find some way to honor cache headers to the extent that when the
// last reference to an image is released, we proactively evict the image from
// our cache if the headers describe the image as having expired at that point.
abstract class NetworkImage extends ImageProvider<NetworkImage> {
  const factory NetworkImage(String url, { double scale, Map<String, String>? headers }) = network_image.NetworkImage;

  String get url;

  double get scale;

  Map<String, String>? get headers;

  @override
  ImageStreamCompleter loadBuffer(NetworkImage key, DecoderBufferCallback decode);

  @override
  ImageStreamCompleter loadImage(NetworkImage key, ImageDecoderCallback decode);
}

@immutable
class FileImage extends ImageProvider<FileImage> {
  const FileImage(this.file, { this.scale = 1.0 });

  final File file;

  final double scale;

  @override
  Future<FileImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<FileImage>(this);
  }

  @override
  ImageStreamCompleter loadBuffer(FileImage key, DecoderBufferCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode: decode),
      scale: key.scale,
      debugLabel: key.file.path,
      informationCollector: () => <DiagnosticsNode>[
        ErrorDescription('Path: ${file.path}'),
      ],
    );
  }

  @override
  @protected
  ImageStreamCompleter loadImage(FileImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode: decode),
      scale: key.scale,
      debugLabel: key.file.path,
      informationCollector: () => <DiagnosticsNode>[
        ErrorDescription('Path: ${file.path}'),
      ],
    );
  }

  Future<ui.Codec> _loadAsync(
    FileImage key, {
    required _SimpleDecoderCallback decode,
  }) async {
    assert(key == this);
    // TODO(jonahwilliams): making this sync caused test failures that seem to
    // indicate that we can fail to call evict unless at least one await has
    // occurred in the test.
    // https://github.com/flutter/flutter/issues/113044
    final int lengthInBytes = await file.length();
    if (lengthInBytes == 0) {
      // The file may become available later.
      PaintingBinding.instance.imageCache.evict(key);
      throw StateError('$file is empty and cannot be loaded as an image.');
    }
    return (file.runtimeType == File)
      ? decode(await ui.ImmutableBuffer.fromFilePath(file.path))
      : decode(await ui.ImmutableBuffer.fromUint8List(await file.readAsBytes()));
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is FileImage
        && other.file.path == file.path
        && other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(file.path, scale);

  @override
  String toString() => '${objectRuntimeType(this, 'FileImage')}("${file.path}", scale: ${scale.toStringAsFixed(1)})';
}

@immutable
class MemoryImage extends ImageProvider<MemoryImage> {
  const MemoryImage(this.bytes, { this.scale = 1.0 });

  final Uint8List bytes;

  final double scale;

  @override
  Future<MemoryImage> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<MemoryImage>(this);
  }

  @override
  ImageStreamCompleter loadBuffer(MemoryImage key, DecoderBufferCallback decode) {
    assert(key == this);
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode: decode),
      scale: key.scale,
      debugLabel: 'MemoryImage(${describeIdentity(key.bytes)})',
    );
  }

  @override
  ImageStreamCompleter loadImage(MemoryImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, decode: decode),
      scale: key.scale,
      debugLabel: 'MemoryImage(${describeIdentity(key.bytes)})',
    );
  }

  Future<ui.Codec> _loadAsync(
    MemoryImage key, {
    required _SimpleDecoderCallback decode,
  }) async {
    assert(key == this);
    return decode(await ui.ImmutableBuffer.fromUint8List(bytes));
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is MemoryImage
        && other.bytes == bytes
        && other.scale == scale;
  }

  @override
  int get hashCode => Object.hash(bytes.hashCode, scale);

  @override
  String toString() => '${objectRuntimeType(this, 'MemoryImage')}(${describeIdentity(bytes)}, scale: ${scale.toStringAsFixed(1)})';
}

@immutable
class ExactAssetImage extends AssetBundleImageProvider {
  const ExactAssetImage(
    this.assetName, {
    this.scale = 1.0,
    this.bundle,
    this.package,
  });

  final String assetName;

  String get keyName => package == null ? assetName : 'packages/$package/$assetName';

  final double scale;

  final AssetBundle? bundle;

  final String? package;

  @override
  Future<AssetBundleImageKey> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<AssetBundleImageKey>(AssetBundleImageKey(
      bundle: bundle ?? configuration.bundle ?? rootBundle,
      name: keyName,
      scale: scale,
    ));
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ExactAssetImage
        && other.keyName == keyName
        && other.scale == scale
        && other.bundle == bundle;
  }

  @override
  int get hashCode => Object.hash(keyName, scale, bundle);

  @override
  String toString() => '${objectRuntimeType(this, 'ExactAssetImage')}(name: "$keyName", scale: ${scale.toStringAsFixed(1)}, bundle: $bundle)';
}

// A completer used when resolving an image fails sync.
class _ErrorImageCompleter extends ImageStreamCompleter { }

class NetworkImageLoadException implements Exception {
  NetworkImageLoadException({required this.statusCode, required this.uri})
      : _message = 'HTTP request failed, statusCode: $statusCode, $uri';

  final int statusCode;

  final String _message;

  final Uri uri;

  @override
  String toString() => _message;
}