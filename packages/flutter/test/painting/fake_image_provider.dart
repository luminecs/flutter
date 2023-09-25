
import 'dart:ui' as ui show Codec;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

class FakeImageProvider extends ImageProvider<FakeImageProvider> {

  const FakeImageProvider(this._codec, { this.scale = 1.0 });

  final ui.Codec _codec;

  final double scale;

  @override
  Future<FakeImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<FakeImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(FakeImageProvider key, ImageDecoderCallback decode) {
    assert(key == this);
    return MultiFrameImageStreamCompleter(
      codec: SynchronousFuture<ui.Codec>(_codec),
      scale: scale,
    );
  }
}