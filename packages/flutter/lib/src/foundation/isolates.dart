import 'dart:async';

import '_isolates_io.dart'
  if (dart.library.js_util) '_isolates_web.dart' as isolates;

typedef ComputeCallback<M, R> = FutureOr<R> Function(M message);

typedef ComputeImpl = Future<R> Function<M, R>(ComputeCallback<M, R> callback, M message, { String? debugLabel });

Future<R> compute<M, R>(ComputeCallback<M, R> callback, M message, {String? debugLabel}) {
  return isolates.compute<M, R>(callback, message, debugLabel: debugLabel);
}