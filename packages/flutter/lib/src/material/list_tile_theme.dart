import 'dart:ui' show lerpDouble;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'list_tile.dart';
import 'material_state.dart';
import 'theme.dart';
import 'theme_data.dart';

// Examples can assume:
// late BuildContext context;

@immutable
class ListTileThemeData with Diagnosticable {
  const ListTileThemeData ({
    this.dense,
    this.shape,
    this.style,
    this.selectedColor,
    this.iconColor,
    this.textColor,
    this.titleTextStyle,
    this.subtitleTextStyle,
    this.leadingAndTrailingTextStyle,
    this.contentPadding,
    this.tileColor,
    this.selectedTileColor,
    this.horizontalTitleGap,
    this.minVerticalPadding,
    this.minLeadingWidth,
    this.enableFeedback,
    this.mouseCursor,
    this.visualDensity,
    this.titleAlignment,
  });

  final bool? dense;

  final ShapeBorder? shape;

  final ListTileStyle? style;

  final Color? selectedColor;

  final Color? iconColor;

  final Color? textColor;

  final TextStyle? titleTextStyle;

  final TextStyle? subtitleTextStyle;

  final TextStyle? leadingAndTrailingTextStyle;

  final EdgeInsetsGeometry? contentPadding;

  final Color? tileColor;

  final Color? selectedTileColor;

  final double? horizontalTitleGap;

  final double? minVerticalPadding;

  final double? minLeadingWidth;

  final bool? enableFeedback;

  final MaterialStateProperty<MouseCursor?>? mouseCursor;

  final VisualDensity? visualDensity;

  final ListTileTitleAlignment? titleAlignment;

  ListTileThemeData copyWith({
    bool? dense,
    ShapeBorder? shape,
    ListTileStyle? style,
    Color? selectedColor,
    Color? iconColor,
    Color? textColor,
    TextStyle? titleTextStyle,
    TextStyle? subtitleTextStyle,
    TextStyle? leadingAndTrailingTextStyle,
    EdgeInsetsGeometry? contentPadding,
    Color? tileColor,
    Color? selectedTileColor,
    double? horizontalTitleGap,
    double? minVerticalPadding,
    double? minLeadingWidth,
    bool? enableFeedback,
    MaterialStateProperty<MouseCursor?>? mouseCursor,
    bool? isThreeLine,
    VisualDensity? visualDensity,
    ListTileTitleAlignment? titleAlignment,
  }) {
    return ListTileThemeData(
      dense: dense ?? this.dense,
      shape: shape ?? this.shape,
      style: style ?? this.style,
      selectedColor: selectedColor ?? this.selectedColor,
      iconColor: iconColor ?? this.iconColor,
      textColor: textColor ?? this.textColor,
      titleTextStyle: titleTextStyle ?? this.titleTextStyle,
      subtitleTextStyle: subtitleTextStyle ?? this.subtitleTextStyle,
      leadingAndTrailingTextStyle: leadingAndTrailingTextStyle ?? this.leadingAndTrailingTextStyle,
      contentPadding: contentPadding ?? this.contentPadding,
      tileColor: tileColor ?? this.tileColor,
      selectedTileColor: selectedTileColor ?? this.selectedTileColor,
      horizontalTitleGap: horizontalTitleGap ?? this.horizontalTitleGap,
      minVerticalPadding: minVerticalPadding ?? this.minVerticalPadding,
      minLeadingWidth: minLeadingWidth ?? this.minLeadingWidth,
      enableFeedback: enableFeedback ?? this.enableFeedback,
      mouseCursor: mouseCursor ?? this.mouseCursor,
      visualDensity: visualDensity ?? this.visualDensity,
      titleAlignment: titleAlignment ?? this.titleAlignment,
    );
  }

