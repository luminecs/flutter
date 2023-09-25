import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';

import 'binding.dart';

export 'dart:typed_data' show ByteData;
export 'dart:ui' show ImmutableBuffer;

abstract class AssetBundle {
  Future<ByteData> load(String key);

  Future<ui.ImmutableBuffer> loadBuffer(String key) async {
    final ByteData data = await load(key);
    return ui.ImmutableBuffer.fromUint8List(Uint8List.sublistView(data));
  }

  Future<String> loadString(String key, { bool cache = true }) async {
    final ByteData data = await load(key);
    // 50 KB of data should take 2-3 ms to parse on a Moto G4, and about 400 μs
    // on a Pixel 4. On the web we can't bail to isolates, though...
    if (data.lengthInBytes < 50 * 1024 || kIsWeb) {
      return utf8.decode(Uint8List.sublistView(data));
    }
    // For strings larger than 50 KB, run the computation in an isolate to
    // avoid causing main thread jank.
    return compute(_utf8decode, data, debugLabel: 'UTF8 decode for "$key"');
  }

  static String _utf8decode(ByteData data) {
    return utf8.decode(Uint8List.sublistView(data));
  }

  Future<T> loadStructuredData<T>(String key, Future<T> Function(String value) parser) async {
    return parser(await loadString(key));
  }

  Future<T> loadStructuredBinaryData<T>(String key, FutureOr<T> Function(ByteData data) parser) async {
    return parser(await load(key));
  }

  void evict(String key) { }

  void clear() { }

  @override
  String toString() => '${describeIdentity(this)}()';
}

class NetworkAssetBundle extends AssetBundle {
  NetworkAssetBundle(Uri baseUrl)
    : _baseUrl = baseUrl,
      _httpClient = HttpClient();

  final Uri _baseUrl;
  final HttpClient _httpClient;

  Uri _urlFromKey(String key) => _baseUrl.resolve(key);

  @override
  Future<ByteData> load(String key) async {
    final HttpClientRequest request = await _httpClient.getUrl(_urlFromKey(key));
    final HttpClientResponse response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        _errorSummaryWithKey(key),
        IntProperty('HTTP status code', response.statusCode),
      ]);
    }
    final Uint8List bytes = await consolidateHttpClientResponseBytes(response);
    return ByteData.sublistView(bytes);
  }

  // TODO(ianh): Once the underlying network logic learns about caching, we
  // should implement evict().

  @override
  String toString() => '${describeIdentity(this)}($_baseUrl)';
}

abstract class CachingAssetBundle extends AssetBundle {
  // TODO(ianh): Replace this with an intelligent cache, see https://github.com/flutter/flutter/issues/3568
  final Map<String, Future<String>> _stringCache = <String, Future<String>>{};
  final Map<String, Future<dynamic>> _structuredDataCache = <String, Future<dynamic>>{};
  final Map<String, Future<dynamic>> _structuredBinaryDataCache = <String, Future<dynamic>>{};

  @override
  Future<String> loadString(String key, { bool cache = true }) {
    if (cache) {
      return _stringCache.putIfAbsent(key, () => super.loadString(key));
    }
    return super.loadString(key);
  }

  @override
  Future<T> loadStructuredData<T>(String key, Future<T> Function(String value) parser) {
    if (_structuredDataCache.containsKey(key)) {
      return _structuredDataCache[key]! as Future<T>;
    }
    // loadString can return a SynchronousFuture in certain cases, like in the
    // flutter_test framework. So, we need to support both async and sync flows.
    Completer<T>? completer; // For async flow.
    Future<T>? synchronousResult; // For sync flow.
    loadString(key, cache: false).then<T>(parser).then<void>((T value) {
      synchronousResult = SynchronousFuture<T>(value);
      _structuredDataCache[key] = synchronousResult!;
      if (completer != null) {
        // We already returned from the loadStructuredData function, which means
        // we are in the asynchronous mode. Pass the value to the completer. The
        // completer's future is what we returned.
        completer.complete(value);
      }
    }, onError: (Object error, StackTrace stack) {
      assert(completer != null, 'unexpected synchronous failure');
      // Either loading or parsing failed. We must report the error back to the
      // caller and anyone waiting on this call. We clear the cache for this
      // key, however, because we want future attempts to try again.
      _structuredDataCache.remove(key);
      completer!.completeError(error, stack);
    });
    if (synchronousResult != null) {
      // The above code ran synchronously. We can synchronously return the result.
      return synchronousResult!;
    }
    // The code above hasn't yet run its "then" handler yet. Let's prepare a
    // completer for it to use when it does run.
    completer = Completer<T>();
    _structuredDataCache[key] = completer.future;
    return completer.future;
  }

