
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('System sound control test', () async {
    final List<MethodCall> log = <MethodCall>[];

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (MethodCall methodCall) async {
      log.add(methodCall);
      return null;
    });

    await SystemSound.play(SystemSoundType.click);

    expect(log, hasLength(1));
    expect(log.single, isMethodCall('SystemSound.play', arguments: 'SystemSoundType.click'));
  });
}