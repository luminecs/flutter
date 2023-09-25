import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> simulateSystemBack() {
  return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
    'flutter/navigation',
    const JSONMessageCodec().encodeMessage(<String, dynamic>{
      'method': 'popRoute',
    }),
    (ByteData? _) {},
  );
}