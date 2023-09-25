
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'icon_theme_data.dart';
import 'text_theme.dart';

export 'package:flutter/foundation.dart' show Brightness;

// Values derived from https://developer.apple.com/design/resources/.
const _CupertinoThemeDefaults _kDefaultTheme = _CupertinoThemeDefaults(
  null,
  CupertinoColors.systemBlue,
  CupertinoColors.systemBackground,
  CupertinoDynamicColor.withBrightness(
    color: Color(0xF0F9F9F9),
    darkColor: Color(0xF01D1D1D),
    // Values extracted from navigation bar. For toolbar or tabbar the dark color is 0xF0161616.
  ),
  CupertinoColors.systemBackground,
  false,
  _CupertinoTextThemeDefaults(CupertinoColors.label, CupertinoColors.inactiveGray),
);

class CupertinoTheme extends StatelessWidget {
  const CupertinoTheme({
    super.key,
    required this.data,
    required this.child,
  });

  final CupertinoThemeData data;

  static CupertinoThemeData of(BuildContext context) {
    final _InheritedCupertinoTheme? inheritedTheme = context.dependOnInheritedWidgetOfExactType<_InheritedCupertinoTheme>();
    return (inheritedTheme?.theme.data ?? const CupertinoThemeData()).resolveFrom(context);
  }

  static Brightness brightnessOf(BuildContext context) {
    final _InheritedCupertinoTheme? inheritedTheme = context.dependOnInheritedWidgetOfExactType<_InheritedCupertinoTheme>();
    return inheritedTheme?.theme.data.brightness ?? MediaQuery.platformBrightnessOf(context);
  }

  static Brightness? maybeBrightnessOf(BuildContext context) {
    final _InheritedCupertinoTheme? inheritedTheme = context.dependOnInheritedWidgetOfExactType<_InheritedCupertinoTheme>();
    return inheritedTheme?.theme.data.brightness ?? MediaQuery.maybePlatformBrightnessOf(context);
  }

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _InheritedCupertinoTheme(
      theme: this,
      child: IconTheme(
        data: CupertinoIconThemeData(color: data.primaryColor),
        child: child,
      ),
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    data.debugFillProperties(properties);
  }
}

class _InheritedCupertinoTheme extends InheritedWidget {
  const _InheritedCupertinoTheme({
    required this.theme,
    required super.child,
  });

  final CupertinoTheme theme;

  @override
  bool updateShouldNotify(_InheritedCupertinoTheme old) => theme.data != old.theme.data;
}

@immutable
class CupertinoThemeData extends NoDefaultCupertinoThemeData with Diagnosticable {
  const CupertinoThemeData({
    Brightness? brightness,
    Color? primaryColor,
    Color? primaryContrastingColor,
    CupertinoTextThemeData? textTheme,
    Color? barBackgroundColor,
    Color? scaffoldBackgroundColor,
    bool? applyThemeToAll,
  }) : this.raw(
        brightness,
        primaryColor,
        primaryContrastingColor,
        textTheme,
        barBackgroundColor,
        scaffoldBackgroundColor,
        applyThemeToAll,
      );

  @protected
  const CupertinoThemeData.raw(
    Brightness? brightness,
    Color? primaryColor,
    Color? primaryContrastingColor,
    CupertinoTextThemeData? textTheme,
    Color? barBackgroundColor,
    Color? scaffoldBackgroundColor,
    bool? applyThemeToAll,
  ) : this._rawWithDefaults(
    brightness,
    primaryColor,
    primaryContrastingColor,
    textTheme,
    barBackgroundColor,
    scaffoldBackgroundColor,
    applyThemeToAll,
    _kDefaultTheme,
  );

  const CupertinoThemeData._rawWithDefaults(
    Brightness? brightness,
    Color? primaryColor,
    Color? primaryContrastingColor,
    CupertinoTextThemeData? textTheme,
    Color? barBackgroundColor,
    Color? scaffoldBackgroundColor,
    bool? applyThemeToAll,
    this._defaults,
  ) : super(
    brightness: brightness,
    primaryColor: primaryColor,
    primaryContrastingColor: primaryContrastingColor,
    textTheme: textTheme,
    barBackgroundColor: barBackgroundColor,
    scaffoldBackgroundColor: scaffoldBackgroundColor,
    applyThemeToAll: applyThemeToAll,
  );

  final _CupertinoThemeDefaults _defaults;

  @override
  Color get primaryColor => super.primaryColor ?? _defaults.primaryColor;

  @override
  Color get primaryContrastingColor => super.primaryContrastingColor ?? _defaults.primaryContrastingColor;

