import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'bottom_app_bar_theme.dart';
import 'color_scheme.dart';
import 'colors.dart';
import 'elevation_overlay.dart';
import 'material.dart';
import 'scaffold.dart';
import 'theme.dart';

// Examples can assume:
// late Widget bottomAppBarContents;

class BottomAppBar extends StatefulWidget {
  const BottomAppBar({
    super.key,
    this.color,
    this.elevation,
    this.shape,
    this.clipBehavior = Clip.none,
    this.notchMargin = 4.0,
    this.child,
    this.padding,
    this.surfaceTintColor,
    this.shadowColor,
    this.height,
  }) : assert(elevation == null || elevation >= 0.0);

  final Widget? child;

  final EdgeInsetsGeometry? padding;

  final Color? color;

  final double? elevation;

  final NotchedShape? shape;

  final Clip clipBehavior;

  final double notchMargin;

  final Color? surfaceTintColor;

  final Color? shadowColor;

  final double? height;

  @override
  State createState() => _BottomAppBarState();
}

class _BottomAppBarState extends State<BottomAppBar> {
  late ValueListenable<ScaffoldGeometry> geometryListenable;
  final GlobalKey materialKey = GlobalKey();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    geometryListenable = Scaffold.geometryOf(context);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isMaterial3 = theme.useMaterial3;
    final BottomAppBarTheme babTheme = BottomAppBarTheme.of(context);
    final BottomAppBarTheme defaults = isMaterial3 ? _BottomAppBarDefaultsM3(context) : _BottomAppBarDefaultsM2(context);

    final bool hasFab = Scaffold.of(context).hasFloatingActionButton;
    final NotchedShape? notchedShape = widget.shape ?? babTheme.shape ?? defaults.shape;
    final CustomClipper<Path> clipper = notchedShape != null && hasFab
      ? _BottomAppBarClipper(
          geometry: geometryListenable,
          shape: notchedShape,
          materialKey: materialKey,
          notchMargin: widget.notchMargin,
        )
      : const ShapeBorderClipper(shape: RoundedRectangleBorder());
    final double elevation = widget.elevation ?? babTheme.elevation ?? defaults.elevation!;
    final double? height = widget.height ?? babTheme.height ?? defaults.height;
    final Color color = widget.color ?? babTheme.color ?? defaults.color!;
    final Color surfaceTintColor = widget.surfaceTintColor ?? babTheme.surfaceTintColor ?? defaults.surfaceTintColor!;
    final Color effectiveColor = isMaterial3
      ? ElevationOverlay.applySurfaceTint(color, surfaceTintColor, elevation)
      : ElevationOverlay.applyOverlay(context, color, elevation);
    final Color shadowColor = widget.shadowColor ?? babTheme.shadowColor ?? defaults.shadowColor!;

    final Widget child = SizedBox(
      height: height,
      child: Padding(
        padding: widget.padding ?? babTheme.padding ?? (isMaterial3 ? const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0) : EdgeInsets.zero),
        child: widget.child,
      ),
    );

    final Material material = Material(
      key: materialKey,
      type: MaterialType.transparency,
      child: SafeArea(child: child),
    );

    return PhysicalShape(
      clipper: clipper,
      elevation: elevation,
      shadowColor: shadowColor,
      color: effectiveColor,
      clipBehavior: widget.clipBehavior,
      child: material,
    );
  }
}

class _BottomAppBarClipper extends CustomClipper<Path> {
  const _BottomAppBarClipper({
    required this.geometry,
    required this.shape,
    required this.materialKey,
    required this.notchMargin,
  }) : super(reclip: geometry);

  final ValueListenable<ScaffoldGeometry> geometry;
  final NotchedShape shape;
  final GlobalKey materialKey;
  final double notchMargin;

  // Returns the top of the BottomAppBar in global coordinates.
  //
  // If the Scaffold's bottomNavigationBar was specified, then we can use its
  // geometry value, otherwise we compute the location based on the AppBar's
  // Material widget.
  double get bottomNavigationBarTop {
    final double? bottomNavigationBarTop = geometry.value.bottomNavigationBarTop;
    if (bottomNavigationBarTop != null) {
      return bottomNavigationBarTop;
    }
    final RenderBox? box = materialKey.currentContext?.findRenderObject() as RenderBox?;
    return box?.localToGlobal(Offset.zero).dy ?? 0;
  }

  @override
  Path getClip(Size size) {
    // button is the floating action button's bounding rectangle in the
    // coordinate system whose origin is at the appBar's top left corner,
    // or null if there is no floating action button.
    final Rect? button = geometry.value.floatingActionButtonArea?.translate(0.0, bottomNavigationBarTop * -1.0);
    return shape.getOuterPath(Offset.zero & size, button?.inflate(notchMargin));
  }

  @override
  bool shouldReclip(_BottomAppBarClipper oldClipper) {
    return oldClipper.geometry != geometry
        || oldClipper.shape != shape
        || oldClipper.notchMargin != notchMargin;
  }
}

class _BottomAppBarDefaultsM2 extends BottomAppBarTheme {
  const _BottomAppBarDefaultsM2(this.context)
    : super(
      elevation: 8.0,
    );

  final BuildContext context;

  @override
  Color? get color => Theme.of(context).bottomAppBarColor;

  @override
  Color? get surfaceTintColor => Theme.of(context).colorScheme.surfaceTint;

  @override
  Color get shadowColor => const Color(0xFF000000);
}

// BEGIN GENERATED TOKEN PROPERTIES - BottomAppBar

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

class _BottomAppBarDefaultsM3 extends BottomAppBarTheme {
  _BottomAppBarDefaultsM3(this.context)
    : super(
      elevation: 3.0,
      height: 80.0,
      shape: const AutomaticNotchedShape(RoundedRectangleBorder()),
    );

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;

  @override
  Color? get color => _colors.surface;

  @override
  Color? get surfaceTintColor => _colors.surfaceTint;

  @override
  Color? get shadowColor => Colors.transparent;
}

// END GENERATED TOKEN PROPERTIES - BottomAppBar