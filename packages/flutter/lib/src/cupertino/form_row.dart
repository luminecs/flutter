// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'theme.dart';

// Content padding determined via SwiftUI's `Form` view in the iOS 14.2 SDK.
const EdgeInsetsGeometry _kDefaultPadding =
    EdgeInsetsDirectional.fromSTEB(20.0, 6.0, 6.0, 6.0);

class CupertinoFormRow extends StatelessWidget {
  const CupertinoFormRow({
    super.key,
    required this.child,
    this.prefix,
    this.padding,
    this.helper,
    this.error,
  });

  final Widget? prefix;

  final EdgeInsetsGeometry? padding;

  final Widget? helper;

  final Widget? error;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final CupertinoThemeData theme = CupertinoTheme.of(context);
    final TextStyle textStyle = theme.textTheme.textStyle.copyWith(
      color: CupertinoDynamicColor.maybeResolve(theme.textTheme.textStyle.color, context)
    );

    return Padding(
      padding: padding ?? _kDefaultPadding,
      child: Column(
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              if (prefix != null)
                DefaultTextStyle(
                  style: textStyle,
                  child: prefix!,
                ),
              Flexible(
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: child,
                ),
              ),
            ],
          ),
          if (helper != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: DefaultTextStyle(
                style: textStyle,
                child: helper!,
              ),
            ),
          if (error != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: DefaultTextStyle(
                style: const TextStyle(
                  color: CupertinoColors.destructiveRed,
                  fontWeight: FontWeight.w500,
                ),
                child: error!,
              ),
            ),
        ],
      ),
    );
  }
}