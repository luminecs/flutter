// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Examples can assume:
// class Cat { }

class Category {
  const Category(this.sections);

  final List<String> sections;
}

class DocumentationIcon {
  const DocumentationIcon(this.url);

  final String url;
}

class Summary {
  const Summary(this.text);

  final String text;
}