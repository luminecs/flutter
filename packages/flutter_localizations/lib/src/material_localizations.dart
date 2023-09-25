
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import 'cupertino_localizations.dart';
import 'l10n/generated_material_localizations.dart';
import 'utils/date_localizations.dart' as util;
import 'widgets_localizations.dart';

// Examples can assume:
// import 'package:flutter_localizations/flutter_localizations.dart';
// import 'package:flutter/material.dart';

abstract class GlobalMaterialLocalizations implements MaterialLocalizations {
  const GlobalMaterialLocalizations({
    required String localeName,
    required intl.DateFormat fullYearFormat,
    required intl.DateFormat compactDateFormat,
    required intl.DateFormat shortDateFormat,
    required intl.DateFormat mediumDateFormat,
    required intl.DateFormat longDateFormat,
    required intl.DateFormat yearMonthFormat,
    required intl.DateFormat shortMonthDayFormat,
    required intl.NumberFormat decimalFormat,
    required intl.NumberFormat twoDigitZeroPaddedFormat,
  }) : _localeName = localeName,
       _fullYearFormat = fullYearFormat,
       _compactDateFormat = compactDateFormat,
       _shortDateFormat = shortDateFormat,
       _mediumDateFormat = mediumDateFormat,
       _longDateFormat = longDateFormat,
       _yearMonthFormat = yearMonthFormat,
       _shortMonthDayFormat = shortMonthDayFormat,
       _decimalFormat = decimalFormat,
       _twoDigitZeroPaddedFormat = twoDigitZeroPaddedFormat;

  final String _localeName;
  final intl.DateFormat _fullYearFormat;
  final intl.DateFormat _compactDateFormat;
  final intl.DateFormat _shortDateFormat;
  final intl.DateFormat _mediumDateFormat;
  final intl.DateFormat _longDateFormat;
  final intl.DateFormat _yearMonthFormat;
  final intl.DateFormat _shortMonthDayFormat;
  final intl.NumberFormat _decimalFormat;
  final intl.NumberFormat _twoDigitZeroPaddedFormat;

  @override
  String formatHour(TimeOfDay timeOfDay, { bool alwaysUse24HourFormat = false }) {
    switch (hourFormat(of: timeOfDayFormat(alwaysUse24HourFormat: alwaysUse24HourFormat))) {
      case HourFormat.HH:
        return _twoDigitZeroPaddedFormat.format(timeOfDay.hour);
      case HourFormat.H:
        return formatDecimal(timeOfDay.hour);
      case HourFormat.h:
        final int hour = timeOfDay.hourOfPeriod;
        return formatDecimal(hour == 0 ? 12 : hour);
    }
  }

  @override
  String formatMinute(TimeOfDay timeOfDay) {
    return _twoDigitZeroPaddedFormat.format(timeOfDay.minute);
  }

  @override
  String formatYear(DateTime date) {
    return _fullYearFormat.format(date);
  }

  @override
  String formatCompactDate(DateTime date) {
    return _compactDateFormat.format(date);
  }

  @override
  String formatShortDate(DateTime date) {
    return _shortDateFormat.format(date);
  }

  @override
  String formatMediumDate(DateTime date) {
    return _mediumDateFormat.format(date);
  }

  @override
  String formatFullDate(DateTime date) {
    return _longDateFormat.format(date);
  }

  @override
  String formatMonthYear(DateTime date) {
    return _yearMonthFormat.format(date);
  }

  @override
  String formatShortMonthDay(DateTime date) {
    return _shortMonthDayFormat.format(date);
  }

  @override
  DateTime? parseCompactDate(String? inputString) {
    try {
      return inputString != null ? _compactDateFormat.parseStrict(inputString) : null;
    } on FormatException {
      return null;
    }
  }

  @override
  List<String> get narrowWeekdays {
    return _longDateFormat.dateSymbols.NARROWWEEKDAYS;
  }

  @override
  int get firstDayOfWeekIndex => (_longDateFormat.dateSymbols.FIRSTDAYOFWEEK + 1) % 7;

