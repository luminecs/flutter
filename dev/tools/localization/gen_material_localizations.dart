
import 'localizations_utils.dart';

String generateMaterialHeader(String regenerateInstructions) {
  return '''

// This file has been automatically generated. Please do not edit it manually.
// To regenerate the file, use:
// $regenerateInstructions

import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../material_localizations.dart';

// The classes defined here encode all of the translations found in the
// `flutter_localizations/lib/src/l10n/*.arb` files.
//
// These classes are constructed by the [getMaterialTranslation] method at the
// bottom of this file, and used by the [_MaterialLocalizationsDelegate.load]
// method defined in `flutter_localizations/lib/src/material_localizations.dart`.''';
}

String generateMaterialConstructor(LocaleInfo locale) {
  final String localeName = locale.originalString;
  return '''
  const MaterialLocalization${locale.camelCase()}({
    super.localeName = '$localeName',
    required super.fullYearFormat,
    required super.compactDateFormat,
    required super.shortDateFormat,
    required super.mediumDateFormat,
    required super.longDateFormat,
    required super.yearMonthFormat,
    required super.shortMonthDayFormat,
    required super.decimalFormat,
    required super.twoDigitZeroPaddedFormat,
  });''';
}

const String materialFactoryName = 'getMaterialTranslation';

const String materialFactoryDeclaration = '''
GlobalMaterialLocalizations? getMaterialTranslation(
  Locale locale,
  intl.DateFormat fullYearFormat,
  intl.DateFormat compactDateFormat,
  intl.DateFormat shortDateFormat,
  intl.DateFormat mediumDateFormat,
  intl.DateFormat longDateFormat,
  intl.DateFormat yearMonthFormat,
  intl.DateFormat shortMonthDayFormat,
  intl.NumberFormat decimalFormat,
  intl.NumberFormat twoDigitZeroPaddedFormat,
) {''';

const String materialFactoryArguments =
    'fullYearFormat: fullYearFormat, compactDateFormat: compactDateFormat, shortDateFormat: shortDateFormat, mediumDateFormat: mediumDateFormat, longDateFormat: longDateFormat, yearMonthFormat: yearMonthFormat, shortMonthDayFormat: shortMonthDayFormat, decimalFormat: decimalFormat, twoDigitZeroPaddedFormat: twoDigitZeroPaddedFormat';

const String materialSupportedLanguagesConstant = 'kMaterialSupportedLanguages';

const String materialSupportedLanguagesDocMacro = 'flutter.localizations.material.languages';