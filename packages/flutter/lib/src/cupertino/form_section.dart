// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'list_section.dart';

// Used for iOS "Inset Grouped" margin, determined from SwiftUI's Forms in
// iOS 14.2 SDK.
const EdgeInsetsDirectional _kFormDefaultInsetGroupedRowsMargin = EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 10.0);

// Standard header margin, determined from SwiftUI's Forms in iOS 14.2 SDK.
const EdgeInsetsDirectional _kFormDefaultHeaderMargin = EdgeInsetsDirectional.fromSTEB(20.0, 16.0, 20.0, 10.0);

// Standard footer margin, determined from SwiftUI's Forms in iOS 14.2 SDK.
const EdgeInsetsDirectional _kFormDefaultFooterMargin = EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 10.0);

class CupertinoFormSection extends StatelessWidget {
  const CupertinoFormSection({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.margin = EdgeInsets.zero,
    this.backgroundColor = CupertinoColors.systemGroupedBackground,
    this.decoration,
    this.clipBehavior = Clip.none,
  })  : _type = CupertinoListSectionType.base,
        assert(children.length > 0);

  const CupertinoFormSection.insetGrouped({
    super.key,
    required this.children,
    this.header,
    this.footer,
    this.margin = _kFormDefaultInsetGroupedRowsMargin,
    this.backgroundColor = CupertinoColors.systemGroupedBackground,
    this.decoration,
    this.clipBehavior = Clip.none,
  })  : _type = CupertinoListSectionType.insetGrouped,
        assert(children.length > 0);

  final CupertinoListSectionType _type;

  final Widget? header;

  final Widget? footer;

  final EdgeInsetsGeometry margin;

  final List<Widget> children;

  final BoxDecoration? decoration;

  final Color backgroundColor;

  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final Widget? headerWidget = header == null
        ? null
        : DefaultTextStyle(
            style: TextStyle(
              fontSize: 13.0,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
            child: Padding(
              padding: _kFormDefaultHeaderMargin,
              child: header,
            ));

    final Widget? footerWidget = footer == null
        ? null
        : DefaultTextStyle(
            style: TextStyle(
              fontSize: 13.0,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
            child: Padding(
              padding: _kFormDefaultFooterMargin,
              child: footer,
            ));

    return _type == CupertinoListSectionType.base
        ? CupertinoListSection(
            header: headerWidget,
            footer: footerWidget,
            margin: margin,
            backgroundColor: backgroundColor,
            decoration: decoration,
            clipBehavior: clipBehavior,
            hasLeading: false,
            children: children)
        : CupertinoListSection.insetGrouped(
            header: headerWidget,
            footer: footerWidget,
            margin: margin,
            backgroundColor: backgroundColor,
            decoration: decoration,
            clipBehavior: clipBehavior,
            hasLeading: false,
            children: children);
  }
}