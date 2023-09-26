import 'dart:typed_data';
import 'dart:ui' as ui;

export 'dart:typed_data' show ByteData;
export 'dart:ui' show PlatformMessageResponseCallback;

typedef MessageHandler = Future<ByteData?>? Function(ByteData? message);

abstract class BinaryMessenger {
  const BinaryMessenger();

  @Deprecated(
      'Instead of calling this method, use ServicesBinding.instance.channelBuffers.push. '
      'In tests, consider using tester.binding.defaultBinaryMessenger.handlePlatformMessage '
      'or TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage. '
      'This feature was deprecated after v3.9.0-19.0.pre.')
  Future<void> handlePlatformMessage(String channel, ByteData? data,
      ui.PlatformMessageResponseCallback? callback);

  Future<ByteData?>? send(String channel, ByteData? message);

  void setMessageHandler(String channel, MessageHandler? handler);

  // Looking for setMockMessageHandler or checkMockMessageHandler?
  // See this shim package: packages/flutter_test/lib/src/deprecated.dart
}
