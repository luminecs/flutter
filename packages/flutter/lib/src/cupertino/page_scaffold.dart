// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'theme.dart';

class CupertinoPageScaffold extends StatefulWidget {
  const CupertinoPageScaffold({
    super.key,
    this.navigationBar,
    this.backgroundColor,
    this.resizeToAvoidBottomInset = true,
    required this.child,
  });

  // TODO(xster): document its page transition animation when ready
  final ObstructingPreferredSizeWidget? navigationBar;

  final Widget child;

  final Color? backgroundColor;

  final bool resizeToAvoidBottomInset;

  @override
  State<CupertinoPageScaffold> createState() => _CupertinoPageScaffoldState();
}

class _CupertinoPageScaffoldState extends State<CupertinoPageScaffold> {

  void _handleStatusBarTap() {
    final ScrollController? primaryScrollController = PrimaryScrollController.maybeOf(context);
    // Only act on the scroll controller if it has any attached scroll positions.
    if (primaryScrollController != null && primaryScrollController.hasClients) {
      primaryScrollController.animateTo(
        0.0,
        // Eyeballed from iOS.
        duration: const Duration(milliseconds: 500),
        curve: Curves.linearToEaseOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget paddedContent = widget.child;

    final MediaQueryData existingMediaQuery = MediaQuery.of(context);
    if (widget.navigationBar != null) {
      // TODO(xster): Use real size after partial layout instead of preferred size.
      // https://github.com/flutter/flutter/issues/12912
      final double topPadding =
          widget.navigationBar!.preferredSize.height + existingMediaQuery.padding.top;

      // Propagate bottom padding and include viewInsets if appropriate
      final double bottomPadding = widget.resizeToAvoidBottomInset
          ? existingMediaQuery.viewInsets.bottom
          : 0.0;

      final EdgeInsets newViewInsets = widget.resizeToAvoidBottomInset
          // The insets are consumed by the scaffolds and no longer exposed to
          // the descendant subtree.
          ? existingMediaQuery.viewInsets.copyWith(bottom: 0.0)
          : existingMediaQuery.viewInsets;

      final bool fullObstruction = widget.navigationBar!.shouldFullyObstruct(context);

      // If navigation bar is opaquely obstructing, directly shift the main content
      // down. If translucent, let main content draw behind navigation bar but hint the
      // obstructed area.
      if (fullObstruction) {
        paddedContent = MediaQuery(
          data: existingMediaQuery
          // If the navigation bar is opaque, the top media query padding is fully consumed by the navigation bar.
          .removePadding(removeTop: true)
          .copyWith(
            viewInsets: newViewInsets,
          ),
          child: Padding(
            padding: EdgeInsets.only(top: topPadding, bottom: bottomPadding),
            child: paddedContent,
          ),
        );
      } else {
        paddedContent = MediaQuery(
          data: existingMediaQuery.copyWith(
            padding: existingMediaQuery.padding.copyWith(
              top: topPadding,
            ),
            viewInsets: newViewInsets,
          ),
          child: Padding(
            padding: EdgeInsets.only(bottom: bottomPadding),
            child: paddedContent,
          ),
        );
      }
    } else {
      // If there is no navigation bar, still may need to add padding in order
      // to support resizeToAvoidBottomInset.
      final double bottomPadding = widget.resizeToAvoidBottomInset
          ? existingMediaQuery.viewInsets.bottom
          : 0.0;
      paddedContent = Padding(
        padding: EdgeInsets.only(bottom: bottomPadding),
        child: paddedContent,
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: CupertinoDynamicColor.maybeResolve(widget.backgroundColor, context)
            ?? CupertinoTheme.of(context).scaffoldBackgroundColor,
      ),
      child: Stack(
        children: <Widget>[
          // The main content being at the bottom is added to the stack first.
          paddedContent,
          if (widget.navigationBar != null)
            Positioned(
              top: 0.0,
              left: 0.0,
              right: 0.0,
              child: MediaQuery.withNoTextScaling(
                child: widget.navigationBar!,
              ),
            ),
          // Add a touch handler the size of the status bar on top of all contents
          // to handle scroll to top by status bar taps.
          Positioned(
            top: 0.0,
            left: 0.0,
            right: 0.0,
            height: existingMediaQuery.padding.top,
            child: GestureDetector(
              excludeFromSemantics: true,
              onTap: _handleStatusBarTap,
            ),
          ),
        ],
      ),
    );
  }
}

abstract class ObstructingPreferredSizeWidget implements PreferredSizeWidget {
  bool shouldFullyObstruct(BuildContext context);
}