// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:characters/characters.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';

import 'basic.dart';
import 'binding.dart';
import 'constants.dart';
import 'container.dart';
import 'context_menu_controller.dart';
import 'debug.dart';
import 'editable_text.dart';
import 'framework.dart';
import 'gesture_detector.dart';
import 'magnifier.dart';
import 'overlay.dart';
import 'scrollable.dart';
import 'tap_region.dart';
import 'ticker_provider.dart';
import 'transitions.dart';

export 'package:flutter/rendering.dart' show TextSelectionPoint;
export 'package:flutter/services.dart' show TextSelectionDelegate;

typedef ToolbarBuilder = Widget Function(BuildContext context, Widget child);

class ToolbarItemsParentData extends ContainerBoxParentData<RenderBox> {
  bool shouldPaint = false;

  @override
  String toString() => '${super.toString()}; shouldPaint=$shouldPaint';
}

abstract class TextSelectionControls {
  Widget buildHandle(BuildContext context, TextSelectionHandleType type, double textLineHeight, [VoidCallback? onTap]);

  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight);

  @Deprecated(
    'Use `contextMenuBuilder` instead. '
    'This feature was deprecated after v3.3.0-0.5.pre.',
  )
  Widget buildToolbar(
    BuildContext context,
    Rect globalEditableRegion,
    double textLineHeight,
    Offset selectionMidpoint,
    List<TextSelectionPoint> endpoints,
    TextSelectionDelegate delegate,
    ValueListenable<ClipboardStatus>? clipboardStatus,
    Offset? lastSecondaryTapDownPosition,
  );

  Size getHandleSize(double textLineHeight);

  @Deprecated(
    'Use `contextMenuBuilder` instead. '
    'This feature was deprecated after v3.3.0-0.5.pre.',
  )
  bool canCut(TextSelectionDelegate delegate) {
    return delegate.cutEnabled && !delegate.textEditingValue.selection.isCollapsed;
  }

  @Deprecated(
    'Use `contextMenuBuilder` instead. '
    'This feature was deprecated after v3.3.0-0.5.pre.',
  )
  bool canCopy(TextSelectionDelegate delegate) {
    return delegate.copyEnabled && !delegate.textEditingValue.selection.isCollapsed;
  }

  @Deprecated(
    'Use `contextMenuBuilder` instead. '
    'This feature was deprecated after v3.3.0-0.5.pre.',
  )
  bool canPaste(TextSelectionDelegate delegate) {
    return delegate.pasteEnabled;
  }

  @Deprecated(
    'Use `contextMenuBuilder` instead. '
    'This feature was deprecated after v3.3.0-0.5.pre.',
  )
  bool canSelectAll(TextSelectionDelegate delegate) {
    return delegate.selectAllEnabled && delegate.textEditingValue.text.isNotEmpty && delegate.textEditingValue.selection.isCollapsed;
  }

  @Deprecated(
    'Use `contextMenuBuilder` instead. '
    'This feature was deprecated after v3.3.0-0.5.pre.',
  )
  void handleCut(TextSelectionDelegate delegate) {
    delegate.cutSelection(SelectionChangedCause.toolbar);
  }

  @Deprecated(
    'Use `contextMenuBuilder` instead. '
    'This feature was deprecated after v3.3.0-0.5.pre.',
  )
  void handleCopy(TextSelectionDelegate delegate) {
    delegate.copySelection(SelectionChangedCause.toolbar);
  }

  // TODO(ianh): https://github.com/flutter/flutter/issues/11427
  @Deprecated(
    'Use `contextMenuBuilder` instead. '
    'This feature was deprecated after v3.3.0-0.5.pre.',
  )
  Future<void> handlePaste(TextSelectionDelegate delegate) async {
    delegate.pasteText(SelectionChangedCause.toolbar);
  }

  @Deprecated(
    'Use `contextMenuBuilder` instead. '
    'This feature was deprecated after v3.3.0-0.5.pre.',
  )
  void handleSelectAll(TextSelectionDelegate delegate) {
    delegate.selectAll(SelectionChangedCause.toolbar);
  }
}

class EmptyTextSelectionControls extends TextSelectionControls {
  @override
  Size getHandleSize(double textLineHeight) => Size.zero;

  @override
  Widget buildToolbar(
    BuildContext context,
    Rect globalEditableRegion,
    double textLineHeight,
    Offset selectionMidpoint,
    List<TextSelectionPoint> endpoints,
    TextSelectionDelegate delegate,
    ValueListenable<ClipboardStatus>? clipboardStatus,
    Offset? lastSecondaryTapDownPosition,
  ) => const SizedBox.shrink();

  @override
  Widget buildHandle(BuildContext context, TextSelectionHandleType type, double textLineHeight, [VoidCallback? onTap]) {
    return const SizedBox.shrink();
  }

  @override
  Offset getHandleAnchor(TextSelectionHandleType type, double textLineHeight) {
    return Offset.zero;
  }
}

final TextSelectionControls emptyTextSelectionControls = EmptyTextSelectionControls();


class TextSelectionOverlay {
  TextSelectionOverlay({
    required TextEditingValue value,
    required this.context,
    Widget? debugRequiredFor,
    required LayerLink toolbarLayerLink,
    required LayerLink startHandleLayerLink,
    required LayerLink endHandleLayerLink,
    required this.renderObject,
    this.selectionControls,
    bool handlesVisible = false,
    required this.selectionDelegate,
    DragStartBehavior dragStartBehavior = DragStartBehavior.start,
    VoidCallback? onSelectionHandleTapped,
    ClipboardStatusNotifier? clipboardStatus,
    this.contextMenuBuilder,
    required TextMagnifierConfiguration magnifierConfiguration,
  }) : _handlesVisible = handlesVisible,
       _value = value {
    renderObject.selectionStartInViewport.addListener(_updateTextSelectionOverlayVisibilities);
    renderObject.selectionEndInViewport.addListener(_updateTextSelectionOverlayVisibilities);
    _updateTextSelectionOverlayVisibilities();
    _selectionOverlay = SelectionOverlay(
      magnifierConfiguration: magnifierConfiguration,
      context: context,
      debugRequiredFor: debugRequiredFor,
      // The metrics will be set when show handles.
      startHandleType: TextSelectionHandleType.collapsed,
      startHandlesVisible: _effectiveStartHandleVisibility,
      lineHeightAtStart: 0.0,
      onStartHandleDragStart: _handleSelectionStartHandleDragStart,
      onStartHandleDragUpdate: _handleSelectionStartHandleDragUpdate,
      onEndHandleDragEnd: _handleAnyDragEnd,
      endHandleType: TextSelectionHandleType.collapsed,
      endHandlesVisible: _effectiveEndHandleVisibility,
      lineHeightAtEnd: 0.0,
      onEndHandleDragStart: _handleSelectionEndHandleDragStart,
      onEndHandleDragUpdate: _handleSelectionEndHandleDragUpdate,
      onStartHandleDragEnd: _handleAnyDragEnd,
      toolbarVisible: _effectiveToolbarVisibility,
      selectionEndpoints: const <TextSelectionPoint>[],
      selectionControls: selectionControls,
      selectionDelegate: selectionDelegate,
      clipboardStatus: clipboardStatus,
      startHandleLayerLink: startHandleLayerLink,
      endHandleLayerLink: endHandleLayerLink,
      toolbarLayerLink: toolbarLayerLink,
      onSelectionHandleTapped: onSelectionHandleTapped,
      dragStartBehavior: dragStartBehavior,
      toolbarLocation: renderObject.lastSecondaryTapDownPosition,
    );
  }

  final BuildContext context;

  // TODO(mpcomplete): what if the renderObject is removed or replaced, or
  // moves? Not sure what cases I need to handle, or how to handle them.
  final RenderEditable renderObject;

  final TextSelectionControls? selectionControls;

  final TextSelectionDelegate selectionDelegate;

  late final SelectionOverlay _selectionOverlay;

  final WidgetBuilder? contextMenuBuilder;

  @visibleForTesting
  TextEditingValue get value => _value;

  TextEditingValue _value;

  TextSelection get _selection => _value.selection;

  final ValueNotifier<bool> _effectiveStartHandleVisibility = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _effectiveEndHandleVisibility = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _effectiveToolbarVisibility = ValueNotifier<bool>(false);

  void _updateTextSelectionOverlayVisibilities() {
    _effectiveStartHandleVisibility.value = _handlesVisible && renderObject.selectionStartInViewport.value;
    _effectiveEndHandleVisibility.value = _handlesVisible && renderObject.selectionEndInViewport.value;
    _effectiveToolbarVisibility.value = renderObject.selectionStartInViewport.value || renderObject.selectionEndInViewport.value;
  }

  bool get handlesVisible => _handlesVisible;
  bool _handlesVisible = false;
  set handlesVisible(bool visible) {
    if (_handlesVisible == visible) {
      return;
    }
    _handlesVisible = visible;
    _updateTextSelectionOverlayVisibilities();
  }

  void showHandles() {
    _updateSelectionOverlay();
    _selectionOverlay.showHandles();
  }

  void hideHandles() => _selectionOverlay.hideHandles();

  void showToolbar() {
    _updateSelectionOverlay();

    if (selectionControls is! TextSelectionHandleControls) {
      _selectionOverlay.showToolbar();
      return;
    }

    if (contextMenuBuilder == null) {
      return;
    }

    assert(context.mounted);
    _selectionOverlay.showToolbar(
      context: context,
      contextMenuBuilder: contextMenuBuilder,
    );
    return;
  }

  void showSpellCheckSuggestionsToolbar(
    WidgetBuilder spellCheckSuggestionsToolbarBuilder
  ) {
    _updateSelectionOverlay();
    assert(context.mounted);
    _selectionOverlay
      .showSpellCheckSuggestionsToolbar(
        context: context,
        builder: spellCheckSuggestionsToolbarBuilder,
    );
    hideHandles();
  }

  void showMagnifier(Offset positionToShow) {
    final TextPosition position = renderObject.getPositionForPoint(positionToShow);
    _updateSelectionOverlay();
    _selectionOverlay.showMagnifier(
      _buildMagnifier(
        currentTextPosition: position,
        globalGesturePosition: positionToShow,
        renderEditable: renderObject,
      ),
    );
  }

  void updateMagnifier(Offset positionToShow) {
    final TextPosition position = renderObject.getPositionForPoint(positionToShow);
    _updateSelectionOverlay();
    _selectionOverlay.updateMagnifier(
      _buildMagnifier(
        currentTextPosition: position,
        globalGesturePosition: positionToShow,
        renderEditable: renderObject,
      ),
    );
  }

  void hideMagnifier() {
    _selectionOverlay.hideMagnifier();
  }

  void update(TextEditingValue newValue) {
    if (_value == newValue) {
      return;
    }
    _value = newValue;
    _updateSelectionOverlay();
    // _updateSelectionOverlay may not rebuild the selection overlay if the
    // text metrics and selection doesn't change even if the text has changed.
    // This rebuild is needed for the toolbar to update based on the latest text
    // value.
    _selectionOverlay.markNeedsBuild();
  }

  void _updateSelectionOverlay() {
    _selectionOverlay
      // Update selection handle metrics.
      ..startHandleType = _chooseType(
        renderObject.textDirection,
        TextSelectionHandleType.left,
        TextSelectionHandleType.right,
      )
      ..lineHeightAtStart = _getStartGlyphHeight()
      ..endHandleType = _chooseType(
        renderObject.textDirection,
        TextSelectionHandleType.right,
        TextSelectionHandleType.left,
      )
      ..lineHeightAtEnd = _getEndGlyphHeight()
      // Update selection toolbar metrics.
      ..selectionEndpoints = renderObject.getEndpointsForSelection(_selection)
      ..toolbarLocation = renderObject.lastSecondaryTapDownPosition;
  }

