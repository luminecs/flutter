

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

export 'dart:ui' show TextDirection;

enum Assertiveness {
  polite,

  assertive,
}

abstract class SemanticsEvent {
  const SemanticsEvent(this.type);

  final String type;

  Map<String, dynamic> toMap({ int? nodeId }) {
    final Map<String, dynamic> event = <String, dynamic>{
      'type': type,
      'data': getDataMap(),
    };
    if (nodeId != null) {
      event['nodeId'] = nodeId;
    }

    return event;
  }

  Map<String, dynamic> getDataMap();

  @override
  String toString() {
    final List<String> pairs = <String>[];
    final Map<String, dynamic> dataMap = getDataMap();
    final List<String> sortedKeys = dataMap.keys.toList()..sort();
    for (final String key in sortedKeys) {
      pairs.add('$key: ${dataMap[key]}');
    }
    return '${objectRuntimeType(this, 'SemanticsEvent')}(${pairs.join(', ')})';
  }
}

class AnnounceSemanticsEvent extends SemanticsEvent {

  const AnnounceSemanticsEvent(this.message, this.textDirection, {this.assertiveness = Assertiveness.polite})
    : super('announce');

  final String message;

  final TextDirection textDirection;

  final Assertiveness assertiveness;

  @override
  Map<String, dynamic> getDataMap() {
    return <String, dynamic> {
      'message': message,
      'textDirection': textDirection.index,
      if (assertiveness != Assertiveness.polite)
        'assertiveness': assertiveness.index,
    };
  }
}

class TooltipSemanticsEvent extends SemanticsEvent {
  const TooltipSemanticsEvent(this.message) : super('tooltip');

  final String message;

  @override
  Map<String, dynamic> getDataMap() {
    return <String, dynamic>{
      'message': message,
    };
  }
}

class LongPressSemanticsEvent extends SemanticsEvent {
  const LongPressSemanticsEvent() : super('longPress');

  @override
  Map<String, dynamic> getDataMap() => const <String, dynamic>{};
}

class TapSemanticEvent extends SemanticsEvent {
  const TapSemanticEvent() : super('tap');

  @override
  Map<String, dynamic> getDataMap() => const <String, dynamic>{};
}

class FocusSemanticEvent extends SemanticsEvent {
  const FocusSemanticEvent() : super('focus');

  @override
  Map<String, dynamic> getDataMap() => const <String, dynamic>{};
}