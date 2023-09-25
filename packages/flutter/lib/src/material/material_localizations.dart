// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'debug.dart';
import 'time.dart';
import 'typography.dart';

// Examples can assume:
// late BuildContext context;

// ADDING A NEW STRING
//
// Please refer to instructions in this markdown file
// (packages/flutter_localizations/README.md)

abstract class MaterialLocalizations {
  String get openAppDrawerTooltip;

  String get backButtonTooltip;

  String get closeButtonTooltip;

  String get deleteButtonTooltip;

  String get moreButtonTooltip;

  String get nextMonthTooltip;

  String get previousMonthTooltip;

  String get firstPageTooltip;

  String get lastPageTooltip;

  String get nextPageTooltip;

  String get previousPageTooltip;

  String get showMenuTooltip;

  String aboutListTileTitle(String applicationName);

  String get licensesPageTitle;

  String licensesPackageDetailText(int licenseCount);

  String pageRowsInfoTitle(int firstRow, int lastRow, int rowCount, bool rowCountIsApproximate);

  String get rowsPerPageTitle;

  String tabLabel({ required int tabIndex, required int tabCount });

  String selectedRowCountTitle(int selectedRowCount);

  String get cancelButtonLabel;

  String get closeButtonLabel;

  String get continueButtonLabel;

  String get copyButtonLabel;

  String get cutButtonLabel;

  String get scanTextButtonLabel;

  String get okButtonLabel;

  String get pasteButtonLabel;

  String get selectAllButtonLabel;

  String get lookUpButtonLabel;

  String get searchWebButtonLabel;

  String get shareButtonLabel;

  String get viewLicensesButtonLabel;

  String get anteMeridiemAbbreviation;

  String get postMeridiemAbbreviation;

  String get timePickerHourModeAnnouncement;

  String get timePickerMinuteModeAnnouncement;

  String get modalBarrierDismissLabel;

  String get menuDismissLabel;

  String get drawerLabel;

  String get popupMenuLabel;

  String get menuBarMenuLabel;

  String get dialogLabel;

  String get alertDialogLabel;

  String get searchFieldLabel;

  String get currentDateLabel;

  String get scrimLabel;

  String get bottomSheetLabel;

  String scrimOnTapHint(String modalRouteContentName);

  TimeOfDayFormat timeOfDayFormat({ bool alwaysUse24HourFormat = false });

  ScriptCategory get scriptCategory;

  String formatDecimal(int number);

  String formatHour(TimeOfDay timeOfDay, { bool alwaysUse24HourFormat = false });

  String formatMinute(TimeOfDay timeOfDay);

  String formatTimeOfDay(TimeOfDay timeOfDay, { bool alwaysUse24HourFormat = false });

  String formatYear(DateTime date);

  String formatCompactDate(DateTime date);

  String formatShortDate(DateTime date);

  String formatMediumDate(DateTime date);

  String formatFullDate(DateTime date);

  String formatMonthYear(DateTime date);

  String formatShortMonthDay(DateTime date);

  DateTime? parseCompactDate(String? inputString);

  List<String> get narrowWeekdays;

  int get firstDayOfWeekIndex;

  String get dateSeparator;

  String get dateHelpText;

  String get selectYearSemanticsLabel;

  String get unspecifiedDate;

  String get unspecifiedDateRange;

  String get dateInputLabel;

  String get dateRangeStartLabel;

  String get dateRangeEndLabel;

  String dateRangeStartDateSemanticLabel(String formattedDate);

  String dateRangeEndDateSemanticLabel(String formattedDate);

  String get invalidDateFormatLabel;

  String get invalidDateRangeLabel;

  String get dateOutOfRangeLabel;

  String get saveButtonLabel;

  String get datePickerHelpText;

  String get dateRangePickerHelpText;

  String get calendarModeButtonLabel;

  String get inputDateModeButtonLabel;

  String get timePickerDialHelpText;

  String get timePickerInputHelpText;

  String get timePickerHourLabel;

  String get timePickerMinuteLabel;

  String get invalidTimeLabel;

  String get dialModeButtonLabel;

  String get inputTimeModeButtonLabel;

  String get signedInLabel;

  String get hideAccountsLabel;

  String get showAccountsLabel;

