// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

String extractPathname(String url) {
  return ensureLeadingSlash(Uri.parse(url).path);
}

String checkBaseHref(String? baseHref) {
  if (baseHref == null) {
    throw Exception('Please add a <base> element to your index.html');
  }
  if (!baseHref.endsWith('/')) {
    throw Exception('The base href has to end with a "/" to work correctly');
  }
  return baseHref;
}

String ensureLeadingSlash(String path) {
  if (!path.startsWith('/')) {
    return '/$path';
  }
  return path;
}

String stripTrailingSlash(String path) {
  if (path.endsWith('/')) {
    return path.substring(0, path.length - 1);
  }
  return path;
}