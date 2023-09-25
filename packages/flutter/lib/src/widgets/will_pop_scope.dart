// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'framework.dart';
import 'navigator.dart';
import 'routes.dart';

@Deprecated(
  'Use PopScope instead. '
  'This feature was deprecated after v3.12.0-1.0.pre.',
)
class WillPopScope extends StatefulWidget {
  @Deprecated(
    'Use PopScope instead. '
    'This feature was deprecated after v3.12.0-1.0.pre.',
  )
  const WillPopScope({
    super.key,
    required this.child,
    required this.onWillPop,
  });

  final Widget child;

  final WillPopCallback? onWillPop;

  @override
  State<WillPopScope> createState() => _WillPopScopeState();
}

class _WillPopScopeState extends State<WillPopScope> {
  ModalRoute<dynamic>? _route;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.onWillPop != null) {
      _route?.removeScopedWillPopCallback(widget.onWillPop!);
    }
    _route = ModalRoute.of(context);
    if (widget.onWillPop != null) {
      _route?.addScopedWillPopCallback(widget.onWillPop!);
    }
  }

  @override
  void didUpdateWidget(WillPopScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.onWillPop != oldWidget.onWillPop && _route != null) {
      if (oldWidget.onWillPop != null) {
        _route!.removeScopedWillPopCallback(oldWidget.onWillPop!);
      }
      if (widget.onWillPop != null) {
        _route!.addScopedWillPopCallback(widget.onWillPop!);
      }
    }
  }

  @override
  void dispose() {
    if (widget.onWillPop != null) {
      _route?.removeScopedWillPopCallback(widget.onWillPop!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}