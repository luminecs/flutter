import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'typography.dart';

@immutable
class TextTheme with Diagnosticable {
  const TextTheme({
    TextStyle? displayLarge,
    TextStyle? displayMedium,
    TextStyle? displaySmall,
    this.headlineLarge,
    TextStyle? headlineMedium,
    TextStyle? headlineSmall,
    TextStyle? titleLarge,
    TextStyle? titleMedium,
    TextStyle? titleSmall,
    TextStyle? bodyLarge,
    TextStyle? bodyMedium,
    TextStyle? bodySmall,
    TextStyle? labelLarge,
    this.labelMedium,
    TextStyle? labelSmall,
    @Deprecated(
      'Use displayLarge instead. '
      'This feature was deprecated after v3.1.0-0.0.pre.',
    )
    TextStyle? headline1,
    @Deprecated(
      'Use displayMedium instead. '
      'This feature was deprecated after v3.1.0-0.0.pre.',
    )
    TextStyle? headline2,
    @Deprecated(
      'Use displaySmall instead. '
      'This feature was deprecated after v3.1.0-0.0.pre.',
    )
    TextStyle? headline3,
    @Deprecated(
      'Use headlineMedium instead. '
      'This feature was deprecated after v3.1.0-0.0.pre.',
    )
    TextStyle? headline4,
    @Deprecated(
      'Use headlineSmall instead. '
      'This feature was deprecated after v3.1.0-0.0.pre.',
    )
    TextStyle? headline5,
    @Deprecated(
      'Use titleLarge instead. '
      'This feature was deprecated after v3.1.0-0.0.pre.',
    )
    TextStyle? headline6,
    @Deprecated(
      'Use titleMedium instead. '
      'This feature was deprecated after v3.1.0-0.0.pre.',
    )
    TextStyle? subtitle1,
    @Deprecated(
      'Use titleSmall instead. '
      'This feature was deprecated after v3.1.0-0.0.pre.',
    )
    TextStyle? subtitle2,
    @Deprecated(
      'Use bodyLarge instead. '
      'This feature was deprecated after v3.1.0-0.0.pre.',
    )
    TextStyle? bodyText1,
    @Deprecated(
      'Use bodyMedium instead. '
      'This feature was deprecated after v3.1.0-0.0.pre.',
    )
    TextStyle? bodyText2,
    @Deprecated(
      'Use bodySmall instead. '
      'This feature was deprecated after v3.1.0-0.0.pre.',
    )
    TextStyle? caption,
    @Deprecated(
      'Use labelLarge instead. '
      'This feature was deprecated after v3.1.0-0.0.pre.',
    )
    TextStyle? button,
    @Deprecated(
      'Use labelSmall instead. '
      'This feature was deprecated after v3.1.0-0.0.pre.',
    )
    TextStyle? overline,
  }) : assert(
         (displayLarge == null && displayMedium == null && displaySmall == null && headlineMedium == null &&
             headlineSmall == null && titleLarge == null && titleMedium == null && titleSmall == null &&
             bodyLarge == null && bodyMedium == null && bodySmall == null && labelLarge == null && labelSmall == null) ||
         (headline1 == null && headline2 == null && headline3 == null && headline4 == null &&
             headline5 == null && headline6 == null && subtitle1 == null && subtitle2 == null &&
             bodyText1 == null && bodyText2 == null && caption == null && button == null && overline == null),
         'Cannot mix 2018 and 2021 terms in call to TextTheme() constructor.'
       ),
       displayLarge = displayLarge ?? headline1,
       displayMedium = displayMedium ?? headline2,
       displaySmall = displaySmall ?? headline3,
       headlineMedium = headlineMedium ?? headline4,
       headlineSmall = headlineSmall ?? headline5,
       titleLarge = titleLarge ?? headline6,
       titleMedium = titleMedium ?? subtitle1,
       titleSmall = titleSmall ?? subtitle2,
       bodyLarge = bodyLarge ?? bodyText1,
       bodyMedium = bodyMedium ?? bodyText2,
       bodySmall = bodySmall ?? caption,
       labelLarge = labelLarge ?? button,
       labelSmall = labelSmall ?? overline;

