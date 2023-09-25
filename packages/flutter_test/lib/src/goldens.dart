// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:typed_data';
import 'dart:ui';

import 'package:path/path.dart' as path;

import '_goldens_io.dart' if (dart.library.html) '_goldens_web.dart' as goldens;

abstract class GoldenFileComparator {
  Future<bool> compare(Uint8List imageBytes, Uri golden);

  Future<void> update(Uri golden, Uint8List imageBytes);

  Uri getTestUri(Uri key, int? version) {
    if (version == null) {
      return key;
    }
    final String keyString = key.toString();
    final String extension = path.extension(keyString);
    return Uri.parse('${keyString.split(extension).join()}.$version$extension');
  }

  static Future<ComparisonResult> compareLists(List<int> test, List<int> master) {
    return goldens.compareLists(test, master);
  }
}

GoldenFileComparator get goldenFileComparator => _goldenFileComparator;
GoldenFileComparator _goldenFileComparator = const TrivialComparator._();
set goldenFileComparator(GoldenFileComparator value) {
  _goldenFileComparator = value;
}

abstract class WebGoldenComparator {
  Future<bool> compare(double width, double height, Uri golden);

  Future<void> update(double width, double height, Uri golden);

  Uri getTestUri(Uri key, int? version) {
    if (version == null) {
      return key;
    }
    final String keyString = key.toString();
    final String extension = path.extension(keyString);
    return Uri.parse('${keyString.split(extension).join()}.$version$extension');
  }
}

WebGoldenComparator get webGoldenComparator => _webGoldenComparator;
WebGoldenComparator _webGoldenComparator = const _TrivialWebGoldenComparator._();
set webGoldenComparator(WebGoldenComparator value) {
  _webGoldenComparator = value;
}

bool autoUpdateGoldenFiles = false;

class TrivialComparator implements GoldenFileComparator {
  const TrivialComparator._();

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) {
    // Ideally we would use markTestSkipped here but in some situations,
    // comparators are called outside of tests.
    // See also: https://github.com/flutter/flutter/issues/91285
    // ignore: avoid_print
    print('Golden file comparison requested for "$golden"; skipping...');
    return Future<bool>.value(true);
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) {
    throw StateError('goldenFileComparator has not been initialized');
  }

  @override
  Uri getTestUri(Uri key, int? version) {
    return key;
  }
}

class _TrivialWebGoldenComparator implements WebGoldenComparator {
  const _TrivialWebGoldenComparator._();

  @override
  Future<bool> compare(double width, double height, Uri golden) {
    // Ideally we would use markTestSkipped here but in some situations,
    // comparators are called outside of tests.
    // See also: https://github.com/flutter/flutter/issues/91285
    // ignore: avoid_print
    print('Golden comparison requested for "$golden"; skipping...');
    return Future<bool>.value(true);
  }

  @override
  Future<void> update(double width, double height, Uri golden) {
    throw StateError('webGoldenComparator has not been initialized');
  }

  @override
  Uri getTestUri(Uri key, int? version) {
    return key;
  }
}

class ComparisonResult {
  ComparisonResult({
    required this.passed,
    required this.diffPercent,
    this.error,
    this.diffs,
  });

  final bool passed;

  final String? error;

  final Map<String, Image>? diffs;

  final double diffPercent;
}