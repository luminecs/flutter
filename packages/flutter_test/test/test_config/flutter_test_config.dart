
import 'dart:async';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await runZoned<dynamic>(testMain, zoneValues: <Type, String>{
    String: '/test_config',
  });
}