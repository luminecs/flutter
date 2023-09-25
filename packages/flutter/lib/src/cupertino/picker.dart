// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'theme.dart';

// Eyeballed values comparing with a native picker to produce the right
// curvatures and densities.
const double _kDefaultDiameterRatio = 1.07;
const double _kDefaultPerspective = 0.003;
const double _kSqueeze = 1.45;

// Opacity fraction value that dims the wheel above and below the "magnifier"
// lens.
const double _kOverAndUnderCenterOpacity = 0.447;

class CupertinoPicker extends StatefulWidget {
  CupertinoPicker({
    super.key,
    this.diameterRatio = _kDefaultDiameterRatio,
    this.backgroundColor,
    this.offAxisFraction = 0.0,
    this.useMagnifier = false,
    this.magnification = 1.0,
    this.scrollController,
    this.squeeze = _kSqueeze,
    required this.itemExtent,
    required this.onSelectedItemChanged,
    required List<Widget> children,
    this.selectionOverlay = const CupertinoPickerDefaultSelectionOverlay(),
    bool looping = false,
  }) : assert(diameterRatio > 0.0, RenderListWheelViewport.diameterRatioZeroMessage),
       assert(magnification > 0),
       assert(itemExtent > 0),
       assert(squeeze > 0),
       childDelegate = looping
                       ? ListWheelChildLoopingListDelegate(children: children)
                       : ListWheelChildListDelegate(children: children);

  CupertinoPicker.builder({
    super.key,
    this.diameterRatio = _kDefaultDiameterRatio,
    this.backgroundColor,
    this.offAxisFraction = 0.0,
    this.useMagnifier = false,
    this.magnification = 1.0,
    this.scrollController,
    this.squeeze = _kSqueeze,
    required this.itemExtent,
    required this.onSelectedItemChanged,
    required NullableIndexedWidgetBuilder itemBuilder,
    int? childCount,
    this.selectionOverlay = const CupertinoPickerDefaultSelectionOverlay(),
  }) : assert(diameterRatio > 0.0, RenderListWheelViewport.diameterRatioZeroMessage),
       assert(magnification > 0),
       assert(itemExtent > 0),
       assert(squeeze > 0),
       childDelegate = ListWheelChildBuilderDelegate(builder: itemBuilder, childCount: childCount);

  final double diameterRatio;

  final Color? backgroundColor;

  final double offAxisFraction;

  final bool useMagnifier;

  final double magnification;

  final FixedExtentScrollController? scrollController;

  final double itemExtent;

  final double squeeze;

  final ValueChanged<int>? onSelectedItemChanged;

  final ListWheelChildDelegate childDelegate;

  final Widget? selectionOverlay;

  @override
  State<StatefulWidget> createState() => _CupertinoPickerState();
}