  @Deprecated(
    'Use the reorderItemToStart from WidgetsLocalizations instead. '
    'This feature was deprecated after v3.10.0-2.0.pre.'
  )
  String get reorderItemToStart;

  @Deprecated(
    'Use the reorderItemToEnd from WidgetsLocalizations instead. '
    'This feature was deprecated after v3.10.0-2.0.pre.'
  )
  String get reorderItemToEnd;

  @Deprecated(
    'Use the reorderItemUp from WidgetsLocalizations instead. '
    'This feature was deprecated after v3.10.0-2.0.pre.'
  )
  String get reorderItemUp;

  @Deprecated(
    'Use the reorderItemDown from WidgetsLocalizations instead. '
    'This feature was deprecated after v3.10.0-2.0.pre.'
  )
  String get reorderItemDown;

  @Deprecated(
    'Use the reorderItemLeft from WidgetsLocalizations instead. '
    'This feature was deprecated after v3.10.0-2.0.pre.'
  )
  String get reorderItemLeft;

  @Deprecated(
    'Use the reorderItemRight from WidgetsLocalizations instead. '
    'This feature was deprecated after v3.10.0-2.0.pre.'
  )
  String get reorderItemRight;

  String get expandedIconTapHint => 'Collapse';

  String get collapsedIconTapHint => 'Expand';

  String get expansionTileExpandedHint => 'double tap to collapse';

  String get expansionTileCollapsedHint => 'double tap to expand';

  String get expansionTileExpandedTapHint => 'Collapse';

  String get expansionTileCollapsedTapHint => 'Expand for more details';

  String get expandedHint => 'Collapsed';

  String get collapsedHint => 'Expanded';

  String remainingTextFieldCharacterCount(int remaining);

  String get refreshIndicatorSemanticLabel;

  String get keyboardKeyAlt;

  String get keyboardKeyAltGraph;

  String get keyboardKeyBackspace;

  String get keyboardKeyCapsLock;

  String get keyboardKeyChannelDown;

  String get keyboardKeyChannelUp;

  String get keyboardKeyControl;

  String get keyboardKeyDelete;

  String get keyboardKeyEject;

  String get keyboardKeyEnd;

  String get keyboardKeyEscape;

  String get keyboardKeyFn;

  String get keyboardKeyHome;

  String get keyboardKeyInsert;

  String get keyboardKeyMeta;

  String get keyboardKeyMetaMacOs;

  String get keyboardKeyMetaWindows;

  String get keyboardKeyNumLock;

  String get keyboardKeyNumpad1;

  String get keyboardKeyNumpad2;

  String get keyboardKeyNumpad3;

  String get keyboardKeyNumpad4;

  String get keyboardKeyNumpad5;

  String get keyboardKeyNumpad6;

  String get keyboardKeyNumpad7;

  String get keyboardKeyNumpad8;

  String get keyboardKeyNumpad9;

  String get keyboardKeyNumpad0;

  String get keyboardKeyNumpadAdd;

  String get keyboardKeyNumpadComma;

  String get keyboardKeyNumpadDecimal;

  String get keyboardKeyNumpadDivide;

  String get keyboardKeyNumpadEnter;

  String get keyboardKeyNumpadEqual;

  String get keyboardKeyNumpadMultiply;

  String get keyboardKeyNumpadParenLeft;

  String get keyboardKeyNumpadParenRight;

  String get keyboardKeyNumpadSubtract;

  String get keyboardKeyPageDown;

  String get keyboardKeyPageUp;

  String get keyboardKeyPower;

  String get keyboardKeyPowerOff;

  String get keyboardKeyPrintScreen;

  String get keyboardKeyScrollLock;

  String get keyboardKeySelect;

  String get keyboardKeyShift;

  String get keyboardKeySpace;

  static MaterialLocalizations of(BuildContext context) {
    assert(debugCheckHasMaterialLocalizations(context));
    return Localizations.of<MaterialLocalizations>(context, MaterialLocalizations)!;
  }
}

class _MaterialLocalizationsDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _MaterialLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => locale.languageCode == 'en';

  @override
  Future<MaterialLocalizations> load(Locale locale) => DefaultMaterialLocalizations.load(locale);

  @override
  bool shouldReload(_MaterialLocalizationsDelegate old) => false;

  @override
  String toString() => 'DefaultMaterialLocalizations.delegate(en_US)';
}

