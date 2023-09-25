// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'focus_manager.dart';
import 'focus_scope.dart';
import 'framework.dart';

export 'package:flutter/services.dart' show RawKeyEvent;

class RawKeyboardListener extends StatefulWidget {
  const RawKeyboardListener({
    super.key,
    required this.focusNode,
    this.autofocus = false,
    this.includeSemantics = true,
    this.onKey,
    required this.child,
  });

  final FocusNode focusNode;

  final bool autofocus;

  final bool includeSemantics;

  final ValueChanged<RawKeyEvent>? onKey;

  final Widget child;

  @override
  State<RawKeyboardListener> createState() => _RawKeyboardListenerState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<FocusNode>('focusNode', focusNode));
  }
}

class _RawKeyboardListenerState extends State<RawKeyboardListener> {
  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(RawKeyboardListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      oldWidget.focusNode.removeListener(_handleFocusChanged);
      widget.focusNode.addListener(_handleFocusChanged);
    }
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChanged);
    _detachKeyboardIfAttached();
    super.dispose();
  }

  void _handleFocusChanged() {
    if (widget.focusNode.hasFocus) {
      _attachKeyboardIfDetached();
    } else {
      _detachKeyboardIfAttached();
    }
  }

  bool _listening = false;

  void _attachKeyboardIfDetached() {
    if (_listening) {
      return;
    }
    RawKeyboard.instance.addListener(_handleRawKeyEvent);
    _listening = true;
  }

  void _detachKeyboardIfAttached() {
    if (!_listening) {
      return;
    }
    RawKeyboard.instance.removeListener(_handleRawKeyEvent);
    _listening = false;
  }

  void _handleRawKeyEvent(RawKeyEvent event) {
    widget.onKey?.call(event);
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      includeSemantics: widget.includeSemantics,
      child: widget.child,
    );
  }
}