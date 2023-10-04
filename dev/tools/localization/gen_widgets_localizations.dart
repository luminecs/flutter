import 'localizations_utils.dart';

// See http://en.wikipedia.org/wiki/Right-to-left
const List<String> _rtlLanguages = <String>[
  'ar', // Arabic
  'fa', // Farsi
  'he', // Hebrew
  'ps', // Pashto
  'ur', // Urdu
];

String generateWidgetsHeader(String regenerateInstructions) {
  return '''

// This file has been automatically generated. Please do not edit it manually.
// To regenerate the file, use:
// $regenerateInstructions

import 'dart:collection';
import 'dart:ui';

import '../widgets_localizations.dart';

// The classes defined here encode all of the translations found in the
// `flutter_localizations/lib/src/l10n/*.arb` files.
//
// These classes are constructed by the [getWidgetsTranslation] method at the
// bottom of this file, and used by the [_WidgetsLocalizationsDelegate.load]
// method defined in `flutter_localizations/lib/src/widgets_localizations.dart`.''';
}

String generateWidgetsConstructor(LocaleInfo locale) {
  final String localeName = locale.originalString;
  final String language = locale.languageCode.toLowerCase();
  final String textDirection = _rtlLanguages.contains(language)
      ? 'TextDirection.rtl'
      : 'TextDirection.ltr';
  return '''
  const WidgetsLocalization${locale.camelCase()}() : super($textDirection);''';
}

String generateWidgetsConstructorForCountrySubclass(LocaleInfo locale) {
  final String localeName = locale.originalString;
  return '''
  const WidgetsLocalization${locale.camelCase()}();''';
}

const String widgetsFactoryName = 'getWidgetsTranslation';

const String widgetsFactoryDeclaration = '''
GlobalWidgetsLocalizations? getWidgetsTranslation(
  Locale locale,
) {''';

const String widgetsFactoryArguments = '';

const String widgetsSupportedLanguagesConstant = 'kWidgetsSupportedLanguages';

const String widgetsSupportedLanguagesDocMacro =
    'flutter.localizations.widgets.languages';
