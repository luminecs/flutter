// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io' show Platform;

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:file/memory.dart';

FileSystem fs = const LocalFileSystem();

void useMemoryFileSystemForTesting() {
  fs = MemoryFileSystem();
}

void restoreFileSystem() {
  fs = const LocalFileSystem();
}

String get testOutputsDirectory => Platform.environment['FLUTTER_TEST_OUTPUTS_DIR'] ?? 'build';