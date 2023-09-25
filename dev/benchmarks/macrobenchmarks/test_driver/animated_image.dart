// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_driver/driver_extension.dart';

import 'package:macrobenchmarks/src/animated_image.dart';

Future<void> main() async {
  final Completer<void> waiter = Completer<void>();
  enableFlutterDriverExtension(handler: (String? request) async {
    if (request != 'waitForAnimation') {
      throw UnsupportedError('Unrecognized request $request');
    }
    await waiter.future;
    return 'done';
  });
  runApp(MaterialApp(
    home: AnimatedImagePage(
      onFrame: (int frameNumber) {
        if (frameNumber == 250) {
          waiter.complete();
        }
      },
    ),
  ));
}