  void updateForScroll() {
    _updateSelectionOverlay();
    // This method may be called due to windows metrics changes. In that case,
    // non of the properties in _selectionOverlay will change, but a rebuild is
    // still needed.
    _selectionOverlay.markNeedsBuild();
  }

  bool get handlesAreVisible => _selectionOverlay._handles != null && handlesVisible;

  bool get toolbarIsVisible => _selectionOverlay.toolbarIsVisible;

  bool get magnifierIsVisible => _selectionOverlay._magnifierController.shown;

  bool get spellCheckToolbarIsVisible => _selectionOverlay._spellCheckToolbarController.isShown;

  void hide() => _selectionOverlay.hide();

  void hideToolbar() => _selectionOverlay.hideToolbar();

  void dispose() {
    _selectionOverlay.dispose();
    renderObject.selectionStartInViewport.removeListener(_updateTextSelectionOverlayVisibilities);
    renderObject.selectionEndInViewport.removeListener(_updateTextSelectionOverlayVisibilities);
    _effectiveToolbarVisibility.dispose();
    _effectiveStartHandleVisibility.dispose();
    _effectiveEndHandleVisibility.dispose();
    hideToolbar();
  }

  double _getStartGlyphHeight() {
    final String currText = selectionDelegate.textEditingValue.text;
    final int firstSelectedGraphemeExtent;
    Rect? startHandleRect;
    // Only calculate handle rects if the text in the previous frame
    // is the same as the text in the current frame. This is done because
    // widget.renderObject contains the renderEditable from the previous frame.
    // If the text changed between the current and previous frames then
    // widget.renderObject.getRectForComposingRange might fail. In cases where
    // the current frame is different from the previous we fall back to
    // renderObject.preferredLineHeight.
    if (renderObject.plainText == currText && _selection.isValid && !_selection.isCollapsed) {
      final String selectedGraphemes = _selection.textInside(currText);
      firstSelectedGraphemeExtent = selectedGraphemes.characters.first.length;
      startHandleRect = renderObject.getRectForComposingRange(TextRange(start: _selection.start, end: _selection.start + firstSelectedGraphemeExtent));
    }
    return startHandleRect?.height ?? renderObject.preferredLineHeight;
  }

  double _getEndGlyphHeight() {
    final String currText = selectionDelegate.textEditingValue.text;
    final int lastSelectedGraphemeExtent;
    Rect? endHandleRect;
    // See the explanation in _getStartGlyphHeight.
    if (renderObject.plainText == currText && _selection.isValid && !_selection.isCollapsed) {
      final String selectedGraphemes = _selection.textInside(currText);
      lastSelectedGraphemeExtent = selectedGraphemes.characters.last.length;
      endHandleRect = renderObject.getRectForComposingRange(TextRange(start: _selection.end - lastSelectedGraphemeExtent, end: _selection.end));
    }
    return endHandleRect?.height ?? renderObject.preferredLineHeight;
  }

  MagnifierInfo _buildMagnifier({
    required RenderEditable renderEditable,
    required Offset globalGesturePosition,
    required TextPosition currentTextPosition,
  }) {
    final Offset globalRenderEditableTopLeft = renderEditable.localToGlobal(Offset.zero);
    final Rect localCaretRect = renderEditable.getLocalRectForCaret(currentTextPosition);

    final TextSelection lineAtOffset = renderEditable.getLineAtOffset(currentTextPosition);
    final TextPosition positionAtEndOfLine = TextPosition(
        offset: lineAtOffset.extentOffset,
        affinity: TextAffinity.upstream,
    );

    // Default affinity is downstream.
    final TextPosition positionAtBeginningOfLine = TextPosition(
      offset: lineAtOffset.baseOffset,
    );

    final Rect lineBoundaries = Rect.fromPoints(
      renderEditable.getLocalRectForCaret(positionAtBeginningOfLine).topCenter,
      renderEditable.getLocalRectForCaret(positionAtEndOfLine).bottomCenter,
    );

    return MagnifierInfo(
      fieldBounds: globalRenderEditableTopLeft & renderEditable.size,
      globalGesturePosition: globalGesturePosition,
      caretRect: localCaretRect.shift(globalRenderEditableTopLeft),
      currentLineBoundaries: lineBoundaries.shift(globalRenderEditableTopLeft),
    );
  }

  // The contact position of the gesture at the current end handle location.
  // Updated when the handle moves.
  late double _endHandleDragPosition;

  // The distance from _endHandleDragPosition to the center of the line that it
  // corresponds to.
  late double _endHandleDragPositionToCenterOfLine;

  void _handleSelectionEndHandleDragStart(DragStartDetails details) {
    if (!renderObject.attached) {
      return;
    }

    // This adjusts for the fact that the selection handles may not
    // perfectly cover the TextPosition that they correspond to.
    _endHandleDragPosition = details.globalPosition.dy;
    final Offset endPoint =
        renderObject.localToGlobal(_selectionOverlay.selectionEndpoints.last.point);
    final double centerOfLine = endPoint.dy - renderObject.preferredLineHeight / 2;
    _endHandleDragPositionToCenterOfLine = centerOfLine - _endHandleDragPosition;
    final TextPosition position = renderObject.getPositionForPoint(
      Offset(
        details.globalPosition.dx,
        centerOfLine,
      ),
    );

    _selectionOverlay.showMagnifier(
      _buildMagnifier(
        currentTextPosition: position,
        globalGesturePosition: details.globalPosition,
        renderEditable: renderObject,
      ),
    );
  }

  double _getHandleDy(double dragDy, double handleDy) {
    final double distanceDragged = dragDy - handleDy;
    final int dragDirection = distanceDragged < 0.0 ? -1 : 1;
    final int linesDragged =
        dragDirection * (distanceDragged.abs() / renderObject.preferredLineHeight).floor();
    return handleDy + linesDragged * renderObject.preferredLineHeight;
  }

  void _handleSelectionEndHandleDragUpdate(DragUpdateDetails details) {
    if (!renderObject.attached) {
      return;
    }

    _endHandleDragPosition = _getHandleDy(details.globalPosition.dy, _endHandleDragPosition);
    final Offset adjustedOffset = Offset(
      details.globalPosition.dx,
      _endHandleDragPosition + _endHandleDragPositionToCenterOfLine,
    );

    final TextPosition position = renderObject.getPositionForPoint(adjustedOffset);

    if (_selection.isCollapsed) {
      _selectionOverlay.updateMagnifier(_buildMagnifier(
        currentTextPosition: position,
        globalGesturePosition: details.globalPosition,
        renderEditable: renderObject,
      ));

      final TextSelection currentSelection = TextSelection.fromPosition(position);
      _handleSelectionHandleChanged(currentSelection);
      return;
    }

    final TextSelection newSelection;
    switch (defaultTargetPlatform) {
      // On Apple platforms, dragging the base handle makes it the extent.
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        newSelection = TextSelection(
          extentOffset: position.offset,
          baseOffset: _selection.start,
        );
        if (position.offset <= _selection.start) {
          return; // Don't allow order swapping.
        }
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        newSelection = TextSelection(
          baseOffset: _selection.baseOffset,
          extentOffset: position.offset,
        );
        if (newSelection.baseOffset >= newSelection.extentOffset) {
          return; // Don't allow order swapping.
        }
    }

    _handleSelectionHandleChanged(newSelection);

     _selectionOverlay.updateMagnifier(_buildMagnifier(
      currentTextPosition: newSelection.extent,
      globalGesturePosition: details.globalPosition,
      renderEditable: renderObject,
    ));
  }

  // The contact position of the gesture at the current start handle location.
  // Updated when the handle moves.
  late double _startHandleDragPosition;

  // The distance from _startHandleDragPosition to the center of the line that
  // it corresponds to.
  late double _startHandleDragPositionToCenterOfLine;

  void _handleSelectionStartHandleDragStart(DragStartDetails details) {
    if (!renderObject.attached) {
      return;
    }

    // This adjusts for the fact that the selection handles may not
    // perfectly cover the TextPosition that they correspond to.
    _startHandleDragPosition = details.globalPosition.dy;
    final Offset startPoint =
        renderObject.localToGlobal(_selectionOverlay.selectionEndpoints.first.point);
    final double centerOfLine = startPoint.dy - renderObject.preferredLineHeight / 2;
    _startHandleDragPositionToCenterOfLine = centerOfLine - _startHandleDragPosition;
    final TextPosition position = renderObject.getPositionForPoint(
      Offset(
        details.globalPosition.dx,
        centerOfLine,
      ),
    );

    _selectionOverlay.showMagnifier(
      _buildMagnifier(
        currentTextPosition: position,
        globalGesturePosition: details.globalPosition,
        renderEditable: renderObject,
      ),
    );
  }

  void _handleSelectionStartHandleDragUpdate(DragUpdateDetails details) {
    if (!renderObject.attached) {
      return;
    }

    _startHandleDragPosition = _getHandleDy(details.globalPosition.dy, _startHandleDragPosition);
    final Offset adjustedOffset = Offset(
      details.globalPosition.dx,
      _startHandleDragPosition + _startHandleDragPositionToCenterOfLine,
    );
    final TextPosition position = renderObject.getPositionForPoint(adjustedOffset);

    if (_selection.isCollapsed) {
      _selectionOverlay.updateMagnifier(_buildMagnifier(
        currentTextPosition: position,
        globalGesturePosition: details.globalPosition,
        renderEditable: renderObject,
      ));

      final TextSelection currentSelection = TextSelection.fromPosition(position);
      _handleSelectionHandleChanged(currentSelection);
      return;
    }

    final TextSelection newSelection;
    switch (defaultTargetPlatform) {
      // On Apple platforms, dragging the base handle makes it the extent.
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        newSelection = TextSelection(
          extentOffset: position.offset,
          baseOffset: _selection.end,
        );
        if (newSelection.extentOffset >= _selection.end) {
          return; // Don't allow order swapping.
        }
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        newSelection = TextSelection(
          baseOffset: position.offset,
          extentOffset: _selection.extentOffset,
        );
        if (newSelection.baseOffset >= newSelection.extentOffset) {
          return; // Don't allow order swapping.
        }
    }

    _selectionOverlay.updateMagnifier(_buildMagnifier(
      currentTextPosition: newSelection.extent.offset < newSelection.base.offset ? newSelection.extent : newSelection.base,
      globalGesturePosition: details.globalPosition,
      renderEditable: renderObject,
    ));

    _handleSelectionHandleChanged(newSelection);
  }

  void _handleAnyDragEnd(DragEndDetails details) {
    if (!context.mounted) {
      return;
    }
    if (selectionControls is! TextSelectionHandleControls) {
      _selectionOverlay.hideMagnifier();
      if (!_selection.isCollapsed) {
        _selectionOverlay.showToolbar();
      }
      return;
    }
    _selectionOverlay.hideMagnifier();
    if (!_selection.isCollapsed) {
      _selectionOverlay.showToolbar(
        context: context,
        contextMenuBuilder: contextMenuBuilder,
      );
    }
  }

  void _handleSelectionHandleChanged(TextSelection newSelection) {
    selectionDelegate.userUpdateTextEditingValue(
      _value.copyWith(selection: newSelection),
      SelectionChangedCause.drag,
    );
  }

  TextSelectionHandleType _chooseType(
      TextDirection textDirection,
      TextSelectionHandleType ltrType,
      TextSelectionHandleType rtlType,
      ) {
    if (_selection.isCollapsed) {
      return TextSelectionHandleType.collapsed;
    }

    switch (textDirection) {
      case TextDirection.ltr:
        return ltrType;
      case TextDirection.rtl:
        return rtlType;
    }
  }
}

