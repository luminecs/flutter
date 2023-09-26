import 'dart:ui';

import 'package:flutter/foundation.dart';

export 'dart:typed_data' show ByteData;

class FontLoader {
  FontLoader(this.family)
      : _loaded = false,
        _fontFutures = <Future<Uint8List>>[];

  final String family;

  void addFont(Future<ByteData> bytes) {
    if (_loaded) {
      throw StateError('FontLoader is already loaded');
    }

    _fontFutures.add(bytes.then(
      (ByteData data) =>
          Uint8List.view(data.buffer, data.offsetInBytes, data.lengthInBytes),
    ));
  }

  Future<void> load() async {
    if (_loaded) {
      throw StateError('FontLoader is already loaded');
    }
    _loaded = true;

    final Iterable<Future<void>> loadFutures = _fontFutures.map(
      (Future<Uint8List> f) => f.then<void>(
        (Uint8List list) => loadFont(list, family),
      ),
    );
    await Future.wait(loadFutures.toList());
  }

  @protected
  @visibleForTesting
  Future<void> loadFont(Uint8List list, String family) {
    return loadFontFromList(list, fontFamily: family);
  }

  bool _loaded;
  final List<Future<Uint8List>> _fontFutures;
}