  @override
  String formatDecimal(int number) {
    return _decimalFormat.format(number);
  }

  @override
  String formatTimeOfDay(TimeOfDay timeOfDay, { bool alwaysUse24HourFormat = false }) {
    // Not using intl.DateFormat for two reasons:
    //
    // - DateFormat supports more formats than our material time picker does,
    //   and we want to be consistent across time picker format and the string
    //   formatting of the time of day.
    // - DateFormat operates on DateTime, which is sensitive to time eras and
    //   time zones, while here we want to format hour and minute within one day
    //   no matter what date the day falls on.
    final String hour = formatHour(timeOfDay, alwaysUse24HourFormat: alwaysUse24HourFormat);
    final String minute = formatMinute(timeOfDay);
    switch (timeOfDayFormat(alwaysUse24HourFormat: alwaysUse24HourFormat)) {
      case TimeOfDayFormat.h_colon_mm_space_a:
        return '$hour:$minute ${_formatDayPeriod(timeOfDay)!}';
      case TimeOfDayFormat.H_colon_mm:
      case TimeOfDayFormat.HH_colon_mm:
        return '$hour:$minute';
      case TimeOfDayFormat.HH_dot_mm:
        return '$hour.$minute';
      case TimeOfDayFormat.a_space_h_colon_mm:
        return '${_formatDayPeriod(timeOfDay)!} $hour:$minute';
      case TimeOfDayFormat.frenchCanadian:
        return '$hour h $minute';
    }
  }

  String? _formatDayPeriod(TimeOfDay timeOfDay) {
    switch (timeOfDay.period) {
      case DayPeriod.am:
        return anteMeridiemAbbreviation;
      case DayPeriod.pm:
        return postMeridiemAbbreviation;
    }
  }

  @protected
  String get dateRangeStartDateSemanticLabelRaw;

  @override
  String dateRangeStartDateSemanticLabel(String formattedDate) {
    return dateRangeStartDateSemanticLabelRaw.replaceFirst(r'$fullDate', formattedDate);
  }

  @protected
  String get dateRangeEndDateSemanticLabelRaw;

  @override
  String dateRangeEndDateSemanticLabel(String formattedDate) {
    return dateRangeEndDateSemanticLabelRaw.replaceFirst(r'$fullDate', formattedDate);
  }

  @protected
  String get scrimOnTapHintRaw;

  @override
  String scrimOnTapHint(String modalRouteContentName) {
    final String text = scrimOnTapHintRaw;
    return text.replaceFirst(r'$modalRouteContentName', modalRouteContentName);
  }

  @protected
  String get aboutListTileTitleRaw;

  @override
  String aboutListTileTitle(String applicationName) {
    final String text = aboutListTileTitleRaw;
    return text.replaceFirst(r'$applicationName', applicationName);
  }

  @protected
  String get pageRowsInfoTitleApproximateRaw;

  @protected
  String get pageRowsInfoTitleRaw;

  @override
  String pageRowsInfoTitle(int firstRow, int lastRow, int rowCount, bool rowCountIsApproximate) {
    String? text = rowCountIsApproximate ? pageRowsInfoTitleApproximateRaw : null;
    text ??= pageRowsInfoTitleRaw;
    return text
      .replaceFirst(r'$firstRow', formatDecimal(firstRow))
      .replaceFirst(r'$lastRow', formatDecimal(lastRow))
      .replaceFirst(r'$rowCount', formatDecimal(rowCount));
  }

  @protected
  String get tabLabelRaw;

  @override
  String tabLabel({ required int tabIndex, required int tabCount }) {
    assert(tabIndex >= 1);
    assert(tabCount >= 1);
    final String template = tabLabelRaw;
    return template
      .replaceFirst(r'$tabIndex', formatDecimal(tabIndex))
      .replaceFirst(r'$tabCount', formatDecimal(tabCount));
  }

  @protected
  String? get selectedRowCountTitleZero => null;