class SelectionOverlay {
  SelectionOverlay({
    required this.context,
    this.debugRequiredFor,
    required TextSelectionHandleType startHandleType,
    required double lineHeightAtStart,
    this.startHandlesVisible,
    this.onStartHandleDragStart,
    this.onStartHandleDragUpdate,
    this.onStartHandleDragEnd,
    required TextSelectionHandleType endHandleType,
    required double lineHeightAtEnd,
    this.endHandlesVisible,
    this.onEndHandleDragStart,
    this.onEndHandleDragUpdate,
    this.onEndHandleDragEnd,
    this.toolbarVisible,
    required List<TextSelectionPoint> selectionEndpoints,
    required this.selectionControls,
    @Deprecated(
      'Use `contextMenuBuilder` in `showToolbar` instead. '
      'This feature was deprecated after v3.3.0-0.5.pre.',
    )
    required this.selectionDelegate,
    required this.clipboardStatus,
    required this.startHandleLayerLink,
    required this.endHandleLayerLink,
    required this.toolbarLayerLink,
    this.dragStartBehavior = DragStartBehavior.start,
    this.onSelectionHandleTapped,
    @Deprecated(
      'Use `contextMenuBuilder` in `showToolbar` instead. '
      'This feature was deprecated after v3.3.0-0.5.pre.',
    )
    Offset? toolbarLocation,
    this.magnifierConfiguration = TextMagnifierConfiguration.disabled,
  }) : _startHandleType = startHandleType,
       _lineHeightAtStart = lineHeightAtStart,
       _endHandleType = endHandleType,
       _lineHeightAtEnd = lineHeightAtEnd,
       _selectionEndpoints = selectionEndpoints,
       _toolbarLocation = toolbarLocation,
       assert(debugCheckHasOverlay(context));

  final BuildContext context;

  final ValueNotifier<MagnifierInfo> _magnifierInfo =
      ValueNotifier<MagnifierInfo>(MagnifierInfo.empty);

  final MagnifierController _magnifierController = MagnifierController();

  final TextMagnifierConfiguration magnifierConfiguration;

  bool get toolbarIsVisible {
    return selectionControls is TextSelectionHandleControls
        ? _contextMenuController.isShown || _spellCheckToolbarController.isShown
        : _toolbar != null || _spellCheckToolbarController.isShown;
  }

  void showMagnifier(MagnifierInfo initialMagnifierInfo) {
    if (toolbarIsVisible) {
      hideToolbar();
    }

    // Start from empty, so we don't utilize any remnant values.
    _magnifierInfo.value = initialMagnifierInfo;

    // Pre-build the magnifiers so we can tell if we've built something
    // or not. If we don't build a magnifiers, then we should not
    // insert anything in the overlay.
    final Widget? builtMagnifier = magnifierConfiguration.magnifierBuilder(
      context,
      _magnifierController,
      _magnifierInfo,
    );

    if (builtMagnifier == null) {
      return;
    }

    _magnifierController.show(
        context: context,
        below: magnifierConfiguration.shouldDisplayHandlesInMagnifier
            ? null
            : _handles?.first,
        builder: (_) => builtMagnifier);
  }

  void hideMagnifier() {
    // This cannot be a check on `MagnifierController.shown`, since
    // it's possible that the magnifier is still in the overlay, but
    // not shown in cases where the magnifier hides itself.
    if (_magnifierController.overlayEntry == null) {
      return;
    }

    _magnifierController.hide();
  }

  TextSelectionHandleType get startHandleType => _startHandleType;
  TextSelectionHandleType _startHandleType;
  set startHandleType(TextSelectionHandleType value) {
    if (_startHandleType == value) {
      return;
    }
    _startHandleType = value;
    markNeedsBuild();
  }

  double get lineHeightAtStart => _lineHeightAtStart;
  double _lineHeightAtStart;
  set lineHeightAtStart(double value) {
    if (_lineHeightAtStart == value) {
      return;
    }
    _lineHeightAtStart = value;
    markNeedsBuild();
  }

  bool _isDraggingStartHandle = false;

  final ValueListenable<bool>? startHandlesVisible;

  final ValueChanged<DragStartDetails>? onStartHandleDragStart;

  void _handleStartHandleDragStart(DragStartDetails details) {
    assert(!_isDraggingStartHandle);
    // Calling OverlayEntry.remove may not happen until the following frame, so
    // it's possible for the handles to receive a gesture after calling remove.
    if (_handles == null) {
      _isDraggingStartHandle = false;
      return;
    }
    _isDraggingStartHandle = details.kind == PointerDeviceKind.touch;
    onStartHandleDragStart?.call(details);
  }

  void _handleStartHandleDragUpdate(DragUpdateDetails details) {
    // Calling OverlayEntry.remove may not happen until the following frame, so
    // it's possible for the handles to receive a gesture after calling remove.
    if (_handles == null) {
      _isDraggingStartHandle = false;
      return;
    }
    onStartHandleDragUpdate?.call(details);
  }

  final ValueChanged<DragUpdateDetails>? onStartHandleDragUpdate;

  final ValueChanged<DragEndDetails>? onStartHandleDragEnd;

  void _handleStartHandleDragEnd(DragEndDetails details) {
    _isDraggingStartHandle = false;
    // Calling OverlayEntry.remove may not happen until the following frame, so
    // it's possible for the handles to receive a gesture after calling remove.
    if (_handles == null) {
      return;
    }
    onStartHandleDragEnd?.call(details);
  }

  TextSelectionHandleType get endHandleType => _endHandleType;
  TextSelectionHandleType _endHandleType;
  set endHandleType(TextSelectionHandleType value) {
    if (_endHandleType == value) {
      return;
    }
    _endHandleType = value;
    markNeedsBuild();
  }

  double get lineHeightAtEnd => _lineHeightAtEnd;
  double _lineHeightAtEnd;
  set lineHeightAtEnd(double value) {
    if (_lineHeightAtEnd == value) {
      return;
    }
    _lineHeightAtEnd = value;
    markNeedsBuild();
  }

  bool _isDraggingEndHandle = false;

  final ValueListenable<bool>? endHandlesVisible;

  final ValueChanged<DragStartDetails>? onEndHandleDragStart;

  void _handleEndHandleDragStart(DragStartDetails details) {
    assert(!_isDraggingEndHandle);
    // Calling OverlayEntry.remove may not happen until the following frame, so
    // it's possible for the handles to receive a gesture after calling remove.
    if (_handles == null) {
      _isDraggingEndHandle = false;
      return;
    }
    _isDraggingEndHandle = details.kind == PointerDeviceKind.touch;
    onEndHandleDragStart?.call(details);
  }

  void _handleEndHandleDragUpdate(DragUpdateDetails details) {
    // Calling OverlayEntry.remove may not happen until the following frame, so
    // it's possible for the handles to receive a gesture after calling remove.
    if (_handles == null) {
      _isDraggingEndHandle = false;
      return;
    }
    onEndHandleDragUpdate?.call(details);
  }

  final ValueChanged<DragUpdateDetails>? onEndHandleDragUpdate;

  final ValueChanged<DragEndDetails>? onEndHandleDragEnd;

  void _handleEndHandleDragEnd(DragEndDetails details) {
    _isDraggingEndHandle = false;
    // Calling OverlayEntry.remove may not happen until the following frame, so
    // it's possible for the handles to receive a gesture after calling remove.
    if (_handles == null) {
      return;
    }
    onEndHandleDragEnd?.call(details);
  }

  final ValueListenable<bool>? toolbarVisible;

