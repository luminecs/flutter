// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart' as intl;

import 'l10n/generated_cupertino_localizations.dart';
import 'utils/date_localizations.dart' as util;
import 'widgets_localizations.dart';

// Examples can assume:
// import 'package:flutter_localizations/flutter_localizations.dart';
// import 'package:flutter/cupertino.dart';

abstract class GlobalCupertinoLocalizations implements CupertinoLocalizations {
  const GlobalCupertinoLocalizations({
    required String localeName,
    required intl.DateFormat fullYearFormat,
    required intl.DateFormat dayFormat,
    required intl.DateFormat mediumDateFormat,
    required intl.DateFormat singleDigitHourFormat,
    required intl.DateFormat singleDigitMinuteFormat,
    required intl.DateFormat doubleDigitMinuteFormat,
    required intl.DateFormat singleDigitSecondFormat,
    required intl.NumberFormat decimalFormat,
  }) : _localeName = localeName,
       _fullYearFormat = fullYearFormat,
       _dayFormat = dayFormat,
       _mediumDateFormat = mediumDateFormat,
       _singleDigitHourFormat = singleDigitHourFormat,
       _singleDigitMinuteFormat = singleDigitMinuteFormat,
       _doubleDigitMinuteFormat = doubleDigitMinuteFormat,
       _singleDigitSecondFormat = singleDigitSecondFormat,
       _decimalFormat =decimalFormat;

  final String _localeName;
  final intl.DateFormat _fullYearFormat;
  final intl.DateFormat _dayFormat;
  final intl.DateFormat _mediumDateFormat;
  final intl.DateFormat _singleDigitHourFormat;
  final intl.DateFormat _singleDigitMinuteFormat;
  final intl.DateFormat _doubleDigitMinuteFormat;
  final intl.DateFormat _singleDigitSecondFormat;
  final intl.NumberFormat _decimalFormat;

  @override
  String datePickerYear(int yearIndex) {
    return _fullYearFormat.format(DateTime.utc(yearIndex));
  }

  @override
  String datePickerMonth(int monthIndex) {
    // It doesn't actually have anything to do with _fullYearFormat. It's just
    // taking advantage of the fact that _fullYearFormat loaded the needed
    // locale's symbols.
    return _fullYearFormat.dateSymbols.MONTHS[monthIndex - 1];
  }

  @override
  String datePickerStandaloneMonth(int monthIndex) {
    // It doesn't actually have anything to do with _fullYearFormat. It's just
    // taking advantage of the fact that _fullYearFormat loaded the needed
    // locale's symbols.
    //
    // Because this will be used without specifying any day of month,
    // in most cases it should be capitalized (according to rules in specific language).
    return intl.toBeginningOfSentenceCase(_fullYearFormat.dateSymbols.STANDALONEMONTHS[monthIndex - 1]) ??
        _fullYearFormat.dateSymbols.STANDALONEMONTHS[monthIndex - 1];
  }

  @override
  String datePickerDayOfMonth(int dayIndex, [int? weekDay]) {
     if (weekDay != null) {
      return ' ${DefaultCupertinoLocalizations.shortWeekdays[weekDay - DateTime.monday]} $dayIndex ';
    }
    // Year and month doesn't matter since we just want to day formatted.
    return _dayFormat.format(DateTime.utc(0, 0, dayIndex));
  }

  @override
  String datePickerMediumDate(DateTime date) {
    return _mediumDateFormat.format(date);
  }

  @override
  String datePickerHour(int hour) {
    return _singleDigitHourFormat.format(DateTime.utc(0, 0, 0, hour));
  }

  @override
  String datePickerMinute(int minute) {
    return _doubleDigitMinuteFormat.format(DateTime.utc(0, 0, 0, 0, minute));
  }

  @protected
  String? get datePickerHourSemanticsLabelZero => null;
  @protected
  String? get datePickerHourSemanticsLabelOne => null;
  @protected
  String? get datePickerHourSemanticsLabelTwo => null;
  @protected
  String? get datePickerHourSemanticsLabelFew => null;
  @protected
  String? get datePickerHourSemanticsLabelMany => null;
  @protected
  String? get datePickerHourSemanticsLabelOther;

