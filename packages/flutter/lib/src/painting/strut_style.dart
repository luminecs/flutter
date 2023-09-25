
import 'dart:ui' show TextLeadingDistribution;

import 'package:flutter/foundation.dart';

import 'basic_types.dart';
import 'text_style.dart';


// ///////////////////////////////////////////////////////////////////////////
// The defaults are noted here for convenience. The actual place where they //
// are defined is in the engine paragraph_style.h of LibTxt. The values here//
// should be updated should it change in the engine. The engine specifies   //
// the defaults in order to reduce the amount of data we pass to native as  //
// strut will usually be unspecified.                                       //
// ///////////////////////////////////////////////////////////////////////////

@immutable
class StrutStyle with Diagnosticable {
  const StrutStyle({
    String? fontFamily,
    List<String>? fontFamilyFallback,
    this.fontSize,
    this.height,
    this.leadingDistribution,
    this.leading,
    this.fontWeight,
    this.fontStyle,
    this.forceStrutHeight,
    this.debugLabel,
    String? package,
  }) : fontFamily = package == null ? fontFamily : 'packages/$package/$fontFamily',
       _fontFamilyFallback = fontFamilyFallback,
       _package = package,
       assert(fontSize == null || fontSize > 0),
       assert(leading == null || leading >= 0),
       assert(package == null || (fontFamily != null || fontFamilyFallback != null));

  StrutStyle.fromTextStyle(
    TextStyle textStyle, {
    String? fontFamily,
    List<String>? fontFamilyFallback,
    double? fontSize,
    double? height,
    TextLeadingDistribution? leadingDistribution,
    this.leading, // TextStyle does not have an equivalent (yet).
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    this.forceStrutHeight,
    String? debugLabel,
    String? package,
  }) : assert(fontSize == null || fontSize > 0),
       assert(leading == null || leading >= 0),
       assert(package == null || fontFamily != null || fontFamilyFallback != null),
       fontFamily = fontFamily != null ? (package == null ? fontFamily : 'packages/$package/$fontFamily') : textStyle.fontFamily,
       _fontFamilyFallback = fontFamilyFallback ?? textStyle.fontFamilyFallback,
       height = height ?? textStyle.height,
       leadingDistribution = leadingDistribution ?? textStyle.leadingDistribution,
       fontSize = fontSize ?? textStyle.fontSize,
       fontWeight = fontWeight ?? textStyle.fontWeight,
       fontStyle = fontStyle ?? textStyle.fontStyle,
       debugLabel = debugLabel ?? textStyle.debugLabel,
       _package = package; // the textStyle._package data is embedded in the
                           // fontFamily names, so we no longer need it.

  static const StrutStyle disabled = StrutStyle(
    height: 0.0,
    leading: 0.0,
  );

  final String? fontFamily;

  List<String>? get fontFamilyFallback {
    if (_package != null && _fontFamilyFallback != null) {
      return _fontFamilyFallback.map((String family) => 'packages/$_package/$family').toList();
    }
    return _fontFamilyFallback;
  }
  final List<String>? _fontFamilyFallback;

  // This is stored in order to prefix the fontFamilies in _fontFamilyFallback
  // in the [fontFamilyFallback] getter.
  final String? _package;

  final double? fontSize;

  final double? height;

  final TextLeadingDistribution? leadingDistribution;

  final FontWeight? fontWeight;

  final FontStyle? fontStyle;

  final double? leading;

  final bool? forceStrutHeight;

  final String? debugLabel;

  RenderComparison compareTo(StrutStyle other) {
    if (identical(this, other)) {
      return RenderComparison.identical;
    }
    if (fontFamily != other.fontFamily ||
        fontSize != other.fontSize ||
        fontWeight != other.fontWeight ||
        fontStyle != other.fontStyle ||
        height != other.height ||
        leading != other.leading ||
        forceStrutHeight != other.forceStrutHeight ||
        !listEquals(fontFamilyFallback, other.fontFamilyFallback)) {
      return RenderComparison.layout;
    }
    return RenderComparison.identical;
  }

  StrutStyle inheritFromTextStyle(TextStyle? other) {
    if (other == null) {
      return this;
    }

    return StrutStyle(
      fontFamily: fontFamily ?? other.fontFamily,
      fontFamilyFallback: fontFamilyFallback ?? other.fontFamilyFallback,
      fontSize: fontSize ?? other.fontSize,
      height: height ?? other.height,
      leading: leading, // No equivalent property in TextStyle yet.
      fontWeight: fontWeight ?? other.fontWeight,
      fontStyle: fontStyle ?? other.fontStyle,
      forceStrutHeight: forceStrutHeight, // StrutStyle-unique property.
      debugLabel: debugLabel ?? other.debugLabel,
      // Package is embedded within the getters for fontFamilyFallback.
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
    return other is StrutStyle
        && other.fontFamily == fontFamily
        && other.fontSize == fontSize
        && other.fontWeight == fontWeight
        && other.fontStyle == fontStyle
        && other.height == height
        && other.leading == leading
        && other.forceStrutHeight == forceStrutHeight;
  }

  @override
  int get hashCode => Object.hash(
    fontFamily,
    fontSize,
    fontWeight,
    fontStyle,
    height,
    leading,
    forceStrutHeight,
  );

  @override
  String toStringShort() => objectRuntimeType(this, 'StrutStyle');

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties, { String prefix = '' }) {
    super.debugFillProperties(properties);
    if (debugLabel != null) {
      properties.add(MessageProperty('${prefix}debugLabel', debugLabel!));
    }
    final List<DiagnosticsNode> styles = <DiagnosticsNode>[
      StringProperty('${prefix}family', fontFamily, defaultValue: null, quoted: false),
      IterableProperty<String>('${prefix}familyFallback', fontFamilyFallback, defaultValue: null),
      DoubleProperty('${prefix}size', fontSize, defaultValue: null),
    ];
    String? weightDescription;
    if (fontWeight != null) {
      weightDescription = 'w${fontWeight!.index + 1}00';
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
    styles.add(EnumProperty<FontStyle>('${prefix}style', fontStyle, defaultValue: null));
    styles.add(DoubleProperty('${prefix}height', height, unit: 'x', defaultValue: null));
    styles.add(FlagProperty('${prefix}forceStrutHeight', value: forceStrutHeight, ifTrue: '$prefix<strut height forced>', ifFalse: '$prefix<strut height normal>'));

    final bool styleSpecified = styles.any((DiagnosticsNode n) => !n.isFiltered(DiagnosticLevel.info));
    styles.forEach(properties.add);

    if (!styleSpecified) {
      properties.add(FlagProperty('forceStrutHeight', value: forceStrutHeight, ifTrue: '$prefix<strut height forced>', ifFalse: '$prefix<strut height normal>'));
    }
  }
}