  List<TextSelectionPoint> get selectionEndpoints => _selectionEndpoints;
  List<TextSelectionPoint> _selectionEndpoints;
  set selectionEndpoints(List<TextSelectionPoint> value) {
    if (!listEquals(_selectionEndpoints, value)) {
      markNeedsBuild();
      if (_isDraggingEndHandle || _isDraggingStartHandle) {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
            HapticFeedback.selectionClick();
          case TargetPlatform.fuchsia:
          case TargetPlatform.iOS:
          case TargetPlatform.linux:
          case TargetPlatform.macOS:
          case TargetPlatform.windows:
            break;
        }
      }
    }
    _selectionEndpoints = value;
  }

  final Widget? debugRequiredFor;

  final LayerLink toolbarLayerLink;

  final LayerLink startHandleLayerLink;

  final LayerLink endHandleLayerLink;

  final TextSelectionControls? selectionControls;

  @Deprecated(
    'Use `contextMenuBuilder` instead. '
    'This feature was deprecated after v3.3.0-0.5.pre.',
  )
  final TextSelectionDelegate? selectionDelegate;

  final DragStartBehavior dragStartBehavior;

  // See https://github.com/flutter/flutter/issues/39376#issuecomment-848406415
  // for provenance.
  final VoidCallback? onSelectionHandleTapped;

  final ClipboardStatusNotifier? clipboardStatus;

  @Deprecated(
    'Use the `contextMenuBuilder` parameter in `showToolbar` instead. '
    'This feature was deprecated after v3.3.0-0.5.pre.',
  )
  Offset? get toolbarLocation => _toolbarLocation;
  Offset? _toolbarLocation;
  set toolbarLocation(Offset? value) {
    if (_toolbarLocation == value) {
      return;
    }
    _toolbarLocation = value;
    markNeedsBuild();
  }

  static const Duration fadeDuration = Duration(milliseconds: 150);

  List<OverlayEntry>? _handles;

  OverlayEntry? _toolbar;

  // Manages the context menu. Not necessarily visible when non-null.
  final ContextMenuController _contextMenuController = ContextMenuController();

  final ContextMenuController _spellCheckToolbarController = ContextMenuController();

  void showHandles() {
    if (_handles != null) {
      return;
    }

    _handles = <OverlayEntry>[
      OverlayEntry(builder: _buildStartHandle),
      OverlayEntry(builder: _buildEndHandle),
    ];
    Overlay.of(context, rootOverlay: true, debugRequiredFor: debugRequiredFor).insertAll(_handles!);
  }

  void hideHandles() {
    if (_handles != null) {
      _handles![0].remove();
      _handles![0].dispose();
      _handles![1].remove();
      _handles![1].dispose();
      _handles = null;
    }
  }

  void showToolbar({
    BuildContext? context,
    WidgetBuilder? contextMenuBuilder,
  }) {
    if (contextMenuBuilder == null) {
      if (_toolbar != null) {
        return;
      }
      _toolbar = OverlayEntry(builder: _buildToolbar);
      Overlay.of(this.context, rootOverlay: true, debugRequiredFor: debugRequiredFor).insert(_toolbar!);
      return;
    }

    if (context == null) {
      return;
    }

    final RenderBox renderBox = context.findRenderObject()! as RenderBox;
    _contextMenuController.show(
      context: context,
      contextMenuBuilder: (BuildContext context) {
        return _SelectionToolbarWrapper(
          layerLink: toolbarLayerLink,
          offset: -renderBox.localToGlobal(Offset.zero),
          child: contextMenuBuilder(context),
        );
      },
    );
  }

  void showSpellCheckSuggestionsToolbar({
    BuildContext? context,
    required WidgetBuilder builder,
  }) {
    if (context == null) {
      return;
    }

    final RenderBox renderBox = context.findRenderObject()! as RenderBox;
    _spellCheckToolbarController.show(
      context: context,
      contextMenuBuilder: (BuildContext context) {
        return _SelectionToolbarWrapper(
          layerLink: toolbarLayerLink,
          offset: -renderBox.localToGlobal(Offset.zero),
          child: builder(context),
        );
      },
    );
  }

  bool _buildScheduled = false;

  void markNeedsBuild() {
    if (_handles == null && _toolbar == null) {
      return;
    }
    // If we are in build state, it will be too late to update visibility.
    // We will need to schedule the build in next frame.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      if (_buildScheduled) {
        return;
      }
      _buildScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((Duration duration) {
        _buildScheduled = false;
        if (_handles != null) {
          _handles![0].markNeedsBuild();
          _handles![1].markNeedsBuild();
        }
        _toolbar?.markNeedsBuild();
        if (_contextMenuController.isShown) {
          _contextMenuController.markNeedsBuild();
        } else if (_spellCheckToolbarController.isShown) {
          _spellCheckToolbarController.markNeedsBuild();
        }
      });
    } else {
      if (_handles != null) {
        _handles![0].markNeedsBuild();
        _handles![1].markNeedsBuild();
      }
      _toolbar?.markNeedsBuild();
      if (_contextMenuController.isShown) {
        _contextMenuController.markNeedsBuild();
      } else if (_spellCheckToolbarController.isShown) {
        _spellCheckToolbarController.markNeedsBuild();
      }
    }
  }

  void hide() {
    _magnifierController.hide();
    if (_handles != null) {
      _handles![0].remove();
      _handles![0].dispose();
      _handles![1].remove();
      _handles![1].dispose();
      _handles = null;
    }
    if (_toolbar != null || _contextMenuController.isShown || _spellCheckToolbarController.isShown) {
      hideToolbar();
    }
  }

  void hideToolbar() {
    _contextMenuController.remove();
    _spellCheckToolbarController.remove();
    if (_toolbar == null) {
      return;
    }
    _toolbar?.remove();
    _toolbar?.dispose();
    _toolbar = null;
  }

  void dispose() {
    hide();
    _magnifierInfo.dispose();
  }

  Widget _buildStartHandle(BuildContext context) {
    final Widget handle;
    final TextSelectionControls? selectionControls = this.selectionControls;
    if (selectionControls == null) {
      handle = const SizedBox.shrink();
    } else {
      handle = _SelectionHandleOverlay(
        type: _startHandleType,
        handleLayerLink: startHandleLayerLink,
        onSelectionHandleTapped: onSelectionHandleTapped,
        onSelectionHandleDragStart: _handleStartHandleDragStart,
        onSelectionHandleDragUpdate: _handleStartHandleDragUpdate,
        onSelectionHandleDragEnd: _handleStartHandleDragEnd,
        selectionControls: selectionControls,
        visibility: startHandlesVisible,
        preferredLineHeight: _lineHeightAtStart,
        dragStartBehavior: dragStartBehavior,
      );
    }
    return TextFieldTapRegion(
      child: ExcludeSemantics(
        child: handle,
      ),
    );
  }

  Widget _buildEndHandle(BuildContext context) {
    final Widget handle;
    final TextSelectionControls? selectionControls = this.selectionControls;
    if (selectionControls == null || _startHandleType == TextSelectionHandleType.collapsed) {
      // Hide the second handle when collapsed.
      handle = const SizedBox.shrink();
    } else {
      handle = _SelectionHandleOverlay(
        type: _endHandleType,
        handleLayerLink: endHandleLayerLink,
        onSelectionHandleTapped: onSelectionHandleTapped,
        onSelectionHandleDragStart: _handleEndHandleDragStart,
        onSelectionHandleDragUpdate: _handleEndHandleDragUpdate,
        onSelectionHandleDragEnd: _handleEndHandleDragEnd,
        selectionControls: selectionControls,
        visibility: endHandlesVisible,
        preferredLineHeight: _lineHeightAtEnd,
        dragStartBehavior: dragStartBehavior,
      );
    }
    return TextFieldTapRegion(
      child: ExcludeSemantics(
        child: handle,
      ),
    );
  }

  // Build the toolbar via TextSelectionControls.
  Widget _buildToolbar(BuildContext context) {
    if (selectionControls == null) {
      return const SizedBox.shrink();
    }
    assert(selectionDelegate != null, 'If not using contextMenuBuilder, must pass selectionDelegate.');

    final RenderBox renderBox = this.context.findRenderObject()! as RenderBox;

    final Rect editingRegion = Rect.fromPoints(
      renderBox.localToGlobal(Offset.zero),
      renderBox.localToGlobal(renderBox.size.bottomRight(Offset.zero)),
    );

    final bool isMultiline = selectionEndpoints.last.point.dy - selectionEndpoints.first.point.dy >
        lineHeightAtEnd / 2;

    // If the selected text spans more than 1 line, horizontally center the toolbar.
    // Derived from both iOS and Android.
    final double midX = isMultiline
      ? editingRegion.width / 2
      : (selectionEndpoints.first.point.dx + selectionEndpoints.last.point.dx) / 2;

    final Offset midpoint = Offset(
      midX,
      // The y-coordinate won't be made use of most likely.
      selectionEndpoints.first.point.dy - lineHeightAtStart,
    );

    return _SelectionToolbarWrapper(
      visibility: toolbarVisible,
      layerLink: toolbarLayerLink,
      offset: -editingRegion.topLeft,
      child: Builder(
        builder: (BuildContext context) {
          return selectionControls!.buildToolbar(
            context,
            editingRegion,
            lineHeightAtStart,
            midpoint,
            selectionEndpoints,
            selectionDelegate!,
            clipboardStatus,
            toolbarLocation,
          );
        },
      ),
    );
  }

  void updateMagnifier(MagnifierInfo magnifierInfo) {
    if (_magnifierController.overlayEntry == null) {
      return;
    }

    _magnifierInfo.value = magnifierInfo;
  }
}

// TODO(justinmc): Currently this fades in but not out on all platforms. It
// should follow the correct fading behavior for the current platform, then be
// made public and de-duplicated with widgets/selectable_region.dart.
// https://github.com/flutter/flutter/issues/107732
// Wrap the given child in the widgets common to both contextMenuBuilder and
// TextSelectionControls.buildToolbar.
class _SelectionToolbarWrapper extends StatefulWidget {
  const _SelectionToolbarWrapper({
    this.visibility,
    required this.layerLink,
    required this.offset,
    required this.child,
  });

  final Widget child;
  final Offset offset;
  final LayerLink layerLink;
  final ValueListenable<bool>? visibility;

  @override
  State<_SelectionToolbarWrapper> createState() => _SelectionToolbarWrapperState();
}

