
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'theme.dart';

// Examples can assume:
// late BuildContext context;

@immutable
class ExpansionTileThemeData with Diagnosticable {
  const ExpansionTileThemeData ({
    this.backgroundColor,
    this.collapsedBackgroundColor,
    this.tilePadding,
    this.expandedAlignment,
    this.childrenPadding,
    this.iconColor,
    this.collapsedIconColor,
    this.textColor,
    this.collapsedTextColor,
    this.shape,
    this.collapsedShape,
    this.clipBehavior,
  });

  final Color? backgroundColor;

  final Color? collapsedBackgroundColor;

  final EdgeInsetsGeometry? tilePadding;

  final AlignmentGeometry? expandedAlignment;

  final EdgeInsetsGeometry? childrenPadding;

  final Color? iconColor;

  final Color? collapsedIconColor;

  final Color? textColor;

  final Color? collapsedTextColor;

  final ShapeBorder? shape;

  final ShapeBorder? collapsedShape;

  final Clip? clipBehavior;

  ExpansionTileThemeData copyWith({
    Color? backgroundColor,
    Color? collapsedBackgroundColor,
    EdgeInsetsGeometry? tilePadding,
    AlignmentGeometry? expandedAlignment,
    EdgeInsetsGeometry? childrenPadding,
    Color? iconColor,
    Color? collapsedIconColor,
    Color? textColor,
    Color? collapsedTextColor,
    ShapeBorder? shape,
    ShapeBorder? collapsedShape,
    Clip? clipBehavior,
  }) {
    return ExpansionTileThemeData(
      backgroundColor: backgroundColor ?? this.backgroundColor,
      collapsedBackgroundColor: collapsedBackgroundColor ?? this.collapsedBackgroundColor,
      tilePadding: tilePadding ?? this.tilePadding,
      expandedAlignment: expandedAlignment ?? this.expandedAlignment,
      childrenPadding: childrenPadding ?? this.childrenPadding,
      iconColor: iconColor ?? this.iconColor,
      collapsedIconColor: collapsedIconColor ?? this.collapsedIconColor,
      textColor: textColor ?? this.textColor,
      collapsedTextColor: collapsedTextColor ?? this.collapsedTextColor,
      shape: shape ?? this.shape,
      collapsedShape: collapsedShape ?? this.collapsedShape,
      clipBehavior: clipBehavior ?? this.clipBehavior,
    );
  }

  static ExpansionTileThemeData? lerp(ExpansionTileThemeData? a, ExpansionTileThemeData? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    return ExpansionTileThemeData(
      backgroundColor: Color.lerp(a?.backgroundColor, b?.backgroundColor, t),
      collapsedBackgroundColor: Color.lerp(a?.collapsedBackgroundColor, b?.collapsedBackgroundColor, t),
      tilePadding: EdgeInsetsGeometry.lerp(a?.tilePadding, b?.tilePadding, t),
      expandedAlignment: AlignmentGeometry.lerp(a?.expandedAlignment, b?.expandedAlignment, t),
      childrenPadding: EdgeInsetsGeometry.lerp(a?.childrenPadding, b?.childrenPadding, t),
      iconColor: Color.lerp(a?.iconColor, b?.iconColor, t),
      collapsedIconColor: Color.lerp(a?.collapsedIconColor, b?.collapsedIconColor, t),
      textColor: Color.lerp(a?.textColor, b?.textColor, t),
      collapsedTextColor: Color.lerp(a?.collapsedTextColor, b?.collapsedTextColor, t),
      shape: ShapeBorder.lerp(a?.shape, b?.shape, t),
      collapsedShape: ShapeBorder.lerp(a?.collapsedShape, b?.collapsedShape, t),
    );
  }

  @override
  int get hashCode {
    return Object.hash(
      backgroundColor,
      collapsedBackgroundColor,
      tilePadding,
      expandedAlignment,
      childrenPadding,
      iconColor,
      collapsedIconColor,
      textColor,
      collapsedTextColor,
      shape,
      collapsedShape,
      clipBehavior,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ExpansionTileThemeData
      && other.backgroundColor == backgroundColor
      && other.collapsedBackgroundColor == collapsedBackgroundColor
      && other.tilePadding == tilePadding
      && other.expandedAlignment == expandedAlignment
      && other.childrenPadding == childrenPadding
      && other.iconColor == iconColor
      && other.collapsedIconColor == collapsedIconColor
      && other.textColor == textColor
      && other.collapsedTextColor == collapsedTextColor
      && other.shape == shape
      && other.collapsedShape == collapsedShape
      && other.clipBehavior == clipBehavior;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(ColorProperty('backgroundColor', backgroundColor, defaultValue: null));
    properties.add(ColorProperty('collapsedBackgroundColor', collapsedBackgroundColor, defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('tilePadding', tilePadding, defaultValue: null));
    properties.add(DiagnosticsProperty<AlignmentGeometry>('expandedAlignment', expandedAlignment, defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('childrenPadding', childrenPadding, defaultValue: null));
    properties.add(ColorProperty('iconColor', iconColor, defaultValue: null));
    properties.add(ColorProperty('collapsedIconColor', collapsedIconColor, defaultValue: null));
    properties.add(ColorProperty('textColor', textColor, defaultValue: null));
    properties.add(ColorProperty('collapsedTextColor', collapsedTextColor, defaultValue: null));
    properties.add(DiagnosticsProperty<ShapeBorder>('shape', shape, defaultValue: null));
    properties.add(DiagnosticsProperty<ShapeBorder>('collapsedShape', collapsedShape, defaultValue: null));
    properties.add(DiagnosticsProperty<Clip>('clipBehavior', clipBehavior, defaultValue: null));
  }
}

class ExpansionTileTheme extends InheritedTheme {
  const ExpansionTileTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final ExpansionTileThemeData data;

  static ExpansionTileThemeData of(BuildContext context) {
    final ExpansionTileTheme? inheritedTheme = context.dependOnInheritedWidgetOfExactType<ExpansionTileTheme>();
    return inheritedTheme?.data ?? Theme.of(context).expansionTileTheme;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return ExpansionTileTheme(data: data, child: child);
  }

  @override
  bool updateShouldNotify(ExpansionTileTheme oldWidget) => data != oldWidget.data;
 }