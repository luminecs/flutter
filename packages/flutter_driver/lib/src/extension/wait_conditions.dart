
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common/wait.dart';

abstract class WaitCondition {
  bool get condition;

  Future<void> wait();
}

class _InternalNoTransientCallbacksCondition implements WaitCondition {
  const _InternalNoTransientCallbacksCondition();

  factory _InternalNoTransientCallbacksCondition.deserialize(SerializableWaitCondition condition) {
    if (condition.conditionName != 'NoTransientCallbacksCondition') {
      throw SerializationException('Error occurred during deserializing from the given condition: ${condition.serialize()}');
    }
    return const _InternalNoTransientCallbacksCondition();
  }

  @override
  bool get condition => SchedulerBinding.instance.transientCallbackCount == 0;

  @override
  Future<void> wait() async {
    while (!condition) {
      await SchedulerBinding.instance.endOfFrame;
    }
    assert(condition);
  }
}

class _InternalNoPendingFrameCondition implements WaitCondition {
  const _InternalNoPendingFrameCondition();

  factory _InternalNoPendingFrameCondition.deserialize(SerializableWaitCondition condition) {
    if (condition.conditionName != 'NoPendingFrameCondition') {
      throw SerializationException('Error occurred during deserializing from the given condition: ${condition.serialize()}');
    }
    return const _InternalNoPendingFrameCondition();
  }

  @override
  bool get condition => !SchedulerBinding.instance.hasScheduledFrame;

  @override
  Future<void> wait() async {
    while (!condition) {
      await SchedulerBinding.instance.endOfFrame;
    }
    assert(condition);
  }
}

class _InternalFirstFrameRasterizedCondition implements WaitCondition {
  const _InternalFirstFrameRasterizedCondition();

  factory _InternalFirstFrameRasterizedCondition.deserialize(SerializableWaitCondition condition) {
    if (condition.conditionName != 'FirstFrameRasterizedCondition') {
      throw SerializationException('Error occurred during deserializing from the given condition: ${condition.serialize()}');
    }
    return const _InternalFirstFrameRasterizedCondition();
  }

  @override
  bool get condition => WidgetsBinding.instance.firstFrameRasterized;

  @override
  Future<void> wait() async {
    await WidgetsBinding.instance.waitUntilFirstFrameRasterized;
    assert(condition);
  }
}

class _InternalNoPendingPlatformMessagesCondition implements WaitCondition {
  const _InternalNoPendingPlatformMessagesCondition();

  factory _InternalNoPendingPlatformMessagesCondition.deserialize(SerializableWaitCondition condition) {
    if (condition.conditionName != 'NoPendingPlatformMessagesCondition') {
      throw SerializationException('Error occurred during deserializing from the given condition: ${condition.serialize()}');
    }
    return const _InternalNoPendingPlatformMessagesCondition();
  }

  @override
  bool get condition {
    final TestDefaultBinaryMessenger binaryMessenger = ServicesBinding.instance.defaultBinaryMessenger as TestDefaultBinaryMessenger;
    return binaryMessenger.pendingMessageCount == 0;
  }

  @override
  Future<void> wait() async {
    final TestDefaultBinaryMessenger binaryMessenger = ServicesBinding.instance.defaultBinaryMessenger as TestDefaultBinaryMessenger;
    while (!condition) {
      await binaryMessenger.platformMessagesFinished;
    }
    assert(condition);
  }
}

class _InternalCombinedCondition implements WaitCondition {
  const _InternalCombinedCondition(this.conditions);

  factory _InternalCombinedCondition.deserialize(SerializableWaitCondition condition) {
    if (condition.conditionName != 'CombinedCondition') {
      throw SerializationException('Error occurred during deserializing from the given condition: ${condition.serialize()}');
    }
    final CombinedCondition combinedCondition = condition as CombinedCondition;
    final List<WaitCondition> conditions = combinedCondition.conditions.map(deserializeCondition).toList();
    return _InternalCombinedCondition(conditions);
  }

  final List<WaitCondition> conditions;

  @override
  bool get condition {
    return conditions.every((WaitCondition condition) => condition.condition);
  }

  @override
  Future<void> wait() async {
    while (!condition) {
      for (final WaitCondition condition in conditions) {
        await condition.wait();
      }
    }
    assert(condition);
  }
}

WaitCondition deserializeCondition(SerializableWaitCondition waitCondition) {
  final String conditionName = waitCondition.conditionName;
  switch (conditionName) {
    case 'NoTransientCallbacksCondition':
      return _InternalNoTransientCallbacksCondition.deserialize(waitCondition);
    case 'NoPendingFrameCondition':
      return _InternalNoPendingFrameCondition.deserialize(waitCondition);
    case 'FirstFrameRasterizedCondition':
      return _InternalFirstFrameRasterizedCondition.deserialize(waitCondition);
    case 'NoPendingPlatformMessagesCondition':
      return _InternalNoPendingPlatformMessagesCondition.deserialize(waitCondition);
    case 'CombinedCondition':
      return _InternalCombinedCondition.deserialize(waitCondition);
  }
  throw SerializationException(
      'Unsupported wait condition $conditionName in ${waitCondition.serialize()}');
}