  final TextStyle? displayLarge;

  final TextStyle? displayMedium;

  final TextStyle? displaySmall;

  final TextStyle? headlineLarge;

  final TextStyle? headlineMedium;

  final TextStyle? headlineSmall;

  final TextStyle? titleLarge;

  final TextStyle? titleMedium;

  final TextStyle? titleSmall;

  final TextStyle? bodyLarge;

  final TextStyle? bodyMedium;

  final TextStyle? bodySmall;

  final TextStyle? labelLarge;

  final TextStyle? labelMedium;

  final TextStyle? labelSmall;

  @Deprecated(
    'Use displayLarge instead. '
    'This feature was deprecated after v3.1.0-0.0.pre.',
  )
  TextStyle? get headline1 => displayLarge;

  @Deprecated(
    'Use displayMedium instead. '
    'This feature was deprecated after v3.1.0-0.0.pre.',
  )
  TextStyle? get headline2 => displayMedium;

  @Deprecated(
    'Use displaySmall instead. '
    'This feature was deprecated after v3.1.0-0.0.pre.',
  )
  TextStyle? get headline3 => displaySmall;

  @Deprecated(
    'Use headlineMedium instead. '
    'This feature was deprecated after v3.1.0-0.0.pre.',
  )
  TextStyle? get headline4 => headlineMedium;

  @Deprecated(
    'Use headlineSmall instead. '
    'This feature was deprecated after v3.1.0-0.0.pre.',
  )
  TextStyle? get headline5 => headlineSmall;

  @Deprecated(
    'Use titleLarge instead. '
    'This feature was deprecated after v3.1.0-0.0.pre.',
  )
  TextStyle? get headline6 => titleLarge;

  @Deprecated(
    'Use titleMedium instead. '
    'This feature was deprecated after v3.1.0-0.0.pre.',
  )
  TextStyle? get subtitle1 => titleMedium;

  @Deprecated(
    'Use titleSmall instead. '
    'This feature was deprecated after v3.1.0-0.0.pre.',
  )
  TextStyle? get subtitle2 => titleSmall;

  @Deprecated(
    'Use bodyLarge instead. '
    'This feature was deprecated after v3.1.0-0.0.pre.',
  )
  TextStyle? get bodyText1 => bodyLarge;

  @Deprecated(
    'Use bodyMedium instead. '
    'This feature was deprecated after v3.1.0-0.0.pre.',
  )
  TextStyle? get bodyText2 => bodyMedium;

  @Deprecated(
    'Use bodySmall instead. '
    'This feature was deprecated after v3.1.0-0.0.pre.',
  )
  TextStyle? get caption => bodySmall;

  @Deprecated(
    'Use labelLarge instead. '
    'This feature was deprecated after v3.1.0-0.0.pre.',
  )
  TextStyle? get button => labelLarge;

  @Deprecated(
    'Use labelSmall instead. '
    'This feature was deprecated after v3.1.0-0.0.pre.',
  )
  TextStyle? get overline => labelSmall;