class _CupertinoPickerState extends State<CupertinoPicker> {
  int? _lastHapticIndex;
  FixedExtentScrollController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.scrollController == null) {
      _controller = FixedExtentScrollController();
    }
  }

  @override
  void didUpdateWidget(CupertinoPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scrollController != null && oldWidget.scrollController == null) {
      _controller = null;
    } else if (widget.scrollController == null && oldWidget.scrollController != null) {
      assert(_controller == null);
      _controller = FixedExtentScrollController();
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _handleSelectedItemChanged(int index) {
    // Only the haptic engine hardware on iOS devices would produce the
    // intended effects.
    final bool hasSuitableHapticHardware;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
        hasSuitableHapticHardware = true;
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        hasSuitableHapticHardware = false;
    }
    if (hasSuitableHapticHardware && index != _lastHapticIndex) {
      _lastHapticIndex = index;
      HapticFeedback.selectionClick();
    }

    widget.onSelectedItemChanged?.call(index);
  }

  Widget _buildSelectionOverlay(Widget selectionOverlay) {
    final double height = widget.itemExtent * widget.magnification;

    return IgnorePointer(
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints.expand(
            height: height,
          ),
          child: selectionOverlay,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle textStyle = CupertinoTheme.of(context).textTheme.pickerTextStyle;
    final Color? resolvedBackgroundColor = CupertinoDynamicColor.maybeResolve(widget.backgroundColor, context);

    assert(RenderListWheelViewport.defaultPerspective == _kDefaultPerspective);
    final Widget result = DefaultTextStyle(
      style: textStyle.copyWith(color: CupertinoDynamicColor.maybeResolve(textStyle.color, context)),
      child: Stack(
        children: <Widget>[
          Positioned.fill(
            child: _CupertinoPickerSemantics(
              scrollController: widget.scrollController ?? _controller!,
              child: ListWheelScrollView.useDelegate(
                controller: widget.scrollController ?? _controller,
                physics: const FixedExtentScrollPhysics(),
                diameterRatio: widget.diameterRatio,
                offAxisFraction: widget.offAxisFraction,
                useMagnifier: widget.useMagnifier,
                magnification: widget.magnification,
                overAndUnderCenterOpacity: _kOverAndUnderCenterOpacity,
                itemExtent: widget.itemExtent,
                squeeze: widget.squeeze,
                onSelectedItemChanged: _handleSelectedItemChanged,
                childDelegate: widget.childDelegate,
              ),
            ),
          ),
          if (widget.selectionOverlay != null)
            _buildSelectionOverlay(widget.selectionOverlay!),
        ],
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(color: resolvedBackgroundColor),
      child: result,
    );
  }
}

class CupertinoPickerDefaultSelectionOverlay extends StatelessWidget {

  const CupertinoPickerDefaultSelectionOverlay({
    super.key,
    this.background = CupertinoColors.tertiarySystemFill,
    this.capStartEdge = true,
    this.capEndEdge = true,
  });

  final bool capStartEdge;

  final bool capEndEdge;

  final Color background;

  static const double _defaultSelectionOverlayHorizontalMargin = 9;

  static const double _defaultSelectionOverlayRadius = 8;

  @override
  Widget build(BuildContext context) {
    const Radius radius = Radius.circular(_defaultSelectionOverlayRadius);

    return Container(
      margin: EdgeInsetsDirectional.only(
        start: capStartEdge ? _defaultSelectionOverlayHorizontalMargin : 0,
        end: capEndEdge ? _defaultSelectionOverlayHorizontalMargin : 0,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadiusDirectional.horizontal(
          start: capStartEdge ? radius : Radius.zero,
          end: capEndEdge ? radius : Radius.zero,
        ),
        color: CupertinoDynamicColor.resolve(background, context),
      ),
    );
  }
}

// Turns the scroll semantics of the ListView into a single adjustable semantics
// node. This is done by removing all of the child semantics of the scroll
// wheel and using the scroll indexes to look up the current, previous, and
// next semantic label. This label is then turned into the value of a new
// adjustable semantic node, with adjustment callbacks wired to move the
// scroll controller.
class _CupertinoPickerSemantics extends SingleChildRenderObjectWidget {
  const _CupertinoPickerSemantics({
    super.child,
    required this.scrollController,
  });

  final FixedExtentScrollController scrollController;

  @override
  RenderObject createRenderObject(BuildContext context) {
    assert(debugCheckHasDirectionality(context));
    return _RenderCupertinoPickerSemantics(scrollController, Directionality.of(context));
  }

  @override
  void updateRenderObject(BuildContext context, covariant _RenderCupertinoPickerSemantics renderObject) {
    assert(debugCheckHasDirectionality(context));
    renderObject
      ..textDirection = Directionality.of(context)
      ..controller = scrollController;
  }
}

class _RenderCupertinoPickerSemantics extends RenderProxyBox {
  _RenderCupertinoPickerSemantics(FixedExtentScrollController controller, this._textDirection) {
    _updateController(null, controller);
  }

  FixedExtentScrollController get controller => _controller;
  late FixedExtentScrollController _controller;
  set controller(FixedExtentScrollController value) => _updateController(_controller, value);

  // This method exists to allow controller to be non-null. It is only called with a null oldValue from constructor.
  void _updateController(FixedExtentScrollController? oldValue, FixedExtentScrollController value) {
    if (value == oldValue) {
      return;
    }
    if (oldValue != null) {
      oldValue.removeListener(_handleScrollUpdate);
    } else {
      _currentIndex = value.initialItem;
    }
    value.addListener(_handleScrollUpdate);
    _controller = value;
  }

  TextDirection get textDirection => _textDirection;
  TextDirection _textDirection;
  set textDirection(TextDirection value) {
    if (textDirection == value) {
      return;
    }
    _textDirection = value;
    markNeedsSemanticsUpdate();
  }

  int _currentIndex = 0;

  void _handleIncrease() {
    controller.jumpToItem(_currentIndex + 1);
  }

  void _handleDecrease() {
    controller.jumpToItem(_currentIndex - 1);
  }

  void _handleScrollUpdate() {
    if (controller.selectedItem == _currentIndex) {
      return;
    }
    _currentIndex = controller.selectedItem;
    markNeedsSemanticsUpdate();
  }
  @override
  void describeSemanticsConfiguration(SemanticsConfiguration config) {
    super.describeSemanticsConfiguration(config);
    config.isSemanticBoundary = true;
    config.textDirection = textDirection;
  }

  @override
  void assembleSemanticsNode(SemanticsNode node, SemanticsConfiguration config, Iterable<SemanticsNode> children) {
    if (children.isEmpty) {
      return super.assembleSemanticsNode(node, config, children);
    }
    final SemanticsNode scrollable = children.first;
    final Map<int, SemanticsNode> indexedChildren = <int, SemanticsNode>{};
    scrollable.visitChildren((SemanticsNode child) {
      assert(child.indexInParent != null);
      indexedChildren[child.indexInParent!] = child;
      return true;
    });
    if (indexedChildren[_currentIndex] == null) {
      return node.updateWith(config: config);
    }
    config.value = indexedChildren[_currentIndex]!.label;
    final SemanticsNode? previousChild = indexedChildren[_currentIndex - 1];
    final SemanticsNode? nextChild = indexedChildren[_currentIndex + 1];
    if (nextChild != null) {
      config.increasedValue = nextChild.label;
      config.onIncrease = _handleIncrease;
    }
    if (previousChild != null) {
      config.decreasedValue = previousChild.label;
      config.onDecrease = _handleDecrease;
    }
    node.updateWith(config: config);
  }

  @override
  void dispose() {
    super.dispose();
    controller.removeListener(_handleScrollUpdate);
  }
}