  @override
  String? datePickerHourSemanticsLabel(int hour) {
    return intl.Intl.pluralLogic(
      hour,
      zero: datePickerHourSemanticsLabelZero,
      one: datePickerHourSemanticsLabelOne,
      two: datePickerHourSemanticsLabelTwo,
      few: datePickerHourSemanticsLabelFew,
      many: datePickerHourSemanticsLabelMany,
      other: datePickerHourSemanticsLabelOther,
      locale: _localeName,
    )?.replaceFirst(r'$hour', _decimalFormat.format(hour));
  }

  @protected
  String? get datePickerMinuteSemanticsLabelZero => null;
  @protected
  String? get datePickerMinuteSemanticsLabelOne => null;
  @protected
  String? get datePickerMinuteSemanticsLabelTwo => null;
  @protected
  String? get datePickerMinuteSemanticsLabelFew => null;
  @protected
  String? get datePickerMinuteSemanticsLabelMany => null;
  @protected
  String? get datePickerMinuteSemanticsLabelOther;

  @override
  String? datePickerMinuteSemanticsLabel(int minute) {
    return intl.Intl.pluralLogic(
      minute,
      zero: datePickerMinuteSemanticsLabelZero,
      one: datePickerMinuteSemanticsLabelOne,
      two: datePickerMinuteSemanticsLabelTwo,
      few: datePickerMinuteSemanticsLabelFew,
      many: datePickerMinuteSemanticsLabelMany,
      other: datePickerMinuteSemanticsLabelOther,
      locale: _localeName,
    )?.replaceFirst(r'$minute', _decimalFormat.format(minute));
  }

  @protected
  String get datePickerDateOrderString;

  @override
  DatePickerDateOrder get datePickerDateOrder {
    switch (datePickerDateOrderString) {
      case 'dmy':
        return DatePickerDateOrder.dmy;
      case 'mdy':
        return DatePickerDateOrder.mdy;
      case 'ymd':
        return DatePickerDateOrder.ymd;
      case 'ydm':
        return DatePickerDateOrder.ydm;
      default:
        assert(
          false,
          'Failed to load DatePickerDateOrder $datePickerDateOrderString for '
          "locale $_localeName.\nNon conforming string for $_localeName's "
          '.arb file',
        );
        return DatePickerDateOrder.mdy;
    }
  }

  @protected
  String get datePickerDateTimeOrderString;

  @override
  DatePickerDateTimeOrder get datePickerDateTimeOrder {
    switch (datePickerDateTimeOrderString) {
      case 'date_time_dayPeriod':
        return DatePickerDateTimeOrder.date_time_dayPeriod;
      case 'date_dayPeriod_time':
        return DatePickerDateTimeOrder.date_dayPeriod_time;
      case 'time_dayPeriod_date':
        return DatePickerDateTimeOrder.time_dayPeriod_date;
      case 'dayPeriod_time_date':
        return DatePickerDateTimeOrder.dayPeriod_time_date;
      default:
        assert(
          false,
          'Failed to load DatePickerDateTimeOrder $datePickerDateTimeOrderString '
          "for locale $_localeName.\nNon conforming string for $_localeName's "
          '.arb file',
        );
        return DatePickerDateTimeOrder.date_time_dayPeriod;
    }
  }

  @protected
  String get tabSemanticsLabelRaw;

  @override
  String tabSemanticsLabel({ required int tabIndex, required int tabCount }) {
    assert(tabIndex >= 1);
    assert(tabCount >= 1);
    final String template = tabSemanticsLabelRaw;
    return template
      .replaceFirst(r'$tabIndex', _decimalFormat.format(tabIndex))
      .replaceFirst(r'$tabCount', _decimalFormat.format(tabCount));
  }

  @override
  String timerPickerHour(int hour) {
    return _singleDigitHourFormat.format(DateTime.utc(0, 0, 0, hour));
  }

