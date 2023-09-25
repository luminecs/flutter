
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'test_async_utils.dart';

final Map<int, ui.Image> _cache = <int, ui.Image>{};

Future<ui.Image> createTestImage({
  int width = 1,
  int height = 1,
  bool cache = true,
}) => TestAsyncUtils.guard(() async {
  assert(width > 0);
  assert(height > 0);

  final int cacheKey = Object.hash(width, height);
  if (cache && _cache.containsKey(cacheKey)) {
    return _cache[cacheKey]!.clone();
  }

  final ui.Image image = await _createImage(width, height);
  if (cache) {
    _cache[cacheKey] = image.clone();
  }
  return image;
});

Future<ui.Image> _createImage(int width, int height) async {
  final Completer<ui.Image> completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    Uint8List.fromList(List<int>.filled(width * height * 4, 0)),
    width,
    height,
    ui.PixelFormat.rgba8888,
    (ui.Image image) {
      completer.complete(image);
    },
  );
  return completer.future;
}