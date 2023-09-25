// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

Never throwToolExit(String? message, { int? exitCode }) {
  throw ToolExit(message, exitCode: exitCode);
}

class ToolExit implements Exception {
  ToolExit(this.message, { this.exitCode });

  final String? message;
  final int? exitCode;

  @override
  String toString() => 'Exception: $message'; // TODO(ianh): Really this should say "Error".
}