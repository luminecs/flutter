// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/painting.dart';
import 'package:flutter/scheduler.dart';

import 'disposable_build_context.dart';
import 'framework.dart';
import 'scrollable.dart';

@optionalTypeArgs
class ScrollAwareImageProvider<T extends Object> extends ImageProvider<T> {
  const ScrollAwareImageProvider({
    required this.context,
    required this.imageProvider,
  });

  final DisposableBuildContext context;

  final ImageProvider<T> imageProvider;

  @override
  void resolveStreamForKey(
    ImageConfiguration configuration,
    ImageStream stream,
    T key,
    ImageErrorListener handleError,
  ) {
    // Something managed to complete the stream, or it's already in the image
    // cache. Notify the wrapped provider and expect it to behave by not
    // reloading the image since it's already resolved.
    // Do this even if the context has gone out of the tree, since it will
    // update LRU information about the cache. Even though we never showed the
    // image, it was still touched more recently.
    // Do this before checking scrolling, so that if the bytes are available we
    // render them even though we're scrolling fast - there's no additional
    // allocations to do for texture memory, it's already there.
    if (stream.completer != null || PaintingBinding.instance.imageCache.containsKey(key)) {
      imageProvider.resolveStreamForKey(configuration, stream, key, handleError);
      return;
    }
    // The context has gone out of the tree - ignore it.
    if (context.context == null) {
      return;
    }
    // Something still wants this image, but check if the context is scrolling
    // too fast before scheduling work that might never show on screen.
    // Try to get to end of the frame callbacks of the next frame, and then
    // check again.
    if (Scrollable.recommendDeferredLoadingForContext(context.context!)) {
      SchedulerBinding.instance.scheduleFrameCallback((_) {
        scheduleMicrotask(() => resolveStreamForKey(configuration, stream, key, handleError));
      });
      return;
    }
    // We are in the tree, we're not scrolling too fast, the cache doesn't
    // have our image, and no one has otherwise completed the stream. Go.
    imageProvider.resolveStreamForKey(configuration, stream, key, handleError);
  }

  @override
  ImageStreamCompleter loadBuffer(T key, DecoderBufferCallback decode) => imageProvider.loadBuffer(key, decode);

  @override
  ImageStreamCompleter loadImage(T key, ImageDecoderCallback decode) => imageProvider.loadImage(key, decode);

  @override
  Future<T> obtainKey(ImageConfiguration configuration) => imageProvider.obtainKey(configuration);
}