  @override
  CupertinoTextThemeData get textTheme {
    return super.textTheme ?? _defaults.textThemeDefaults.createDefaults(primaryColor: primaryColor);
  }

  @override
  Color get barBackgroundColor => super.barBackgroundColor ?? _defaults.barBackgroundColor;

  @override
  Color get scaffoldBackgroundColor => super.scaffoldBackgroundColor ?? _defaults.scaffoldBackgroundColor;

  @override
  bool get applyThemeToAll => super.applyThemeToAll ?? _defaults.applyThemeToAll;

  @override
  NoDefaultCupertinoThemeData noDefault() {
    return NoDefaultCupertinoThemeData(
      brightness: super.brightness,
      primaryColor: super.primaryColor,
      primaryContrastingColor: super.primaryContrastingColor,
      textTheme: super.textTheme,
      barBackgroundColor: super.barBackgroundColor,
      scaffoldBackgroundColor: super.scaffoldBackgroundColor,
      applyThemeToAll: super.applyThemeToAll,
    );
  }

  @override
  CupertinoThemeData resolveFrom(BuildContext context) {
    Color? convertColor(Color? color) => CupertinoDynamicColor.maybeResolve(color, context);

    return CupertinoThemeData._rawWithDefaults(
      brightness,
      convertColor(super.primaryColor),
      convertColor(super.primaryContrastingColor),
      super.textTheme?.resolveFrom(context),
      convertColor(super.barBackgroundColor),
      convertColor(super.scaffoldBackgroundColor),
      applyThemeToAll,
      _defaults.resolveFrom(context, super.textTheme == null),
    );
  }

  @override
  CupertinoThemeData copyWith({
    Brightness? brightness,
    Color? primaryColor,
    Color? primaryContrastingColor,
    CupertinoTextThemeData? textTheme,
    Color? barBackgroundColor,
    Color? scaffoldBackgroundColor,
    bool? applyThemeToAll,
  }) {
    return CupertinoThemeData._rawWithDefaults(
      brightness ?? super.brightness,
      primaryColor ?? super.primaryColor,
      primaryContrastingColor ?? super.primaryContrastingColor,
      textTheme ?? super.textTheme,
      barBackgroundColor ?? super.barBackgroundColor,
      scaffoldBackgroundColor ?? super.scaffoldBackgroundColor,
      applyThemeToAll ?? super.applyThemeToAll,
      _defaults,
    );
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    const CupertinoThemeData defaultData = CupertinoThemeData();
    properties.add(EnumProperty<Brightness>('brightness', brightness, defaultValue: null));
    properties.add(createCupertinoColorProperty('primaryColor', primaryColor, defaultValue: defaultData.primaryColor));
    properties.add(createCupertinoColorProperty('primaryContrastingColor', primaryContrastingColor, defaultValue: defaultData.primaryContrastingColor));
    properties.add(createCupertinoColorProperty('barBackgroundColor', barBackgroundColor, defaultValue: defaultData.barBackgroundColor));
    properties.add(createCupertinoColorProperty('scaffoldBackgroundColor', scaffoldBackgroundColor, defaultValue: defaultData.scaffoldBackgroundColor));
    properties.add(DiagnosticsProperty<bool>('applyThemeToAll', applyThemeToAll, defaultValue: defaultData.applyThemeToAll));
    textTheme.debugFillProperties(properties);
  }

  @override
  bool operator == (Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is CupertinoThemeData
      && other.brightness == brightness
      && other.primaryColor == primaryColor
      && other.primaryContrastingColor == primaryContrastingColor
      && other.textTheme == textTheme
      && other.barBackgroundColor == barBackgroundColor
      && other.scaffoldBackgroundColor == scaffoldBackgroundColor
      && other.applyThemeToAll == applyThemeToAll;
  }

  @override
  int get hashCode => Object.hash(
    brightness,
    primaryColor,
    primaryContrastingColor,
    textTheme,
    barBackgroundColor,
    scaffoldBackgroundColor,
    applyThemeToAll,
  );
}

class NoDefaultCupertinoThemeData {
  const NoDefaultCupertinoThemeData({
    this.brightness,
    this.primaryColor,
    this.primaryContrastingColor,
    this.textTheme,
    this.barBackgroundColor,
    this.scaffoldBackgroundColor,
    this.applyThemeToAll,
  });

  final Brightness? brightness;

  final Color? primaryColor;

  final Color? primaryContrastingColor;

  final CupertinoTextThemeData? textTheme;

  final Color? barBackgroundColor;

  final Color? scaffoldBackgroundColor;

  final bool? applyThemeToAll;

  NoDefaultCupertinoThemeData noDefault() => this;