  @override
  String timerPickerMinute(int minute) {
    return _singleDigitMinuteFormat.format(DateTime.utc(0, 0, 0, 0, minute));
  }

  @override
  String timerPickerSecond(int second) {
    return _singleDigitSecondFormat.format(DateTime.utc(0, 0, 0, 0, 0, second));
  }

  @protected
  String? get timerPickerHourLabelZero => null;
  @protected
  String? get timerPickerHourLabelOne => null;
  @protected
  String? get timerPickerHourLabelTwo => null;
  @protected
  String? get timerPickerHourLabelFew => null;
  @protected
  String? get timerPickerHourLabelMany => null;
  @protected
  String? get timerPickerHourLabelOther;

  @override
  String? timerPickerHourLabel(int hour) {
    return intl.Intl.pluralLogic(
      hour,
      zero: timerPickerHourLabelZero,
      one: timerPickerHourLabelOne,
      two: timerPickerHourLabelTwo,
      few: timerPickerHourLabelFew,
      many: timerPickerHourLabelMany,
      other: timerPickerHourLabelOther,
      locale: _localeName,
    )?.replaceFirst(r'$hour', _decimalFormat.format(hour));
  }

  @override
  List<String> get timerPickerHourLabels => <String>[
    if (timerPickerHourLabelZero != null) timerPickerHourLabelZero!,
    if (timerPickerHourLabelOne != null) timerPickerHourLabelOne!,
    if (timerPickerHourLabelTwo != null) timerPickerHourLabelTwo!,
    if (timerPickerHourLabelFew != null) timerPickerHourLabelFew!,
    if (timerPickerHourLabelMany != null) timerPickerHourLabelMany!,
    if (timerPickerHourLabelOther != null) timerPickerHourLabelOther!,
  ];

  @protected
  String? get timerPickerMinuteLabelZero => null;
  @protected
  String? get timerPickerMinuteLabelOne => null;
  @protected
  String? get timerPickerMinuteLabelTwo => null;
  @protected
  String? get timerPickerMinuteLabelFew => null;
  @protected
  String? get timerPickerMinuteLabelMany => null;
  @protected
  String? get timerPickerMinuteLabelOther;

  @override
  String? timerPickerMinuteLabel(int minute) {
    return intl.Intl.pluralLogic(
      minute,
      zero: timerPickerMinuteLabelZero,
      one: timerPickerMinuteLabelOne,
      two: timerPickerMinuteLabelTwo,
      few: timerPickerMinuteLabelFew,
      many: timerPickerMinuteLabelMany,
      other: timerPickerMinuteLabelOther,
      locale: _localeName,
    )?.replaceFirst(r'$minute', _decimalFormat.format(minute));
  }

  @override
  List<String> get timerPickerMinuteLabels => <String>[
    if (timerPickerMinuteLabelZero != null) timerPickerMinuteLabelZero!,
    if (timerPickerMinuteLabelOne != null) timerPickerMinuteLabelOne!,
    if (timerPickerMinuteLabelTwo != null) timerPickerMinuteLabelTwo!,
    if (timerPickerMinuteLabelFew != null) timerPickerMinuteLabelFew!,
    if (timerPickerMinuteLabelMany != null) timerPickerMinuteLabelMany!,
    if (timerPickerMinuteLabelOther != null) timerPickerMinuteLabelOther!,
  ];

  @protected
  String? get timerPickerSecondLabelZero => null;
  @protected
  String? get timerPickerSecondLabelOne => null;
  @protected
  String? get timerPickerSecondLabelTwo => null;
  @protected
  String? get timerPickerSecondLabelFew => null;
  @protected
  String? get timerPickerSecondLabelMany => null;
  @protected
  String? get timerPickerSecondLabelOther;

