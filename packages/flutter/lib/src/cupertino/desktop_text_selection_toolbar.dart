
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'colors.dart';

// The minimum padding from all edges of the selection toolbar to all edges of
// the screen.
const double _kToolbarScreenPadding = 8.0;

// These values were measured from a screenshot of the native context menu on
// macOS 13.2 on a Macbook Pro.
const double _kToolbarSaturationBoost = 3;
const double _kToolbarBlurSigma = 20;
const double _kToolbarWidth = 222.0;
const Radius _kToolbarBorderRadius = Radius.circular(8.0);
const EdgeInsets _kToolbarPadding = EdgeInsets.all(6.0);
const List<BoxShadow> _kToolbarShadow = <BoxShadow>[
  BoxShadow(
    color: Color.fromARGB(60, 0, 0, 0),
    blurRadius: 10.0,
    spreadRadius: 0.5,
    offset: Offset(0.0, 4.0),
  ),
];

// These values were measured from a screenshot of the native context menu on
// macOS 13.2 on a Macbook Pro.
const CupertinoDynamicColor _kToolbarBorderColor =
    CupertinoDynamicColor.withBrightness(
  color: Color(0xFFB8B8B8),
  darkColor: Color(0xFF5B5B5B),
);
const CupertinoDynamicColor _kToolbarBackgroundColor =
    CupertinoDynamicColor.withBrightness(
  color: Color(0xB2FFFFFF),
  darkColor: Color(0xB2303030),
);

class CupertinoDesktopTextSelectionToolbar extends StatelessWidget {
  const CupertinoDesktopTextSelectionToolbar({
    super.key,
    required this.anchor,
    required this.children,
  }) : assert(children.length > 0);

  static List<double> _matrixWithSaturation(double saturation) {
    final double r = 0.213 * (1 - saturation);
    final double g = 0.715 * (1 - saturation);
    final double b = 0.072 * (1 - saturation);

    return <double>[
      r + saturation, g, b, 0, 0, //
      r, g + saturation, b, 0, 0, //
      r, g, b + saturation, 0, 0, //
      0, 0, 0, 1, 0, //
    ];
  }

  final Offset anchor;

  final List<Widget> children;

  // Builds a toolbar just like the default Mac toolbar, with the right color
  // background, padding, and rounded corners.
  static Widget _defaultToolbarBuilder(BuildContext context, Widget child) {
    return Container(
      width: _kToolbarWidth,
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        boxShadow: _kToolbarShadow,
        borderRadius: BorderRadius.all(_kToolbarBorderRadius),
      ),
      child: BackdropFilter(
        // Flutter web doesn't support ImageFilter.compose on CanvasKit yet
        // (https://github.com/flutter/flutter/issues/120123).
        filter: kIsWeb
            ? ImageFilter.blur(
                sigmaX: _kToolbarBlurSigma,
                sigmaY: _kToolbarBlurSigma,
              )
            : ImageFilter.compose(
                outer: ColorFilter.matrix(
                  _matrixWithSaturation(_kToolbarSaturationBoost),
                ),
                inner: ImageFilter.blur(
                  sigmaX: _kToolbarBlurSigma,
                  sigmaY: _kToolbarBlurSigma,
                ),
              ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _kToolbarBackgroundColor.resolveFrom(context),
            border: Border.all(
              color: _kToolbarBorderColor.resolveFrom(context),
            ),
            borderRadius: const BorderRadius.all(_kToolbarBorderRadius),
          ),
          child: Padding(
            padding: _kToolbarPadding,
            child: child,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMediaQuery(context));

    final double paddingAbove =
        MediaQuery.paddingOf(context).top + _kToolbarScreenPadding;
    final Offset localAdjustment = Offset(_kToolbarScreenPadding, paddingAbove);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        _kToolbarScreenPadding,
        paddingAbove,
        _kToolbarScreenPadding,
        _kToolbarScreenPadding,
      ),
      child: CustomSingleChildLayout(
        delegate: DesktopTextSelectionToolbarLayoutDelegate(
          anchor: anchor - localAdjustment,
        ),
        child: _defaultToolbarBuilder(
          context,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: children,
          ),
        ),
      ),
    );
  }
}