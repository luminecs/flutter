import 'dart:io' show FileSystemException, stderr;

class DriverError extends Error {
  DriverError(this.message, [this.originalError, this.originalStackTrace]);

  final String message;

  final Object? originalError;

  final Object? originalStackTrace;

  @override
  String toString() {
    if (originalError == null) {
      return 'DriverError: $message\n';
    }
    return '''
DriverError: $message
Original error: $originalError
Original stack trace:
$originalStackTrace
''';
  }
}

typedef DriverLogCallback = void Function(String source, String message);

DriverLogCallback driverLog = _defaultDriverLogger;

void _defaultDriverLogger(String source, String message) {
  try {
    stderr.writeln('$source: $message');
  } on FileSystemException {
    // May encounter IO error: https://github.com/flutter/flutter/issues/69314
  }
}
