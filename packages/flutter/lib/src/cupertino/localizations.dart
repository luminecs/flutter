import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'debug.dart';

// Examples can assume:
// late BuildContext context;

enum DatePickerDateTimeOrder {
  date_time_dayPeriod,
  date_dayPeriod_time,
  time_dayPeriod_date,
  dayPeriod_time_date,
}

enum DatePickerDateOrder {
  dmy,
  mdy,
  ymd,
  ydm,
}

abstract class CupertinoLocalizations {
  // The global version uses date symbols data from the intl package.
  String datePickerYear(int yearIndex);

  // The global version uses date symbols data from the intl package.
  String datePickerMonth(int monthIndex);

  // The global version uses date symbols data from the intl package.
  String datePickerStandaloneMonth(int monthIndex);

  // The global version uses date symbols data from the intl package.
  String datePickerDayOfMonth(int dayIndex, [int? weekDay]);

  // The global version is based on intl package's DateFormat.MMMEd.
  String datePickerMediumDate(DateTime date);

  // The global version uses date symbols data from the intl package.
  String datePickerHour(int hour);

  // The global version uses the translated string from the arb file.
  String? datePickerHourSemanticsLabel(int hour);

  // The global version uses date symbols data from the intl package.
  String datePickerMinute(int minute);

  // The global version uses the translated string from the arb file.
  String? datePickerMinuteSemanticsLabel(int minute);

  // The global version uses the translated string from the arb file.
  DatePickerDateOrder get datePickerDateOrder;

  // The global version uses the translated string from the arb file.
  DatePickerDateTimeOrder get datePickerDateTimeOrder;

  // The global version uses the translated string from the arb file.
  String get anteMeridiemAbbreviation;

  // The global version uses the translated string from the arb file.
  String get postMeridiemAbbreviation;

  // The global version uses the translated string from the arb file.
  String get todayLabel;

  // The global version uses the translated string from the arb file.
  String get alertDialogLabel;

  String tabSemanticsLabel({required int tabIndex, required int tabCount});

  // The global version uses date symbols data from the intl package.
  String timerPickerHour(int hour);

  // The global version uses date symbols data from the intl package.
  String timerPickerMinute(int minute);

  // The global version uses date symbols data from the intl package.
  String timerPickerSecond(int second);

  // The global version uses the translated string from the arb file.
  String? timerPickerHourLabel(int hour);

  List<String> get timerPickerHourLabels;

  // The global version uses the translated string from the arb file.
  String? timerPickerMinuteLabel(int minute);

  List<String> get timerPickerMinuteLabels;

  // The global version uses the translated string from the arb file.
  String? timerPickerSecondLabel(int second);

  List<String> get timerPickerSecondLabels;

  // The global version uses the translated string from the arb file.
  String get cutButtonLabel;

  // The global version uses the translated string from the arb file.
  String get copyButtonLabel;

  // The global version uses the translated string from the arb file.
  String get pasteButtonLabel;

  // The global version uses the translated string from the arb file.
  String get noSpellCheckReplacementsLabel;

  // The global version uses the translated string from the arb file.
  String get selectAllButtonLabel;

  // The global version uses the translated string from the arb file.
  String get lookUpButtonLabel;

  // The global version uses the translated string from the arb file.
  String get searchWebButtonLabel;

  // The global version uses the translated string from the arb file.
  String get shareButtonLabel;

  // The global version uses the translated string from the arb file.
  String get searchTextFieldPlaceholderLabel;

  String get modalBarrierDismissLabel;

  String get menuDismissLabel;

  static CupertinoLocalizations of(BuildContext context) {
    assert(debugCheckHasCupertinoLocalizations(context));
    return Localizations.of<CupertinoLocalizations>(
        context, CupertinoLocalizations)!;
  }
}

class _CupertinoLocalizationsDelegate
    extends LocalizationsDelegate<CupertinoLocalizations> {
  const _CupertinoLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  Future<CupertinoLocalizations> load(Locale locale) =>
      DefaultCupertinoLocalizations.load(locale);

  @override
  bool shouldReload(_CupertinoLocalizationsDelegate old) => false;

  @override
  String toString() => 'DefaultCupertinoLocalizations.delegate(en_US)';
}

