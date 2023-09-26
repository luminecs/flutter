import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'ink_well.dart';
import 'material_state.dart';
import 'tabs.dart';
import 'theme.dart';

@immutable
class TabBarTheme with Diagnosticable {
  const TabBarTheme({
    this.indicator,
    this.indicatorColor,
    this.indicatorSize,
    this.dividerColor,
    this.dividerHeight,
    this.labelColor,
    this.labelPadding,
    this.labelStyle,
    this.unselectedLabelColor,
    this.unselectedLabelStyle,
    this.overlayColor,
    this.splashFactory,
    this.mouseCursor,
    this.tabAlignment,
  });

  final Decoration? indicator;

  final Color? indicatorColor;

  final TabBarIndicatorSize? indicatorSize;

  final Color? dividerColor;

  final double? dividerHeight;

  final Color? labelColor;

  final EdgeInsetsGeometry? labelPadding;

  final TextStyle? labelStyle;

  final Color? unselectedLabelColor;

  final TextStyle? unselectedLabelStyle;

  final MaterialStateProperty<Color?>? overlayColor;

  final InteractiveInkFeatureFactory? splashFactory;

  final MaterialStateProperty<MouseCursor?>? mouseCursor;

  final TabAlignment? tabAlignment;

  TabBarTheme copyWith({
    Decoration? indicator,
    Color? indicatorColor,
    TabBarIndicatorSize? indicatorSize,
    Color? dividerColor,
    double? dividerHeight,
    Color? labelColor,
    EdgeInsetsGeometry? labelPadding,
    TextStyle? labelStyle,
    Color? unselectedLabelColor,
    TextStyle? unselectedLabelStyle,
    MaterialStateProperty<Color?>? overlayColor,
    InteractiveInkFeatureFactory? splashFactory,
    MaterialStateProperty<MouseCursor?>? mouseCursor,
    TabAlignment? tabAlignment,
  }) {
    return TabBarTheme(
      indicator: indicator ?? this.indicator,
      indicatorColor: indicatorColor ?? this.indicatorColor,
      indicatorSize: indicatorSize ?? this.indicatorSize,
      dividerColor: dividerColor ?? this.dividerColor,
      dividerHeight: dividerHeight ?? this.dividerHeight,
      labelColor: labelColor ?? this.labelColor,
      labelPadding: labelPadding ?? this.labelPadding,
      labelStyle: labelStyle ?? this.labelStyle,
      unselectedLabelColor: unselectedLabelColor ?? this.unselectedLabelColor,
      unselectedLabelStyle: unselectedLabelStyle ?? this.unselectedLabelStyle,
      overlayColor: overlayColor ?? this.overlayColor,
      splashFactory: splashFactory ?? this.splashFactory,
      mouseCursor: mouseCursor ?? this.mouseCursor,
      tabAlignment: tabAlignment ?? this.tabAlignment,
    );
  }

  static TabBarTheme of(BuildContext context) {
    return Theme.of(context).tabBarTheme;
  }

  static TabBarTheme lerp(TabBarTheme a, TabBarTheme b, double t) {
    if (identical(a, b)) {
      return a;
    }
    return TabBarTheme(
      indicator: Decoration.lerp(a.indicator, b.indicator, t),
      indicatorColor: Color.lerp(a.indicatorColor, b.indicatorColor, t),
      indicatorSize: t < 0.5 ? a.indicatorSize : b.indicatorSize,
      dividerColor: Color.lerp(a.dividerColor, b.dividerColor, t),
      dividerHeight: t < 0.5 ? a.dividerHeight : b.dividerHeight,
      labelColor: Color.lerp(a.labelColor, b.labelColor, t),
      labelPadding: EdgeInsetsGeometry.lerp(a.labelPadding, b.labelPadding, t),
      labelStyle: TextStyle.lerp(a.labelStyle, b.labelStyle, t),
      unselectedLabelColor:
          Color.lerp(a.unselectedLabelColor, b.unselectedLabelColor, t),
      unselectedLabelStyle:
          TextStyle.lerp(a.unselectedLabelStyle, b.unselectedLabelStyle, t),
      overlayColor: MaterialStateProperty.lerp<Color?>(
          a.overlayColor, b.overlayColor, t, Color.lerp),
      splashFactory: t < 0.5 ? a.splashFactory : b.splashFactory,
      mouseCursor: t < 0.5 ? a.mouseCursor : b.mouseCursor,
      tabAlignment: t < 0.5 ? a.tabAlignment : b.tabAlignment,
    );
  }

  @override
  int get hashCode => Object.hash(
        indicator,
        indicatorColor,
        indicatorSize,
        dividerColor,
        dividerHeight,
        labelColor,
        labelPadding,
        labelStyle,
        unselectedLabelColor,
        unselectedLabelStyle,
        overlayColor,
        splashFactory,
        mouseCursor,
        tabAlignment,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is TabBarTheme &&
        other.indicator == indicator &&
        other.indicatorColor == indicatorColor &&
        other.indicatorSize == indicatorSize &&
        other.dividerColor == dividerColor &&
        other.dividerHeight == dividerHeight &&
        other.labelColor == labelColor &&
        other.labelPadding == labelPadding &&
        other.labelStyle == labelStyle &&
        other.unselectedLabelColor == unselectedLabelColor &&
        other.unselectedLabelStyle == unselectedLabelStyle &&
        other.overlayColor == overlayColor &&
        other.splashFactory == splashFactory &&
        other.mouseCursor == mouseCursor &&
        other.tabAlignment == tabAlignment;
  }
}
