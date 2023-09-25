// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:ui' show Color;

import 'framework.dart';

class BottomNavigationBarItem {
  const BottomNavigationBarItem({
    required this.icon,
    this.label,
    Widget? activeIcon,
    this.backgroundColor,
    this.tooltip,
  }) : activeIcon = activeIcon ?? icon;

  final Widget icon;

  final Widget activeIcon;

  final String? label;

  final Color? backgroundColor;

  final String? tooltip;
}