import 'dart:async';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  await runZoned<dynamic>(testMain, zoneValues: <Type, dynamic>{
    String: '/test_config/nested_config',
    int: 123,
  });
}