  @protected
  String? get selectedRowCountTitleOne => null;

  @protected
  String? get selectedRowCountTitleTwo => null;

  @protected
  String? get selectedRowCountTitleFew => null;

  @protected
  String? get selectedRowCountTitleMany => null;

  @protected
  String get selectedRowCountTitleOther;

  @override
  String selectedRowCountTitle(int selectedRowCount) {
    return intl.Intl.pluralLogic(
      selectedRowCount,
      zero: selectedRowCountTitleZero,
      one: selectedRowCountTitleOne,
      two: selectedRowCountTitleTwo,
      few: selectedRowCountTitleFew,
      many: selectedRowCountTitleMany,
      other: selectedRowCountTitleOther,
      locale: _localeName,
    ).replaceFirst(r'$selectedRowCount', formatDecimal(selectedRowCount));
  }

  @protected
  TimeOfDayFormat get timeOfDayFormatRaw;

  @override
  TimeOfDayFormat timeOfDayFormat({ bool alwaysUse24HourFormat = false }) {
    if (alwaysUse24HourFormat) {
      return _get24HourVersionOf(timeOfDayFormatRaw);
    }
    return timeOfDayFormatRaw;
  }

  @protected
  String? get licensesPackageDetailTextZero => null;

  @protected
  String? get licensesPackageDetailTextOne => null;

  @protected
  String? get licensesPackageDetailTextTwo => null;

  @protected
  String? get licensesPackageDetailTextMany => null;

  @protected
  String? get licensesPackageDetailTextFew => null;

  @protected
  String get licensesPackageDetailTextOther;

  @override
  String licensesPackageDetailText(int licenseCount) {
    return intl.Intl.pluralLogic(
      licenseCount,
      zero: licensesPackageDetailTextZero,
      one: licensesPackageDetailTextOne,
      two: licensesPackageDetailTextTwo,
      many: licensesPackageDetailTextMany,
      few: licensesPackageDetailTextFew,
      other: licensesPackageDetailTextOther,
      locale: _localeName,
    ).replaceFirst(r'$licenseCount', formatDecimal(licenseCount));
  }

  @protected
  String? get remainingTextFieldCharacterCountZero => null;

  @protected
  String? get remainingTextFieldCharacterCountOne => null;

  @protected
  String? get remainingTextFieldCharacterCountTwo => null;

  @protected
  String? get remainingTextFieldCharacterCountMany => null;

  @protected
  String? get remainingTextFieldCharacterCountFew => null;

  @protected
  String get remainingTextFieldCharacterCountOther;

  @override
  String remainingTextFieldCharacterCount(int remaining) {
    return intl.Intl.pluralLogic(
      remaining,
      zero: remainingTextFieldCharacterCountZero,
      one: remainingTextFieldCharacterCountOne,
      two: remainingTextFieldCharacterCountTwo,
      many: remainingTextFieldCharacterCountMany,
      few: remainingTextFieldCharacterCountFew,
      other: remainingTextFieldCharacterCountOther,
      locale: _localeName,
    ).replaceFirst(r'$remainingCount', formatDecimal(remaining));
  }

  @override
  ScriptCategory get scriptCategory;

  static const LocalizationsDelegate<MaterialLocalizations> delegate = _MaterialLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> delegates = <LocalizationsDelegate<dynamic>>[
    GlobalCupertinoLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];
}

TimeOfDayFormat _get24HourVersionOf(TimeOfDayFormat original) {
  switch (original) {
    case TimeOfDayFormat.HH_colon_mm:
    case TimeOfDayFormat.HH_dot_mm:
    case TimeOfDayFormat.frenchCanadian:
    case TimeOfDayFormat.H_colon_mm:
      return original;
    case TimeOfDayFormat.h_colon_mm_space_a:
    case TimeOfDayFormat.a_space_h_colon_mm:
      return TimeOfDayFormat.HH_colon_mm;
  }
}

