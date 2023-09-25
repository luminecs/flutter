import 'dart:async';

// package:flutter_goldens is not used as part of the test process for web.
Future<void> testExecutable(FutureOr<void> Function() testMain) async => testMain();