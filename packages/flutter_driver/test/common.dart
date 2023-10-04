import 'dart:io';

import 'package:flutter_driver/src/common/error.dart';
import 'package:test/test.dart';

export 'package:test/fake.dart';
export 'package:test/test.dart';

void tryToDelete(Directory directory) {
  // This should not be necessary, but it turns out that
  // on Windows it's common for deletions to fail due to
  // bogus (we think) "access denied" errors.
  try {
    directory.deleteSync(recursive: true);
  } on FileSystemException catch (error) {
    driverLog('test', 'Failed to delete ${directory.path}: $error');
  }
}

final Matcher throwsDriverError = throwsA(isA<DriverError>());