class _MaterialLocalizationsDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _MaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => kMaterialSupportedLanguages.contains(locale.languageCode);

  static final Map<Locale, Future<MaterialLocalizations>> _loadedTranslations = <Locale, Future<MaterialLocalizations>>{};

  @override
  Future<MaterialLocalizations> load(Locale locale) {
    assert(isSupported(locale));
    return _loadedTranslations.putIfAbsent(locale, () {
      util.loadDateIntlDataIfNotLoaded();

      final String localeName = intl.Intl.canonicalizedLocale(locale.toString());
      assert(
        locale.toString() == localeName,
        'Flutter does not support the non-standard locale form $locale (which '
        'might be $localeName',
      );

      intl.DateFormat fullYearFormat;
      intl.DateFormat compactDateFormat;
      intl.DateFormat shortDateFormat;
      intl.DateFormat mediumDateFormat;
      intl.DateFormat longDateFormat;
      intl.DateFormat yearMonthFormat;
      intl.DateFormat shortMonthDayFormat;
      if (intl.DateFormat.localeExists(localeName)) {
        fullYearFormat = intl.DateFormat.y(localeName);
        compactDateFormat = intl.DateFormat.yMd(localeName);
        shortDateFormat = intl.DateFormat.yMMMd(localeName);
        mediumDateFormat = intl.DateFormat.MMMEd(localeName);
        longDateFormat = intl.DateFormat.yMMMMEEEEd(localeName);
        yearMonthFormat = intl.DateFormat.yMMMM(localeName);
        shortMonthDayFormat = intl.DateFormat.MMMd(localeName);
      } else if (intl.DateFormat.localeExists(locale.languageCode)) {
        fullYearFormat = intl.DateFormat.y(locale.languageCode);
        compactDateFormat = intl.DateFormat.yMd(locale.languageCode);
        shortDateFormat = intl.DateFormat.yMMMd(locale.languageCode);
        mediumDateFormat = intl.DateFormat.MMMEd(locale.languageCode);
        longDateFormat = intl.DateFormat.yMMMMEEEEd(locale.languageCode);
        yearMonthFormat = intl.DateFormat.yMMMM(locale.languageCode);
        shortMonthDayFormat = intl.DateFormat.MMMd(locale.languageCode);
      } else {
        fullYearFormat = intl.DateFormat.y();
        compactDateFormat = intl.DateFormat.yMd();
        shortDateFormat = intl.DateFormat.yMMMd();
        mediumDateFormat = intl.DateFormat.MMMEd();
        longDateFormat = intl.DateFormat.yMMMMEEEEd();
        yearMonthFormat = intl.DateFormat.yMMMM();
        shortMonthDayFormat = intl.DateFormat.MMMd();
      }

      intl.NumberFormat decimalFormat;
      intl.NumberFormat twoDigitZeroPaddedFormat;
      if (intl.NumberFormat.localeExists(localeName)) {
        decimalFormat = intl.NumberFormat.decimalPattern(localeName);
        twoDigitZeroPaddedFormat = intl.NumberFormat('00', localeName);
      } else if (intl.NumberFormat.localeExists(locale.languageCode)) {
        decimalFormat = intl.NumberFormat.decimalPattern(locale.languageCode);
        twoDigitZeroPaddedFormat = intl.NumberFormat('00', locale.languageCode);
      } else {
        decimalFormat = intl.NumberFormat.decimalPattern();
        twoDigitZeroPaddedFormat = intl.NumberFormat('00');
      }

      return SynchronousFuture<MaterialLocalizations>(getMaterialTranslation(
        locale,
        fullYearFormat,
        compactDateFormat,
        shortDateFormat,
        mediumDateFormat,
        longDateFormat,
        yearMonthFormat,
        shortMonthDayFormat,
        decimalFormat,
        twoDigitZeroPaddedFormat,
      )!);
    });
  }

  @override
  bool shouldReload(_MaterialLocalizationsDelegate old) => false;

  @override
  String toString() => 'GlobalMaterialLocalizations.delegate(${kMaterialSupportedLanguages.length} locales)';
}