  static ListTileThemeData? lerp(ListTileThemeData? a, ListTileThemeData? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    return ListTileThemeData(
      dense: t < 0.5 ? a?.dense : b?.dense,
      shape: ShapeBorder.lerp(a?.shape, b?.shape, t),
      style: t < 0.5 ? a?.style : b?.style,
      selectedColor: Color.lerp(a?.selectedColor, b?.selectedColor, t),
      iconColor: Color.lerp(a?.iconColor, b?.iconColor, t),
      textColor: Color.lerp(a?.textColor, b?.textColor, t),
      titleTextStyle: TextStyle.lerp(a?.titleTextStyle, b?.titleTextStyle, t),
      subtitleTextStyle: TextStyle.lerp(a?.subtitleTextStyle, b?.subtitleTextStyle, t),
      leadingAndTrailingTextStyle: TextStyle.lerp(a?.leadingAndTrailingTextStyle, b?.leadingAndTrailingTextStyle, t),
      contentPadding: EdgeInsetsGeometry.lerp(a?.contentPadding, b?.contentPadding, t),
      tileColor: Color.lerp(a?.tileColor, b?.tileColor, t),
      selectedTileColor: Color.lerp(a?.selectedTileColor, b?.selectedTileColor, t),
      horizontalTitleGap: lerpDouble(a?.horizontalTitleGap, b?.horizontalTitleGap, t),
      minVerticalPadding: lerpDouble(a?.minVerticalPadding, b?.minVerticalPadding, t),
      minLeadingWidth: lerpDouble(a?.minLeadingWidth, b?.minLeadingWidth, t),
      enableFeedback: t < 0.5 ? a?.enableFeedback : b?.enableFeedback,
      mouseCursor: t < 0.5 ? a?.mouseCursor : b?.mouseCursor,
      visualDensity: t < 0.5 ? a?.visualDensity : b?.visualDensity,
      titleAlignment: t < 0.5 ? a?.titleAlignment : b?.titleAlignment,
    );
  }

  @override
  int get hashCode => Object.hash(
    dense,
    shape,
    style,
    selectedColor,
    iconColor,
    textColor,
    titleTextStyle,
    subtitleTextStyle,
    leadingAndTrailingTextStyle,
    contentPadding,
    tileColor,
    selectedTileColor,
    horizontalTitleGap,
    minVerticalPadding,
    minLeadingWidth,
    enableFeedback,
    mouseCursor,
    visualDensity,
    titleAlignment,
  );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ListTileThemeData
      && other.dense == dense
      && other.shape == shape
      && other.style == style
      && other.selectedColor == selectedColor
      && other.iconColor == iconColor
      && other.titleTextStyle == titleTextStyle
      && other.subtitleTextStyle == subtitleTextStyle
      && other.leadingAndTrailingTextStyle == leadingAndTrailingTextStyle
      && other.textColor == textColor
      && other.contentPadding == contentPadding
      && other.tileColor == tileColor
      && other.selectedTileColor == selectedTileColor
      && other.horizontalTitleGap == horizontalTitleGap
      && other.minVerticalPadding == minVerticalPadding
      && other.minLeadingWidth == minLeadingWidth
      && other.enableFeedback == enableFeedback
      && other.mouseCursor == mouseCursor
      && other.visualDensity == visualDensity
      && other.titleAlignment == titleAlignment;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<bool>('dense', dense, defaultValue: null));
    properties.add(DiagnosticsProperty<ShapeBorder>('shape', shape, defaultValue: null));
    properties.add(EnumProperty<ListTileStyle>('style', style, defaultValue: null));
    properties.add(ColorProperty('selectedColor', selectedColor, defaultValue: null));
    properties.add(ColorProperty('iconColor', iconColor, defaultValue: null));
    properties.add(ColorProperty('textColor', textColor, defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle>('titleTextStyle', titleTextStyle, defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle>('subtitleTextStyle', subtitleTextStyle, defaultValue: null));
    properties.add(DiagnosticsProperty<TextStyle>('leadingAndTrailingTextStyle', leadingAndTrailingTextStyle, defaultValue: null));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('contentPadding', contentPadding, defaultValue: null));
    properties.add(ColorProperty('tileColor', tileColor, defaultValue: null));
    properties.add(ColorProperty('selectedTileColor', selectedTileColor, defaultValue: null));
    properties.add(DoubleProperty('horizontalTitleGap', horizontalTitleGap, defaultValue: null));
    properties.add(DoubleProperty('minVerticalPadding', minVerticalPadding, defaultValue: null));
    properties.add(DoubleProperty('minLeadingWidth', minLeadingWidth, defaultValue: null));
    properties.add(DiagnosticsProperty<bool>('enableFeedback', enableFeedback, defaultValue: null));
    properties.add(DiagnosticsProperty<MaterialStateProperty<MouseCursor?>>('mouseCursor', mouseCursor, defaultValue: null));
    properties.add(DiagnosticsProperty<VisualDensity>('visualDensity', visualDensity, defaultValue: null));
    properties.add(DiagnosticsProperty<ListTileTitleAlignment>('titleAlignment', titleAlignment, defaultValue: null));
  }
}