class _SelectionToolbarWrapperState extends State<_SelectionToolbarWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Animation<double> get _opacity => _controller.view;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(duration: SelectionOverlay.fadeDuration, vsync: this);

    _toolbarVisibilityChanged();
    widget.visibility?.addListener(_toolbarVisibilityChanged);
  }

  @override
  void didUpdateWidget(_SelectionToolbarWrapper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.visibility == widget.visibility) {
      return;
    }
    oldWidget.visibility?.removeListener(_toolbarVisibilityChanged);
    _toolbarVisibilityChanged();
    widget.visibility?.addListener(_toolbarVisibilityChanged);
  }

  @override
  void dispose() {
    widget.visibility?.removeListener(_toolbarVisibilityChanged);
    _controller.dispose();
    super.dispose();
  }

  void _toolbarVisibilityChanged() {
    if (widget.visibility?.value ?? true) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFieldTapRegion(
      child: Directionality(
        textDirection: Directionality.of(this.context),
        child: FadeTransition(
          opacity: _opacity,
          child: CompositedTransformFollower(
            link: widget.layerLink,
            showWhenUnlinked: false,
            offset: widget.offset,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _SelectionHandleOverlay extends StatefulWidget {
  const _SelectionHandleOverlay({
    required this.type,
    required this.handleLayerLink,
    this.onSelectionHandleTapped,
    this.onSelectionHandleDragStart,
    this.onSelectionHandleDragUpdate,
    this.onSelectionHandleDragEnd,
    required this.selectionControls,
    this.visibility,
    required this.preferredLineHeight,
    this.dragStartBehavior = DragStartBehavior.start,
  });

  final LayerLink handleLayerLink;
  final VoidCallback? onSelectionHandleTapped;
  final ValueChanged<DragStartDetails>? onSelectionHandleDragStart;
  final ValueChanged<DragUpdateDetails>? onSelectionHandleDragUpdate;
  final ValueChanged<DragEndDetails>? onSelectionHandleDragEnd;
  final TextSelectionControls selectionControls;
  final ValueListenable<bool>? visibility;
  final double preferredLineHeight;
  final TextSelectionHandleType type;
  final DragStartBehavior dragStartBehavior;

  @override
  State<_SelectionHandleOverlay> createState() => _SelectionHandleOverlayState();
}

class _SelectionHandleOverlayState extends State<_SelectionHandleOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Animation<double> get _opacity => _controller.view;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(duration: SelectionOverlay.fadeDuration, vsync: this);

    _handleVisibilityChanged();
    widget.visibility?.addListener(_handleVisibilityChanged);
  }

  void _handleVisibilityChanged() {
    if (widget.visibility?.value ?? true) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  void didUpdateWidget(_SelectionHandleOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.visibility?.removeListener(_handleVisibilityChanged);
    _handleVisibilityChanged();
    widget.visibility?.addListener(_handleVisibilityChanged);
  }

  @override
  void dispose() {
    widget.visibility?.removeListener(_handleVisibilityChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Offset handleAnchor = widget.selectionControls.getHandleAnchor(
      widget.type,
      widget.preferredLineHeight,
    );
    final Size handleSize = widget.selectionControls.getHandleSize(
      widget.preferredLineHeight,
    );

    final Rect handleRect = Rect.fromLTWH(
      -handleAnchor.dx,
      -handleAnchor.dy,
      handleSize.width,
      handleSize.height,
    );

    // Make sure the GestureDetector is big enough to be easily interactive.
    final Rect interactiveRect = handleRect.expandToInclude(
      Rect.fromCircle(center: handleRect.center, radius: kMinInteractiveDimension / 2),
    );
    final RelativeRect padding = RelativeRect.fromLTRB(
      math.max((interactiveRect.width - handleRect.width) / 2, 0),
      math.max((interactiveRect.height - handleRect.height) / 2, 0),
      math.max((interactiveRect.width - handleRect.width) / 2, 0),
      math.max((interactiveRect.height - handleRect.height) / 2, 0),
    );

    return CompositedTransformFollower(
      link: widget.handleLayerLink,
      offset: interactiveRect.topLeft,
      showWhenUnlinked: false,
      child: FadeTransition(
        opacity: _opacity,
        child: Container(
          alignment: Alignment.topLeft,
          width: interactiveRect.width,
          height: interactiveRect.height,
          child: RawGestureDetector(
            behavior: HitTestBehavior.translucent,
            gestures: <Type, GestureRecognizerFactory>{
              PanGestureRecognizer: GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
                () => PanGestureRecognizer(
                  debugOwner: this,
                  // Mouse events select the text and do not drag the cursor.
                  supportedDevices: <PointerDeviceKind>{
                    PointerDeviceKind.touch,
                    PointerDeviceKind.stylus,
                    PointerDeviceKind.unknown,
                  },
                ),
                (PanGestureRecognizer instance) {
                  instance
                    ..dragStartBehavior = widget.dragStartBehavior
                    ..onStart = widget.onSelectionHandleDragStart
                    ..onUpdate = widget.onSelectionHandleDragUpdate
                    ..onEnd = widget.onSelectionHandleDragEnd;
                },
              ),
            },
            child: Padding(
              padding: EdgeInsets.only(
                left: padding.left,
                top: padding.top,
                right: padding.right,
                bottom: padding.bottom,
              ),
              child: widget.selectionControls.buildHandle(
                context,
                widget.type,
                widget.preferredLineHeight,
                widget.onSelectionHandleTapped,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

abstract class TextSelectionGestureDetectorBuilderDelegate {
  GlobalKey<EditableTextState> get editableTextKey;

  bool get forcePressEnabled;

  bool get selectionEnabled;
}

class TextSelectionGestureDetectorBuilder {
  TextSelectionGestureDetectorBuilder({
    required this.delegate,
  });

  @protected
  final TextSelectionGestureDetectorBuilderDelegate delegate;

  // Shows the magnifier on supported platforms at the given offset, currently
  // only Android and iOS.
  void _showMagnifierIfSupportedByPlatform(Offset positionToShow) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        editableText.showMagnifier(positionToShow);
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
    }
  }

  // Hides the magnifier on supported platforms, currently only Android and iOS.
  void _hideMagnifierIfSupportedByPlatform() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        editableText.hideMagnifier();
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
    }
  }

  bool get _lastSecondaryTapWasOnSelection {
    assert(renderEditable.lastSecondaryTapDownPosition != null);
    if (renderEditable.selection == null) {
      return false;
    }

    final TextPosition textPosition = renderEditable.getPositionForPoint(
      renderEditable.lastSecondaryTapDownPosition!,
    );

    return renderEditable.selection!.start <= textPosition.offset
        && renderEditable.selection!.end >= textPosition.offset;
  }

  bool _positionWasOnSelectionExclusive(TextPosition textPosition) {
    final TextSelection? selection = renderEditable.selection;
    if (selection == null) {
      return false;
    }

    return selection.start < textPosition.offset
        && selection.end > textPosition.offset;
  }

  bool _positionWasOnSelectionInclusive(TextPosition textPosition) {
    final TextSelection? selection = renderEditable.selection;
    if (selection == null) {
      return false;
    }

    return selection.start <= textPosition.offset
        && selection.end >= textPosition.offset;
  }

  bool _positionOnSelection(Offset position, TextSelection? targetSelection) {
    if (targetSelection == null) {
      return false;
    }

    final TextPosition textPosition = renderEditable.getPositionForPoint(position);

    return targetSelection.start <= textPosition.offset
        && targetSelection.end >= textPosition.offset;
  }

  // Expand the selection to the given global position.
  //
  // Either base or extent will be moved to the last tapped position, whichever
  // is closest. The selection will never shrink or pivot, only grow.
  //
  // If fromSelection is given, will expand from that selection instead of the
  // current selection in renderEditable.
  //
  // See also:
  //
  //   * [_extendSelection], which is similar but pivots the selection around
  //     the base.
  void _expandSelection(Offset offset, SelectionChangedCause cause, [TextSelection? fromSelection]) {
    assert(renderEditable.selection?.baseOffset != null);

    final TextPosition tappedPosition = renderEditable.getPositionForPoint(offset);
    final TextSelection selection = fromSelection ?? renderEditable.selection!;
    final bool baseIsCloser =
        (tappedPosition.offset - selection.baseOffset).abs()
        < (tappedPosition.offset - selection.extentOffset).abs();
    final TextSelection nextSelection = selection.copyWith(
      baseOffset: baseIsCloser ? selection.extentOffset : selection.baseOffset,
      extentOffset: tappedPosition.offset,
    );

    editableText.userUpdateTextEditingValue(
      editableText.textEditingValue.copyWith(
        selection: nextSelection,
      ),
      cause,
    );
  }

  // Extend the selection to the given global position.
  //
  // Holds the base in place and moves the extent.
  //
  // See also:
  //
  //   * [_expandSelection], which is similar but always increases the size of
  //     the selection.
  void _extendSelection(Offset offset, SelectionChangedCause cause) {
    assert(renderEditable.selection?.baseOffset != null);

    final TextPosition tappedPosition = renderEditable.getPositionForPoint(offset);
    final TextSelection selection = renderEditable.selection!;
    final TextSelection nextSelection = selection.copyWith(
      extentOffset: tappedPosition.offset,
    );

    editableText.userUpdateTextEditingValue(
      editableText.textEditingValue.copyWith(
        selection: nextSelection,
      ),
      cause,
    );
  }

  bool get shouldShowSelectionToolbar => _shouldShowSelectionToolbar;
  bool _shouldShowSelectionToolbar = true;

  @protected
  EditableTextState get editableText => delegate.editableTextKey.currentState!;

  @protected
  RenderEditable get renderEditable => editableText.renderEditable;

  bool _isShiftPressed = false;

  double _dragStartScrollOffset = 0.0;

  double _dragStartViewportOffset = 0.0;

  double get _scrollPosition {
    final ScrollableState? scrollableState =
        delegate.editableTextKey.currentContext == null
            ? null
            : Scrollable.maybeOf(delegate.editableTextKey.currentContext!);
    return scrollableState == null
        ? 0.0
        : scrollableState.position.pixels;
  }

  // For a shift + tap + drag gesture, the TextSelection at the point of the
  // tap. Mac uses this value to reset to the original selection when an
  // inversion of the base and offset happens.
  TextSelection? _dragStartSelection;

  // For tap + drag gesture on iOS, whether the position where the drag started
  // was on the previous TextSelection. iOS uses this value to determine if
  // the cursor should move on drag update.
  //
  // If the drag started on the previous selection then the cursor will move on
  // drag update. If the drag did not start on the previous selection then the
  // cursor will not move on drag update.
  bool? _dragBeganOnPreviousSelection;

  // For iOS long press behavior when the field is not focused. iOS uses this value
  // to determine if a long press began on a field that was not focused.
  //
  // If the field was not focused when the long press began, a long press will select
  // the word and a long press move will select word-by-word. If the field was
  // focused, the cursor moves to the long press position.
  bool _longPressStartedWithoutFocus = false;

  @protected
  void onTapTrackStart() {
    _isShiftPressed = HardwareKeyboard.instance.logicalKeysPressed
        .intersection(<LogicalKeyboardKey>{LogicalKeyboardKey.shiftLeft, LogicalKeyboardKey.shiftRight})
        .isNotEmpty;
  }

  @protected
  void onTapTrackReset() {
    _isShiftPressed = false;
  }

  @protected
  void onTapDown(TapDragDownDetails details) {
    if (!delegate.selectionEnabled) {
      return;
    }
    // TODO(Renzo-Olivares): Migrate text selection gestures away from saving state
    // in renderEditable. The gesture callbacks can use the details objects directly
    // in callbacks variants that provide them [TapGestureRecognizer.onSecondaryTap]
    // vs [TapGestureRecognizer.onSecondaryTapUp] instead of having to track state in
    // renderEditable. When this migration is complete we should remove this hack.
    // See https://github.com/flutter/flutter/issues/115130.
    renderEditable.handleTapDown(TapDownDetails(globalPosition: details.globalPosition));
    // The selection overlay should only be shown when the user is interacting
    // through a touch screen (via either a finger or a stylus). A mouse shouldn't
    // trigger the selection overlay.
    // For backwards-compatibility, we treat a null kind the same as touch.
    final PointerDeviceKind? kind = details.kind;
    // TODO(justinmc): Should a desktop platform show its selection toolbar when
    // receiving a tap event?  Say a Windows device with a touchscreen.
    // https://github.com/flutter/flutter/issues/106586
    _shouldShowSelectionToolbar = kind == null
      || kind == PointerDeviceKind.touch
      || kind == PointerDeviceKind.stylus;

    // It is impossible to extend the selection when the shift key is pressed, if the
    // renderEditable.selection is invalid.
    final bool isShiftPressedValid = _isShiftPressed && renderEditable.selection?.baseOffset != null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        // On mobile platforms the selection is set on tap up.
        editableText.hideToolbar(false);
      case TargetPlatform.iOS:
        // On mobile platforms the selection is set on tap up.
        break;
      case TargetPlatform.macOS:
        editableText.hideToolbar();
        // On macOS, a shift-tapped unfocused field expands from 0, not from the
        // previous selection.
        if (isShiftPressedValid) {
          final TextSelection? fromSelection = renderEditable.hasFocus
              ? null
              : const TextSelection.collapsed(offset: 0);
          _expandSelection(
            details.globalPosition,
            SelectionChangedCause.tap,
            fromSelection,
          );
          return;
        }
        // On macOS, a tap/click places the selection in a precise position.
        // This differs from iOS/iPadOS, where if the gesture is done by a touch
        // then the selection moves to the closest word edge, instead of a
        // precise position.
        renderEditable.selectPosition(cause: SelectionChangedCause.tap);
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        editableText.hideToolbar();
        if (isShiftPressedValid) {
          _extendSelection(details.globalPosition, SelectionChangedCause.tap);
          return;
        }
        renderEditable.selectPosition(cause: SelectionChangedCause.tap);
    }
  }

  @protected
  void onForcePressStart(ForcePressDetails details) {
    assert(delegate.forcePressEnabled);
    _shouldShowSelectionToolbar = true;
    if (delegate.selectionEnabled) {
      renderEditable.selectWordsInRange(
        from: details.globalPosition,
        cause: SelectionChangedCause.forcePress,
      );
    }
  }

  @protected
  void onForcePressEnd(ForcePressDetails details) {
    assert(delegate.forcePressEnabled);
    renderEditable.selectWordsInRange(
      from: details.globalPosition,
      cause: SelectionChangedCause.forcePress,
    );
    if (shouldShowSelectionToolbar) {
      editableText.showToolbar();
    }
  }

  @protected
  void onSingleTapUp(TapDragUpDetails details) {
    if (delegate.selectionEnabled) {
      // It is impossible to extend the selection when the shift key is pressed, if the
      // renderEditable.selection is invalid.
      final bool isShiftPressedValid = _isShiftPressed && renderEditable.selection?.baseOffset != null;
      switch (defaultTargetPlatform) {
        case TargetPlatform.linux:
        case TargetPlatform.macOS:
        case TargetPlatform.windows:
          break;
          // On desktop platforms the selection is set on tap down.
        case TargetPlatform.android:
          if (isShiftPressedValid) {
            _extendSelection(details.globalPosition, SelectionChangedCause.tap);
            return;
          }
          renderEditable.selectPosition(cause: SelectionChangedCause.tap);
          editableText.showSpellCheckSuggestionsToolbar();
        case TargetPlatform.fuchsia:
          if (isShiftPressedValid) {
            _extendSelection(details.globalPosition, SelectionChangedCause.tap);
            return;
          }
          renderEditable.selectPosition(cause: SelectionChangedCause.tap);
        case TargetPlatform.iOS:
          if (isShiftPressedValid) {
            // On iOS, a shift-tapped unfocused field expands from 0, not from
            // the previous selection.
            final TextSelection? fromSelection = renderEditable.hasFocus
                ? null
                : const TextSelection.collapsed(offset: 0);
            _expandSelection(
              details.globalPosition,
              SelectionChangedCause.tap,
              fromSelection,
            );
            return;
          }
          switch (details.kind) {
            case PointerDeviceKind.mouse:
            case PointerDeviceKind.trackpad:
            case PointerDeviceKind.stylus:
            case PointerDeviceKind.invertedStylus:
              // TODO(camsim99): Determine spell check toolbar behavior in these cases:
              // https://github.com/flutter/flutter/issues/119573.
              // Precise devices should place the cursor at a precise position if the
              // word at the text position is not misspelled.
              renderEditable.selectPosition(cause: SelectionChangedCause.tap);
            case PointerDeviceKind.touch:
            case PointerDeviceKind.unknown:
              // If the word that was tapped is misspelled, select the word and show the spell check suggestions
              // toolbar once. If additional taps are made on a misspelled word, toggle the toolbar. If the word
              // is not misspelled, default to the following behavior:
              //
              // Toggle the toolbar if the `previousSelection` is collapsed, the tap is on the selection, the
              // TextAffinity remains the same, and the editable is focused. The TextAffinity is important when the
              // cursor is on the boundary of a line wrap, if the affinity is different (i.e. it is downstream), the
              // selection should move to the following line and not toggle the toolbar.
              //
              // Toggle the toolbar when the tap is exclusively within the bounds of a non-collapsed `previousSelection`,
              // and the editable is focused.
              //
              // Selects the word edge closest to the tap when the editable is not focused, or if the tap was neither exclusively
              // or inclusively on `previousSelection`. If the selection remains the same after selecting the word edge, then we
              // toggle the toolbar. If the selection changes then we hide the toolbar.
              final TextSelection previousSelection = renderEditable.selection ?? editableText.textEditingValue.selection;
              final TextPosition textPosition = renderEditable.getPositionForPoint(details.globalPosition);
              final bool isAffinityTheSame = textPosition.affinity == previousSelection.affinity;
              final bool wordAtCursorIndexIsMisspelled = editableText.findSuggestionSpanAtCursorIndex(textPosition.offset) != null;

              if (wordAtCursorIndexIsMisspelled) {
                renderEditable.selectWord(cause: SelectionChangedCause.tap);
                if (previousSelection != editableText.textEditingValue.selection) {
                  editableText.showSpellCheckSuggestionsToolbar();
                } else {
                  editableText.toggleToolbar(false);
                }
              } else if (((_positionWasOnSelectionExclusive(textPosition) && !previousSelection.isCollapsed) || (_positionWasOnSelectionInclusive(textPosition) && previousSelection.isCollapsed && isAffinityTheSame)) && renderEditable.hasFocus) {
                editableText.toggleToolbar(false);
              } else {
                renderEditable.selectWordEdge(cause: SelectionChangedCause.tap);
                if (previousSelection == editableText.textEditingValue.selection && renderEditable.hasFocus) {
                  editableText.toggleToolbar(false);
                } else {
                  editableText.hideToolbar(false);
                }
              }
          }
      }
    }
  }

  @protected
  void onSingleTapCancel() { /* Subclass should override this method if needed. */ }

  @protected
  void onSingleLongTapStart(LongPressStartDetails details) {
    if (delegate.selectionEnabled) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          if (!renderEditable.hasFocus) {
            _longPressStartedWithoutFocus = true;
            renderEditable.selectWord(cause: SelectionChangedCause.longPress);
          } else {
            renderEditable.selectPositionAt(
              from: details.globalPosition,
              cause: SelectionChangedCause.longPress,
            );
          }
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          renderEditable.selectWord(cause: SelectionChangedCause.longPress);
      }

      _showMagnifierIfSupportedByPlatform(details.globalPosition);

      _dragStartViewportOffset = renderEditable.offset.pixels;
      _dragStartScrollOffset = _scrollPosition;
    }
  }

  @protected
  void onSingleLongTapMoveUpdate(LongPressMoveUpdateDetails details) {
    if (delegate.selectionEnabled) {
      // Adjust the drag start offset for possible viewport offset changes.
      final Offset editableOffset = renderEditable.maxLines == 1
          ? Offset(renderEditable.offset.pixels - _dragStartViewportOffset, 0.0)
          : Offset(0.0, renderEditable.offset.pixels - _dragStartViewportOffset);
      final Offset scrollableOffset = Offset(
        0.0,
        _scrollPosition - _dragStartScrollOffset,
      );

      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          if (_longPressStartedWithoutFocus) {
            renderEditable.selectWordsInRange(
              from: details.globalPosition - details.offsetFromOrigin - editableOffset - scrollableOffset,
              to: details.globalPosition,
              cause: SelectionChangedCause.longPress,
            );
          } else {
            renderEditable.selectPositionAt(
              from: details.globalPosition,
              cause: SelectionChangedCause.longPress,
            );
          }
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          renderEditable.selectWordsInRange(
            from: details.globalPosition - details.offsetFromOrigin - editableOffset - scrollableOffset,
            to: details.globalPosition,
            cause: SelectionChangedCause.longPress,
          );
      }

      _showMagnifierIfSupportedByPlatform(details.globalPosition);
    }
  }

  @protected
  void onSingleLongTapEnd(LongPressEndDetails details) {
    _hideMagnifierIfSupportedByPlatform();
    if (shouldShowSelectionToolbar) {
      editableText.showToolbar();
    }
    _longPressStartedWithoutFocus = false;
    _dragStartViewportOffset = 0.0;
    _dragStartScrollOffset = 0.0;
  }

  @protected
  void onSecondaryTap() {
    if (!delegate.selectionEnabled) {
      return;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        if (!_lastSecondaryTapWasOnSelection || !renderEditable.hasFocus) {
          renderEditable.selectWord(cause: SelectionChangedCause.tap);
        }
        if (shouldShowSelectionToolbar) {
          editableText.hideToolbar();
          editableText.showToolbar();
        }
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        if (!renderEditable.hasFocus) {
          renderEditable.selectPosition(cause: SelectionChangedCause.tap);
        }
        editableText.toggleToolbar();
    }
  }

  @protected
  void onSecondaryTapDown(TapDownDetails details) {
    // TODO(Renzo-Olivares): Migrate text selection gestures away from saving state
    // in renderEditable. The gesture callbacks can use the details objects directly
    // in callbacks variants that provide them [TapGestureRecognizer.onSecondaryTap]
    // vs [TapGestureRecognizer.onSecondaryTapUp] instead of having to track state in
    // renderEditable. When this migration is complete we should remove this hack.
    // See https://github.com/flutter/flutter/issues/115130.
    renderEditable.handleSecondaryTapDown(TapDownDetails(globalPosition: details.globalPosition));
    _shouldShowSelectionToolbar = true;
  }

  @protected
  void onDoubleTapDown(TapDragDownDetails details) {
    if (delegate.selectionEnabled) {
      renderEditable.selectWord(cause: SelectionChangedCause.doubleTap);
      if (shouldShowSelectionToolbar) {
        editableText.showToolbar();
      }
    }
  }

  // Selects the set of paragraphs in a document that intersect a given range of
  // global positions.
  void _selectParagraphsInRange({required Offset from, Offset? to, SelectionChangedCause? cause}) {
    final TextBoundary paragraphBoundary = ParagraphBoundary(editableText.textEditingValue.text);
    _selectTextBoundariesInRange(boundary: paragraphBoundary, from: from, to: to, cause: cause);
  }

  // Selects the set of lines in a document that intersect a given range of
  // global positions.
  void _selectLinesInRange({required Offset from, Offset? to, SelectionChangedCause? cause}) {
    final TextBoundary lineBoundary = LineBoundary(renderEditable);
    _selectTextBoundariesInRange(boundary: lineBoundary, from: from, to: to, cause: cause);
  }

  // Returns the location of a text boundary at `extent`. When `extent` is at
  // the end of the text, returns the previous text boundary's location.
  TextRange _moveToTextBoundary(TextPosition extent, TextBoundary textBoundary) {
    assert(extent.offset >= 0);
    // Use extent.offset - 1 when `extent` is at the end of the text to retrieve
    // the previous text boundary's location.
    final int start = textBoundary.getLeadingTextBoundaryAt(extent.offset == editableText.textEditingValue.text.length ? extent.offset - 1 : extent.offset) ?? 0;
    final int end = textBoundary.getTrailingTextBoundaryAt(extent.offset) ?? editableText.textEditingValue.text.length;
    return TextRange(start: start, end: end);
  }

  // Selects the set of text boundaries in a document that intersect a given
  // range of global positions.
  //
  // The set of text boundaries selected are not strictly bounded by the range
  // of global positions.
  //
  // The first and last endpoints of the selection will always be at the
  // beginning and end of a text boundary respectively.
  void _selectTextBoundariesInRange({required TextBoundary boundary, required Offset from, Offset? to, SelectionChangedCause? cause}) {
    final TextPosition fromPosition = renderEditable.getPositionForPoint(from);
    final TextRange fromRange = _moveToTextBoundary(fromPosition, boundary);
    final TextPosition toPosition = to == null
        ? fromPosition
        : renderEditable.getPositionForPoint(to);
    final TextRange toRange = toPosition == fromPosition
        ? fromRange
        : _moveToTextBoundary(toPosition, boundary);
    final bool isFromBoundaryBeforeToBoundary = fromRange.start < toRange.end;

    final TextSelection newSelection = isFromBoundaryBeforeToBoundary
        ? TextSelection(baseOffset: fromRange.start, extentOffset: toRange.end)
        : TextSelection(baseOffset: fromRange.end, extentOffset: toRange.start);

    editableText.userUpdateTextEditingValue(
      editableText.textEditingValue.copyWith(selection: newSelection),
      cause,
    );
  }

  @protected
  void onTripleTapDown(TapDragDownDetails details) {
    if (!delegate.selectionEnabled) {
      return;
    }
    if (renderEditable.maxLines == 1) {
      editableText.selectAll(SelectionChangedCause.tap);
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
        case TargetPlatform.windows:
          _selectParagraphsInRange(from: details.globalPosition, cause: SelectionChangedCause.tap);
        case TargetPlatform.linux:
          _selectLinesInRange(from: details.globalPosition, cause: SelectionChangedCause.tap);
      }
    }
    if (shouldShowSelectionToolbar) {
      editableText.showToolbar();
    }
  }

  @protected
  void onDragSelectionStart(TapDragStartDetails details) {
    if (!delegate.selectionEnabled) {
      return;
    }
    final PointerDeviceKind? kind = details.kind;
    _shouldShowSelectionToolbar = kind == null
      || kind == PointerDeviceKind.touch
      || kind == PointerDeviceKind.stylus;

    _dragStartSelection = renderEditable.selection;
    _dragStartScrollOffset = _scrollPosition;
    _dragStartViewportOffset = renderEditable.offset.pixels;
    _dragBeganOnPreviousSelection = _positionOnSelection(details.globalPosition, _dragStartSelection);

    if (_TextSelectionGestureDetectorState._getEffectiveConsecutiveTapCount(details.consecutiveTapCount) > 1) {
      // Do not set the selection on a consecutive tap and drag.
      return;
    }

    if (_isShiftPressed && renderEditable.selection != null && renderEditable.selection!.isValid) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
        case TargetPlatform.macOS:
          _expandSelection(details.globalPosition, SelectionChangedCause.drag);
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          _extendSelection(details.globalPosition, SelectionChangedCause.drag);
      }
    } else {
      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
          switch (details.kind) {
            case PointerDeviceKind.mouse:
            case PointerDeviceKind.trackpad:
              renderEditable.selectPositionAt(
                from: details.globalPosition,
                cause: SelectionChangedCause.drag,
              );
            case PointerDeviceKind.stylus:
            case PointerDeviceKind.invertedStylus:
            case PointerDeviceKind.touch:
            case PointerDeviceKind.unknown:
              // For iOS platforms, a touch drag does not initiate unless the
              // editable has focus and the drag began on the previous selection.
              assert(_dragBeganOnPreviousSelection != null);
              if (renderEditable.hasFocus && _dragBeganOnPreviousSelection!) {
                renderEditable.selectPositionAt(
                  from: details.globalPosition,
                  cause: SelectionChangedCause.drag,
                );
                _showMagnifierIfSupportedByPlatform(details.globalPosition);
              }
            case null:
          }
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
          switch (details.kind) {
            case PointerDeviceKind.mouse:
            case PointerDeviceKind.trackpad:
              renderEditable.selectPositionAt(
                from: details.globalPosition,
                cause: SelectionChangedCause.drag,
              );
            case PointerDeviceKind.stylus:
            case PointerDeviceKind.invertedStylus:
            case PointerDeviceKind.touch:
            case PointerDeviceKind.unknown:
              // For Android, Fucshia, and iOS platforms, a touch drag
              // does not initiate unless the editable has focus.
              if (renderEditable.hasFocus) {
                renderEditable.selectPositionAt(
                  from: details.globalPosition,
                  cause: SelectionChangedCause.drag,
                );
                _showMagnifierIfSupportedByPlatform(details.globalPosition);
              }
            case null:
          }
        case TargetPlatform.linux:
        case TargetPlatform.macOS:
        case TargetPlatform.windows:
          renderEditable.selectPositionAt(
            from: details.globalPosition,
            cause: SelectionChangedCause.drag,
          );
      }
    }
  }

  @protected
  void onDragSelectionUpdate(TapDragUpdateDetails details) {
    if (!delegate.selectionEnabled) {
      return;
    }

    if (!_isShiftPressed) {
      // Adjust the drag start offset for possible viewport offset changes.
      final Offset editableOffset = renderEditable.maxLines == 1
          ? Offset(renderEditable.offset.pixels - _dragStartViewportOffset, 0.0)
          : Offset(0.0, renderEditable.offset.pixels - _dragStartViewportOffset);
      final Offset scrollableOffset = Offset(
        0.0,
        _scrollPosition - _dragStartScrollOffset,
      );
      final Offset dragStartGlobalPosition = details.globalPosition - details.offsetFromOrigin;

      // Select word by word.
      if (_TextSelectionGestureDetectorState._getEffectiveConsecutiveTapCount(details.consecutiveTapCount) == 2) {
        renderEditable.selectWordsInRange(
          from: dragStartGlobalPosition - editableOffset - scrollableOffset,
          to: details.globalPosition,
          cause: SelectionChangedCause.drag,
        );

        switch (details.kind) {
          case PointerDeviceKind.stylus:
          case PointerDeviceKind.invertedStylus:
          case PointerDeviceKind.touch:
          case PointerDeviceKind.unknown:
            return _showMagnifierIfSupportedByPlatform(details.globalPosition);
          case PointerDeviceKind.mouse:
          case PointerDeviceKind.trackpad:
          case null:
            return;
        }
      }

      // Select paragraph-by-paragraph.
      if (_TextSelectionGestureDetectorState._getEffectiveConsecutiveTapCount(details.consecutiveTapCount) == 3) {
        switch (defaultTargetPlatform) {
          case TargetPlatform.android:
          case TargetPlatform.fuchsia:
          case TargetPlatform.iOS:
            switch (details.kind) {
              case PointerDeviceKind.mouse:
              case PointerDeviceKind.trackpad:
                return _selectParagraphsInRange(
                  from: dragStartGlobalPosition - editableOffset - scrollableOffset,
                  to: details.globalPosition,
                  cause: SelectionChangedCause.drag,
                );
              case PointerDeviceKind.stylus:
              case PointerDeviceKind.invertedStylus:
              case PointerDeviceKind.touch:
              case PointerDeviceKind.unknown:
              case null:
                // Triple tap to drag is not present on these platforms when using
                // non-precise pointer devices at the moment.
                break;
            }
            return;
          case TargetPlatform.linux:
            return _selectLinesInRange(
              from: dragStartGlobalPosition - editableOffset - scrollableOffset,
              to: details.globalPosition,
              cause: SelectionChangedCause.drag,
            );
          case TargetPlatform.windows:
          case TargetPlatform.macOS:
            return _selectParagraphsInRange(
              from: dragStartGlobalPosition - editableOffset - scrollableOffset,
              to: details.globalPosition,
              cause: SelectionChangedCause.drag,
            );
        }
      }

      switch (defaultTargetPlatform) {
        case TargetPlatform.iOS:
          // With a touch device, nothing should happen, unless there was a double tap, or
          // there was a collapsed selection, and the tap/drag position is at the collapsed selection.
          // In that case the caret should move with the drag position.
          //
          // With a mouse device, a drag should select the range from the origin of the drag
          // to the current position of the drag.
          switch (details.kind) {
            case PointerDeviceKind.mouse:
            case PointerDeviceKind.trackpad:
              return renderEditable.selectPositionAt(
                from: dragStartGlobalPosition - editableOffset - scrollableOffset,
                to: details.globalPosition,
                cause: SelectionChangedCause.drag,
              );
            case PointerDeviceKind.stylus:
            case PointerDeviceKind.invertedStylus:
            case PointerDeviceKind.touch:
            case PointerDeviceKind.unknown:
              assert(_dragBeganOnPreviousSelection != null);
              if (renderEditable.hasFocus
                  && _dragStartSelection!.isCollapsed
                  && _dragBeganOnPreviousSelection!
              ) {
                renderEditable.selectPositionAt(
                  from: details.globalPosition,
                  cause: SelectionChangedCause.drag,
                );
                return _showMagnifierIfSupportedByPlatform(details.globalPosition);
              }
            case null:
              break;
          }
          return;
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
          // With a precise pointer device, such as a mouse, trackpad, or stylus,
          // the drag will select the text spanning the origin of the drag to the end of the drag.
          // With a touch device, the cursor should move with the drag.
          switch (details.kind) {
            case PointerDeviceKind.mouse:
            case PointerDeviceKind.trackpad:
            case PointerDeviceKind.stylus:
            case PointerDeviceKind.invertedStylus:
              return renderEditable.selectPositionAt(
                from: dragStartGlobalPosition - editableOffset - scrollableOffset,
                to: details.globalPosition,
                cause: SelectionChangedCause.drag,
              );
            case PointerDeviceKind.touch:
            case PointerDeviceKind.unknown:
              if (renderEditable.hasFocus) {
                renderEditable.selectPositionAt(
                  from: details.globalPosition,
                  cause: SelectionChangedCause.drag,
                );
                return _showMagnifierIfSupportedByPlatform(details.globalPosition);
              }
            case null:
              break;
          }
          return;
        case TargetPlatform.macOS:
        case TargetPlatform.linux:
        case TargetPlatform.windows:
          return renderEditable.selectPositionAt(
            from: dragStartGlobalPosition - editableOffset - scrollableOffset,
            to: details.globalPosition,
            cause: SelectionChangedCause.drag,
          );
      }
    }

    if (_dragStartSelection!.isCollapsed
        || (defaultTargetPlatform != TargetPlatform.iOS
            && defaultTargetPlatform != TargetPlatform.macOS)) {
      return _extendSelection(details.globalPosition, SelectionChangedCause.drag);
    }

    // If the drag inverts the selection, Mac and iOS revert to the initial
    // selection.
    final TextSelection selection = editableText.textEditingValue.selection;
    final TextPosition nextExtent = renderEditable.getPositionForPoint(details.globalPosition);
    final bool isShiftTapDragSelectionForward =
        _dragStartSelection!.baseOffset < _dragStartSelection!.extentOffset;
    final bool isInverted = isShiftTapDragSelectionForward
        ? nextExtent.offset < _dragStartSelection!.baseOffset
        : nextExtent.offset > _dragStartSelection!.baseOffset;
    if (isInverted && selection.baseOffset == _dragStartSelection!.baseOffset) {
      editableText.userUpdateTextEditingValue(
        editableText.textEditingValue.copyWith(
          selection: TextSelection(
            baseOffset: _dragStartSelection!.extentOffset,
            extentOffset: nextExtent.offset,
          ),
        ),
        SelectionChangedCause.drag,
      );
    } else if (!isInverted
        && nextExtent.offset != _dragStartSelection!.baseOffset
        && selection.baseOffset != _dragStartSelection!.baseOffset) {
      editableText.userUpdateTextEditingValue(
        editableText.textEditingValue.copyWith(
          selection: TextSelection(
            baseOffset: _dragStartSelection!.baseOffset,
            extentOffset: nextExtent.offset,
          ),
        ),
        SelectionChangedCause.drag,
      );
    } else {
      _extendSelection(details.globalPosition, SelectionChangedCause.drag);
    }
  }

  @protected
  void onDragSelectionEnd(TapDragEndDetails details) {
    _dragBeganOnPreviousSelection = null;

    if (_shouldShowSelectionToolbar && _TextSelectionGestureDetectorState._getEffectiveConsecutiveTapCount(details.consecutiveTapCount) == 2) {
      editableText.showToolbar();
    }

    if (_isShiftPressed) {
      _dragStartSelection = null;
    }

    _hideMagnifierIfSupportedByPlatform();
  }

  Widget buildGestureDetector({
    Key? key,
    HitTestBehavior? behavior,
    required Widget child,
  }) {
    return TextSelectionGestureDetector(
      key: key,
      onTapTrackStart: onTapTrackStart,
      onTapTrackReset: onTapTrackReset,
      onTapDown: onTapDown,
      onForcePressStart: delegate.forcePressEnabled ? onForcePressStart : null,
      onForcePressEnd: delegate.forcePressEnabled ? onForcePressEnd : null,
      onSecondaryTap: onSecondaryTap,
      onSecondaryTapDown: onSecondaryTapDown,
      onSingleTapUp: onSingleTapUp,
      onSingleTapCancel: onSingleTapCancel,
      onSingleLongTapStart: onSingleLongTapStart,
      onSingleLongTapMoveUpdate: onSingleLongTapMoveUpdate,
      onSingleLongTapEnd: onSingleLongTapEnd,
      onDoubleTapDown: onDoubleTapDown,
      onTripleTapDown: onTripleTapDown,
      onDragSelectionStart: onDragSelectionStart,
      onDragSelectionUpdate: onDragSelectionUpdate,
      onDragSelectionEnd: onDragSelectionEnd,
      behavior: behavior,
      child: child,
    );
  }
}

