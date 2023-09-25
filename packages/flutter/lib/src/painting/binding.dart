// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show ServicesBinding;

import 'image_cache.dart';
import 'shader_warm_up.dart';

mixin PaintingBinding on BindingBase, ServicesBinding {
  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
    _imageCache = createImageCache();
    shaderWarmUp?.execute();
  }

  static PaintingBinding get instance => BindingBase.checkInstance(_instance);
  static PaintingBinding? _instance;

  static ShaderWarmUp? shaderWarmUp;

  ImageCache get imageCache => _imageCache;
  late ImageCache _imageCache;

  @protected
  ImageCache createImageCache() => ImageCache();

  @Deprecated(
    'Use instantiateImageCodecWithSize instead. '
    'This feature was deprecated after v3.7.0-1.4.pre.',
  )
  Future<ui.Codec> instantiateImageCodecFromBuffer(
    ui.ImmutableBuffer buffer, {
    int? cacheWidth,
    int? cacheHeight,
    bool allowUpscaling = false,
  }) {
    assert(cacheWidth == null || cacheWidth > 0);
    assert(cacheHeight == null || cacheHeight > 0);
    return ui.instantiateImageCodecFromBuffer(
      buffer,
      targetWidth: cacheWidth,
      targetHeight: cacheHeight,
      allowUpscaling: allowUpscaling,
    );
  }

  Future<ui.Codec> instantiateImageCodecWithSize(
    ui.ImmutableBuffer buffer, {
    ui.TargetImageSizeCallback? getTargetSize,
  }) {
    return ui.instantiateImageCodecWithSize(buffer, getTargetSize: getTargetSize);
  }

  @override
  void evict(String asset) {
    super.evict(asset);
    imageCache.clear();
    imageCache.clearLiveImages();
  }

  @override
  void handleMemoryPressure() {
    super.handleMemoryPressure();
    imageCache.clear();
  }

  Listenable get systemFonts => _systemFonts;
  final _SystemFontsNotifier _systemFonts = _SystemFontsNotifier();

  @override
  Future<void> handleSystemMessage(Object systemMessage) async {
    await super.handleSystemMessage(systemMessage);
    final Map<String, dynamic> message = systemMessage as Map<String, dynamic>;
    final String type = message['type'] as String;
    switch (type) {
      case 'fontsChange':
        _systemFonts.notifyListeners();
    }
    return;
  }
}

class _SystemFontsNotifier extends Listenable {
  final Set<VoidCallback> _systemFontsCallbacks = <VoidCallback>{};

  void notifyListeners () {
    for (final VoidCallback callback in _systemFontsCallbacks) {
      callback();
    }
  }

  @override
  void addListener(VoidCallback listener) {
    _systemFontsCallbacks.add(listener);
  }
  @override
  void removeListener(VoidCallback listener) {
    _systemFontsCallbacks.remove(listener);
  }
}

ImageCache get imageCache => PaintingBinding.instance.imageCache;