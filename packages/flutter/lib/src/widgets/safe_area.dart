// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'basic.dart';
import 'debug.dart';
import 'framework.dart';
import 'media_query.dart';

class SafeArea extends StatelessWidget {
  const SafeArea({
    super.key,
    this.left = true,
    this.top = true,
    this.right = true,
    this.bottom = true,
    this.minimum = EdgeInsets.zero,
    this.maintainBottomViewPadding = false,
    required this.child,
  });

  final bool left;

  final bool top;

  final bool right;

  final bool bottom;

  final EdgeInsets minimum;

  final bool maintainBottomViewPadding;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMediaQuery(context));
    EdgeInsets padding = MediaQuery.paddingOf(context);
    // Bottom padding has been consumed - i.e. by the keyboard
    if (maintainBottomViewPadding) {
      padding = padding.copyWith(bottom: MediaQuery.viewPaddingOf(context).bottom);
    }

    return Padding(
      padding: EdgeInsets.only(
        left: math.max(left ? padding.left : 0.0, minimum.left),
        top: math.max(top ? padding.top : 0.0, minimum.top),
        right: math.max(right ? padding.right : 0.0, minimum.right),
        bottom: math.max(bottom ? padding.bottom : 0.0, minimum.bottom),
      ),
      child: MediaQuery.removePadding(
        context: context,
        removeLeft: left,
        removeTop: top,
        removeRight: right,
        removeBottom: bottom,
        child: child,
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('left', value: left, ifTrue: 'avoid left padding'));
    properties.add(FlagProperty('top', value: top, ifTrue: 'avoid top padding'));
    properties.add(FlagProperty('right', value: right, ifTrue: 'avoid right padding'));
    properties.add(FlagProperty('bottom', value: bottom, ifTrue: 'avoid bottom padding'));
  }
}

class SliverSafeArea extends StatelessWidget {
  const SliverSafeArea({
    super.key,
    this.left = true,
    this.top = true,
    this.right = true,
    this.bottom = true,
    this.minimum = EdgeInsets.zero,
    required this.sliver,
  });

  final bool left;

  final bool top;

  final bool right;

  final bool bottom;

  final EdgeInsets minimum;

  final Widget sliver;

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMediaQuery(context));
    final EdgeInsets padding = MediaQuery.paddingOf(context);
    return SliverPadding(
      padding: EdgeInsets.only(
        left: math.max(left ? padding.left : 0.0, minimum.left),
        top: math.max(top ? padding.top : 0.0, minimum.top),
        right: math.max(right ? padding.right : 0.0, minimum.right),
        bottom: math.max(bottom ? padding.bottom : 0.0, minimum.bottom),
      ),
      sliver: MediaQuery.removePadding(
        context: context,
        removeLeft: left,
        removeTop: top,
        removeRight: right,
        removeBottom: bottom,
        child: sliver,
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(FlagProperty('left', value: left, ifTrue: 'avoid left padding'));
    properties.add(FlagProperty('top', value: top, ifTrue: 'avoid top padding'));
    properties.add(FlagProperty('right', value: right, ifTrue: 'avoid right padding'));
    properties.add(FlagProperty('bottom', value: bottom, ifTrue: 'avoid bottom padding'));
  }
}