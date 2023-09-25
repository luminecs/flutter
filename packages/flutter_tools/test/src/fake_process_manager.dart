// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io' as io show Process, ProcessResult, ProcessSignal, ProcessStartMode, systemEncoding;

import 'package:file/file.dart';
import 'package:meta/meta.dart';
import 'package:process/process.dart';

import 'test_wrapper.dart';

export 'package:process/process.dart' show ProcessManager;

typedef VoidCallback = void Function();

@immutable
class FakeCommand {
  const FakeCommand({
    required this.command,
    this.workingDirectory,
    this.environment,
    this.encoding,
    this.duration = Duration.zero,
    this.onRun,
    this.exitCode = 0,
    this.stdout = '',
    this.stderr = '',
    this.completer,
    this.stdin,
    this.exception,
    this.outputFollowsExit = false,
    this.processStartMode,
  });

  final List<Pattern> command;

  final String? workingDirectory;

  final Map<String, String>? environment;

  final Encoding? encoding;

  final Duration duration;

  final VoidCallback? onRun;

  final int exitCode;

  final String stdout;

  final String stderr;

  final Completer<void>? completer;

  final IOSink? stdin;

  final Object? exception;

  final bool outputFollowsExit;

  final io.ProcessStartMode? processStartMode;

  void _matches(
    List<String> command,
    String? workingDirectory,
    Map<String, String>? environment,
    Encoding? encoding,
    io.ProcessStartMode? mode,
  ) {
    final List<dynamic> matchers = this.command.map((Pattern x) => x is String ? x : matches(x)).toList();
    expect(command, matchers);
    if (processStartMode != null) {
      expect(mode, processStartMode);
    }
    if (this.workingDirectory != null) {
      expect(workingDirectory, this.workingDirectory);
    }
    if (this.environment != null) {
      expect(environment, this.environment);
    }
    if (this.encoding != null) {
      expect(encoding, this.encoding);
    }
  }
}

@visibleForTesting
class FakeProcess implements io.Process {
  FakeProcess({
    int exitCode = 0,
    Duration duration = Duration.zero,
    this.pid = 1234,
    List<int> stderr = const <int>[],
    IOSink? stdin,
    List<int> stdout = const <int>[],
    Completer<void>? completer,
    bool outputFollowsExit = false,
  }) : _exitCode = exitCode,
       exitCode = Future<void>.delayed(duration).then((void value) {
         if (completer != null) {
           return completer.future.then((void _) => exitCode);
         }
         return exitCode;
       }),
      _stderr = stderr,
      stdin = stdin ?? IOSink(StreamController<List<int>>().sink),
      _stdout = stdout,
      _completer = completer
  {
    if (_stderr.isEmpty) {
      this.stderr = const Stream<List<int>>.empty();
    } else if (outputFollowsExit) {
      // Wait for the process to exit before emitting stderr.
      this.stderr = Stream<List<int>>.fromFuture(this.exitCode.then((_) {
        // Return a Future so stderr isn't immediately available to those who
        // await exitCode, but is available asynchronously later.
        return Future<List<int>>(() => _stderr);
      }));
    } else {
      this.stderr = Stream<List<int>>.value(_stderr);
    }

    if (_stdout.isEmpty) {
      this.stdout = const Stream<List<int>>.empty();
    } else if (outputFollowsExit) {
      // Wait for the process to exit before emitting stdout.
      this.stdout = Stream<List<int>>.fromFuture(this.exitCode.then((_) {
        // Return a Future so stdout isn't immediately available to those who
        // await exitCode, but is available asynchronously later.
        return Future<List<int>>(() => _stdout);
      }));
    } else {
      this.stdout = Stream<List<int>>.value(_stdout);
    }
  }

  final int _exitCode;

  final Completer<void>? _completer;

  @override
  final Future<int> exitCode;

  @override
  final int pid;

  final List<int> _stderr;

  @override
  late final Stream<List<int>> stderr;

  @override
  final IOSink stdin;

  @override
  late final Stream<List<int>> stdout;

  final List<int> _stdout;

  @override
  bool kill([io.ProcessSignal signal = io.ProcessSignal.sigterm]) {
    // Killing a fake process has no effect.
    return false;
  }
}

abstract class FakeProcessManager implements ProcessManager {
  factory FakeProcessManager.any() = _FakeAnyProcessManager;

  factory FakeProcessManager.list(List<FakeCommand> commands) = _SequenceProcessManager;
  factory FakeProcessManager.empty() => _SequenceProcessManager(<FakeCommand>[]);

  FakeProcessManager._();

  void addCommand(FakeCommand command);

  void addCommands(Iterable<FakeCommand> commands) {
    commands.forEach(addCommand);
  }

  final Map<int, FakeProcess> _fakeRunningProcesses = <int, FakeProcess>{};

  bool get hasRemainingExpectations;

  List<FakeCommand> get _remainingExpectations;

  @protected
  FakeCommand findCommand(
    List<String> command,
    String? workingDirectory,
    Map<String, String>? environment,
    Encoding? encoding,
    io.ProcessStartMode? mode,
  );

  int _pid = 9999;

  FakeProcess _runCommand(
    List<String> command, {
    String? workingDirectory,
    Map<String, String>? environment,
    Encoding? encoding,
    io.ProcessStartMode? mode,
  }) {
    _pid += 1;
    final FakeCommand fakeCommand = findCommand(
      command,
      workingDirectory,
      environment,
      encoding,
      mode,
    );
    if (fakeCommand.exception != null) {
      assert(fakeCommand.exception is Exception || fakeCommand.exception is Error);
      throw fakeCommand.exception!; // ignore: only_throw_errors
    }
    if (fakeCommand.onRun != null) {
      fakeCommand.onRun!();
    }
    return FakeProcess(
      duration: fakeCommand.duration,
      exitCode: fakeCommand.exitCode,
      pid: _pid,
      stderr: encoding?.encode(fakeCommand.stderr) ?? fakeCommand.stderr.codeUnits,
      stdin: fakeCommand.stdin,
      stdout: encoding?.encode(fakeCommand.stdout) ?? fakeCommand.stdout.codeUnits,
      completer: fakeCommand.completer,
      outputFollowsExit: fakeCommand.outputFollowsExit,
    );
  }

