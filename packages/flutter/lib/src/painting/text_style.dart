import 'dart:ui' as ui
    show
        FontFeature,
        FontVariation,
        ParagraphStyle,
        Shadow,
        StrutStyle,
        TextHeightBehavior,
        TextLeadingDistribution,
        TextStyle,
        lerpDouble;

import 'package:flutter/foundation.dart';

import 'basic_types.dart';
import 'colors.dart';
import 'strut_style.dart';
import 'text_painter.dart';
import 'text_scaler.dart';

const String _kDefaultDebugLabel = 'unknown';

const String _kColorForegroundWarning =
    'Cannot provide both a color and a foreground\n'
    'The color argument is just a shorthand for "foreground: Paint()..color = color".';

const String _kColorBackgroundWarning =
    'Cannot provide both a backgroundColor and a background\n'
    'The backgroundColor argument is just a shorthand for "background: Paint()..color = color".';

// The default font size if none is specified. This should be kept in
// sync with the default values in text_painter.dart, as well as the
// defaults set in the engine (eg, LibTxt's text_style.h, paragraph_style.h).
const double _kDefaultFontSize = 14.0;

// Examples can assume:
// late BuildContext context;

//
// The implementation of these defaults can be found in:
// /packages/flutter/lib/src/material/typography.dart
@immutable
class TextStyle with Diagnosticable {
  const TextStyle({
    this.inherit = true,
    this.color,
    this.backgroundColor,
    this.fontSize,
    this.fontWeight,
    this.fontStyle,
    this.letterSpacing,
    this.wordSpacing,
    this.textBaseline,
    this.height,
    this.leadingDistribution,
    this.locale,
    this.foreground,
    this.background,
    this.shadows,
    this.fontFeatures,
    this.fontVariations,
    this.decoration,
    this.decorationColor,
    this.decorationStyle,
    this.decorationThickness,
    this.debugLabel,
    String? fontFamily,
    List<String>? fontFamilyFallback,
    String? package,
    this.overflow,
  })  : fontFamily =
            package == null ? fontFamily : 'packages/$package/$fontFamily',
        _fontFamilyFallback = fontFamilyFallback,
        _package = package,
        assert(color == null || foreground == null, _kColorForegroundWarning),
        assert(backgroundColor == null || background == null,
            _kColorBackgroundWarning);

  final bool inherit;

  final Color? color;

  final Color? backgroundColor;

  final String? fontFamily;

  List<String>? get fontFamilyFallback => _package == null
      ? _fontFamilyFallback
      : _fontFamilyFallback
          ?.map((String str) => 'packages/$_package/$str')
          .toList();
  final List<String>? _fontFamilyFallback;

  // This is stored in order to prefix the fontFamilies in _fontFamilyFallback
  // in the [fontFamilyFallback] getter.
  final String? _package;

  final double? fontSize;

  final FontWeight? fontWeight;

  final FontStyle? fontStyle;

  final double? letterSpacing;

  final double? wordSpacing;

  final TextBaseline? textBaseline;

  final double? height;

  final ui.TextLeadingDistribution? leadingDistribution;

  final Locale? locale;

  final Paint? foreground;

  final Paint? background;

  final TextDecoration? decoration;

  final Color? decorationColor;

  final TextDecorationStyle? decorationStyle;

  final double? decorationThickness;

  final String? debugLabel;

  final List<ui.Shadow>? shadows;

  final List<ui.FontFeature>? fontFeatures;

  final List<ui.FontVariation>? fontVariations;

  final TextOverflow? overflow;

  // Return the original value of fontFamily, without the additional
  // "packages/$_package/" prefix.
  String? get _fontFamily {
    if (_package != null) {
      final String fontFamilyPrefix = 'packages/$_package/';
      assert(fontFamily?.startsWith(fontFamilyPrefix) ?? true);
      return fontFamily?.substring(fontFamilyPrefix.length);
    }
    return fontFamily;
  }

