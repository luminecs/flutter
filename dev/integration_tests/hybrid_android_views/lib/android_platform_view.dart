// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

MethodChannel channel = const MethodChannel('android_views_integration');

class AndroidPlatformView extends StatelessWidget {
  const AndroidPlatformView({
    super.key,
    this.onPlatformViewCreated,
    this.useHybridComposition = false,
    required this.viewType,
  });

  final String viewType;

  final PlatformViewCreatedCallback? onPlatformViewCreated;

  // Use hybrid composition.
  final bool useHybridComposition;

  @override
  Widget build(BuildContext context) {
    return PlatformViewLink(
      viewType: viewType,
      surfaceFactory:
          (BuildContext context, PlatformViewController controller) {
        return AndroidViewSurface(
          controller: controller as AndroidViewController,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        );
      },
      onCreatePlatformView: (PlatformViewCreationParams params) {
        print('useHybridComposition=$useHybridComposition');
        late AndroidViewController controller;
        if (useHybridComposition) {
          controller = PlatformViewsService.initExpensiveAndroidView(
            id: params.id,
            viewType: params.viewType,
            layoutDirection: TextDirection.ltr,
          );
        } else {
          controller = PlatformViewsService.initSurfaceAndroidView(
            id: params.id,
            viewType: params.viewType,
            layoutDirection: TextDirection.ltr,
          );
        }
        if (onPlatformViewCreated != null) {
          controller.addOnPlatformViewCreatedListener(onPlatformViewCreated!);
        }
        return controller
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          ..create();
      },
    );
  }
}