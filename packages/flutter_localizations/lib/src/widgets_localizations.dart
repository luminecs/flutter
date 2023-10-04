import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'l10n/generated_widgets_localizations.dart';

abstract class GlobalWidgetsLocalizations implements WidgetsLocalizations {
  const GlobalWidgetsLocalizations(this.textDirection);

  @override
  final TextDirection textDirection;

  static const LocalizationsDelegate<WidgetsLocalizations> delegate =
      _WidgetsLocalizationsDelegate();
}

class _WidgetsLocalizationsDelegate
    extends LocalizationsDelegate<WidgetsLocalizations> {
  const _WidgetsLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      kWidgetsSupportedLanguages.contains(locale.languageCode);

  static final Map<Locale, Future<WidgetsLocalizations>> _loadedTranslations =
      <Locale, Future<WidgetsLocalizations>>{};

  @override
  Future<WidgetsLocalizations> load(Locale locale) {
    assert(isSupported(locale));
    return _loadedTranslations.putIfAbsent(locale, () {
      return SynchronousFuture<WidgetsLocalizations>(getWidgetsTranslation(
        locale,
      )!);
    });
  }

  @override
  bool shouldReload(_WidgetsLocalizationsDelegate old) => false;

  @override
  String toString() =>
      'GlobalWidgetsLocalizations.delegate(${kWidgetsSupportedLanguages.length} locales)';
}