  TextStyle copyWith({
    bool? inherit,
    Color? color,
    Color? backgroundColor,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? letterSpacing,
    double? wordSpacing,
    TextBaseline? textBaseline,
    double? height,
    ui.TextLeadingDistribution? leadingDistribution,
    Locale? locale,
    Paint? foreground,
    Paint? background,
    List<ui.Shadow>? shadows,
    List<ui.FontFeature>? fontFeatures,
    List<ui.FontVariation>? fontVariations,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double? decorationThickness,
    String? debugLabel,
    String? fontFamily,
    List<String>? fontFamilyFallback,
    String? package,
    TextOverflow? overflow,
  }) {
    assert(color == null || foreground == null, _kColorForegroundWarning);
    assert(backgroundColor == null || background == null,
        _kColorBackgroundWarning);
    String? newDebugLabel;
    assert(() {
      if (this.debugLabel != null) {
        newDebugLabel = debugLabel ?? '(${this.debugLabel}).copyWith';
      }
      return true;
    }());

    return TextStyle(
      inherit: inherit ?? this.inherit,
      color: this.foreground == null && foreground == null
          ? color ?? this.color
          : null,
      backgroundColor: this.background == null && background == null
          ? backgroundColor ?? this.backgroundColor
          : null,
      fontSize: fontSize ?? this.fontSize,
      fontWeight: fontWeight ?? this.fontWeight,
      fontStyle: fontStyle ?? this.fontStyle,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      wordSpacing: wordSpacing ?? this.wordSpacing,
      textBaseline: textBaseline ?? this.textBaseline,
      height: height ?? this.height,
      leadingDistribution: leadingDistribution ?? this.leadingDistribution,
      locale: locale ?? this.locale,
      foreground: foreground ?? this.foreground,
      background: background ?? this.background,
      shadows: shadows ?? this.shadows,
      fontFeatures: fontFeatures ?? this.fontFeatures,
      fontVariations: fontVariations ?? this.fontVariations,
      decoration: decoration ?? this.decoration,
      decorationColor: decorationColor ?? this.decorationColor,
      decorationStyle: decorationStyle ?? this.decorationStyle,
      decorationThickness: decorationThickness ?? this.decorationThickness,
      debugLabel: newDebugLabel,
      fontFamily: fontFamily ?? _fontFamily,
      fontFamilyFallback: fontFamilyFallback ?? _fontFamilyFallback,
      package: package ?? _package,
      overflow: overflow ?? this.overflow,
    );
  }

