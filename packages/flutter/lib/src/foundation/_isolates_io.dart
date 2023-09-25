import 'dart:async';
import 'dart:isolate';

import 'constants.dart';
import 'isolates.dart' as isolates;

export 'isolates.dart' show ComputeCallback;

@pragma('vm:prefer-inline')
Future<R> compute<M, R>(isolates.ComputeCallback<M, R> callback, M message, {String? debugLabel}) async {
  debugLabel ??= kReleaseMode ? 'compute' : callback.toString();

  return Isolate.run<R>(() {
    return callback(message);
  }, debugName: debugLabel);
}