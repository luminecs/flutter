import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class FeedbackTester {
  FeedbackTester() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, _handler);
  }

  int get hapticCount => _hapticCount;
  int _hapticCount = 0;

  int get clickSoundCount => _clickSoundCount;
  int _clickSoundCount = 0;

  Future<void> _handler(MethodCall methodCall) async {
    if (methodCall.method == 'HapticFeedback.vibrate') {
      _hapticCount++;
    }
    if (methodCall.method == 'SystemSound.play' &&
        methodCall.arguments == SystemSoundType.click.toString()) {
      _clickSoundCount++;
    }
  }

  void dispose() {
    assert(TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .checkMockMessageHandler(SystemChannels.platform.name, _handler));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  }
}