  TextStyle apply({
    Color? color,
    Color? backgroundColor,
    TextDecoration? decoration,
    Color? decorationColor,
    TextDecorationStyle? decorationStyle,
    double decorationThicknessFactor = 1.0,
    double decorationThicknessDelta = 0.0,
    String? fontFamily,
    List<String>? fontFamilyFallback,
    double fontSizeFactor = 1.0,
    double fontSizeDelta = 0.0,
    int fontWeightDelta = 0,
    FontStyle? fontStyle,
    double letterSpacingFactor = 1.0,
    double letterSpacingDelta = 0.0,
    double wordSpacingFactor = 1.0,
    double wordSpacingDelta = 0.0,
    double heightFactor = 1.0,
    double heightDelta = 0.0,
    TextBaseline? textBaseline,
    ui.TextLeadingDistribution? leadingDistribution,
    Locale? locale,
    List<ui.Shadow>? shadows,
    List<ui.FontFeature>? fontFeatures,
    List<ui.FontVariation>? fontVariations,
    String? package,
    TextOverflow? overflow,
  }) {
    assert(fontSize != null || (fontSizeFactor == 1.0 && fontSizeDelta == 0.0));
    assert(fontWeight != null || fontWeightDelta == 0.0);
    assert(letterSpacing != null ||
        (letterSpacingFactor == 1.0 && letterSpacingDelta == 0.0));
    assert(wordSpacing != null ||
        (wordSpacingFactor == 1.0 && wordSpacingDelta == 0.0));
    assert(decorationThickness != null ||
        (decorationThicknessFactor == 1.0 && decorationThicknessDelta == 0.0));

    String? modifiedDebugLabel;
    assert(() {
      if (debugLabel != null) {
        modifiedDebugLabel = '($debugLabel).apply';
      }
      return true;
    }());

    return TextStyle(
      inherit: inherit,
      color: foreground == null ? color ?? this.color : null,
      backgroundColor:
          background == null ? backgroundColor ?? this.backgroundColor : null,
      fontFamily: fontFamily ?? _fontFamily,
      fontFamilyFallback: fontFamilyFallback ?? _fontFamilyFallback,
      fontSize:
          fontSize == null ? null : fontSize! * fontSizeFactor + fontSizeDelta,
      fontWeight: fontWeight == null
          ? null
          : FontWeight.values[(fontWeight!.index + fontWeightDelta).clamp(
              0, FontWeight.values.length - 1)], // ignore_clamp_double_lint
      fontStyle: fontStyle ?? this.fontStyle,
      letterSpacing: letterSpacing == null
          ? null
          : letterSpacing! * letterSpacingFactor + letterSpacingDelta,
      wordSpacing: wordSpacing == null
          ? null
          : wordSpacing! * wordSpacingFactor + wordSpacingDelta,
      textBaseline: textBaseline ?? this.textBaseline,
      height: height == null ? null : height! * heightFactor + heightDelta,
      leadingDistribution: leadingDistribution ?? this.leadingDistribution,
      locale: locale ?? this.locale,
      foreground: foreground,
      background: background,
      shadows: shadows ?? this.shadows,
      fontFeatures: fontFeatures ?? this.fontFeatures,
      fontVariations: fontVariations ?? this.fontVariations,
      decoration: decoration ?? this.decoration,
      decorationColor: decorationColor ?? this.decorationColor,
      decorationStyle: decorationStyle ?? this.decorationStyle,
      decorationThickness: decorationThickness == null
          ? null
          : decorationThickness! * decorationThicknessFactor +
              decorationThicknessDelta,
      overflow: overflow ?? this.overflow,
      package: package ?? _package,
      debugLabel: modifiedDebugLabel,
    );
  }

  TextStyle merge(TextStyle? other) {
    if (other == null) {
      return this;
    }
    if (!other.inherit) {
      return other;
    }

    String? mergedDebugLabel;
    assert(() {
      if (other.debugLabel != null || debugLabel != null) {
        mergedDebugLabel =
            '(${debugLabel ?? _kDefaultDebugLabel}).merge(${other.debugLabel ?? _kDefaultDebugLabel})';
      }
      return true;
    }());

    return copyWith(
      color: other.color,
      backgroundColor: other.backgroundColor,
      fontSize: other.fontSize,
      fontWeight: other.fontWeight,
      fontStyle: other.fontStyle,
      letterSpacing: other.letterSpacing,
      wordSpacing: other.wordSpacing,
      textBaseline: other.textBaseline,
      height: other.height,
      leadingDistribution: other.leadingDistribution,
      locale: other.locale,
      foreground: other.foreground,
      background: other.background,
      shadows: other.shadows,
      fontFeatures: other.fontFeatures,
      fontVariations: other.fontVariations,
      decoration: other.decoration,
      decorationColor: other.decorationColor,
      decorationStyle: other.decorationStyle,
      decorationThickness: other.decorationThickness,
      debugLabel: mergedDebugLabel,
      fontFamily: other._fontFamily,
      fontFamilyFallback: other._fontFamilyFallback,
      package: other._package,
      overflow: other.overflow,
    );
  }

