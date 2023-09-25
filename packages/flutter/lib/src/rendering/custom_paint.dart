// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';

import 'box.dart';
import 'object.dart';
import 'proxy_box.dart';

typedef SemanticsBuilderCallback = List<CustomPainterSemantics> Function(Size size);

abstract class CustomPainter extends Listenable {
  const CustomPainter({ Listenable? repaint }) : _repaint = repaint;

  final Listenable? _repaint;

  @override
  void addListener(VoidCallback listener) => _repaint?.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _repaint?.removeListener(listener);

  void paint(Canvas canvas, Size size);

  SemanticsBuilderCallback? get semanticsBuilder => null;

  bool shouldRebuildSemantics(covariant CustomPainter oldDelegate) => shouldRepaint(oldDelegate);

  bool shouldRepaint(covariant CustomPainter oldDelegate);

  bool? hitTest(Offset position) => null;

  @override
  String toString() => '${describeIdentity(this)}(${ _repaint?.toString() ?? "" })';
}

@immutable
class CustomPainterSemantics {
  const CustomPainterSemantics({
    this.key,
    required this.rect,
    required this.properties,
    this.transform,
    this.tags,
  });

  final Key? key;

  final Rect rect;

  final Matrix4? transform;

  final SemanticsProperties properties;

  final Set<SemanticsTag>? tags;
}

class RenderCustomPaint extends RenderProxyBox {
  RenderCustomPaint({
    CustomPainter? painter,
    CustomPainter? foregroundPainter,
    Size preferredSize = Size.zero,
    this.isComplex = false,
    this.willChange = false,
    RenderBox? child,
  }) : _painter = painter,
       _foregroundPainter = foregroundPainter,
       _preferredSize = preferredSize,
       super(child);

  CustomPainter? get painter => _painter;
  CustomPainter? _painter;
  set painter(CustomPainter? value) {
    if (_painter == value) {
      return;
    }
    final CustomPainter? oldPainter = _painter;
    _painter = value;
    _didUpdatePainter(_painter, oldPainter);
  }

  CustomPainter? get foregroundPainter => _foregroundPainter;
  CustomPainter? _foregroundPainter;
  set foregroundPainter(CustomPainter? value) {
    if (_foregroundPainter == value) {
      return;
    }
    final CustomPainter? oldPainter = _foregroundPainter;
    _foregroundPainter = value;
    _didUpdatePainter(_foregroundPainter, oldPainter);
  }

  void _didUpdatePainter(CustomPainter? newPainter, CustomPainter? oldPainter) {
    // Check if we need to repaint.
    if (newPainter == null) {
      assert(oldPainter != null); // We should be called only for changes.
      markNeedsPaint();
    } else if (oldPainter == null ||
        newPainter.runtimeType != oldPainter.runtimeType ||
        newPainter.shouldRepaint(oldPainter)) {
      markNeedsPaint();
    }
    if (attached) {
      oldPainter?.removeListener(markNeedsPaint);
      newPainter?.addListener(markNeedsPaint);
    }

    // Check if we need to rebuild semantics.
    if (newPainter == null) {
      assert(oldPainter != null); // We should be called only for changes.
      if (attached) {
        markNeedsSemanticsUpdate();
      }
    } else if (oldPainter == null ||
        newPainter.runtimeType != oldPainter.runtimeType ||
        newPainter.shouldRebuildSemantics(oldPainter)) {
      markNeedsSemanticsUpdate();
    }
  }

  Size get preferredSize => _preferredSize;
  Size _preferredSize;
  set preferredSize(Size value) {
    if (preferredSize == value) {
      return;
    }
    _preferredSize = value;
    markNeedsLayout();
  }

  bool isComplex;

  bool willChange;

  @override
  double computeMinIntrinsicWidth(double height) {
    if (child == null) {
      return preferredSize.width.isFinite ? preferredSize.width : 0;
    }
    return super.computeMinIntrinsicWidth(height);
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    if (child == null) {
      return preferredSize.width.isFinite ? preferredSize.width : 0;
    }
    return super.computeMaxIntrinsicWidth(height);
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    if (child == null) {
      return preferredSize.height.isFinite ? preferredSize.height : 0;
    }
    return super.computeMinIntrinsicHeight(width);
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    if (child == null) {
      return preferredSize.height.isFinite ? preferredSize.height : 0;
    }
    return super.computeMaxIntrinsicHeight(width);
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _painter?.addListener(markNeedsPaint);
    _foregroundPainter?.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _painter?.removeListener(markNeedsPaint);
    _foregroundPainter?.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, { required Offset position }) {
    if (_foregroundPainter != null && (_foregroundPainter!.hitTest(position) ?? false)) {
      return true;
    }
    return super.hitTestChildren(result, position: position);
  }