  @protected
  NoDefaultCupertinoThemeData resolveFrom(BuildContext context) {
    Color? convertColor(Color? color) => CupertinoDynamicColor.maybeResolve(color, context);

    return NoDefaultCupertinoThemeData(
      brightness: brightness,
      primaryColor: convertColor(primaryColor),
      primaryContrastingColor: convertColor(primaryContrastingColor),
      textTheme: textTheme?.resolveFrom(context),
      barBackgroundColor: convertColor(barBackgroundColor),
      scaffoldBackgroundColor: convertColor(scaffoldBackgroundColor),
      applyThemeToAll: applyThemeToAll,
    );
  }

  NoDefaultCupertinoThemeData copyWith({
    Brightness? brightness,
    Color? primaryColor,
    Color? primaryContrastingColor,
    CupertinoTextThemeData? textTheme,
    Color? barBackgroundColor ,
    Color? scaffoldBackgroundColor,
    bool? applyThemeToAll,
  }) {
    return NoDefaultCupertinoThemeData(
      brightness: brightness ?? this.brightness,
      primaryColor: primaryColor ?? this.primaryColor,
      primaryContrastingColor: primaryContrastingColor ?? this.primaryContrastingColor,
      textTheme: textTheme ?? this.textTheme,
      barBackgroundColor: barBackgroundColor ?? this.barBackgroundColor,
      scaffoldBackgroundColor: scaffoldBackgroundColor ?? this.scaffoldBackgroundColor,
      applyThemeToAll: applyThemeToAll ?? this.applyThemeToAll,
    );
  }
}

@immutable
class _CupertinoThemeDefaults {
  const _CupertinoThemeDefaults(
    this.brightness,
    this.primaryColor,
    this.primaryContrastingColor,
    this.barBackgroundColor,
    this.scaffoldBackgroundColor,
    this.applyThemeToAll,
    this.textThemeDefaults,
  );

  final Brightness? brightness;
  final Color primaryColor;
  final Color primaryContrastingColor;
  final Color barBackgroundColor;
  final Color scaffoldBackgroundColor;
  final bool applyThemeToAll;
  final _CupertinoTextThemeDefaults textThemeDefaults;

  _CupertinoThemeDefaults resolveFrom(BuildContext context, bool resolveTextTheme) {
    Color convertColor(Color color) => CupertinoDynamicColor.resolve(color, context);

    return _CupertinoThemeDefaults(
      brightness,
      convertColor(primaryColor),
      convertColor(primaryContrastingColor),
      convertColor(barBackgroundColor),
      convertColor(scaffoldBackgroundColor),
      applyThemeToAll,
      resolveTextTheme ? textThemeDefaults.resolveFrom(context) : textThemeDefaults,
    );
  }
}

@immutable
class _CupertinoTextThemeDefaults {
  const _CupertinoTextThemeDefaults(
    this.labelColor,
    this.inactiveGray,
  );

  final Color labelColor;
  final Color inactiveGray;

  _CupertinoTextThemeDefaults resolveFrom(BuildContext context) {
    return _CupertinoTextThemeDefaults(
      CupertinoDynamicColor.resolve(labelColor, context),
      CupertinoDynamicColor.resolve(inactiveGray, context),
    );
  }

  CupertinoTextThemeData createDefaults({ required Color primaryColor }) {
    return _DefaultCupertinoTextThemeData(
      primaryColor: primaryColor,
      labelColor: labelColor,
      inactiveGray: inactiveGray,
    );
  }
}

// CupertinoTextThemeData with no text styles explicitly specified.
// The implementation of this class may need to be updated when any of the default
// text styles changes.
class _DefaultCupertinoTextThemeData extends CupertinoTextThemeData {
  const _DefaultCupertinoTextThemeData({
    required this.labelColor,
    required this.inactiveGray,
    required super.primaryColor,
  });

  final Color labelColor;
  final Color inactiveGray;

  @override
  TextStyle get textStyle => super.textStyle.copyWith(color: labelColor);

  @override
  TextStyle get tabLabelTextStyle => super.tabLabelTextStyle.copyWith(color: inactiveGray);

  @override
  TextStyle get navTitleTextStyle => super.navTitleTextStyle.copyWith(color: labelColor);

  @override
  TextStyle get navLargeTitleTextStyle => super.navLargeTitleTextStyle.copyWith(color: labelColor);

  @override
  TextStyle get pickerTextStyle => super.pickerTextStyle.copyWith(color: labelColor);

  @override
  TextStyle get dateTimePickerTextStyle => super.dateTimePickerTextStyle.copyWith(color: labelColor);
}