// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'basic.dart';
import 'framework.dart';

abstract class StatusTransitionWidget extends StatefulWidget {
  const StatusTransitionWidget({
    super.key,
    required this.animation,
  });

  final Animation<double> animation;

  Widget build(BuildContext context);

  @override
  State<StatusTransitionWidget> createState() => _StatusTransitionState();
}

class _StatusTransitionState extends State<StatusTransitionWidget> {
  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_animationStatusChanged);
  }

  @override
  void didUpdateWidget(StatusTransitionWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animation != oldWidget.animation) {
      oldWidget.animation.removeStatusListener(_animationStatusChanged);
      widget.animation.addStatusListener(_animationStatusChanged);
    }
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_animationStatusChanged);
    super.dispose();
  }

  void _animationStatusChanged(AnimationStatus status) {
    setState(() {
      // The animation's state is our build state, and it changed already.
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.build(context);
  }
}