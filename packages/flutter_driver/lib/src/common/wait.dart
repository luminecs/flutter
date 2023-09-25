
import 'dart:convert';

import 'message.dart';

class WaitForCondition extends Command {
  const WaitForCondition(this.condition, {super.timeout});

  WaitForCondition.deserialize(super.json)
      : condition = _deserialize(json),
        super.deserialize();

  final SerializableWaitCondition condition;

  @override
  Map<String, String> serialize() => super.serialize()..addAll(condition.serialize());

  @override
  String get kind => 'waitForCondition';

  @override
  bool get requiresRootWidgetAttached => condition.requiresRootWidgetAttached;
}

class SerializationException implements Exception {
  const SerializationException([this.message]);

  final String? message;

  @override
  String toString() => 'SerializationException($message)';
}

abstract class SerializableWaitCondition {
  const SerializableWaitCondition();

  String get conditionName;

  Map<String, String> serialize() {
    return <String, String>{
      'conditionName': conditionName,
    };
  }

  bool get requiresRootWidgetAttached => true;
}

class NoTransientCallbacks extends SerializableWaitCondition {
  const NoTransientCallbacks();

  factory NoTransientCallbacks.deserialize(Map<String, String> json) {
    if (json['conditionName'] != 'NoTransientCallbacksCondition') {
      throw SerializationException('Error occurred during deserializing the NoTransientCallbacksCondition JSON string: $json');
    }
    return const NoTransientCallbacks();
  }

  @override
  String get conditionName => 'NoTransientCallbacksCondition';
}

class NoPendingFrame extends SerializableWaitCondition {
  const NoPendingFrame();

  factory NoPendingFrame.deserialize(Map<String, String> json) {
    if (json['conditionName'] != 'NoPendingFrameCondition') {
      throw SerializationException('Error occurred during deserializing the NoPendingFrameCondition JSON string: $json');
    }
    return const NoPendingFrame();
  }

  @override
  String get conditionName => 'NoPendingFrameCondition';
}

class FirstFrameRasterized extends SerializableWaitCondition {
  const FirstFrameRasterized();

  factory FirstFrameRasterized.deserialize(Map<String, String> json) {
    if (json['conditionName'] != 'FirstFrameRasterizedCondition') {
      throw SerializationException('Error occurred during deserializing the FirstFrameRasterizedCondition JSON string: $json');
    }
    return const FirstFrameRasterized();
  }

  @override
  String get conditionName => 'FirstFrameRasterizedCondition';

  @override
  bool get requiresRootWidgetAttached => false;
}

class NoPendingPlatformMessages extends SerializableWaitCondition {
  const NoPendingPlatformMessages();

  factory NoPendingPlatformMessages.deserialize(Map<String, String> json) {
    if (json['conditionName'] != 'NoPendingPlatformMessagesCondition') {
      throw SerializationException('Error occurred during deserializing the NoPendingPlatformMessagesCondition JSON string: $json');
    }
    return const NoPendingPlatformMessages();
  }

  @override
  String get conditionName => 'NoPendingPlatformMessagesCondition';
}

class CombinedCondition extends SerializableWaitCondition {
  const CombinedCondition(this.conditions);

  factory CombinedCondition.deserialize(Map<String, String> jsonMap) {
    if (jsonMap['conditionName'] != 'CombinedCondition') {
      throw SerializationException('Error occurred during deserializing the CombinedCondition JSON string: $jsonMap');
    }
    if (jsonMap['conditions'] == null) {
      return const CombinedCondition(<SerializableWaitCondition>[]);
    }

    final List<SerializableWaitCondition> conditions = <SerializableWaitCondition>[];
    for (final Map<String, dynamic> condition in (json.decode(jsonMap['conditions']!) as List<dynamic>).cast<Map<String, dynamic>>()) {
      conditions.add(_deserialize(condition.cast<String, String>()));
    }
    return CombinedCondition(conditions);
  }

  final List<SerializableWaitCondition> conditions;

  @override
  String get conditionName => 'CombinedCondition';

  @override
  Map<String, String> serialize() {
    final Map<String, String> jsonMap = super.serialize();
    final List<Map<String, String>> jsonConditions = conditions.map(
      (SerializableWaitCondition condition) {
        return condition.serialize();
      }).toList();
    jsonMap['conditions'] = json.encode(jsonConditions);
    return jsonMap;
  }
}

SerializableWaitCondition _deserialize(Map<String, String> json) {
  final String conditionName = json['conditionName']!;
  switch (conditionName) {
    case 'NoTransientCallbacksCondition':
      return NoTransientCallbacks.deserialize(json);
    case 'NoPendingFrameCondition':
      return NoPendingFrame.deserialize(json);
    case 'FirstFrameRasterizedCondition':
      return FirstFrameRasterized.deserialize(json);
    case 'NoPendingPlatformMessagesCondition':
      return NoPendingPlatformMessages.deserialize(json);
    case 'CombinedCondition':
      return CombinedCondition.deserialize(json);
  }
  throw SerializationException(
      'Unsupported wait condition $conditionName in the JSON string $json');
}