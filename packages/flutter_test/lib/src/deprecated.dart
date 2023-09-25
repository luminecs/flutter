
import 'package:flutter/services.dart';

import 'binding.dart';

extension TestBinaryMessengerExtension on BinaryMessenger {
  @Deprecated(
    'Use tester.binding.defaultBinaryMessenger.setMockMessageHandler or '
    'TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler instead. '
    'For the first argument, pass channel.name. '
    'This feature was deprecated after v3.9.0-19.0.pre.'
  )
  void setMockMessageHandler(String channel, MessageHandler? handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(channel, handler);
  }

  @Deprecated(
    'Use tester.binding.defaultBinaryMessenger.checkMockMessageHandler or '
    'TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.checkMockMessageHandler instead. '
    'For the first argument, pass channel.name. '
    'This feature was deprecated after v3.9.0-19.0.pre.'
  )
  bool checkMockMessageHandler(String channel, Object? handler) {
    return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.checkMockMessageHandler(channel, handler);
  }
}

extension TestBasicMessageChannelExtension<T> on BasicMessageChannel<T> {
  @Deprecated(
    'Use tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler or '
    'TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler instead. '
    'Pass the channel as the first argument. '
    'This feature was deprecated after v3.9.0-19.0.pre.'
  )
  void setMockMessageHandler(Future<T> Function(T? message)? handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockDecodedMessageHandler<T>(this, handler);
  }

  @Deprecated(
    'Use tester.binding.defaultBinaryMessenger.checkMockMessageHandler or '
    'TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.checkMockMessageHandler instead. '
    'For the first argument, pass channel.name. '
    'This feature was deprecated after v3.9.0-19.0.pre.'
  )
  bool checkMockMessageHandler(Object? handler) {
    return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.checkMockMessageHandler(name, handler);
  }
}

extension TestMethodChannelExtension on MethodChannel {
  @Deprecated(
    'Use tester.binding.defaultBinaryMessenger.setMockMethodCallHandler or '
    'TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler instead. '
    'Pass the channel as the first argument. '
    'This feature was deprecated after v3.9.0-19.0.pre.'
  )
  void setMockMethodCallHandler(Future<dynamic>? Function(MethodCall call)? handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(this, handler);
  }

  @Deprecated(
    'Use tester.binding.defaultBinaryMessenger.checkMockMessageHandler or '
    'TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.checkMockMessageHandler instead. '
    'For the first argument, pass channel.name. '
    'This feature was deprecated after v3.9.0-19.0.pre.'
  )
  bool checkMockMethodCallHandler(Object? handler) {
    return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.checkMockMessageHandler(name, handler);
  }
}