  @override
  Future<io.Process> start(
    List<dynamic> command, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true, // ignored
    bool runInShell = false, // ignored
    io.ProcessStartMode mode = io.ProcessStartMode.normal,
  }) {
    final FakeProcess process = _runCommand(
      command.cast<String>(),
      workingDirectory: workingDirectory,
      environment: environment,
      encoding: io.systemEncoding,
      mode: mode,
    );
    if (process._completer != null) {
      _fakeRunningProcesses[process.pid] = process;
      process.exitCode.whenComplete(() {
        _fakeRunningProcesses.remove(process.pid);
      });
    }
    return Future<io.Process>.value(process);
  }

  @override
  Future<io.ProcessResult> run(
    List<dynamic> command, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true, // ignored
    bool runInShell = false, // ignored
    Encoding? stdoutEncoding = io.systemEncoding,
    Encoding? stderrEncoding = io.systemEncoding,
  }) async {
    final FakeProcess process = _runCommand(
      command.cast<String>(),
      workingDirectory: workingDirectory,
      environment: environment,
      encoding: stdoutEncoding,
    );
    await process.exitCode;
    return io.ProcessResult(
      process.pid,
      process._exitCode,
      stdoutEncoding == null ? process._stdout : await stdoutEncoding.decodeStream(process.stdout),
      stderrEncoding == null ? process._stderr : await stderrEncoding.decodeStream(process.stderr),
    );
  }

  @override
  io.ProcessResult runSync(
    List<dynamic> command, {
    String? workingDirectory,
    Map<String, String>? environment,
    bool includeParentEnvironment = true, // ignored
    bool runInShell = false, // ignored
    Encoding? stdoutEncoding = io.systemEncoding,
    Encoding? stderrEncoding = io.systemEncoding,
  }) {
    final FakeProcess process = _runCommand(
      command.cast<String>(),
      workingDirectory: workingDirectory,
      environment: environment,
      encoding: stdoutEncoding,
    );
    return io.ProcessResult(
      process.pid,
      process._exitCode,
      stdoutEncoding == null ? process._stdout : stdoutEncoding.decode(process._stdout),
      stderrEncoding == null ? process._stderr : stderrEncoding.decode(process._stderr),
    );
  }

  @override
  bool canRun(dynamic executable, {String? workingDirectory}) => !excludedExecutables.contains(executable);

  Set<String> excludedExecutables = <String>{};

  @override
  bool killPid(int pid, [io.ProcessSignal signal = io.ProcessSignal.sigterm]) {
    // Killing a fake process has no effect unless it has an attached completer.
    final FakeProcess? fakeProcess = _fakeRunningProcesses[pid];
    if (fakeProcess == null) {
      return false;
    }
    if (fakeProcess._completer != null) {
      fakeProcess._completer.complete();
    }
    return true;
  }
}

class _FakeAnyProcessManager extends FakeProcessManager {
  _FakeAnyProcessManager() : super._();

  @override
  FakeCommand findCommand(
    List<String> command,
    String? workingDirectory,
    Map<String, String>? environment,
    Encoding? encoding,
    io.ProcessStartMode? mode,
  ) {
    return FakeCommand(
      command: command,
      workingDirectory: workingDirectory,
      environment: environment,
      encoding: encoding,
      processStartMode: mode,
    );
  }

  @override
  void addCommand(FakeCommand command) { }

  @override
  bool get hasRemainingExpectations => true;

  @override
  List<FakeCommand> get _remainingExpectations => <FakeCommand>[];
}

class _SequenceProcessManager extends FakeProcessManager {
  _SequenceProcessManager(this._commands) : super._();

  final List<FakeCommand> _commands;

  @override
  FakeCommand findCommand(
    List<String> command,
    String? workingDirectory,
    Map<String, String>? environment,
    Encoding? encoding,
    io.ProcessStartMode? mode,
  ) {
    expect(_commands, isNotEmpty,
      reason: 'ProcessManager was told to execute $command (in $workingDirectory) '
              'but the FakeProcessManager.list expected no more processes.'
    );
    _commands.first._matches(command, workingDirectory, environment, encoding, mode);
    return _commands.removeAt(0);
  }

  @override
  void addCommand(FakeCommand command) {
    _commands.add(command);
  }

  @override
  bool get hasRemainingExpectations => _commands.isNotEmpty;

  @override
  List<FakeCommand> get _remainingExpectations => _commands;
}

const Matcher hasNoRemainingExpectations = _HasNoRemainingExpectations();

class _HasNoRemainingExpectations extends Matcher {
  const _HasNoRemainingExpectations();

  @override
  bool matches(dynamic item, Map<dynamic, dynamic> matchState) =>
      item is FakeProcessManager && !item.hasRemainingExpectations;

  @override
  Description describe(Description description) =>
      description.add('a fake process manager with no remaining expectations');

  @override
  Description describeMismatch(
      dynamic item,
      Description description,
      Map<dynamic, dynamic> matchState,
      bool verbose,
      ) {
    final FakeProcessManager fakeProcessManager = item as FakeProcessManager;
    return description.add(
        'has remaining expectations:\n${fakeProcessManager._remainingExpectations.map((FakeCommand command) => command.command).join('\n')}');
  }
}