class TextSelectionGestureDetector extends StatefulWidget {
  const TextSelectionGestureDetector({
    super.key,
    this.onTapTrackStart,
    this.onTapTrackReset,
    this.onTapDown,
    this.onForcePressStart,
    this.onForcePressEnd,
    this.onSecondaryTap,
    this.onSecondaryTapDown,
    this.onSingleTapUp,
    this.onSingleTapCancel,
    this.onSingleLongTapStart,
    this.onSingleLongTapMoveUpdate,
    this.onSingleLongTapEnd,
    this.onDoubleTapDown,
    this.onTripleTapDown,
    this.onDragSelectionStart,
    this.onDragSelectionUpdate,
    this.onDragSelectionEnd,
    this.behavior,
    required this.child,
  });

  final VoidCallback? onTapTrackStart;

  final VoidCallback? onTapTrackReset;

  final GestureTapDragDownCallback? onTapDown;

  final GestureForcePressStartCallback? onForcePressStart;

  final GestureForcePressEndCallback? onForcePressEnd;

  final GestureTapCallback? onSecondaryTap;

  final GestureTapDownCallback? onSecondaryTapDown;

  final GestureTapDragUpCallback? onSingleTapUp;

  final GestureCancelCallback? onSingleTapCancel;

  final GestureLongPressStartCallback? onSingleLongTapStart;