  @override
  bool hitTestSelf(Offset position) {
    return _painter != null && (_painter!.hitTest(position) ?? true);
  }

  @override
  void performLayout() {
    super.performLayout();
    markNeedsSemanticsUpdate();
  }

  @override
  Size computeSizeForNoChild(BoxConstraints constraints) {
    return constraints.constrain(preferredSize);
  }

  void _paintWithPainter(Canvas canvas, Offset offset, CustomPainter painter) {
    late int debugPreviousCanvasSaveCount;
    canvas.save();
    assert(() {
      debugPreviousCanvasSaveCount = canvas.getSaveCount();
      return true;
    }());
    if (offset != Offset.zero) {
      canvas.translate(offset.dx, offset.dy);
    }
    painter.paint(canvas, size);
    assert(() {
      // This isn't perfect. For example, we can't catch the case of
      // someone first restoring, then setting a transform or whatnot,
      // then saving.
      // If this becomes a real problem, we could add logic to the
      // Canvas class to lock the canvas at a particular save count
      // such that restore() fails if it would take the lock count
      // below that number.
      final int debugNewCanvasSaveCount = canvas.getSaveCount();
      if (debugNewCanvasSaveCount > debugPreviousCanvasSaveCount) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
            'The $painter custom painter called canvas.save() or canvas.saveLayer() at least '
            '${debugNewCanvasSaveCount - debugPreviousCanvasSaveCount} more '
            'time${debugNewCanvasSaveCount - debugPreviousCanvasSaveCount == 1 ? '' : 's' } '
            'than it called canvas.restore().',
          ),
          ErrorDescription('This leaves the canvas in an inconsistent state and will probably result in a broken display.'),
          ErrorHint('You must pair each call to save()/saveLayer() with a later matching call to restore().'),
        ]);
      }
      if (debugNewCanvasSaveCount < debugPreviousCanvasSaveCount) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
            'The $painter custom painter called canvas.restore() '
            '${debugPreviousCanvasSaveCount - debugNewCanvasSaveCount} more '
            'time${debugPreviousCanvasSaveCount - debugNewCanvasSaveCount == 1 ? '' : 's' } '
            'than it called canvas.save() or canvas.saveLayer().',
          ),
          ErrorDescription('This leaves the canvas in an inconsistent state and will result in a broken display.'),
          ErrorHint('You should only call restore() if you first called save() or saveLayer().'),
        ]);
      }
      return debugNewCanvasSaveCount == debugPreviousCanvasSaveCount;
    }());
    canvas.restore();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_painter != null) {
      _paintWithPainter(context.canvas, offset, _painter!);
      _setRasterCacheHints(context);
    }
    super.paint(context, offset);
    if (_foregroundPainter != null) {
      _paintWithPainter(context.canvas, offset, _foregroundPainter!);
      _setRasterCacheHints(context);
    }
  }

  void _setRasterCacheHints(PaintingContext context) {
    if (isComplex) {
      context.setIsComplexHint();
    }
    if (willChange) {
      context.setWillChangeHint();
    }
  }

  SemanticsBuilderCallback? _backgroundSemanticsBuilder;

  SemanticsBuilderCallback? _foregroundSemanticsBuilder;

  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    _backgroundSemanticsBuilder = painter?.semanticsBuilder;
    _foregroundSemanticsBuilder = foregroundPainter?.semanticsBuilder;
    config.isSemanticBoundary = _backgroundSemanticsBuilder != null || _foregroundSemanticsBuilder != null;
  }

  List<SemanticsNode>? _backgroundSemanticsNodes;

  List<SemanticsNode>? _foregroundSemanticsNodes;

  @override
  void assembleSemanticsNode(
    SemanticsNode node,
    SemanticsConfiguration config,
    Iterable<SemanticsNode> children,
  ) {
    assert(() {
      if (child == null && children.isNotEmpty) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary(
            '$runtimeType does not have a child widget but received a non-empty list of child SemanticsNode:\n'
            '${children.join('\n')}',
          ),
        ]);
      }
      return true;
    }());

    final List<CustomPainterSemantics> backgroundSemantics = _backgroundSemanticsBuilder != null
      ? _backgroundSemanticsBuilder!(size)
      : const <CustomPainterSemantics>[];
    _backgroundSemanticsNodes = _updateSemanticsChildren(_backgroundSemanticsNodes, backgroundSemantics);

    final List<CustomPainterSemantics> foregroundSemantics = _foregroundSemanticsBuilder != null
      ? _foregroundSemanticsBuilder!(size)
      : const <CustomPainterSemantics>[];
    _foregroundSemanticsNodes = _updateSemanticsChildren(_foregroundSemanticsNodes, foregroundSemantics);

    final bool hasBackgroundSemantics = _backgroundSemanticsNodes != null && _backgroundSemanticsNodes!.isNotEmpty;
    final bool hasForegroundSemantics = _foregroundSemanticsNodes != null && _foregroundSemanticsNodes!.isNotEmpty;
    final List<SemanticsNode> finalChildren = <SemanticsNode>[
      if (hasBackgroundSemantics) ..._backgroundSemanticsNodes!,
      ...children,
      if (hasForegroundSemantics) ..._foregroundSemanticsNodes!,
    ];
    super.assembleSemanticsNode(node, config, finalChildren);
  }

  @override
  void clearSemantics() {
    super.clearSemantics();
    _backgroundSemanticsNodes = null;
    _foregroundSemanticsNodes = null;
  }

  static List<SemanticsNode> _updateSemanticsChildren(
    List<SemanticsNode>? oldSemantics,
    List<CustomPainterSemantics>? newChildSemantics,
  ) {
    oldSemantics = oldSemantics ?? const <SemanticsNode>[];
    newChildSemantics = newChildSemantics ?? const <CustomPainterSemantics>[];

    assert(() {
      final Map<Key, int> keys = HashMap<Key, int>();
      final List<DiagnosticsNode> information = <DiagnosticsNode>[];
      for (int i = 0; i < newChildSemantics!.length; i += 1) {
        final CustomPainterSemantics child = newChildSemantics[i];
        if (child.key != null) {
          if (keys.containsKey(child.key)) {
            information.add(ErrorDescription('- duplicate key ${child.key} found at position $i'));
          }
          keys[child.key!] = i;
        }
      }

      if (information.isNotEmpty) {
        information.insert(0, ErrorSummary('Failed to update the list of CustomPainterSemantics:'));
        throw FlutterError.fromParts(information);
      }

      return true;
    }());

    int newChildrenTop = 0;
    int oldChildrenTop = 0;
    int newChildrenBottom = newChildSemantics.length - 1;
    int oldChildrenBottom = oldSemantics.length - 1;

    final List<SemanticsNode?> newChildren = List<SemanticsNode?>.filled(newChildSemantics.length, null);

    // Update the top of the list.
    while ((oldChildrenTop <= oldChildrenBottom) && (newChildrenTop <= newChildrenBottom)) {
      final SemanticsNode oldChild = oldSemantics[oldChildrenTop];
      final CustomPainterSemantics newSemantics = newChildSemantics[newChildrenTop];
      if (!_canUpdateSemanticsChild(oldChild, newSemantics)) {
        break;
      }
      final SemanticsNode newChild = _updateSemanticsChild(oldChild, newSemantics);
      newChildren[newChildrenTop] = newChild;
      newChildrenTop += 1;
      oldChildrenTop += 1;
    }

    // Scan the bottom of the list.
    while ((oldChildrenTop <= oldChildrenBottom) && (newChildrenTop <= newChildrenBottom)) {
      final SemanticsNode oldChild = oldSemantics[oldChildrenBottom];
      final CustomPainterSemantics newChild = newChildSemantics[newChildrenBottom];
      if (!_canUpdateSemanticsChild(oldChild, newChild)) {
        break;
      }
      oldChildrenBottom -= 1;
      newChildrenBottom -= 1;
    }

    // Scan the old children in the middle of the list.
    final bool haveOldChildren = oldChildrenTop <= oldChildrenBottom;
    late final Map<Key, SemanticsNode> oldKeyedChildren;
    if (haveOldChildren) {
      oldKeyedChildren = <Key, SemanticsNode>{};
      while (oldChildrenTop <= oldChildrenBottom) {
        final SemanticsNode oldChild = oldSemantics[oldChildrenTop];
        if (oldChild.key != null) {
          oldKeyedChildren[oldChild.key!] = oldChild;
        }
        oldChildrenTop += 1;
      }
    }

    // Update the middle of the list.
    while (newChildrenTop <= newChildrenBottom) {
      SemanticsNode? oldChild;
      final CustomPainterSemantics newSemantics = newChildSemantics[newChildrenTop];
      if (haveOldChildren) {
        final Key? key = newSemantics.key;
        if (key != null) {
          oldChild = oldKeyedChildren[key];
          if (oldChild != null) {
            if (_canUpdateSemanticsChild(oldChild, newSemantics)) {
              // we found a match!
              // remove it from oldKeyedChildren so we don't unsync it later
              oldKeyedChildren.remove(key);
            } else {
              // Not a match, let's pretend we didn't see it for now.
              oldChild = null;
            }
          }
        }
      }
      assert(oldChild == null || _canUpdateSemanticsChild(oldChild, newSemantics));
      final SemanticsNode newChild = _updateSemanticsChild(oldChild, newSemantics);
      assert(oldChild == newChild || oldChild == null);
      newChildren[newChildrenTop] = newChild;
      newChildrenTop += 1;
    }

    // We've scanned the whole list.
    assert(oldChildrenTop == oldChildrenBottom + 1);
    assert(newChildrenTop == newChildrenBottom + 1);
    assert(newChildSemantics.length - newChildrenTop == oldSemantics.length - oldChildrenTop);
    newChildrenBottom = newChildSemantics.length - 1;
    oldChildrenBottom = oldSemantics.length - 1;

    // Update the bottom of the list.
    while ((oldChildrenTop <= oldChildrenBottom) && (newChildrenTop <= newChildrenBottom)) {
      final SemanticsNode oldChild = oldSemantics[oldChildrenTop];
      final CustomPainterSemantics newSemantics = newChildSemantics[newChildrenTop];
      assert(_canUpdateSemanticsChild(oldChild, newSemantics));
      final SemanticsNode newChild = _updateSemanticsChild(oldChild, newSemantics);
      assert(oldChild == newChild);
      newChildren[newChildrenTop] = newChild;
      newChildrenTop += 1;
      oldChildrenTop += 1;
    }

    assert(() {
      for (final SemanticsNode? node in newChildren) {
        assert(node != null);
      }
      return true;
    }());

    return newChildren.cast<SemanticsNode>();
  }

  static bool _canUpdateSemanticsChild(SemanticsNode oldChild, CustomPainterSemantics newSemantics) {
    return oldChild.key == newSemantics.key;
  }

  static SemanticsNode _updateSemanticsChild(SemanticsNode? oldChild, CustomPainterSemantics newSemantics) {
    assert(oldChild == null || _canUpdateSemanticsChild(oldChild, newSemantics));

    final SemanticsNode newChild = oldChild ?? SemanticsNode(
      key: newSemantics.key,
    );

    final SemanticsProperties properties = newSemantics.properties;
    final SemanticsConfiguration config = SemanticsConfiguration();
    if (properties.sortKey != null) {
      config.sortKey = properties.sortKey;
    }
    if (properties.checked != null) {
      config.isChecked = properties.checked;
    }
    if (properties.mixed != null) {
      config.isCheckStateMixed = properties.mixed;
    }
    if (properties.selected != null) {
      config.isSelected = properties.selected!;
    }
    if (properties.button != null) {
      config.isButton = properties.button!;
    }
    if (properties.expanded != null) {
      config.isExpanded = properties.expanded;
    }
    if (properties.link != null) {
      config.isLink = properties.link!;
    }
    if (properties.textField != null) {
      config.isTextField = properties.textField!;
    }
    if (properties.slider != null) {
      config.isSlider = properties.slider!;
    }
    if (properties.keyboardKey != null) {
      config.isKeyboardKey = properties.keyboardKey!;
    }
    if (properties.readOnly != null) {
      config.isReadOnly = properties.readOnly!;
    }
    if (properties.focusable != null) {
      config.isFocusable = properties.focusable!;
    }
    if (properties.focused != null) {
      config.isFocused = properties.focused!;
    }
    if (properties.enabled != null) {
      config.isEnabled = properties.enabled;
    }
    if (properties.inMutuallyExclusiveGroup != null) {
      config.isInMutuallyExclusiveGroup = properties.inMutuallyExclusiveGroup!;
    }
    if (properties.obscured != null) {
      config.isObscured = properties.obscured!;
    }
    if (properties.multiline != null) {
      config.isMultiline = properties.multiline!;
    }
    if (properties.hidden != null) {
      config.isHidden = properties.hidden!;
    }
    if (properties.header != null) {
      config.isHeader = properties.header!;
    }
    if (properties.scopesRoute != null) {
      config.scopesRoute = properties.scopesRoute!;
    }
    if (properties.namesRoute != null) {
      config.namesRoute = properties.namesRoute!;
    }
    if (properties.liveRegion != null) {
      config.liveRegion = properties.liveRegion!;
    }
    if (properties.maxValueLength != null) {
      config.maxValueLength = properties.maxValueLength;
    }
    if (properties.currentValueLength != null) {
      config.currentValueLength = properties.currentValueLength;
    }
    if (properties.toggled != null) {
      config.isToggled = properties.toggled;
    }
    if (properties.image != null) {
      config.isImage = properties.image!;
    }
    if (properties.label != null) {
      config.label = properties.label!;
    }
    if (properties.value != null) {
      config.value = properties.value!;
    }
    if (properties.increasedValue != null) {
      config.increasedValue = properties.increasedValue!;
    }
    if (properties.decreasedValue != null) {
      config.decreasedValue = properties.decreasedValue!;
    }
    if (properties.hint != null) {
      config.hint = properties.hint!;
    }
    if (properties.textDirection != null) {
      config.textDirection = properties.textDirection;
    }
    if (properties.onTap != null) {
      config.onTap = properties.onTap;
    }
    if (properties.onLongPress != null) {
      config.onLongPress = properties.onLongPress;
    }
    if (properties.onScrollLeft != null) {
      config.onScrollLeft = properties.onScrollLeft;
    }
    if (properties.onScrollRight != null) {
      config.onScrollRight = properties.onScrollRight;
    }
    if (properties.onScrollUp != null) {
      config.onScrollUp = properties.onScrollUp;
    }
    if (properties.onScrollDown != null) {
      config.onScrollDown = properties.onScrollDown;
    }
    if (properties.onIncrease != null) {
      config.onIncrease = properties.onIncrease;
    }
    if (properties.onDecrease != null) {
      config.onDecrease = properties.onDecrease;
    }
    if (properties.onCopy != null) {
      config.onCopy = properties.onCopy;
    }
    if (properties.onCut != null) {
      config.onCut = properties.onCut;
    }
    if (properties.onPaste != null) {
      config.onPaste = properties.onPaste;
    }
    if (properties.onMoveCursorForwardByCharacter != null) {
      config.onMoveCursorForwardByCharacter = properties.onMoveCursorForwardByCharacter;
    }
    if (properties.onMoveCursorBackwardByCharacter != null) {
      config.onMoveCursorBackwardByCharacter = properties.onMoveCursorBackwardByCharacter;
    }
    if (properties.onMoveCursorForwardByWord != null) {
      config.onMoveCursorForwardByWord = properties.onMoveCursorForwardByWord;
    }
    if (properties.onMoveCursorBackwardByWord != null) {
      config.onMoveCursorBackwardByWord = properties.onMoveCursorBackwardByWord;
    }
    if (properties.onSetSelection != null) {
      config.onSetSelection = properties.onSetSelection;
    }
    if (properties.onSetText != null) {
      config.onSetText = properties.onSetText;
    }
    if (properties.onDidGainAccessibilityFocus != null) {
      config.onDidGainAccessibilityFocus = properties.onDidGainAccessibilityFocus;
    }
    if (properties.onDidLoseAccessibilityFocus != null) {
      config.onDidLoseAccessibilityFocus = properties.onDidLoseAccessibilityFocus;
    }
    if (properties.onDismiss != null) {
      config.onDismiss = properties.onDismiss;
    }

    newChild.updateWith(
      config: config,
      // As of now CustomPainter does not support multiple tree levels.
      childrenInInversePaintOrder: const <SemanticsNode>[],
    );

    newChild
      ..rect = newSemantics.rect
      ..transform = newSemantics.transform
      ..tags = newSemantics.tags;

    return newChild;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(MessageProperty('painter', '$painter'));
    properties.add(MessageProperty('foregroundPainter', '$foregroundPainter', level: foregroundPainter != null ? DiagnosticLevel.info : DiagnosticLevel.fine));
    properties.add(DiagnosticsProperty<Size>('preferredSize', preferredSize, defaultValue: Size.zero));
    properties.add(DiagnosticsProperty<bool>('isComplex', isComplex, defaultValue: false));
    properties.add(DiagnosticsProperty<bool>('willChange', willChange, defaultValue: false));
  }
}