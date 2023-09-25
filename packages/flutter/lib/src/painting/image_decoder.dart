
import 'dart:typed_data';
import 'dart:ui' as ui show Codec, FrameInfo, Image, ImmutableBuffer;

import 'binding.dart';

Future<ui.Image> decodeImageFromList(Uint8List bytes) async {
  final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final ui.Codec codec = await PaintingBinding.instance.instantiateImageCodecWithSize(buffer);
  final ui.FrameInfo frameInfo = await codec.getNextFrame();
  return frameInfo.image;
}