class ListTileTheme extends InheritedTheme {
  const ListTileTheme({
    super.key,
    ListTileThemeData? data,
    bool? dense,
    ShapeBorder? shape,
    ListTileStyle? style,
    Color? selectedColor,
    Color? iconColor,
    Color? textColor,
    EdgeInsetsGeometry? contentPadding,
    Color? tileColor,
    Color? selectedTileColor,
    bool? enableFeedback,
    MaterialStateProperty<MouseCursor?>? mouseCursor,
    double? horizontalTitleGap,
    double? minVerticalPadding,
    double? minLeadingWidth,
    required super.child,
  }) : assert(
         data == null ||
         (shape ??
          selectedColor ??
          iconColor ??
          textColor ??
          contentPadding ??
          tileColor ??
          selectedTileColor ??
          enableFeedback ??
          mouseCursor ??
          horizontalTitleGap ??
          minVerticalPadding ??
          minLeadingWidth) == null),
       _data = data,
       _dense = dense,
       _shape = shape,
       _style = style,
       _selectedColor = selectedColor,
       _iconColor = iconColor,
       _textColor = textColor,
       _contentPadding = contentPadding,
       _tileColor = tileColor,
       _selectedTileColor = selectedTileColor,
       _enableFeedback = enableFeedback,
       _mouseCursor = mouseCursor,
       _horizontalTitleGap = horizontalTitleGap,
       _minVerticalPadding = minVerticalPadding,
       _minLeadingWidth = minLeadingWidth;

  final ListTileThemeData? _data;
  final bool? _dense;
  final ShapeBorder? _shape;
  final ListTileStyle? _style;
  final Color? _selectedColor;
  final Color? _iconColor;
  final Color? _textColor;
  final EdgeInsetsGeometry? _contentPadding;
  final Color? _tileColor;
  final Color? _selectedTileColor;
  final double? _horizontalTitleGap;
  final double? _minVerticalPadding;
  final double? _minLeadingWidth;
  final bool? _enableFeedback;
  final MaterialStateProperty<MouseCursor?>? _mouseCursor;

  ListTileThemeData get data {
    return _data ?? ListTileThemeData(
      dense: _dense,
      shape: _shape,
      style: _style,
      selectedColor: _selectedColor,
      iconColor: _iconColor,
      textColor: _textColor,
      contentPadding: _contentPadding,
      tileColor: _tileColor,
      selectedTileColor: _selectedTileColor,
      enableFeedback: _enableFeedback,
      mouseCursor: _mouseCursor,
      horizontalTitleGap: _horizontalTitleGap,
      minVerticalPadding: _minVerticalPadding,
      minLeadingWidth: _minLeadingWidth,
    );
  }

  bool? get dense => _data != null ? _data.dense : _dense;

  ShapeBorder? get shape => _data != null ? _data.shape : _shape;

  ListTileStyle? get style => _data != null ? _data.style : _style;

  Color? get selectedColor => _data != null ? _data.selectedColor : _selectedColor;

  Color? get iconColor => _data != null ? _data.iconColor : _iconColor;