class DefaultCupertinoLocalizations implements CupertinoLocalizations {
  const DefaultCupertinoLocalizations();

  static const List<String> shortWeekdays = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  static const List<String> _shortMonths = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static const List<String> _months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  String datePickerYear(int yearIndex) => yearIndex.toString();

  @override
  String datePickerMonth(int monthIndex) => _months[monthIndex - 1];

  @override
  String datePickerStandaloneMonth(int monthIndex) => _months[monthIndex - 1];

  @override
  String datePickerDayOfMonth(int dayIndex, [int? weekDay]) {
    if (weekDay != null) {
      return ' ${shortWeekdays[weekDay - DateTime.monday]} $dayIndex ';
    }

    return dayIndex.toString();
  }

  @override
  String datePickerHour(int hour) => hour.toString();

  @override
  String datePickerHourSemanticsLabel(int hour) => "$hour o'clock";

  @override
  String datePickerMinute(int minute) => minute.toString().padLeft(2, '0');

  @override
  String datePickerMinuteSemanticsLabel(int minute) {
    if (minute == 1) {
      return '1 minute';
    }
    return '$minute minutes';
  }

  @override
  String datePickerMediumDate(DateTime date) {
    return '${shortWeekdays[date.weekday - DateTime.monday]} '
        '${_shortMonths[date.month - DateTime.january]} '
        '${date.day.toString().padRight(2)}';
  }

  @override
  DatePickerDateOrder get datePickerDateOrder => DatePickerDateOrder.mdy;

  @override
  DatePickerDateTimeOrder get datePickerDateTimeOrder =>
      DatePickerDateTimeOrder.date_time_dayPeriod;

  @override
  String get anteMeridiemAbbreviation => 'AM';

  @override
  String get postMeridiemAbbreviation => 'PM';

  @override
  String get todayLabel => 'Today';

  @override
  String get alertDialogLabel => 'Alert';

  @override
  String tabSemanticsLabel({required int tabIndex, required int tabCount}) {
    assert(tabIndex >= 1);
    assert(tabCount >= 1);
    return 'Tab $tabIndex of $tabCount';
  }

  @override
  String timerPickerHour(int hour) => hour.toString();

  @override
  String timerPickerMinute(int minute) => minute.toString();

  @override
  String timerPickerSecond(int second) => second.toString();

  @override
  String timerPickerHourLabel(int hour) => hour == 1 ? 'hour' : 'hours';

  @override
  List<String> get timerPickerHourLabels => const <String>['hour', 'hours'];

  @override
  String timerPickerMinuteLabel(int minute) => 'min.';

  @override
  List<String> get timerPickerMinuteLabels => const <String>['min.'];

  @override
  String timerPickerSecondLabel(int second) => 'sec.';

  @override
  List<String> get timerPickerSecondLabels => const <String>['sec.'];

  @override
  String get cutButtonLabel => 'Cut';

  @override
  String get copyButtonLabel => 'Copy';

  @override
  String get pasteButtonLabel => 'Paste';

  @override
  String get noSpellCheckReplacementsLabel => 'No Replacements Found';

  @override
  String get selectAllButtonLabel => 'Select All';

  @override
  String get lookUpButtonLabel => 'Look Up';

  @override
  String get searchWebButtonLabel => 'Search Web';

  @override
  String get shareButtonLabel => 'Share...';

  @override
  String get searchTextFieldPlaceholderLabel => 'Search';

  @override
  String get modalBarrierDismissLabel => 'Dismiss';

  @override
  String get menuDismissLabel => 'Dismiss menu';

  static Future<CupertinoLocalizations> load(Locale locale) {
    return SynchronousFuture<CupertinoLocalizations>(
        const DefaultCupertinoLocalizations());
  }

  static const LocalizationsDelegate<CupertinoLocalizations> delegate =
      _CupertinoLocalizationsDelegate();
}
