
import 'dart:io' as io;

import 'package:meta/meta.dart';

abstract class Stdio {
  final List<String> logs = <String>[];

  @mustCallSuper
  void printError(String message) {
    logs.add('[error] $message');
  }

  @mustCallSuper
  void printWarning(String message) {
    logs.add('[warning] $message');
  }

  @mustCallSuper
  void printStatus(String message) {
    logs.add('[status] $message');
  }

  @mustCallSuper
  void printTrace(String message) {
    logs.add('[trace] $message');
  }

  @mustCallSuper
  void write(String message) {
    logs.add('[write] $message');
  }

  String readLineSync();
}

class VerboseStdio extends Stdio {
  VerboseStdio({
    required this.stdout,
    required this.stderr,
    required this.stdin,
    this.filter,
  });

  factory VerboseStdio.local() => VerboseStdio(
        stdout: io.stdout,
        stderr: io.stderr,
        stdin: io.stdin,
      );

  final io.Stdout stdout;
  final io.Stdout stderr;
  final io.Stdin stdin;

  final String Function(String)? filter;

  @override
  void printError(String message) {
    if (filter != null) {
      message = filter!(message);
    }
    super.printError(message);
    stderr.writeln(message);
  }

  @override
  void printWarning(String message) {
    if (filter != null) {
      message = filter!(message);
    }
    super.printWarning(message);
    stderr.writeln(message);
  }

  @override
  void printStatus(String message) {
    if (filter != null) {
      message = filter!(message);
    }
    super.printStatus(message);
    stdout.writeln(message);
  }

  @override
  void printTrace(String message) {
    if (filter != null) {
      message = filter!(message);
    }
    super.printTrace(message);
    stdout.writeln(message);
  }

  @override
  void write(String message) {
    if (filter != null) {
      message = filter!(message);
    }
    super.write(message);
    stdout.write(message);
  }

  @override
  String readLineSync() {
    return stdin.readLineSync()!;
  }
}