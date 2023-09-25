
import 'dart:async';


import 'goldens_io.dart' if (dart.library.html) 'goldens_web.dart' as flutter_goldens;

Future<void> testExecutable(FutureOr<void> Function() testMain) {
  // Enable golden file testing using Skia Gold.
  return flutter_goldens.testExecutable(testMain, namePrefix: 'api');
}