  final GestureLongPressMoveUpdateCallback? onSingleLongTapMoveUpdate;

  final GestureLongPressEndCallback? onSingleLongTapEnd;

  final GestureTapDragDownCallback? onDoubleTapDown;

  final GestureTapDragDownCallback? onTripleTapDown;

  final GestureTapDragStartCallback? onDragSelectionStart;

  final GestureTapDragUpdateCallback? onDragSelectionUpdate;

  final GestureTapDragEndCallback? onDragSelectionEnd;

  final HitTestBehavior? behavior;

  final Widget child;

  @override
  State<StatefulWidget> createState() => _TextSelectionGestureDetectorState();
}

class _TextSelectionGestureDetectorState extends State<TextSelectionGestureDetector> {

  // Converts the details.consecutiveTapCount from a TapAndDrag*Details object,
  // which can grow to be infinitely large, to a value between 1 and 3. The value
  // that the raw count is converted to is based on the default observed behavior
  // on the native platforms.
  //
  // This method should be used in all instances when details.consecutiveTapCount
  // would be used.
  static int _getEffectiveConsecutiveTapCount(int rawCount) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
        // From observation, these platform's reset their tap count to 0 when
        // the number of consecutive taps exceeds 3. For example on Debian Linux
        // with GTK, when going past a triple click, on the fourth click the
        // selection is moved to the precise click position, on the fifth click
        // the word at the position is selected, and on the sixth click the
        // paragraph at the position is selected.
        return rawCount <= 3 ? rawCount : (rawCount % 3 == 0 ? 3 : rawCount % 3);
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        // From observation, these platform's either hold their tap count at 3.
        // For example on macOS, when going past a triple click, the selection
        // should be retained at the paragraph that was first selected on triple
        // click.
        return math.min(rawCount, 3);
      case TargetPlatform.windows:
        // From observation, this platform's consecutive tap actions alternate
        // between double click and triple click actions. For example, after a
        // triple click has selected a paragraph, on the next click the word at
        // the clicked position will be selected, and on the next click the
        // paragraph at the position is selected.
        return rawCount < 2 ? rawCount : 2 + rawCount % 2;
    }
  }

  void _handleTapTrackStart() {
    widget.onTapTrackStart?.call();
  }

  void _handleTapTrackReset() {
    widget.onTapTrackReset?.call();
  }

  // The down handler is force-run on success of a single tap and optimistically
  // run before a long press success.
  void _handleTapDown(TapDragDownDetails details) {
    widget.onTapDown?.call(details);
    // This isn't detected as a double tap gesture in the gesture recognizer
    // because it's 2 single taps, each of which may do different things depending
    // on whether it's a single tap, the first tap of a double tap, the second
    // tap held down, a clean double tap etc.
    if (_getEffectiveConsecutiveTapCount(details.consecutiveTapCount) == 2) {
      return widget.onDoubleTapDown?.call(details);
    }

    if (_getEffectiveConsecutiveTapCount(details.consecutiveTapCount) == 3) {
      return widget.onTripleTapDown?.call(details);
    }
  }

  void _handleTapUp(TapDragUpDetails details) {
    if (_getEffectiveConsecutiveTapCount(details.consecutiveTapCount) == 1) {
      widget.onSingleTapUp?.call(details);
    }
  }

  void _handleTapCancel() {
    widget.onSingleTapCancel?.call();
  }

  void _handleDragStart(TapDragStartDetails details) {
    widget.onDragSelectionStart?.call(details);
  }

  void _handleDragUpdate(TapDragUpdateDetails details) {
    widget.onDragSelectionUpdate?.call(details);
  }

  void _handleDragEnd(TapDragEndDetails details) {
    widget.onDragSelectionEnd?.call(details);
  }

  void _forcePressStarted(ForcePressDetails details) {
    widget.onForcePressStart?.call(details);
  }

  void _forcePressEnded(ForcePressDetails details) {
    widget.onForcePressEnd?.call(details);
  }

  void _handleLongPressStart(LongPressStartDetails details) {
    if (widget.onSingleLongTapStart != null) {
      widget.onSingleLongTapStart!(details);
    }
  }

  void _handleLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (widget.onSingleLongTapMoveUpdate != null) {
      widget.onSingleLongTapMoveUpdate!(details);
    }
  }

  void _handleLongPressEnd(LongPressEndDetails details) {
    if (widget.onSingleLongTapEnd != null) {
      widget.onSingleLongTapEnd!(details);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<Type, GestureRecognizerFactory> gestures = <Type, GestureRecognizerFactory>{};

    gestures[TapGestureRecognizer] = GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
      () => TapGestureRecognizer(debugOwner: this),
      (TapGestureRecognizer instance) {
        instance
          ..onSecondaryTap = widget.onSecondaryTap
          ..onSecondaryTapDown = widget.onSecondaryTapDown;
      },
    );

    if (widget.onSingleLongTapStart != null ||
        widget.onSingleLongTapMoveUpdate != null ||
        widget.onSingleLongTapEnd != null) {
      gestures[LongPressGestureRecognizer] = GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
        () => LongPressGestureRecognizer(debugOwner: this, supportedDevices: <PointerDeviceKind>{ PointerDeviceKind.touch }),
        (LongPressGestureRecognizer instance) {
          instance
            ..onLongPressStart = _handleLongPressStart
            ..onLongPressMoveUpdate = _handleLongPressMoveUpdate
            ..onLongPressEnd = _handleLongPressEnd;
        },
      );
    }

    if (widget.onDragSelectionStart != null ||
        widget.onDragSelectionUpdate != null ||
        widget.onDragSelectionEnd != null) {
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
        case TargetPlatform.fuchsia:
        case TargetPlatform.iOS:
          gestures[TapAndHorizontalDragGestureRecognizer] = GestureRecognizerFactoryWithHandlers<TapAndHorizontalDragGestureRecognizer>(
            () => TapAndHorizontalDragGestureRecognizer(debugOwner: this),
            (TapAndHorizontalDragGestureRecognizer instance) {
              instance
                // Text selection should start from the position of the first pointer
                // down event.
                ..dragStartBehavior = DragStartBehavior.down
                ..onTapTrackStart = _handleTapTrackStart
                ..onTapTrackReset = _handleTapTrackReset
                ..onTapDown = _handleTapDown
                ..onDragStart = _handleDragStart
                ..onDragUpdate = _handleDragUpdate
                ..onDragEnd = _handleDragEnd
                ..onTapUp = _handleTapUp
                ..onCancel = _handleTapCancel;
            },
          );
        case TargetPlatform.linux:
        case TargetPlatform.macOS:
        case TargetPlatform.windows:
          gestures[TapAndPanGestureRecognizer] = GestureRecognizerFactoryWithHandlers<TapAndPanGestureRecognizer>(
            () => TapAndPanGestureRecognizer(debugOwner: this),
            (TapAndPanGestureRecognizer instance) {
              instance
                // Text selection should start from the position of the first pointer
                // down event.
                ..dragStartBehavior = DragStartBehavior.down
                ..onTapTrackStart = _handleTapTrackStart
                ..onTapTrackReset = _handleTapTrackReset
                ..onTapDown = _handleTapDown
                ..onDragStart = _handleDragStart
                ..onDragUpdate = _handleDragUpdate
                ..onDragEnd = _handleDragEnd
                ..onTapUp = _handleTapUp
                ..onCancel = _handleTapCancel;
            },
          );
      }
    }

    if (widget.onForcePressStart != null || widget.onForcePressEnd != null) {
      gestures[ForcePressGestureRecognizer] = GestureRecognizerFactoryWithHandlers<ForcePressGestureRecognizer>(
        () => ForcePressGestureRecognizer(debugOwner: this),
        (ForcePressGestureRecognizer instance) {
          instance
            ..onStart = widget.onForcePressStart != null ? _forcePressStarted : null
            ..onEnd = widget.onForcePressEnd != null ? _forcePressEnded : null;
        },
      );
    }

    return RawGestureDetector(
      gestures: gestures,
      excludeFromSemantics: true,
      behavior: widget.behavior,
      child: widget.child,
    );
  }
}