  TextTheme copyWith({
    TextStyle? displayLarge,
    TextStyle? displayMedium,
    TextStyle? displaySmall,
    TextStyle? headlineLarge,
    TextStyle? headlineMedium,
    TextStyle? headlineSmall,
    TextStyle? titleLarge,
    TextStyle? titleMedium,
    TextStyle? titleSmall,
    TextStyle? bodyLarge,
    TextStyle? bodyMedium,
    TextStyle? bodySmall,
    TextStyle? labelLarge,
    TextStyle? labelMedium,
    TextStyle? labelSmall,
    @Deprecated(
      'Use displayLarge instead. '
      'This feature was deprecated after v3.1.0-0.0.pre.',
    )
    TextStyle? headline1,
    @Deprecated(
      'Use displayMedium instead. '
      'This feature was deprecated after v3.1.0-0.0.pre.',
    )
    TextStyle? headline2,
    @Deprecated(
      'Use displaySmall instead. '
      'This feature was deprecated after v3.1.0-0.0.pre.',
    )
    TextStyle? headline3,
    @Deprecated(
      'Use headlineMedium instead. '
      'This feature was deprecated after v3.1.0-0.0.pre.',
    )
    TextStyle? headline4,
    @Deprecated(
      'Use headlineSmall instead. '
      'This feature was deprecated after v3.1.0-0.0.pre.',
    )
    TextStyle? headline5,
    @Deprecated(
      'Use titleLarge instead. '
      'This feature was deprecated after v3.1.0-0.0.pre.',
    )
    TextStyle? headline6,
    @Deprecated(
      'Use titleMedium instead. '
      'This feature was deprecated after v3.1.0-0.0.pre.',
    )
    TextStyle? subtitle1,
    @Deprecated(
      'Use titleSmall instead. '
      'This feature was deprecated after v3.1.0-0.0.pre.',
    )
    TextStyle? subtitle2,
    @Deprecated(
      'Use bodyLarge instead. '
      'This feature was deprecated after v3.1.0-0.0.pre.',
    )
    TextStyle? bodyText1,
    @Deprecated(
      'Use bodyMedium instead. '
      'This feature was deprecated after v3.1.0-0.0.pre.',
    )
    TextStyle? bodyText2,
    @Deprecated(
      'Use bodySmall instead. '
      'This feature was deprecated after v3.1.0-0.0.pre.',
    )
    TextStyle? caption,
    @Deprecated(
      'Use labelLarge instead. '
      'This feature was deprecated after v3.1.0-0.0.pre.',
    )
    TextStyle? button,
    @Deprecated(
      'Use labelSmall instead. '
      'This feature was deprecated after v3.1.0-0.0.pre.',
    )
    TextStyle? overline,
  }) {
    assert(
      (displayLarge == null && displayMedium == null && displaySmall == null && headlineMedium == null &&
          headlineSmall == null && titleLarge == null && titleMedium == null && titleSmall == null &&
          bodyLarge == null && bodyMedium == null && bodySmall == null && labelLarge == null && labelSmall == null) ||
      (headline1 == null && headline2 == null && headline3 == null && headline4 == null &&
          headline5 == null && headline6 == null && subtitle1 == null && subtitle2 == null &&
          bodyText1 == null && bodyText2 == null && caption == null && button == null && overline == null),
      'Cannot mix 2018 and 2021 terms in call to TextTheme() constructor.'
    );
    return TextTheme(
      displayLarge: displayLarge ?? headline1 ?? this.displayLarge,
      displayMedium: displayMedium ?? headline2 ?? this.displayMedium,
      displaySmall: displaySmall ?? headline3 ?? this.displaySmall,
      headlineLarge: headlineLarge ?? this.headlineLarge,
      headlineMedium: headlineMedium ?? headline4 ?? this.headlineMedium,
      headlineSmall: headlineSmall ?? headline5 ?? this.headlineSmall,
      titleLarge: titleLarge ?? headline6 ?? this.titleLarge,
      titleMedium: titleMedium ?? subtitle1 ?? this.titleMedium,
      titleSmall: titleSmall ?? subtitle2 ?? this.titleSmall,
      bodyLarge: bodyLarge ?? bodyText1 ?? this.bodyLarge,
      bodyMedium: bodyMedium ?? bodyText2 ?? this.bodyMedium,
      bodySmall: bodySmall ?? caption ?? this.bodySmall,
      labelLarge: labelLarge ?? button ?? this.labelLarge,
      labelMedium: labelMedium ?? this.labelMedium,
      labelSmall: labelSmall ?? overline ?? this.labelSmall,
    );
  }

