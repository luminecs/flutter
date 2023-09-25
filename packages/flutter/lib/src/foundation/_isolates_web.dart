
import 'isolates.dart' as isolates;

export 'isolates.dart' show ComputeCallback;

@pragma('dart2js:tryInline')
Future<R> compute<M, R>(isolates.ComputeCallback<M, R> callback, M message, { String? debugLabel }) async {
  // To avoid blocking the UI immediately for an expensive function call, we
  // pump a single frame to allow the framework to complete the current set
  // of work.
  await null;
  return callback(message);
}