// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'basic.dart';
import 'debug.dart';
import 'framework.dart';
import 'gesture_detector.dart';
import 'navigator.dart';
import 'transitions.dart';

class _SemanticsClipper extends SingleChildRenderObjectWidget{
  const _SemanticsClipper({
    super.child,
    required this.clipDetailsNotifier,
  });

  final ValueNotifier<EdgeInsets> clipDetailsNotifier;

  @override
  _RenderSemanticsClipper createRenderObject(BuildContext context) {
    return _RenderSemanticsClipper(clipDetailsNotifier: clipDetailsNotifier,);
  }

  @override
  void updateRenderObject(BuildContext context, _RenderSemanticsClipper renderObject) {
    renderObject.clipDetailsNotifier = clipDetailsNotifier;
  }
}
class _RenderSemanticsClipper extends RenderProxyBox {
  _RenderSemanticsClipper({
    required ValueNotifier<EdgeInsets> clipDetailsNotifier,
    RenderBox? child,
  }) : _clipDetailsNotifier = clipDetailsNotifier,
      super(child);

  ValueNotifier<EdgeInsets> _clipDetailsNotifier;

  ValueNotifier<EdgeInsets> get clipDetailsNotifier => _clipDetailsNotifier;
  set clipDetailsNotifier (ValueNotifier<EdgeInsets> newNotifier) {
    if (_clipDetailsNotifier == newNotifier) {
      return;
    }
    if (attached) {
      _clipDetailsNotifier.removeListener(markNeedsSemanticsUpdate);
    }
    _clipDetailsNotifier = newNotifier;
    _clipDetailsNotifier.addListener(markNeedsSemanticsUpdate);
    markNeedsSemanticsUpdate();
  }

  @override
  Rect get semanticBounds {
    final EdgeInsets clipDetails = _clipDetailsNotifier.value;
    final Rect originalRect = super.semanticBounds;
    final Rect clippedRect = Rect.fromLTRB(
      originalRect.left + clipDetails.left,
      originalRect.top + clipDetails.top,
      originalRect.right - clipDetails.right,
      originalRect.bottom - clipDetails.bottom,
    );
    return clippedRect;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    clipDetailsNotifier.addListener(markNeedsSemanticsUpdate);
  }

  @override
  void detach() {
    clipDetailsNotifier.removeListener(markNeedsSemanticsUpdate);
    super.detach();
  }

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isSemanticBoundary = true;
  }
}

class ModalBarrier extends StatelessWidget {
  const ModalBarrier({
    super.key,
    this.color,
    this.dismissible = true,
    this.onDismiss,
    this.semanticsLabel,
    this.barrierSemanticsDismissible = true,
    this.clipDetailsNotifier,
    this.semanticsOnTapHint,
  });

  final Color? color;

  final bool dismissible;

  final VoidCallback? onDismiss;

  final bool? barrierSemanticsDismissible;

  final String? semanticsLabel;

  final ValueNotifier<EdgeInsets>? clipDetailsNotifier;

  final String? semanticsOnTapHint;

  @override
  Widget build(BuildContext context) {
    assert(!dismissible || semanticsLabel == null || debugCheckHasDirectionality(context));
    final bool platformSupportsDismissingBarrier;
    switch (defaultTargetPlatform) {
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        platformSupportsDismissingBarrier = false;
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        platformSupportsDismissingBarrier = true;
    }
    final bool semanticsDismissible = dismissible && platformSupportsDismissingBarrier;
    final bool modalBarrierSemanticsDismissible = barrierSemanticsDismissible ?? semanticsDismissible;

    void handleDismiss() {
      if (dismissible) {
        if (onDismiss != null) {
          onDismiss!();
        } else {
          Navigator.maybePop(context);
        }
      } else {
        SystemSound.play(SystemSoundType.alert);
      }
    }

    Widget barrier = Semantics(
      onTapHint: semanticsOnTapHint,
      onTap: semanticsDismissible && semanticsLabel != null ? handleDismiss : null,
      onDismiss: semanticsDismissible && semanticsLabel != null ? handleDismiss : null,
      label: semanticsDismissible ? semanticsLabel : null,
      textDirection: semanticsDismissible && semanticsLabel != null ? Directionality.of(context) : null,
      child: MouseRegion(
        cursor: SystemMouseCursors.basic,
        child: ConstrainedBox(
        constraints: const BoxConstraints.expand(),
        child: color == null ? null : ColoredBox(
          color: color!,
          ),
        ),
      ),
    );

    // Developers can set [dismissible: true] and [barrierSemanticsDismissible: true]
    // to allow assistive technology users to dismiss a modal BottomSheet by
    // tapping on the Scrim focus.
    // On iOS, some modal barriers are not dismissible in accessibility mode.
    final bool excluding = !semanticsDismissible || !modalBarrierSemanticsDismissible;

    if (!excluding && clipDetailsNotifier != null) {
      barrier = _SemanticsClipper(
        clipDetailsNotifier: clipDetailsNotifier!,
        child: barrier,
      );
    }

    return BlockSemantics(
      child: ExcludeSemantics(
        excluding: excluding,
        child: _ModalBarrierGestureDetector(
          onDismiss: handleDismiss,
          child: barrier,
        ),
      ),
    );
  }
}

