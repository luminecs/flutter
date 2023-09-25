// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

String replaceFirst(String originalContents, String before, String after) {
  final String result = originalContents.replaceFirst(before, after);
  if (result != originalContents) {
    return result;
  }

  final String beforeCrlf = before.replaceAll('\n', '\r\n');
  final String afterCrlf = after.replaceAll('\n', '\r\n');

  return originalContents.replaceFirst(beforeCrlf, afterCrlf);
}