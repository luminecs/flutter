// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'basic.dart';
import 'framework.dart';
import 'layout_builder.dart';
import 'media_query.dart';

typedef OrientationWidgetBuilder = Widget Function(BuildContext context, Orientation orientation);

class OrientationBuilder extends StatelessWidget {
  const OrientationBuilder({
    super.key,
    required this.builder,
  });

  final OrientationWidgetBuilder builder;

  Widget _buildWithConstraints(BuildContext context, BoxConstraints constraints) {
    // If the constraints are fully unbounded (i.e., maxWidth and maxHeight are
    // both infinite), we prefer Orientation.portrait because its more common to
    // scroll vertically then horizontally.
    final Orientation orientation = constraints.maxWidth > constraints.maxHeight ? Orientation.landscape : Orientation.portrait;
    return builder(context, orientation);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: _buildWithConstraints);
  }
}