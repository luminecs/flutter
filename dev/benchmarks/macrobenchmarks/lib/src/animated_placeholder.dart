// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:ui' as ui show Codec;
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

const String kAnimatedGif = 'R0lGODlhAQABAKEDAAAA//8AAAD/AP///yH/C05FVFNDQVBFMi'
                            '4wAwEAAAAh+QQACgD/ACwAAAAAAQABAAACAkwBACH5BAAKAP8A'
                            'LAAAAAABAAEAAAICVAEAIfkEAAoA/wAsAAAAAAEAAQAAAgJEAQ'
                            'A7';

const String kBlueSquare = 'iVBORw0KGgoAAAANSUhEUgAAADIAAAAyCAYAAAAeP4ixAAAASEl'
                           'EQVR42u3PMQ0AMAgAsGFjL/4tYQU08JLWQSN/9TsgRERERERERE'
                           'REREREREREREREREREREREREREREREREREREREREQ2BgNuaUcSj'
                           'uqqAAAAAElFTkSuQmCC';

class AnimatedPlaceholderPage extends StatelessWidget {
  const AnimatedPlaceholderPage({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: 100,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 10),
      itemBuilder: (BuildContext context, int index) {
        return FadeInImage(
          placeholder: const DelayedBase64Image(Duration.zero, kAnimatedGif),
          image: DelayedBase64Image(Duration(milliseconds: 100 * index), kBlueSquare),
        );
      },
    );
  }
}

int _key = 0;
class DelayedBase64Image extends ImageProvider<int> {
  const DelayedBase64Image(this.delay, this.data);

  final String data;

  final Duration delay;

  @override
  Future<int> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<int>(_key++);
  }

  @override
  ImageStreamCompleter loadImage(int key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: Future<ui.Codec>.delayed(
        delay,
        () async => decode(await ImmutableBuffer.fromUint8List(base64.decode(data))),
      ),
      scale: 1.0,
    );
  }
}