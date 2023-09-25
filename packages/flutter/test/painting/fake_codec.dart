import 'dart:ui' as ui show Codec, FrameInfo, instantiateImageCodec;

import 'package:flutter/foundation.dart';

class FakeCodec implements ui.Codec {
  FakeCodec._(this._frameCount, this._repetitionCount, this._frameInfos);

  final int _frameCount;
  final int _repetitionCount;
  final List<ui.FrameInfo> _frameInfos;
  int _nextFrame = 0;
  int _numFramesAsked = 0;

  static Future<FakeCodec> fromData(Uint8List data) async {
    final ui.Codec codec = await ui.instantiateImageCodec(data);
    final int frameCount = codec.frameCount;
    final List<ui.FrameInfo> frameInfos = <ui.FrameInfo>[];
    for (int i = 0; i < frameCount; i += 1) {
      frameInfos.add(await codec.getNextFrame());
    }
    return FakeCodec._(frameCount, codec.repetitionCount, frameInfos);
  }

  @override
  int get frameCount => _frameCount;

  @override
  int get repetitionCount => _repetitionCount;

  int get numFramesAsked => _numFramesAsked;

  @override
  Future<ui.FrameInfo> getNextFrame() {
    _numFramesAsked += 1;
    final SynchronousFuture<ui.FrameInfo> result =
      SynchronousFuture<ui.FrameInfo>(_frameInfos[_nextFrame]);
    _nextFrame = (_nextFrame + 1) % _frameCount;
    return result;
  }

  @override
  void dispose() { }
}