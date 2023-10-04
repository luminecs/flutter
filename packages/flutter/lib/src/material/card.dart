import 'package:flutter/widgets.dart';

import 'card_theme.dart';
import 'color_scheme.dart';
import 'material.dart';
import 'theme.dart';

class Card extends StatelessWidget {
  const Card({
    super.key,
    this.color,
    this.shadowColor,
    this.surfaceTintColor,
    this.elevation,
    this.shape,
    this.borderOnForeground = true,
    this.margin,
    this.clipBehavior,
    this.child,
    this.semanticContainer = true,
  }) : assert(elevation == null || elevation >= 0.0);

  final Color? color;

  final Color? shadowColor;

  final Color? surfaceTintColor;

  final double? elevation;

  final ShapeBorder? shape;

  final bool borderOnForeground;

  final Clip? clipBehavior;

  final EdgeInsetsGeometry? margin;

  final bool semanticContainer;

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final CardTheme cardTheme = CardTheme.of(context);
    final CardTheme defaults = Theme.of(context).useMaterial3
        ? _CardDefaultsM3(context)
        : _CardDefaultsM2(context);

    return Semantics(
      container: semanticContainer,
      child: Container(
        margin: margin ?? cardTheme.margin ?? defaults.margin!,
        child: Material(
          type: MaterialType.card,
          color: color ?? cardTheme.color ?? defaults.color,
          shadowColor:
              shadowColor ?? cardTheme.shadowColor ?? defaults.shadowColor,
          surfaceTintColor: surfaceTintColor ??
              cardTheme.surfaceTintColor ??
              defaults.surfaceTintColor,
          elevation: elevation ?? cardTheme.elevation ?? defaults.elevation!,
          shape: shape ?? cardTheme.shape ?? defaults.shape,
          borderOnForeground: borderOnForeground,
          clipBehavior:
              clipBehavior ?? cardTheme.clipBehavior ?? defaults.clipBehavior!,
          child: Semantics(
            explicitChildNodes: !semanticContainer,
            child: child,
          ),
        ),
      ),
    );
  }
}

// Hand coded defaults based on Material Design 2.
class _CardDefaultsM2 extends CardTheme {
  const _CardDefaultsM2(this.context)
      : super(
            clipBehavior: Clip.none,
            elevation: 1.0,
            margin: const EdgeInsets.all(4.0),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(4.0)),
            ));

  final BuildContext context;

  @override
  Color? get color => Theme.of(context).cardColor;

  @override
  Color? get shadowColor => Theme.of(context).shadowColor;
}

// BEGIN GENERATED TOKEN PROPERTIES - Card

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

class _CardDefaultsM3 extends CardTheme {
  _CardDefaultsM3(this.context)
      : super(
          clipBehavior: Clip.none,
          elevation: 1.0,
          margin: const EdgeInsets.all(4.0),
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12.0))),
        );

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;

  @override
  Color? get color => _colors.surface;

  @override
  Color? get shadowColor => _colors.shadow;

  @override
  Color? get surfaceTintColor => _colors.surfaceTint;
}

// END GENERATED TOKEN PROPERTIES - Card