  TextTheme merge(TextTheme? other) {
    if (other == null) {
      return this;
    }
    return copyWith(
      displayLarge: displayLarge?.merge(other.displayLarge) ?? other.displayLarge,
      displayMedium: displayMedium?.merge(other.displayMedium) ?? other.displayMedium,
      displaySmall: displaySmall?.merge(other.displaySmall) ?? other.displaySmall,
      headlineLarge: headlineLarge?.merge(other.headlineLarge) ?? other.headlineLarge,
      headlineMedium: headlineMedium?.merge(other.headlineMedium) ?? other.headlineMedium,
      headlineSmall: headlineSmall?.merge(other.headlineSmall) ?? other.headlineSmall,
      titleLarge: titleLarge?.merge(other.titleLarge) ?? other.titleLarge,
      titleMedium: titleMedium?.merge(other.titleMedium) ?? other.titleMedium,
      titleSmall: titleSmall?.merge(other.titleSmall) ?? other.titleSmall,
      bodyLarge: bodyLarge?.merge(other.bodyLarge) ?? other.bodyLarge,
      bodyMedium: bodyMedium?.merge(other.bodyMedium) ?? other.bodyMedium,
      bodySmall: bodySmall?.merge(other.bodySmall) ?? other.bodySmall,
      labelLarge: labelLarge?.merge(other.labelLarge) ?? other.labelLarge,
      labelMedium: labelMedium?.merge(other.labelMedium) ?? other.labelMedium,
      labelSmall: labelSmall?.merge(other.labelSmall) ?? other.labelSmall,
    );
  }

