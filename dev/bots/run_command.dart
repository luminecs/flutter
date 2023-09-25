
import 'dart:async';
import 'dart:convert';
import 'dart:core' hide print;
import 'dart:io' as io;

import 'package:path/path.dart' as path;

import 'utils.dart';

Stream<String> runAndGetStdout(String executable, List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  bool expectNonZeroExit = false,
}) async* {
  final StreamController<String> output = StreamController<String>();
  final Future<CommandResult?> command = runCommand(
    executable,
    arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    expectNonZeroExit: expectNonZeroExit,
    // Capture the output so it's not printed to the console by default.
    outputMode: OutputMode.capture,
    outputListener: (String line, io.Process process) {
      output.add(line);
    },
  );

  // Close the stream controller after the command is complete. Otherwise,
  // the yield* will never finish.
  command.whenComplete(output.close);

  yield* output.stream;
}

class Command {
  Command._(this.process, this._time, this._savedStdout, this._savedStderr);

  final io.Process process;
  final Stopwatch _time;
  final Future<String> _savedStdout;
  final Future<String> _savedStderr;
}

class CommandResult {
  CommandResult._(this.exitCode, this.elapsedTime, this.flattenedStdout, this.flattenedStderr);

  final int exitCode;

  final Duration elapsedTime;

  final String? flattenedStdout;

  final String? flattenedStderr;
}

Future<Command> startCommand(String executable, List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  OutputMode outputMode = OutputMode.print,
  bool Function(String)? removeLine,
  void Function(String, io.Process)? outputListener,
}) async {
  final String commandDescription = '${path.relative(executable, from: workingDirectory)} ${arguments.join(' ')}';
  final String relativeWorkingDir = path.relative(workingDirectory ?? io.Directory.current.path);
  print('RUNNING: cd $cyan$relativeWorkingDir$reset; $green$commandDescription$reset');

  final Stopwatch time = Stopwatch()..start();
  final io.Process process = await io.Process.start(executable, arguments,
    workingDirectory: workingDirectory,
    environment: environment,
  );
  return Command._(
    process,
    time,
    process.stdout
      .transform<String>(const Utf8Decoder())
      .transform(const LineSplitter())
      .where((String line) => removeLine == null || !removeLine(line))
      .map<String>((String line) {
        final String formattedLine = '$line\n';
        if (outputListener != null) {
          outputListener(formattedLine, process);
        }
        switch (outputMode) {
          case OutputMode.print:
            print(line);
          case OutputMode.capture:
            break;
        }
        return line;
      })
      .join('\n'),
    process.stderr
      .transform<String>(const Utf8Decoder())
      .transform(const LineSplitter())
      .map<String>((String line) {
        switch (outputMode) {
          case OutputMode.print:
            print(line);
          case OutputMode.capture:
            break;
        }
        return line;
      })
      .join('\n'),
  );
}

Future<CommandResult> runCommand(String executable, List<String> arguments, {
  String? workingDirectory,
  Map<String, String>? environment,
  bool expectNonZeroExit = false,
  int? expectedExitCode,
  String? failureMessage,
  OutputMode outputMode = OutputMode.print,
  bool Function(String)? removeLine,
  void Function(String, io.Process)? outputListener,
}) async {
  final String commandDescription = '${path.relative(executable, from: workingDirectory)} ${arguments.join(' ')}';
  final String relativeWorkingDir = path.relative(workingDirectory ?? io.Directory.current.path);

  final Command command = await startCommand(executable, arguments,
    workingDirectory: workingDirectory,
    environment: environment,
    outputMode: outputMode,
    removeLine: removeLine,
    outputListener: outputListener,
  );

  final CommandResult result = CommandResult._(
    await command.process.exitCode,
    command._time.elapsed,
    await command._savedStdout,
    await command._savedStderr,
  );

  if ((result.exitCode == 0) == expectNonZeroExit || (expectedExitCode != null && result.exitCode != expectedExitCode)) {
    // Print the output when we get unexpected results (unless output was
    // printed already).
    switch (outputMode) {
      case OutputMode.print:
        break;
      case OutputMode.capture:
        print(result.flattenedStdout);
        print(result.flattenedStderr);
    }
    String allOutput;
    if (failureMessage == null) {
      allOutput = '${result.flattenedStdout}\n${result.flattenedStderr}';
      if (allOutput.split('\n').length > 10) {
        allOutput = '(stdout/stderr output was more than 10 lines)';
      }
    } else {
      allOutput = '';
    }
    foundError(<String>[
      if (failureMessage != null)
        failureMessage,
      '${bold}Command: $green$commandDescription$reset',
      if (failureMessage == null)
        '$bold${red}Command exited with exit code ${result.exitCode} but expected ${expectNonZeroExit ? (expectedExitCode ?? 'non-zero') : 'zero'} exit code.$reset',
      '${bold}Working directory: $cyan${path.absolute(relativeWorkingDir)}$reset',
      if (allOutput.isNotEmpty)
        '${bold}stdout and stderr output:\n$allOutput',
    ]);
  } else {
    print('ELAPSED TIME: ${prettyPrintDuration(result.elapsedTime)} for $green$commandDescription$reset in $cyan$relativeWorkingDir$reset');
  }
  return result;
}

enum OutputMode {
  print,

  capture,
}