  Color? get textColor => _data != null ? _data.textColor : _textColor;

  EdgeInsetsGeometry? get contentPadding => _data != null ? _data.contentPadding : _contentPadding;

  Color? get tileColor => _data != null ? _data.tileColor : _tileColor;

  Color? get selectedTileColor => _data != null ? _data.selectedTileColor : _selectedTileColor;

  double? get horizontalTitleGap => _data != null ? _data.horizontalTitleGap : _horizontalTitleGap;

  double? get minVerticalPadding => _data != null ? _data.minVerticalPadding : _minVerticalPadding;

  double? get minLeadingWidth => _data != null ? _data.minLeadingWidth : _minLeadingWidth;

  bool? get enableFeedback => _data != null ? _data.enableFeedback : _enableFeedback;

  static ListTileThemeData of(BuildContext context) {
    final ListTileTheme? result = context.dependOnInheritedWidgetOfExactType<ListTileTheme>();
    return result?.data ?? Theme.of(context).listTileTheme;
  }

  static Widget merge({
    Key? key,
    bool? dense,
    ShapeBorder? shape,
    ListTileStyle? style,
    Color? selectedColor,
    Color? iconColor,
    Color? textColor,
    TextStyle? titleTextStyle,
    TextStyle? subtitleTextStyle,
    TextStyle? leadingAndTrailingTextStyle,
    EdgeInsetsGeometry? contentPadding,
    Color? tileColor,
    Color? selectedTileColor,
    bool? enableFeedback,
    double? horizontalTitleGap,
    double? minVerticalPadding,
    double? minLeadingWidth,
    ListTileTitleAlignment? titleAlignment,
    MaterialStateProperty<MouseCursor?>? mouseCursor,
    VisualDensity? visualDensity,
    required Widget child,
  }) {
    return Builder(
      builder: (BuildContext context) {
        final ListTileThemeData parent = ListTileTheme.of(context);
        return ListTileTheme(
          key: key,
          data: ListTileThemeData(
            dense: dense ?? parent.dense,
            shape: shape ?? parent.shape,
            style: style ?? parent.style,
            selectedColor: selectedColor ?? parent.selectedColor,
            iconColor: iconColor ?? parent.iconColor,
            textColor: textColor ?? parent.textColor,
            titleTextStyle: titleTextStyle ?? parent.titleTextStyle,
            subtitleTextStyle: subtitleTextStyle ?? parent.subtitleTextStyle,
            leadingAndTrailingTextStyle: leadingAndTrailingTextStyle ?? parent.leadingAndTrailingTextStyle,
            contentPadding: contentPadding ?? parent.contentPadding,
            tileColor: tileColor ?? parent.tileColor,
            selectedTileColor: selectedTileColor ?? parent.selectedTileColor,
            enableFeedback: enableFeedback ?? parent.enableFeedback,
            horizontalTitleGap: horizontalTitleGap ?? parent.horizontalTitleGap,
            minVerticalPadding: minVerticalPadding ?? parent.minVerticalPadding,
            minLeadingWidth: minLeadingWidth ?? parent.minLeadingWidth,
            titleAlignment: titleAlignment ?? parent.titleAlignment,
            mouseCursor: mouseCursor ?? parent.mouseCursor,
            visualDensity: visualDensity ?? parent.visualDensity,
          ),
          child: child,
        );
      },
    );
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return ListTileTheme(
      data: ListTileThemeData(
        dense: dense,
        shape: shape,
        style: style,
        selectedColor: selectedColor,
        iconColor: iconColor,
        textColor: textColor,
        contentPadding: contentPadding,
        tileColor: tileColor,
        selectedTileColor: selectedTileColor,
        enableFeedback: enableFeedback,
        horizontalTitleGap: horizontalTitleGap,
        minVerticalPadding: minVerticalPadding,
        minLeadingWidth: minLeadingWidth,
      ),
      child: child,
    );
  }

  @override
  bool updateShouldNotify(ListTileTheme oldWidget) => data != oldWidget.data;
}