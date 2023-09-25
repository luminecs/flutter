import 'package:flutter/foundation.dart';

import 'platform_channel.dart';

export 'dart:typed_data' show ByteData;

abstract class MessageCodec<T> {
  ByteData? encodeMessage(T message);

  T? decodeMessage(ByteData? message);
}

@pragma('vm:keep-name')
@immutable
class MethodCall {
  const MethodCall(this.method, [this.arguments]);

  final String method;

  final dynamic arguments;

  @override
  String toString() => '${objectRuntimeType(this, 'MethodCall')}($method, $arguments)';
}

abstract class MethodCodec {
  ByteData encodeMethodCall(MethodCall methodCall);

  MethodCall decodeMethodCall(ByteData? methodCall);

  dynamic decodeEnvelope(ByteData envelope);

  ByteData encodeSuccessEnvelope(Object? result);

  ByteData encodeErrorEnvelope({ required String code, String? message, Object? details});
}

class PlatformException implements Exception {
  PlatformException({
    required this.code,
    this.message,
    this.details,
    this.stacktrace,
  });

  final String code;

  final String? message;

  final dynamic details;

  final String? stacktrace;

  @override
  String toString() => 'PlatformException($code, $message, $details, $stacktrace)';
}

class MissingPluginException implements Exception {
  MissingPluginException([this.message]);

  final String? message;

  @override
  String toString() => 'MissingPluginException($message)';
}