  static TextStyle? lerp(TextStyle? a, TextStyle? b, double t) {
    if (identical(a, b)) {
      return a;
    }
    String? lerpDebugLabel;
    assert(() {
      lerpDebugLabel =
          'lerp(${a?.debugLabel ?? _kDefaultDebugLabel} ⎯${t.toStringAsFixed(1)}→ ${b?.debugLabel ?? _kDefaultDebugLabel})';
      return true;
    }());

    if (a == null) {
      return TextStyle(
        inherit: b!.inherit,
        color: Color.lerp(null, b.color, t),
        backgroundColor: Color.lerp(null, b.backgroundColor, t),
        fontSize: t < 0.5 ? null : b.fontSize,
        fontWeight: FontWeight.lerp(null, b.fontWeight, t),
        fontStyle: t < 0.5 ? null : b.fontStyle,
        letterSpacing: t < 0.5 ? null : b.letterSpacing,
        wordSpacing: t < 0.5 ? null : b.wordSpacing,
        textBaseline: t < 0.5 ? null : b.textBaseline,
        height: t < 0.5 ? null : b.height,
        leadingDistribution: t < 0.5 ? null : b.leadingDistribution,
        locale: t < 0.5 ? null : b.locale,
        foreground: t < 0.5 ? null : b.foreground,
        background: t < 0.5 ? null : b.background,
        shadows: t < 0.5 ? null : b.shadows,
        fontFeatures: t < 0.5 ? null : b.fontFeatures,
        fontVariations: t < 0.5 ? null : b.fontVariations,
        decoration: t < 0.5 ? null : b.decoration,
        decorationColor: Color.lerp(null, b.decorationColor, t),
        decorationStyle: t < 0.5 ? null : b.decorationStyle,
        decorationThickness: t < 0.5 ? null : b.decorationThickness,
        debugLabel: lerpDebugLabel,
        fontFamily: t < 0.5 ? null : b._fontFamily,
        fontFamilyFallback: t < 0.5 ? null : b._fontFamilyFallback,
        package: t < 0.5 ? null : b._package,
        overflow: t < 0.5 ? null : b.overflow,
      );
    }

    if (b == null) {
      return TextStyle(
        inherit: a.inherit,
        color: Color.lerp(a.color, null, t),
        backgroundColor: Color.lerp(null, a.backgroundColor, t),
        fontSize: t < 0.5 ? a.fontSize : null,
        fontWeight: FontWeight.lerp(a.fontWeight, null, t),
        fontStyle: t < 0.5 ? a.fontStyle : null,
        letterSpacing: t < 0.5 ? a.letterSpacing : null,
        wordSpacing: t < 0.5 ? a.wordSpacing : null,
        textBaseline: t < 0.5 ? a.textBaseline : null,
        height: t < 0.5 ? a.height : null,
        leadingDistribution: t < 0.5 ? a.leadingDistribution : null,
        locale: t < 0.5 ? a.locale : null,
        foreground: t < 0.5 ? a.foreground : null,
        background: t < 0.5 ? a.background : null,
        shadows: t < 0.5 ? a.shadows : null,
        fontFeatures: t < 0.5 ? a.fontFeatures : null,
        fontVariations: t < 0.5 ? a.fontVariations : null,
        decoration: t < 0.5 ? a.decoration : null,
        decorationColor: Color.lerp(a.decorationColor, null, t),
        decorationStyle: t < 0.5 ? a.decorationStyle : null,
        decorationThickness: t < 0.5 ? a.decorationThickness : null,
        debugLabel: lerpDebugLabel,
        fontFamily: t < 0.5 ? a._fontFamily : null,
        fontFamilyFallback: t < 0.5 ? a._fontFamilyFallback : null,
        package: t < 0.5 ? a._package : null,
        overflow: t < 0.5 ? a.overflow : null,
      );
    }

    assert(() {
      if (a.inherit == b.inherit) {
        return true;
      }

      final List<String> nullFields = <String>[
        if (a.foreground == null &&
            b.foreground == null &&
            a.color == null &&
            b.color == null)
          'color',
        if (a.background == null &&
            b.background == null &&
            a.backgroundColor == null &&
            b.backgroundColor == null)
          'backgroundColor',
        if (a.fontSize == null && b.fontSize == null) 'fontSize',
        if (a.letterSpacing == null && b.letterSpacing == null) 'letterSpacing',
        if (a.wordSpacing == null && b.wordSpacing == null) 'wordSpacing',
        if (a.height == null && b.height == null) 'height',
        if (a.decorationColor == null && b.decorationColor == null)
          'decorationColor',
        if (a.decorationThickness == null && b.decorationThickness == null)
          'decorationThickness',
      ];
      if (nullFields.isEmpty) {
        return true;
      }

      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary(
            'Failed to interpolate TextStyles with different inherit values.'),
        ErrorSpacer(),
        ErrorDescription('The TextStyles being interpolated were:'),
        a.toDiagnosticsNode(
            name: 'from', style: DiagnosticsTreeStyle.singleLine),
        b.toDiagnosticsNode(name: 'to', style: DiagnosticsTreeStyle.singleLine),
        ErrorDescription(
            'The following fields are unspecified in both TextStyles:\n'
            '${nullFields.map((String name) => '"$name"').join(', ')}.\n'
            'When "inherit" changes during the transition, these fields may '
            'observe abrupt value changes as a result, causing "jump"s in the '
            'transition.'),
        ErrorSpacer(),
        ErrorHint(
          'In general, TextStyle.lerp only works well when both TextStyles have '
          'the same "inherit" value, and specify the same fields.',
        ),
        ErrorHint(
            'If the TextStyles were directly created by you, consider bringing '
            'them to parity to ensure a smooth transition.'),
        ErrorSpacer(),
        ErrorHint(
            'If one of the TextStyles being lerped is significantly more elaborate '
            'than the other, and has "inherited" set to false, it is often because '
            'it is merged with another TextStyle before being lerped. Comparing '
            'the "debugLabel"s of the two TextStyles may help identify if that was '
            'the case.'),
        ErrorHint(
            'For example, you may see this error message when trying to lerp '
            'between "ThemeData()" and "Theme.of(context)". This is because '
            'TextStyles from "Theme.of(context)" are merged with TextStyles from '
            'another theme and thus are more elaborate than the TextStyles from '
            '"ThemeData()" (which is reflected in their "debugLabel"s -- '
            'TextStyles from "Theme.of(context)" should have labels in the form of '
            '"(<A TextStyle>).merge(<Another TextStyle>)"). It is recommended to '
            'only lerp ThemeData with matching TextStyles.'),
      ]);
    }());

    return TextStyle(
      inherit: t < 0.5 ? a.inherit : b.inherit,
      color: a.foreground == null && b.foreground == null
          ? Color.lerp(a.color, b.color, t)
          : null,
      backgroundColor: a.background == null && b.background == null
          ? Color.lerp(a.backgroundColor, b.backgroundColor, t)
          : null,
      fontSize:
          ui.lerpDouble(a.fontSize ?? b.fontSize, b.fontSize ?? a.fontSize, t),
      fontWeight: FontWeight.lerp(a.fontWeight, b.fontWeight, t),
      fontStyle: t < 0.5 ? a.fontStyle : b.fontStyle,
      letterSpacing: ui.lerpDouble(a.letterSpacing ?? b.letterSpacing,
          b.letterSpacing ?? a.letterSpacing, t),
      wordSpacing: ui.lerpDouble(
          a.wordSpacing ?? b.wordSpacing, b.wordSpacing ?? a.wordSpacing, t),
      textBaseline: t < 0.5 ? a.textBaseline : b.textBaseline,
      height: ui.lerpDouble(a.height ?? b.height, b.height ?? a.height, t),
      leadingDistribution:
          t < 0.5 ? a.leadingDistribution : b.leadingDistribution,
      locale: t < 0.5 ? a.locale : b.locale,
      foreground: (a.foreground != null || b.foreground != null)
          ? t < 0.5
              ? a.foreground ?? (Paint()..color = a.color!)
              : b.foreground ?? (Paint()..color = b.color!)
          : null,
      background: (a.background != null || b.background != null)
          ? t < 0.5
              ? a.background ?? (Paint()..color = a.backgroundColor!)
              : b.background ?? (Paint()..color = b.backgroundColor!)
          : null,
      shadows: t < 0.5 ? a.shadows : b.shadows,
      fontFeatures: t < 0.5 ? a.fontFeatures : b.fontFeatures,
      fontVariations: t < 0.5 ? a.fontVariations : b.fontVariations,
      decoration: t < 0.5 ? a.decoration : b.decoration,
      decorationColor: Color.lerp(a.decorationColor, b.decorationColor, t),
      decorationStyle: t < 0.5 ? a.decorationStyle : b.decorationStyle,
      decorationThickness: ui.lerpDouble(
          a.decorationThickness ?? b.decorationThickness,
          b.decorationThickness ?? a.decorationThickness,
          t),
      debugLabel: lerpDebugLabel,
      fontFamily: t < 0.5 ? a._fontFamily : b._fontFamily,
      fontFamilyFallback:
          t < 0.5 ? a._fontFamilyFallback : b._fontFamilyFallback,
      package: t < 0.5 ? a._package : b._package,
      overflow: t < 0.5 ? a.overflow : b.overflow,
    );
  }

  ui.TextStyle getTextStyle({
    @Deprecated(
      'Use textScaler instead. '
      'Use of textScaleFactor was deprecated in preparation for the upcoming nonlinear text scaling support. '
      'This feature was deprecated after v3.12.0-2.0.pre.',
    )
    double textScaleFactor = 1.0,
    TextScaler textScaler = TextScaler.noScaling,
  }) {
    assert(
      identical(textScaler, TextScaler.noScaling) || textScaleFactor == 1.0,
      'textScaleFactor is deprecated and cannot be specified when textScaler is specified.',
    );
    final double? fontSize = switch (this.fontSize) {
      null => null,
      final double size when textScaler == TextScaler.noScaling =>
        size * textScaleFactor,
      final double size => textScaler.scale(size),
    };
    return ui.TextStyle(
      color: color,
      decoration: decoration,
      decorationColor: decorationColor,
      decorationStyle: decorationStyle,
      decorationThickness: decorationThickness,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      textBaseline: textBaseline,
      leadingDistribution: leadingDistribution,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: fontSize,
      letterSpacing: letterSpacing,
      wordSpacing: wordSpacing,
      height: height,
      locale: locale,
      foreground: foreground,
      background: switch ((background, backgroundColor)) {
        (final Paint paint, _) => paint,
        (_, final Color color) => Paint()..color = color,
        _ => null,
      },
      shadows: shadows,
      fontFeatures: fontFeatures,
      fontVariations: fontVariations,
    );
  }

  ui.ParagraphStyle getParagraphStyle({
    TextAlign? textAlign,
    TextDirection? textDirection,
    TextScaler textScaler = TextScaler.noScaling,
    String? ellipsis,
    int? maxLines,
    ui.TextHeightBehavior? textHeightBehavior,
    Locale? locale,
    String? fontFamily,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? height,
    StrutStyle? strutStyle,
  }) {
    assert(maxLines == null || maxLines > 0);
    final ui.TextLeadingDistribution? leadingDistribution =
        this.leadingDistribution;
    final ui.TextHeightBehavior? effectiveTextHeightBehavior =
        textHeightBehavior ??
            (leadingDistribution == null
                ? null
                : ui.TextHeightBehavior(
                    leadingDistribution: leadingDistribution));

    return ui.ParagraphStyle(
      textAlign: textAlign,
      textDirection: textDirection,
      // Here, we establish the contents of this TextStyle as the paragraph's default font
      // unless an override is passed in.
      fontWeight: fontWeight ?? this.fontWeight,
      fontStyle: fontStyle ?? this.fontStyle,
      fontFamily: fontFamily ?? this.fontFamily,
      fontSize:
          textScaler.scale(fontSize ?? this.fontSize ?? _kDefaultFontSize),
      height: height ?? this.height,
      textHeightBehavior: effectiveTextHeightBehavior,
      strutStyle: strutStyle == null
          ? null
          : ui.StrutStyle(
              fontFamily: strutStyle.fontFamily,
              fontFamilyFallback: strutStyle.fontFamilyFallback,
              fontSize: switch (strutStyle.fontSize) {
                null => null,
                final double unscaled => textScaler.scale(unscaled),
              },
              height: strutStyle.height,
              leading: strutStyle.leading,
              fontWeight: strutStyle.fontWeight,
              fontStyle: strutStyle.fontStyle,
              forceStrutHeight: strutStyle.forceStrutHeight,
            ),
      maxLines: maxLines,
      ellipsis: ellipsis,
      locale: locale,
    );
  }

  RenderComparison compareTo(TextStyle other) {
    if (identical(this, other)) {
      return RenderComparison.identical;
    }
    if (inherit != other.inherit ||
        fontFamily != other.fontFamily ||
        fontSize != other.fontSize ||
        fontWeight != other.fontWeight ||
        fontStyle != other.fontStyle ||
        letterSpacing != other.letterSpacing ||
        wordSpacing != other.wordSpacing ||
        textBaseline != other.textBaseline ||
        height != other.height ||
        leadingDistribution != other.leadingDistribution ||
        locale != other.locale ||
        foreground != other.foreground ||
        background != other.background ||
        !listEquals(shadows, other.shadows) ||
        !listEquals(fontFeatures, other.fontFeatures) ||
        !listEquals(fontVariations, other.fontVariations) ||
        !listEquals(fontFamilyFallback, other.fontFamilyFallback) ||
        overflow != other.overflow) {
      return RenderComparison.layout;
    }
    if (color != other.color ||
        backgroundColor != other.backgroundColor ||
        decoration != other.decoration ||
        decorationColor != other.decorationColor ||
        decorationStyle != other.decorationStyle ||
        decorationThickness != other.decorationThickness) {
      return RenderComparison.paint;
    }
    return RenderComparison.identical;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is TextStyle &&
        other.inherit == inherit &&
        other.color == color &&
        other.backgroundColor == backgroundColor &&
        other.fontSize == fontSize &&
        other.fontWeight == fontWeight &&
        other.fontStyle == fontStyle &&
        other.letterSpacing == letterSpacing &&
        other.wordSpacing == wordSpacing &&
        other.textBaseline == textBaseline &&
        other.height == height &&
        other.leadingDistribution == leadingDistribution &&
        other.locale == locale &&
        other.foreground == foreground &&
        other.background == background &&
        listEquals(other.shadows, shadows) &&
        listEquals(other.fontFeatures, fontFeatures) &&
        listEquals(other.fontVariations, fontVariations) &&
        other.decoration == decoration &&
        other.decorationColor == decorationColor &&
        other.decorationStyle == decorationStyle &&
        other.decorationThickness == decorationThickness &&
        other.fontFamily == fontFamily &&
        listEquals(other.fontFamilyFallback, fontFamilyFallback) &&
        other._package == _package &&
        other.overflow == overflow;
  }

  @override
  int get hashCode {
    final List<String>? fontFamilyFallback = this.fontFamilyFallback;
    final int fontHash = Object.hash(
      decorationStyle,
      decorationThickness,
      fontFamily,
      fontFamilyFallback == null ? null : Object.hashAll(fontFamilyFallback),
      _package,
      overflow,
    );

    final List<ui.Shadow>? shadows = this.shadows;
    final List<ui.FontFeature>? fontFeatures = this.fontFeatures;
    final List<ui.FontVariation>? fontVariations = this.fontVariations;
    return Object.hash(
      inherit,
      color,
      backgroundColor,
      fontSize,
      fontWeight,
      fontStyle,
      letterSpacing,
      wordSpacing,
      textBaseline,
      height,
      leadingDistribution,
      locale,
      foreground,
      background,
      shadows == null ? null : Object.hashAll(shadows),
      fontFeatures == null ? null : Object.hashAll(fontFeatures),
      fontVariations == null ? null : Object.hashAll(fontVariations),
      decoration,
      decorationColor,
      fontHash,
    );
  }

  @override
  String toStringShort() => objectRuntimeType(this, 'TextStyle');

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties,
      {String prefix = ''}) {
    super.debugFillProperties(properties);
    if (debugLabel != null) {
      properties.add(MessageProperty('${prefix}debugLabel', debugLabel!));
    }
    final List<DiagnosticsNode> styles = <DiagnosticsNode>[
      ColorProperty('${prefix}color', color, defaultValue: null),
      ColorProperty('${prefix}backgroundColor', backgroundColor,
          defaultValue: null),
      StringProperty('${prefix}family', fontFamily,
          defaultValue: null, quoted: false),
      IterableProperty<String>('${prefix}familyFallback', fontFamilyFallback,
          defaultValue: null),
      DoubleProperty('${prefix}size', fontSize, defaultValue: null),
    ];
    String? weightDescription;
    if (fontWeight != null) {
      weightDescription = '${fontWeight!.index + 1}00';
    }
    // TODO(jacobr): switch this to use enumProperty which will either cause the
    // weight description to change to w600 from 600 or require existing
    // enumProperty to handle this special case.
    styles.add(DiagnosticsProperty<FontWeight>(
      '${prefix}weight',
      fontWeight,
      description: weightDescription,
      defaultValue: null,
    ));
    styles.add(EnumProperty<FontStyle>('${prefix}style', fontStyle,
        defaultValue: null));
    styles.add(DoubleProperty('${prefix}letterSpacing', letterSpacing,
        defaultValue: null));
    styles.add(DoubleProperty('${prefix}wordSpacing', wordSpacing,
        defaultValue: null));
    styles.add(EnumProperty<TextBaseline>('${prefix}baseline', textBaseline,
        defaultValue: null));
    styles.add(DoubleProperty('${prefix}height', height,
        unit: 'x', defaultValue: null));
    styles.add(EnumProperty<ui.TextLeadingDistribution>(
        '${prefix}leadingDistribution', leadingDistribution,
        defaultValue: null));
    styles.add(DiagnosticsProperty<Locale>('${prefix}locale', locale,
        defaultValue: null));
    styles.add(DiagnosticsProperty<Paint>('${prefix}foreground', foreground,
        defaultValue: null));
    styles.add(DiagnosticsProperty<Paint>('${prefix}background', background,
        defaultValue: null));
    if (decoration != null ||
        decorationColor != null ||
        decorationStyle != null ||
        decorationThickness != null) {
      final List<String> decorationDescription = <String>[];
      if (decorationStyle != null) {
        decorationDescription.add(decorationStyle!.name);
      }

      // Hide decorationColor from the default text view as it is shown in the
      // terse decoration summary as well.
      styles.add(ColorProperty('${prefix}decorationColor', decorationColor,
          defaultValue: null, level: DiagnosticLevel.fine));

      if (decorationColor != null) {
        decorationDescription.add('$decorationColor');
      }

      // Intentionally collide with the property 'decoration' added below.
      // Tools that show hidden properties could choose the first property
      // matching the name to disambiguate.
      styles.add(DiagnosticsProperty<TextDecoration>(
          '${prefix}decoration', decoration,
          defaultValue: null, level: DiagnosticLevel.hidden));
      if (decoration != null) {
        decorationDescription.add('$decoration');
      }
      assert(decorationDescription.isNotEmpty);
      styles.add(MessageProperty(
          '${prefix}decoration', decorationDescription.join(' ')));
      styles.add(DoubleProperty(
          '${prefix}decorationThickness', decorationThickness,
          unit: 'x', defaultValue: null));
    }

    final bool styleSpecified =
        styles.any((DiagnosticsNode n) => !n.isFiltered(DiagnosticLevel.info));
    properties.add(DiagnosticsProperty<bool>('${prefix}inherit', inherit,
        level: (!styleSpecified && inherit)
            ? DiagnosticLevel.fine
            : DiagnosticLevel.info));
    styles.forEach(properties.add);

    if (!styleSpecified) {
      properties.add(FlagProperty('inherit',
          value: inherit,
          ifTrue: '$prefix<all styles inherited>',
          ifFalse: '$prefix<no style specified>'));
    }

    styles.add(EnumProperty<TextOverflow>('${prefix}overflow', overflow,
        defaultValue: null));
  }
}
