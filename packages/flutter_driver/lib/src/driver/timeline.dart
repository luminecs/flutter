// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

class Timeline {
  factory Timeline.fromJson(Map<String, dynamic> json) {
    return Timeline._(json, _parseEvents(json));
  }

  Timeline._(this.json, this.events);

  final Map<String, dynamic> json;

  final List<TimelineEvent>? events;
}

class TimelineEvent {
  TimelineEvent(this.json)
      : name = json['name'] as String?,
        category = json['cat'] as String?,
        phase = json['ph'] as String?,
        processId = json['pid'] as int?,
        threadId = json['tid'] as int?,
        duration = json['dur'] != null
            ? Duration(microseconds: json['dur'] as int)
            : null,
        threadDuration = json['tdur'] != null
            ? Duration(microseconds: json['tdur'] as int)
            : null,
        timestampMicros = json['ts'] as int?,
        threadTimestampMicros = json['tts'] as int?,
        arguments = json['args'] as Map<String, dynamic>?;

  final Map<String, dynamic> json;

  final String? name;

  final String? category;

  final String? phase;

  final int? processId;

  final int? threadId;

  final Duration? duration;

  final Duration? threadDuration;

  final int? timestampMicros;

  final int? threadTimestampMicros;

  final Map<String, dynamic>? arguments;
}

List<TimelineEvent>? _parseEvents(Map<String, dynamic> json) {
  final List<dynamic>? jsonEvents = json['traceEvents'] as List<dynamic>?;

  if (jsonEvents == null) {
    return null;
  }

  final List<TimelineEvent> timelineEvents =
      Iterable.castFrom<dynamic, Map<String, dynamic>>(jsonEvents)
          .map<TimelineEvent>(
              (Map<String, dynamic> eventJson) => TimelineEvent(eventJson))
          .toList();

  timelineEvents.sort((TimelineEvent e1, TimelineEvent e2) {
    final int? ts1 = e1.timestampMicros;
    final int? ts2 = e2.timestampMicros;
    if (ts1 == null) {
      if (ts2 == null) {
        return 0;
      } else {
        return -1;
      }
    } else if (ts2 == null) {
      return 1;
    } else {
      return ts1.compareTo(ts2);
    }
  });

  return timelineEvents;
}