  TextTheme apply({
    String? fontFamily,
    List<String>? fontFamilyFallback,
    String? package,
    double fontSizeFactor = 1.0,
    double fontSizeDelta = 0.0,
    Color? displayColor,
    Color? bodyColor,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
  }) {
    return TextTheme(
      displayLarge: displayLarge?.apply(
        color: displayColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      displayMedium: displayMedium?.apply(
        color: displayColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      displaySmall: displaySmall?.apply(
        color: displayColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      headlineLarge: headlineLarge?.apply(
        color: displayColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      headlineMedium: headlineMedium?.apply(
        color: displayColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      headlineSmall: headlineSmall?.apply(
        color: bodyColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      titleLarge: titleLarge?.apply(
        color: bodyColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      titleMedium: titleMedium?.apply(
        color: bodyColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      titleSmall: titleSmall?.apply(
        color: bodyColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      bodyLarge: bodyLarge?.apply(
        color: bodyColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      bodyMedium: bodyMedium?.apply(
        color: bodyColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      bodySmall: bodySmall?.apply(
        color: displayColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      labelLarge: labelLarge?.apply(
        color: bodyColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      labelMedium: labelMedium?.apply(
        color: bodyColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
      labelSmall: labelSmall?.apply(
        color: bodyColor,
        decoration: decoration,
        decorationColor: decorationColor,
        decorationStyle: decorationStyle,
        fontFamily: fontFamily,
        fontFamilyFallback: fontFamilyFallback,
        fontSizeFactor: fontSizeFactor,
        fontSizeDelta: fontSizeDelta,
        package: package,
      ),
    );
  }

  static TextTheme lerp(TextTheme? a, TextTheme? b, double t) {
    if (identical(a, b) && a != null) {
      return a;
    }
    return TextTheme(
      displayLarge: TextStyle.lerp(a?.displayLarge, b?.displayLarge, t),
      displayMedium: TextStyle.lerp(a?.displayMedium, b?.displayMedium, t),
      displaySmall: TextStyle.lerp(a?.displaySmall, b?.displaySmall, t),
      headlineLarge: TextStyle.lerp(a?.headlineLarge, b?.headlineLarge, t),
      headlineMedium: TextStyle.lerp(a?.headlineMedium, b?.headlineMedium, t),
      headlineSmall: TextStyle.lerp(a?.headlineSmall, b?.headlineSmall, t),
      titleLarge: TextStyle.lerp(a?.titleLarge, b?.titleLarge, t),
      titleMedium: TextStyle.lerp(a?.titleMedium, b?.titleMedium, t),
      titleSmall: TextStyle.lerp(a?.titleSmall, b?.titleSmall, t),
      bodyLarge: TextStyle.lerp(a?.bodyLarge, b?.bodyLarge, t),
      bodyMedium: TextStyle.lerp(a?.bodyMedium, b?.bodyMedium, t),
      bodySmall: TextStyle.lerp(a?.bodySmall, b?.bodySmall, t),
      labelLarge: TextStyle.lerp(a?.labelLarge, b?.labelLarge, t),
      labelMedium: TextStyle.lerp(a?.labelMedium, b?.labelMedium, t),
      labelSmall: TextStyle.lerp(a?.labelSmall, b?.labelSmall, t),
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
    return other is TextTheme
      && displayLarge == other.displayLarge
      && displayMedium == other.displayMedium
      && displaySmall == other.displaySmall
      && headlineLarge == other.headlineLarge
      && headlineMedium == other.headlineMedium
      && headlineSmall == other.headlineSmall
      && titleLarge == other.titleLarge
      && titleMedium == other.titleMedium
      && titleSmall == other.titleSmall
      && bodyLarge == other.bodyLarge
      && bodyMedium == other.bodyMedium
      && bodySmall == other.bodySmall
      && labelLarge == other.labelLarge
      && labelMedium == other.labelMedium
      && labelSmall == other.labelSmall;
  }

  @override
  int get hashCode => Object.hash(
    displayLarge,
    displayMedium,
    displaySmall,
    headlineLarge,
    headlineMedium,
    headlineSmall,
    titleLarge,
    titleMedium,
    titleSmall,
    bodyLarge,
    bodyMedium,
    bodySmall,
    labelLarge,
    labelMedium,
    labelSmall,
  );

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    final TextTheme defaultTheme = Typography.material2018(platform: defaultTargetPlatform).black;
    properties.add(DiagnosticsProperty<TextStyle>('displayLarge', displayLarge, defaultValue: defaultTheme.displayLarge));
    properties.add(DiagnosticsProperty<TextStyle>('displayMedium', displayMedium, defaultValue: defaultTheme.displayMedium));
    properties.add(DiagnosticsProperty<TextStyle>('displaySmall', displaySmall, defaultValue: defaultTheme.displaySmall));
    properties.add(DiagnosticsProperty<TextStyle>('headlineLarge', headlineLarge, defaultValue: defaultTheme.headlineLarge));
    properties.add(DiagnosticsProperty<TextStyle>('headlineMedium', headlineMedium, defaultValue: defaultTheme.headlineMedium));
    properties.add(DiagnosticsProperty<TextStyle>('headlineSmall', headlineSmall, defaultValue: defaultTheme.headlineSmall));
    properties.add(DiagnosticsProperty<TextStyle>('titleLarge', titleLarge, defaultValue: defaultTheme.titleLarge));
    properties.add(DiagnosticsProperty<TextStyle>('titleMedium', titleMedium, defaultValue: defaultTheme.titleMedium));
    properties.add(DiagnosticsProperty<TextStyle>('titleSmall', titleSmall, defaultValue: defaultTheme.titleSmall));
    properties.add(DiagnosticsProperty<TextStyle>('bodyLarge', bodyLarge, defaultValue: defaultTheme.bodyLarge));
    properties.add(DiagnosticsProperty<TextStyle>('bodyMedium', bodyMedium, defaultValue: defaultTheme.bodyMedium));
    properties.add(DiagnosticsProperty<TextStyle>('bodySmall', bodySmall, defaultValue: defaultTheme.bodySmall));
    properties.add(DiagnosticsProperty<TextStyle>('labelLarge', labelLarge, defaultValue: defaultTheme.labelLarge));
    properties.add(DiagnosticsProperty<TextStyle>('labelMedium', labelMedium, defaultValue: defaultTheme.labelMedium));
    properties.add(DiagnosticsProperty<TextStyle>('labelSmall', labelSmall, defaultValue: defaultTheme.labelSmall));
  }
}