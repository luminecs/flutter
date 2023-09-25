// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'focus_manager.dart';
import 'focus_scope.dart';
import 'framework.dart';

export 'package:flutter/services.dart' show KeyEvent;

class KeyboardListener extends StatelessWidget {
  const KeyboardListener({
    super.key,
    required this.focusNode,
    this.autofocus = false,
    this.includeSemantics = true,
    this.onKeyEvent,
    required this.child,
  });

  final FocusNode focusNode;

  final bool autofocus;

  final bool includeSemantics;

  final ValueChanged<KeyEvent>? onKeyEvent;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: focusNode,
      autofocus: autofocus,
      includeSemantics: includeSemantics,
      onKeyEvent: (FocusNode node, KeyEvent event) {
        onKeyEvent?.call(event);
        return KeyEventResult.ignored;
      },
      child: child,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<FocusNode>('focusNode', focusNode));
  }
}