  @override
  String? timerPickerSecondLabel(int second) {
    return intl.Intl.pluralLogic(
      second,
      zero: timerPickerSecondLabelZero,
      one: timerPickerSecondLabelOne,
      two: timerPickerSecondLabelTwo,
      few: timerPickerSecondLabelFew,
      many: timerPickerSecondLabelMany,
      other: timerPickerSecondLabelOther,
      locale: _localeName,
    )?.replaceFirst(r'$second', _decimalFormat.format(second));
  }

  @override
  List<String> get timerPickerSecondLabels => <String>[
    if (timerPickerSecondLabelZero != null) timerPickerSecondLabelZero!,
    if (timerPickerSecondLabelOne != null) timerPickerSecondLabelOne!,
    if (timerPickerSecondLabelTwo != null) timerPickerSecondLabelTwo!,
    if (timerPickerSecondLabelFew != null) timerPickerSecondLabelFew!,
    if (timerPickerSecondLabelMany != null) timerPickerSecondLabelMany!,
    if (timerPickerSecondLabelOther != null) timerPickerSecondLabelOther!,
  ];

  static const LocalizationsDelegate<CupertinoLocalizations> delegate = _GlobalCupertinoLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> delegates = <LocalizationsDelegate<dynamic>>[
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];
}

class _GlobalCupertinoLocalizationsDelegate extends LocalizationsDelegate<CupertinoLocalizations> {
  const _GlobalCupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => kCupertinoSupportedLanguages.contains(locale.languageCode);

  static final Map<Locale, Future<CupertinoLocalizations>> _loadedTranslations = <Locale, Future<CupertinoLocalizations>>{};

  @override
  Future<CupertinoLocalizations> load(Locale locale) {
    assert(isSupported(locale));
    return _loadedTranslations.putIfAbsent(locale, () {
      util.loadDateIntlDataIfNotLoaded();

      final String localeName = intl.Intl.canonicalizedLocale(locale.toString());
      assert(
        locale.toString() == localeName,
        'Flutter does not support the non-standard locale form $locale (which '
        'might be $localeName',
      );

      late intl.DateFormat fullYearFormat;
      late intl.DateFormat dayFormat;
      late intl.DateFormat mediumDateFormat;
      // We don't want any additional decoration here. The am/pm is handled in
      // the date picker. We just want an hour number localized.
      late intl.DateFormat singleDigitHourFormat;
      late intl.DateFormat singleDigitMinuteFormat;
      late intl.DateFormat doubleDigitMinuteFormat;
      late intl.DateFormat singleDigitSecondFormat;
      late intl.NumberFormat decimalFormat;

      void loadFormats(String? locale) {
        fullYearFormat = intl.DateFormat.y(locale);
        dayFormat = intl.DateFormat.d(locale);
        mediumDateFormat = intl.DateFormat.MMMEd(locale);
        // TODO(xster): fix when https://github.com/dart-lang/intl/issues/207 is resolved.
        singleDigitHourFormat = intl.DateFormat('HH', locale);
        singleDigitMinuteFormat = intl.DateFormat.m(locale);
        doubleDigitMinuteFormat = intl.DateFormat('mm', locale);
        singleDigitSecondFormat = intl.DateFormat.s(locale);
        decimalFormat = intl.NumberFormat.decimalPattern(locale);
      }

      if (intl.DateFormat.localeExists(localeName)) {
        loadFormats(localeName);
      } else if (intl.DateFormat.localeExists(locale.languageCode)) {
        loadFormats(locale.languageCode);
      } else {
        loadFormats(null);
      }

      return SynchronousFuture<CupertinoLocalizations>(getCupertinoTranslation(
        locale,
        fullYearFormat,
        dayFormat,
        mediumDateFormat,
        singleDigitHourFormat,
        singleDigitMinuteFormat,
        doubleDigitMinuteFormat,
        singleDigitSecondFormat,
        decimalFormat,
      )!);
    });
  }

  @override
  bool shouldReload(_GlobalCupertinoLocalizationsDelegate old) => false;

  @override
  String toString() => 'GlobalCupertinoLocalizations.delegate(${kCupertinoSupportedLanguages.length} locales)';
}