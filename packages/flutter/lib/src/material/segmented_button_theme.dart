import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'button_style.dart';
import 'theme.dart';

// Examples can assume:
// late BuildContext context;

@immutable
class SegmentedButtonThemeData with Diagnosticable {
  const SegmentedButtonThemeData({
    this.style,
    this.selectedIcon,
  });

  final ButtonStyle? style;

  final Widget? selectedIcon;

  SegmentedButtonThemeData copyWith({
    ButtonStyle? style,
    Widget? selectedIcon,
  }) {
    return SegmentedButtonThemeData(
      style: style ?? this.style,
      selectedIcon: selectedIcon ?? this.selectedIcon,
    );
  }

  static SegmentedButtonThemeData lerp(
      SegmentedButtonThemeData? a, SegmentedButtonThemeData? b, double t) {
    if (identical(a, b) && a != null) {
      return a;
    }
    return SegmentedButtonThemeData(
      style: ButtonStyle.lerp(a?.style, b?.style, t),
      selectedIcon: t < 0.5 ? a?.selectedIcon : b?.selectedIcon,
    );
  }

  @override
  int get hashCode => Object.hash(
        style,
        selectedIcon,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is SegmentedButtonThemeData &&
        other.style == style &&
        other.selectedIcon == selectedIcon;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(
        DiagnosticsProperty<ButtonStyle>('style', style, defaultValue: null));
    properties.add(DiagnosticsProperty<Widget>('selectedIcon', selectedIcon,
        defaultValue: null));
  }
}

class SegmentedButtonTheme extends InheritedTheme {
  const SegmentedButtonTheme({
    super.key,
    required this.data,
    required super.child,
  });

  final SegmentedButtonThemeData data;

  static SegmentedButtonThemeData of(BuildContext context) {
    return maybeOf(context) ?? Theme.of(context).segmentedButtonTheme;
  }

  static SegmentedButtonThemeData? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<SegmentedButtonTheme>()
        ?.data;
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return SegmentedButtonTheme(data: data, child: child);
  }

  @override
  bool updateShouldNotify(SegmentedButtonTheme oldWidget) =>
      data != oldWidget.data;
}
