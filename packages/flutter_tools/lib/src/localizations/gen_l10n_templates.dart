
const String emptyPubspecTemplate = '''
# Generated by the flutter tool
name: synthetic_package
description: The Flutter application's synthetic package.
''';

const String fileTemplate = '''
@(header)import 'dart:async';

@(requiresFoundationImport)
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

@(messageClassImports)

abstract class @(class) {
  @(class)(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static @(class)@(canBeNullable) of(BuildContext context) {
    return Localizations.of<@(class)>(context, @(class))@(needsNullCheck);
  }

  static const LocalizationsDelegate<@(class)> delegate = _@(class)Delegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  static const List<Locale> supportedLocales = <Locale>[
    @(supportedLocales)
  ];

@(methods)}

@(delegateClass)
''';

const String numberFormatPositionalTemplate = '''
    final intl.NumberFormat @(placeholder)NumberFormat = intl.NumberFormat.@(format)(localeName);
    final String @(placeholder)String = @(placeholder)NumberFormat.format(@(placeholder));
''';

const String numberFormatNamedTemplate = '''
    final intl.NumberFormat @(placeholder)NumberFormat = intl.NumberFormat.@(format)(
      locale: localeName,
      @(parameters)
    );
    final String @(placeholder)String = @(placeholder)NumberFormat.format(@(placeholder));
''';

const String dateFormatTemplate = '''
    final intl.DateFormat @(placeholder)DateFormat = intl.DateFormat.@(format)(localeName);
    final String @(placeholder)String = @(placeholder)DateFormat.format(@(placeholder));
''';

const String dateFormatCustomTemplate = '''
    final intl.DateFormat @(placeholder)DateFormat = intl.DateFormat(@(format), localeName);
    final String @(placeholder)String = @(placeholder)DateFormat.format(@(placeholder));
''';

const String getterTemplate = '''
  @override
  String get @(name) => @(message);''';

const String methodTemplate = '''
  @override
  String @(name)(@(parameters)) {
@(dateFormatting)
@(numberFormatting)
@(tempVars)    return @(message);
  }''';

const String pluralVariableTemplate = '''
    String @(varName) = intl.Intl.pluralLogic(
      @(count),
      locale: localeName,
@(pluralLogicArgs)
    );''';

const String selectVariableTemplate = '''
    String @(varName) = intl.Intl.selectLogic(
      @(choice),
      {
@(selectCases)
      },
    );''';

const String dateVariableTemplate = '''
    String @(varName) = intl.DateFormat.@(formatType)(localeName).format(@(argument));''';

const String classFileTemplate = '''
@(header)@(requiresIntlImport)import '@(fileName)';

class @(class) extends @(baseClass) {
  @(class)([String locale = '@(localeName)']) : super(locale);

@(methods)
}
@(subclasses)''';

const String subclassTemplate = '''

class @(class) extends @(baseLanguageClassName) {
  @(class)(): super('@(localeName)');

@(methods)
}
''';

const String baseClassGetterTemplate = '''
@(comment)
@(templateLocaleTranslationComment)
  String get @(name);
''';

const String baseClassMethodTemplate = '''
@(comment)
@(templateLocaleTranslationComment)
  String @(name)(@(parameters));
''';

// DELEGATE CLASS TEMPLATES

const String delegateClassTemplate = '''
class _@(class)Delegate extends LocalizationsDelegate<@(class)> {
  const _@(class)Delegate();

  @override
  Future<@(class)> load(Locale locale) {
    @(loadBody)
  }

  @override
  bool isSupported(Locale locale) => <String>[@(supportedLanguageCodes)].contains(locale.languageCode);

  @override
  bool shouldReload(_@(class)Delegate old) => false;
}

@(lookupFunction)''';

const String loadBodyTemplate = '''return SynchronousFuture<@(class)>(@(lookupName)(locale));''';

const String loadBodyDeferredLoadingTemplate = '''return @(lookupName)(locale);''';

// DELEGATE LOOKUP TEMPLATES

const String lookupFunctionTemplate = r'''
@(class) @(lookupName)(Locale locale) {
  @(lookupBody)

  throw FlutterError(
    '@(class).delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}''';

const String lookupFunctionDeferredLoadingTemplate = r'''
Future<@(class)> @(lookupName)(Locale locale) {
  @(lookupBody)

  throw FlutterError(
    '@(class).delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.'
  );
}''';

const String lookupBodyTemplate = '''
@(lookupAllCodesSpecified)
@(lookupScriptCodeSpecified)
@(lookupCountryCodeSpecified)
@(lookupLanguageCodeSpecified)''';

const String switchClauseTemplate = '''case '@(case)': return @(localeClass)();''';

const String switchClauseDeferredLoadingTemplate = '''case '@(case)': return @(library).loadLibrary().then((dynamic _) => @(library).@(localeClass)());''';

const String nestedSwitchTemplate = '''
case '@(languageCode)': {
  switch (locale.@(code)) {
    @(switchClauses)
  }
  break;
}''';

const String languageCodeSwitchTemplate = '''
  @(comment)
  switch (locale.languageCode) {
    @(switchClauses)
  }
''';

const String allCodesLookupTemplate = '''
  // Lookup logic when language+script+country codes are specified.
  switch (locale.toString()) {
    @(allCodesSwitchClauses)
  }
''';