  @override
  Future<T> loadStructuredBinaryData<T>(String key, FutureOr<T> Function(ByteData data) parser) {
    if (_structuredBinaryDataCache.containsKey(key)) {
      return _structuredBinaryDataCache[key]! as Future<T>;
    }
    // load can return a SynchronousFuture in certain cases, like in the
    // flutter_test framework. So, we need to support both async and sync flows.
    Completer<T>? completer; // For async flow.
    Future<T>? synchronousResult; // For sync flow.
    load(key).then<T>(parser).then<void>((T value) {
      synchronousResult = SynchronousFuture<T>(value);
      _structuredBinaryDataCache[key] = synchronousResult!;
      if (completer != null) {
        // The load and parse operation ran asynchronously. We already returned
        // from the loadStructuredBinaryData function and therefore the caller
        // was given the future of the completer.
        completer.complete(value);
      }
    }, onError: (Object error, StackTrace stack) {
      assert(completer != null, 'unexpected synchronous failure');
      // Either loading or parsing failed. We must report the error back to the
      // caller and anyone waiting on this call. We clear the cache for this
      // key, however, because we want future attempts to try again.
      _structuredBinaryDataCache.remove(key);
      completer!.completeError(error, stack);
    });
    if (synchronousResult != null) {
      // The above code ran synchronously. We can synchronously return the result.
      return synchronousResult!;
    }
    // Since the above code is being run asynchronously and thus hasn't run its
    // `then` handler yet, we'll return a completer that will be completed
    // when the handler does run.
    completer = Completer<T>();
    _structuredBinaryDataCache[key] = completer.future;
    return completer.future;
  }

  @override
  void evict(String key) {
    _stringCache.remove(key);
    _structuredDataCache.remove(key);
    _structuredBinaryDataCache.remove(key);
  }

  @override
  void clear() {
    _stringCache.clear();
    _structuredDataCache.clear();
    _structuredBinaryDataCache.clear();
  }

  @override
  Future<ui.ImmutableBuffer> loadBuffer(String key) async {
    final ByteData data = await load(key);
    return ui.ImmutableBuffer.fromUint8List(Uint8List.sublistView(data));
  }
}

class PlatformAssetBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) {
    final Uint8List encoded = utf8.encode(Uri(path: Uri.encodeFull(key)).path);
    final Future<ByteData>? future = ServicesBinding.instance.defaultBinaryMessenger.send(
      'flutter/assets',
      ByteData.sublistView(encoded),
    )?.then((ByteData? asset) {
      if (asset == null) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          _errorSummaryWithKey(key),
          ErrorDescription('The asset does not exist or has empty data.'),
        ]);
      }
      return asset;
    });
    if (future == null) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        _errorSummaryWithKey(key),
        ErrorDescription('The asset does not exist or has empty data.'),
      ]);
    }
    return future;
  }

  @override
  Future<ui.ImmutableBuffer> loadBuffer(String key) async {
    if (kIsWeb) {
      final ByteData bytes = await load(key);
      return ui.ImmutableBuffer.fromUint8List(Uint8List.sublistView(bytes));
    }
    bool debugUsePlatformChannel = false;
    assert(() {
      // dart:io is safe to use here since we early return for web
      // above. If that code is changed, this needs to be guarded on
      // web presence. Override how assets are loaded in tests so that
      // the old loader behavior that allows tests to load assets from
      // the current package using the package prefix.
      if (Platform.environment.containsKey('UNIT_TEST_ASSETS')) {
        debugUsePlatformChannel = true;
      }
      return true;
    }());
    if (debugUsePlatformChannel) {
      final ByteData bytes = await load(key);
      return ui.ImmutableBuffer.fromUint8List(Uint8List.sublistView(bytes));
    }
    try {
      return await ui.ImmutableBuffer.fromAsset(key);
    } on Exception catch (e) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        _errorSummaryWithKey(key),
        ErrorDescription(e.toString()),
      ]);
    }
  }
}

AssetBundle _initRootBundle() {
  return PlatformAssetBundle();
}

ErrorSummary _errorSummaryWithKey(String key) {
  return ErrorSummary('Unable to load asset: "$key".');
}

final AssetBundle rootBundle = _initRootBundle();