class ClipboardStatusNotifier extends ValueNotifier<ClipboardStatus> with WidgetsBindingObserver {
  ClipboardStatusNotifier({
    ClipboardStatus value = ClipboardStatus.unknown,
  }) : super(value);

  bool _disposed = false;

  Future<void> update() async {
    if (_disposed) {
      return;
    }

    final bool hasStrings;
    try {
      hasStrings = await Clipboard.hasStrings();
    } catch (exception, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: exception,
        stack: stack,
        library: 'widget library',
        context: ErrorDescription('while checking if the clipboard has strings'),
      ));
      // In the case of an error from the Clipboard API, set the value to
      // unknown so that it will try to update again later.
      if (_disposed) {
        return;
      }
      value = ClipboardStatus.unknown;
      return;
    }
    final ClipboardStatus nextStatus = hasStrings
        ? ClipboardStatus.pasteable
        : ClipboardStatus.notPasteable;

    if (_disposed) {
      return;
    }
    value = nextStatus;
  }

  @override
  void addListener(VoidCallback listener) {
    if (!hasListeners) {
      WidgetsBinding.instance.addObserver(this);
    }
    if (value == ClipboardStatus.unknown) {
      update();
    }
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!_disposed && !hasListeners) {
      WidgetsBinding.instance.removeObserver(this);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        update();
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        // Nothing to do.
        break;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    super.dispose();
  }
}

enum ClipboardStatus {
  pasteable,

  unknown,

  notPasteable,
}

class LiveTextInputStatusNotifier extends ValueNotifier<LiveTextInputStatus> with WidgetsBindingObserver {
  LiveTextInputStatusNotifier({
    LiveTextInputStatus value = LiveTextInputStatus.unknown,
  }) : super(value);

  bool _disposed = false;

  Future<void> update() async {
    if (_disposed) {
      return;
    }

    final bool isLiveTextInputEnabled;
    try {
      isLiveTextInputEnabled = await LiveText.isLiveTextInputAvailable();
    } catch (exception, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: exception,
        stack: stack,
        library: 'widget library',
        context: ErrorDescription('while checking the availability of Live Text input'),
      ));
      // In the case of an error from the Live Text API, set the value to
      // unknown so that it will try to update again later.
      if (_disposed || value == LiveTextInputStatus.unknown) {
        return;
      }
      value = LiveTextInputStatus.unknown;
      return;
    }

    final LiveTextInputStatus nextStatus = isLiveTextInputEnabled
        ? LiveTextInputStatus.enabled
        : LiveTextInputStatus.disabled;

    if (_disposed || nextStatus == value) {
      return;
    }
    value = nextStatus;
  }

  @override
  void addListener(VoidCallback listener) {
    if (!hasListeners) {
      WidgetsBinding.instance.addObserver(this);
    }
    if (value == LiveTextInputStatus.unknown) {
      update();
    }
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!_disposed && !hasListeners) {
      WidgetsBinding.instance.removeObserver(this);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        update();
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      // Nothing to do.
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    super.dispose();
  }
}

enum LiveTextInputStatus {
  enabled,

  unknown,

  disabled,
}

// TODO(justinmc): Deprecate this after TextSelectionControls.buildToolbar is
// deleted, when users should migrate back to TextSelectionControls.buildHandle.
// See https://github.com/flutter/flutter/pull/124262
mixin TextSelectionHandleControls on TextSelectionControls {
  @override
  Widget buildToolbar(
    BuildContext context,
    Rect globalEditableRegion,
    double textLineHeight,
    Offset selectionMidpoint,
    List<TextSelectionPoint> endpoints,
    TextSelectionDelegate delegate,
    ValueListenable<ClipboardStatus>? clipboardStatus,
    Offset? lastSecondaryTapDownPosition,
  ) => const SizedBox.shrink();

  @override
  bool canCut(TextSelectionDelegate delegate) => false;

  @override
  bool canCopy(TextSelectionDelegate delegate) => false;

  @override
  bool canPaste(TextSelectionDelegate delegate) => false;

  @override
  bool canSelectAll(TextSelectionDelegate delegate) => false;

  @override
  void handleCut(TextSelectionDelegate delegate, [ClipboardStatusNotifier? clipboardStatus]) {}

  @override
  void handleCopy(TextSelectionDelegate delegate, [ClipboardStatusNotifier? clipboardStatus]) {}

  @override
  Future<void> handlePaste(TextSelectionDelegate delegate) async {}

  @override
  void handleSelectAll(TextSelectionDelegate delegate) {}
}