// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'debug.dart';
import 'material_localizations.dart';


enum DayPeriod {
  am,

  pm,
}

@immutable
class TimeOfDay {
  const TimeOfDay({ required this.hour, required this.minute });

  TimeOfDay.fromDateTime(DateTime time)
    : hour = time.hour,
      minute = time.minute;

  factory TimeOfDay.now() { return TimeOfDay.fromDateTime(DateTime.now()); }

  static const int hoursPerDay = 24;

  static const int hoursPerPeriod = 12;

  static const int minutesPerHour = 60;

  TimeOfDay replacing({ int? hour, int? minute }) {
    assert(hour == null || (hour >= 0 && hour < hoursPerDay));
    assert(minute == null || (minute >= 0 && minute < minutesPerHour));
    return TimeOfDay(hour: hour ?? this.hour, minute: minute ?? this.minute);
  }

  final int hour;

  final int minute;

  DayPeriod get period => hour < hoursPerPeriod ? DayPeriod.am : DayPeriod.pm;

  int get hourOfPeriod => hour == 0 || hour == 12 ? 12 : hour - periodOffset;

  int get periodOffset => period == DayPeriod.am ? 0 : hoursPerPeriod;

  String format(BuildContext context) {
    assert(debugCheckHasMediaQuery(context));
    assert(debugCheckHasMaterialLocalizations(context));
    final MaterialLocalizations localizations = MaterialLocalizations.of(context);
    return localizations.formatTimeOfDay(
      this,
      alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TimeOfDay
        && other.hour == hour
        && other.minute == minute;
  }

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() {
    String addLeadingZeroIfNeeded(int value) {
      if (value < 10) {
        return '0$value';
      }
      return value.toString();
    }

    final String hourLabel = addLeadingZeroIfNeeded(hour);
    final String minuteLabel = addLeadingZeroIfNeeded(minute);

    return '$TimeOfDay($hourLabel:$minuteLabel)';
  }
}

class RestorableTimeOfDay extends RestorableValue<TimeOfDay> {
  RestorableTimeOfDay(TimeOfDay defaultValue) : _defaultValue = defaultValue;

  final TimeOfDay _defaultValue;

  @override
  TimeOfDay createDefaultValue() => _defaultValue;

  @override
  void didUpdateValue(TimeOfDay? oldValue) {
    assert(debugIsSerializableForRestoration(value.hour));
    assert(debugIsSerializableForRestoration(value.minute));
    notifyListeners();
  }

  @override
  TimeOfDay fromPrimitives(Object? data) {
    final List<Object?> timeData = data! as List<Object?>;
    return TimeOfDay(
      minute: timeData[0]! as int,
      hour: timeData[1]! as int,
    );
  }

  @override
  Object? toPrimitives() => <int>[value.minute, value.hour];
}

enum TimeOfDayFormat {
  HH_colon_mm,

  HH_dot_mm,

  frenchCanadian,

  H_colon_mm,

  h_colon_mm_space_a,

  a_space_h_colon_mm,
}

enum HourFormat {
  HH,

  H,

  h,
}

HourFormat hourFormat({ required TimeOfDayFormat of }) {
  switch (of) {
    case TimeOfDayFormat.h_colon_mm_space_a:
    case TimeOfDayFormat.a_space_h_colon_mm:
      return HourFormat.h;
    case TimeOfDayFormat.H_colon_mm:
      return HourFormat.H;
    case TimeOfDayFormat.HH_dot_mm:
    case TimeOfDayFormat.HH_colon_mm:
    case TimeOfDayFormat.frenchCanadian:
      return HourFormat.HH;
  }
}