class AnimatedModalBarrier extends AnimatedWidget {
  const AnimatedModalBarrier({
    super.key,
    required Animation<Color?> color,
    this.dismissible = true,
    this.semanticsLabel,
    this.barrierSemanticsDismissible,
    this.onDismiss,
    this.clipDetailsNotifier,
    this.semanticsOnTapHint,
  }) : super(listenable: color);

  Animation<Color?> get color => listenable as Animation<Color?>;

  final bool dismissible;

  final String? semanticsLabel;

  final bool? barrierSemanticsDismissible;

  final VoidCallback? onDismiss;

  final ValueNotifier<EdgeInsets>? clipDetailsNotifier;

  final String? semanticsOnTapHint;

  @override
  Widget build(BuildContext context) {
    return ModalBarrier(
      color: color.value,
      dismissible: dismissible,
      semanticsLabel: semanticsLabel,
      barrierSemanticsDismissible: barrierSemanticsDismissible,
      onDismiss: onDismiss,
      clipDetailsNotifier: clipDetailsNotifier,
      semanticsOnTapHint: semanticsOnTapHint,
    );
  }
}

// Recognizes tap down by any pointer button.
//
// It is similar to [TapGestureRecognizer.onTapDown], but accepts any single
// button, which means the gesture also takes parts in gesture arenas.
class _AnyTapGestureRecognizer extends BaseTapGestureRecognizer {
  _AnyTapGestureRecognizer();

  VoidCallback? onAnyTapUp;

  @protected
  @override
  bool isPointerAllowed(PointerDownEvent event) {
    if (onAnyTapUp == null) {
      return false;
    }
    return super.isPointerAllowed(event);
  }

  @protected
  @override
  void handleTapDown({PointerDownEvent? down}) {
    // Do nothing.
  }

  @protected
  @override
  void handleTapUp({PointerDownEvent? down, PointerUpEvent? up}) {
    if (onAnyTapUp != null) {
      invokeCallback('onAnyTapUp', onAnyTapUp!);
    }
  }

  @protected
  @override
  void handleTapCancel({PointerDownEvent? down, PointerCancelEvent? cancel, String? reason}) {
    // Do nothing.
  }

  @override
  String get debugDescription => 'any tap';
}

class _AnyTapGestureRecognizerFactory extends GestureRecognizerFactory<_AnyTapGestureRecognizer> {
  const _AnyTapGestureRecognizerFactory({this.onAnyTapUp});

  final VoidCallback? onAnyTapUp;

  @override
  _AnyTapGestureRecognizer constructor() => _AnyTapGestureRecognizer();

  @override
  void initializer(_AnyTapGestureRecognizer instance) {
    instance.onAnyTapUp = onAnyTapUp;
  }
}

// A GestureDetector used by ModalBarrier. It only has one callback,
// [onAnyTapDown], which recognizes tap down unconditionally.
class _ModalBarrierGestureDetector extends StatelessWidget {
  const _ModalBarrierGestureDetector({
    required this.child,
    required this.onDismiss,
  });

  final Widget child;

  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final Map<Type, GestureRecognizerFactory> gestures = <Type, GestureRecognizerFactory>{
      _AnyTapGestureRecognizer: _AnyTapGestureRecognizerFactory(onAnyTapUp: onDismiss),
    };

    return RawGestureDetector(
      gestures: gestures,
      behavior: HitTestBehavior.opaque,
      child: child,
    );
  }
}