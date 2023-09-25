// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:html';

import 'package:flutter_test/flutter_test.dart';

bool get isFirefox => window.navigator.userAgent.toLowerCase().contains('firefox');

List<Node> findElements(String selector) {
  final Element? flutterView = document.querySelector('flutter-view');

  if (flutterView == null) {
    fail(
      'Failed to locate <flutter-view>. Possible reasons:\n'
      ' - The application failed to start'
      ' - `findElements` was called before the application started'
    );
  }

  return flutterView.querySelectorAll(selector);
}