class DefaultMaterialLocalizations implements MaterialLocalizations {
  const DefaultMaterialLocalizations();

  // Ordered to match DateTime.monday=1, DateTime.sunday=6
  static const List<String> _shortWeekdays = <String>[
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];

  // Ordered to match DateTime.monday=1, DateTime.sunday=6
  static const List<String> _weekdays = <String>[
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const List<String> _narrowWeekdays = <String>[
    'S',
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
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

  int _getDaysInMonth(int year, int month) {
    if (month == DateTime.february) {
      final bool isLeapYear = (year % 4 == 0) && (year % 100 != 0) ||
          (year % 400 == 0);
      if (isLeapYear) {
        return 29;
      }
      return 28;
    }
    const List<int> daysInMonth = <int>[31, -1, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return daysInMonth[month - 1];
  }

  @override
  String formatHour(TimeOfDay timeOfDay, { bool alwaysUse24HourFormat = false }) {
    final TimeOfDayFormat format = timeOfDayFormat(alwaysUse24HourFormat: alwaysUse24HourFormat);
    switch (format) {
      case TimeOfDayFormat.h_colon_mm_space_a:
        return formatDecimal(timeOfDay.hourOfPeriod == 0 ? 12 : timeOfDay.hourOfPeriod);
      case TimeOfDayFormat.HH_colon_mm:
        return _formatTwoDigitZeroPad(timeOfDay.hour);
      case TimeOfDayFormat.a_space_h_colon_mm:
      case TimeOfDayFormat.frenchCanadian:
      case TimeOfDayFormat.H_colon_mm:
      case TimeOfDayFormat.HH_dot_mm:
        throw AssertionError('$runtimeType does not support $format.');
    }
  }

  String _formatTwoDigitZeroPad(int number) {
    assert(0 <= number && number < 100);

    if (number < 10) {
      return '0$number';
    }

    return '$number';
  }

  @override
  String formatMinute(TimeOfDay timeOfDay) {
    final int minute = timeOfDay.minute;
    return minute < 10 ? '0$minute' : minute.toString();
  }

  @override
  String formatYear(DateTime date) => date.year.toString();

  @override
  String formatCompactDate(DateTime date) {
    // Assumes US mm/dd/yyyy format
    final String month = _formatTwoDigitZeroPad(date.month);
    final String day = _formatTwoDigitZeroPad(date.day);
    final String year = date.year.toString().padLeft(4, '0');
    return '$month/$day/$year';
  }

  @override
  String formatShortDate(DateTime date) {
    final String month = _shortMonths[date.month - DateTime.january];
    return '$month ${date.day}, ${date.year}';
  }

  @override
  String formatMediumDate(DateTime date) {
    final String day = _shortWeekdays[date.weekday - DateTime.monday];
    final String month = _shortMonths[date.month - DateTime.january];
    return '$day, $month ${date.day}';
  }

  @override
  String formatFullDate(DateTime date) {
    final String month = _months[date.month - DateTime.january];
    return '${_weekdays[date.weekday - DateTime.monday]}, $month ${date.day}, ${date.year}';
  }

  @override
  String formatMonthYear(DateTime date) {
    final String year = formatYear(date);
    final String month = _months[date.month - DateTime.january];
    return '$month $year';
  }

  @override
  String formatShortMonthDay(DateTime date) {
    final String month = _shortMonths[date.month - DateTime.january];
    return '$month ${date.day}';
  }

  @override
  DateTime? parseCompactDate(String? inputString) {
    if (inputString == null) {
      return null;
    }

    // Assumes US mm/dd/yyyy format
    final List<String> inputParts = inputString.split('/');
    if (inputParts.length != 3) {
      return null;
    }

    final int? year = int.tryParse(inputParts[2], radix: 10);
    if (year == null || year < 1) {
      return null;
    }

    final int? month = int.tryParse(inputParts[0], radix: 10);
    if (month == null || month < 1 || month > 12) {
      return null;
    }

    final int? day = int.tryParse(inputParts[1], radix: 10);
    if (day == null || day < 1 || day > _getDaysInMonth(year, month)) {
      return null;
    }

    try {
      return DateTime(year, month, day);
    } on ArgumentError {
      return null;
    }
  }

  @override
  List<String> get narrowWeekdays => _narrowWeekdays;

  @override
  int get firstDayOfWeekIndex => 0; // narrowWeekdays[0] is 'S' for Sunday

  @override
  String get dateSeparator => '/';

  @override
  String get dateHelpText => 'mm/dd/yyyy';

  @override
  String get selectYearSemanticsLabel => 'Select year';

  @override
  String get unspecifiedDate => 'Date';

  @override
  String get unspecifiedDateRange => 'Date Range';

  @override
  String get dateInputLabel => 'Enter Date';

  @override
  String get dateRangeStartLabel => 'Start Date';

  @override
  String get dateRangeEndLabel => 'End Date';

  @override
  String dateRangeStartDateSemanticLabel(String formattedDate) => 'Start date $formattedDate';

  @override
  String dateRangeEndDateSemanticLabel(String formattedDate) => 'End date $formattedDate';

  @override
  String get invalidDateFormatLabel => 'Invalid format.';

  @override
  String get invalidDateRangeLabel => 'Invalid range.';

  @override
  String get dateOutOfRangeLabel => 'Out of range.';

  @override
  String get saveButtonLabel => 'Save';

  @override
  String get datePickerHelpText => 'Select date';

  @override
  String get dateRangePickerHelpText => 'Select range';

  @override
  String get calendarModeButtonLabel => 'Switch to calendar';

  @override
  String get inputDateModeButtonLabel => 'Switch to input';

  @override
  String get timePickerDialHelpText => 'Select time';

  @override
  String get timePickerInputHelpText => 'Enter time';

  @override
  String get timePickerHourLabel => 'Hour';

  @override
  String get timePickerMinuteLabel => 'Minute';

  @override
  String get invalidTimeLabel => 'Enter a valid time';

  @override
  String get dialModeButtonLabel => 'Switch to dial picker mode';

  @override
  String get inputTimeModeButtonLabel => 'Switch to text input mode';

  String _formatDayPeriod(TimeOfDay timeOfDay) {
    switch (timeOfDay.period) {
      case DayPeriod.am:
        return anteMeridiemAbbreviation;
      case DayPeriod.pm:
        return postMeridiemAbbreviation;
    }
  }

  @override
  String formatDecimal(int number) {
    if (number > -1000 && number < 1000) {
      return number.toString();
    }

    final String digits = number.abs().toString();
    final StringBuffer result = StringBuffer(number < 0 ? '-' : '');
    final int maxDigitIndex = digits.length - 1;
    for (int i = 0; i <= maxDigitIndex; i += 1) {
      result.write(digits[i]);
      if (i < maxDigitIndex && (maxDigitIndex - i) % 3 == 0) {
        result.write(',');
      }
    }
    return result.toString();
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
    final StringBuffer buffer = StringBuffer();

    // Add hour:minute.
    buffer
      ..write(formatHour(timeOfDay, alwaysUse24HourFormat: alwaysUse24HourFormat))
      ..write(':')
      ..write(formatMinute(timeOfDay));

    if (alwaysUse24HourFormat) {
      // There's no AM/PM indicator in 24-hour format.
      return '$buffer';
    }

    // Add AM/PM indicator.
    buffer
      ..write(' ')
      ..write(_formatDayPeriod(timeOfDay));
    return '$buffer';
  }

  @override
  String get openAppDrawerTooltip => 'Open navigation menu';

  @override
  String get backButtonTooltip => 'Back';

  @override
  String get closeButtonTooltip => 'Close';

  @override
  String get deleteButtonTooltip => 'Delete';

  @override
  String get moreButtonTooltip => 'More';

  @override
  String get nextMonthTooltip => 'Next month';

  @override
  String get previousMonthTooltip => 'Previous month';

  @override
  String get nextPageTooltip => 'Next page';

  @override
  String get previousPageTooltip => 'Previous page';

  @override
  String get firstPageTooltip => 'First page';

  @override
  String get lastPageTooltip => 'Last page';

  @override
  String get showMenuTooltip => 'Show menu';

  @override
  String get drawerLabel => 'Navigation menu';

  @override
  String get menuBarMenuLabel => 'Menu bar menu';

  @override
  String get popupMenuLabel => 'Popup menu';

  @override
  String get dialogLabel => 'Dialog';

  @override
  String get alertDialogLabel => 'Alert';

  @override
  String get searchFieldLabel => 'Search';

  @override
  String get currentDateLabel => 'Today';

  @override
  String get scrimLabel => 'Scrim';

  @override
  String get bottomSheetLabel => 'Bottom Sheet';

  @override
  String scrimOnTapHint(String modalRouteContentName) => 'Close $modalRouteContentName';

  @override
  String aboutListTileTitle(String applicationName) => 'About $applicationName';

  @override
  String get licensesPageTitle => 'Licenses';

  @override
  String licensesPackageDetailText(int licenseCount) {
    assert(licenseCount >= 0);
    switch (licenseCount) {
      case 0:
        return 'No licenses.';
      case 1:
        return '1 license.';
      default:
        return '$licenseCount licenses.';
    }
  }

  @override
  String pageRowsInfoTitle(int firstRow, int lastRow, int rowCount, bool rowCountIsApproximate) {
    return rowCountIsApproximate
      ? '$firstRow–$lastRow of about $rowCount'
      : '$firstRow–$lastRow of $rowCount';
  }

  @override
  String get rowsPerPageTitle => 'Rows per page:';

  @override
  String tabLabel({ required int tabIndex, required int tabCount }) {
    assert(tabIndex >= 1);
    assert(tabCount >= 1);
    return 'Tab $tabIndex of $tabCount';
  }

  @override
  String selectedRowCountTitle(int selectedRowCount) {
    switch (selectedRowCount) {
      case 0:
        return 'No items selected';
      case 1:
        return '1 item selected';
      default:
        return '$selectedRowCount items selected';
    }
  }

  @override
  String get cancelButtonLabel => 'Cancel';

  @override
  String get closeButtonLabel => 'Close';

  @override
  String get continueButtonLabel => 'Continue';

  @override
  String get copyButtonLabel => 'Copy';

  @override
  String get cutButtonLabel => 'Cut';

  @override
  String get scanTextButtonLabel => 'Scan text';

  @override
  String get okButtonLabel => 'OK';

  @override
  String get pasteButtonLabel => 'Paste';

  @override
  String get selectAllButtonLabel => 'Select all';

  @override
  String get lookUpButtonLabel => 'Look Up';

  @override
  String get searchWebButtonLabel => 'Search Web';

  @override
  String get shareButtonLabel => 'Share...';

  @override
  String get viewLicensesButtonLabel => 'View licenses';

  @override
  String get anteMeridiemAbbreviation => 'AM';

  @override
  String get postMeridiemAbbreviation => 'PM';

  @override
  String get timePickerHourModeAnnouncement => 'Select hours';

  @override
  String get timePickerMinuteModeAnnouncement => 'Select minutes';

  @override
  String get modalBarrierDismissLabel => 'Dismiss';

  @override
  String get menuDismissLabel => 'Dismiss menu';

  @override
  ScriptCategory get scriptCategory => ScriptCategory.englishLike;

  @override
  TimeOfDayFormat timeOfDayFormat({ bool alwaysUse24HourFormat = false }) {
    return alwaysUse24HourFormat
      ? TimeOfDayFormat.HH_colon_mm
      : TimeOfDayFormat.h_colon_mm_space_a;
  }

  @override
  String get signedInLabel => 'Signed in';

  @override
  String get hideAccountsLabel => 'Hide accounts';

  @override
  String get showAccountsLabel => 'Show accounts';

  @override
  String get reorderItemUp => 'Move up';

  @override
  String get reorderItemDown => 'Move down';

  @override
  String get reorderItemLeft => 'Move left';

  @override
  String get reorderItemRight => 'Move right';

  @override
  String get reorderItemToEnd => 'Move to the end';

  @override
  String get reorderItemToStart => 'Move to the start';

  @override
  String get expandedIconTapHint => 'Collapse';

  @override
  String get collapsedIconTapHint => 'Expand';

  @override
  String get expansionTileExpandedHint => 'double tap to collapse';

  @override
  String get expansionTileCollapsedHint => 'double tap to expand';

  @override
  String get expansionTileExpandedTapHint => 'Collapse';

  @override
  String get expansionTileCollapsedTapHint => 'Expand for more details';

  @override
  String get expandedHint => 'Collapsed';

  @override
  String get collapsedHint => 'Expanded';

  @override
  String get refreshIndicatorSemanticLabel => 'Refresh';

  static Future<MaterialLocalizations> load(Locale locale) {
    return SynchronousFuture<MaterialLocalizations>(const DefaultMaterialLocalizations());
  }

  static const LocalizationsDelegate<MaterialLocalizations> delegate = _MaterialLocalizationsDelegate();

  @override
  String remainingTextFieldCharacterCount(int remaining) {
    switch (remaining) {
      case 0:
        return 'No characters remaining';
      case 1:
        return '1 character remaining';
      default:
        return '$remaining characters remaining';
    }
  }

  @override
  String get keyboardKeyAlt => 'Alt';

  @override
  String get keyboardKeyAltGraph => 'AltGr';

  @override
  String get keyboardKeyBackspace => 'Backspace';

  @override
  String get keyboardKeyCapsLock => 'Caps Lock';

  @override
  String get keyboardKeyChannelDown => 'Channel Down';

  @override
  String get keyboardKeyChannelUp => 'Channel Up';

  @override
  String get keyboardKeyControl => 'Ctrl';

  @override
  String get keyboardKeyDelete => 'Del';

  @override
  String get keyboardKeyEject => 'Eject';

  @override
  String get keyboardKeyEnd => 'End';

  @override
  String get keyboardKeyEscape => 'Esc';

  @override
  String get keyboardKeyFn => 'Fn';

  @override
  String get keyboardKeyHome => 'Home';

  @override
  String get keyboardKeyInsert => 'Insert';

  @override
  String get keyboardKeyMeta => 'Meta';

  @override
  String get keyboardKeyMetaMacOs => 'Command';

  @override
  String get keyboardKeyMetaWindows => 'Win';

  @override
  String get keyboardKeyNumLock => 'Num Lock';

  @override
  String get keyboardKeyNumpad1 => 'Num 1';

  @override
  String get keyboardKeyNumpad2 => 'Num 2';

  @override
  String get keyboardKeyNumpad3 => 'Num 3';

  @override
  String get keyboardKeyNumpad4 => 'Num 4';

  @override
  String get keyboardKeyNumpad5 => 'Num 5';

  @override
  String get keyboardKeyNumpad6 => 'Num 6';

  @override
  String get keyboardKeyNumpad7 => 'Num 7';

  @override
  String get keyboardKeyNumpad8 => 'Num 8';

  @override
  String get keyboardKeyNumpad9 => 'Num 9';

  @override
  String get keyboardKeyNumpad0 => 'Num 0';

  @override
  String get keyboardKeyNumpadAdd => 'Num +';

  @override
  String get keyboardKeyNumpadComma => 'Num ,';

  @override
  String get keyboardKeyNumpadDecimal => 'Num .';

  @override
  String get keyboardKeyNumpadDivide => 'Num /';

  @override
  String get keyboardKeyNumpadEnter => 'Num Enter';

  @override
  String get keyboardKeyNumpadEqual => 'Num =';

  @override
  String get keyboardKeyNumpadMultiply => 'Num *';

  @override
  String get keyboardKeyNumpadParenLeft => 'Num (';

  @override
  String get keyboardKeyNumpadParenRight => 'Num )';

  @override
  String get keyboardKeyNumpadSubtract => 'Num -';

  @override
  String get keyboardKeyPageDown => 'PgDown';

  @override
  String get keyboardKeyPageUp => 'PgUp';

  @override
  String get keyboardKeyPower => 'Power';

  @override
  String get keyboardKeyPowerOff => 'Power Off';

  @override
  String get keyboardKeyPrintScreen => 'Print Screen';

  @override
  String get keyboardKeyScrollLock => 'Scroll Lock';

  @override
  String get keyboardKeySelect => 'Select';

  @override
  String get keyboardKeyShift => 'Shift';

  @override
  String get keyboardKeySpace => 'Space';
}