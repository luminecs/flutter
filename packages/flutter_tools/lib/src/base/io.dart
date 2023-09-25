// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library;

// We allow `print()` in this file as a fallback for writing to the terminal via
// regular stdout/stderr/stdio paths. Everything else in the flutter_tools
// library should route terminal I/O through the [Stdio] class defined below.
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:io' as io
  show
    IOSink,
    InternetAddress,
    InternetAddressType,
    NetworkInterface,
    Process,
    ProcessInfo,
    ProcessSignal,
    Stdin,
    StdinException,
    Stdout,
    StdoutException,
    exit,
    pid,
    stderr,
    stdin,
    stdout;

import 'package:file/file.dart';
import 'package:meta/meta.dart';

import 'async_guard.dart';
import 'platform.dart';
import 'process.dart';

export 'dart:io'
    show
        BytesBuilder,
        CompressionOptions,
        // Directory,         NO! Use `file_system.dart`
        // File,              NO! Use `file_system.dart`
        // FileSystemEntity,  NO! Use `file_system.dart`
        GZipCodec,
        HandshakeException,
        HttpClient,
        HttpClientRequest,
        HttpClientResponse,
        HttpClientResponseCompressionState,
        HttpException,
        HttpHeaders,
        HttpRequest,
        HttpResponse,
        HttpServer,
        HttpStatus,
        IOException,
        IOSink,
        InternetAddress,
        InternetAddressType,
        // Link              NO! Use `file_system.dart`
        // NetworkInterface  NO! Use `io.dart`
        OSError,
        // Platform          NO! use `platform.dart`
        Process,
        ProcessException,
        // ProcessInfo,      NO! use `io.dart`
        ProcessResult,
        // ProcessSignal     NO! Use [ProcessSignal] below.
        ProcessStartMode,
        // RandomAccessFile  NO! Use `file_system.dart`
        ServerSocket,
        SignalException,
        Socket,
        SocketException,
        Stdin,
        StdinException,
        Stdout,
        WebSocket,
        WebSocketException,
        WebSocketTransformer,
        ZLibEncoder,
        exitCode,
        gzip,
        pid,
        // stderr,           NO! Use `io.dart`
        // stdin,            NO! Use `io.dart`
        // stdout,           NO! Use `io.dart`
        systemEncoding;

typedef ExitFunction = void Function(int exitCode);

const ExitFunction _defaultExitFunction = io.exit;

ExitFunction _exitFunction = _defaultExitFunction;

ExitFunction get exit {
  assert(
    _exitFunction != io.exit || !_inUnitTest(),
    'io.exit was called with assertions active in a unit test',
  );
  return _exitFunction;
}

// Whether the tool is executing in a unit test.
bool _inUnitTest() {
  return Zone.current[#test.declarer] != null;
}

@visibleForTesting
void setExitFunctionForTests([ ExitFunction? exitFunction ]) {
  _exitFunction = exitFunction ?? (int exitCode) {
    throw ProcessExit(exitCode, immediate: true);
  };
}

@visibleForTesting
void restoreExitFunction() {
  _exitFunction = _defaultExitFunction;
}

class ProcessSignal {
  @visibleForTesting
  const ProcessSignal(this._delegate, {@visibleForTesting Platform platform = const LocalPlatform()})
    : _platform = platform;

  static const ProcessSignal sigwinch = PosixProcessSignal(io.ProcessSignal.sigwinch);
  static const ProcessSignal sigterm = PosixProcessSignal(io.ProcessSignal.sigterm);
  static const ProcessSignal sigusr1 = PosixProcessSignal(io.ProcessSignal.sigusr1);
  static const ProcessSignal sigusr2 = PosixProcessSignal(io.ProcessSignal.sigusr2);
  static const ProcessSignal sigint = ProcessSignal(io.ProcessSignal.sigint);
  static const ProcessSignal sigkill = ProcessSignal(io.ProcessSignal.sigkill);

  final io.ProcessSignal _delegate;
  final Platform _platform;

  Stream<ProcessSignal> watch() {
    return _delegate.watch().map<ProcessSignal>((io.ProcessSignal signal) => this);
  }

  bool send(int pid) {
    assert(!_platform.isWindows || this == ProcessSignal.sigterm);
    return io.Process.killPid(pid, _delegate);
  }

  @override
  String toString() => _delegate.toString();
}

@visibleForTesting
class PosixProcessSignal extends ProcessSignal {

  const PosixProcessSignal(super.wrappedSignal, {@visibleForTesting super.platform});

  @override
  Stream<ProcessSignal> watch() {
    // This uses the real platform since it invokes dart:io functionality directly.
    if (_platform.isWindows) {
      return const Stream<ProcessSignal>.empty();
    }
    return super.watch();
  }
}

class Stdio {
  Stdio();

  @visibleForTesting
  Stdio.test({
    required io.Stdout stdout,
    required io.IOSink stderr,
  }) : _stdoutOverride = stdout, _stderrOverride = stderr;

  io.Stdout? _stdoutOverride;
  io.IOSink? _stderrOverride;

  // These flags exist to remember when the done Futures on stdout and stderr
  // complete to avoid trying to write to a closed stream sink, which would
  // generate a [StateError].
  bool _stdoutDone = false;
  bool _stderrDone = false;

  Stream<List<int>> get stdin => io.stdin;

  io.Stdout get stdout {
    if (_stdout != null) {
      return _stdout!;
    }
    _stdout = _stdoutOverride ?? io.stdout;
    _stdout!.done.then(
      (void _) { _stdoutDone = true; },
      onError: (Object err, StackTrace st) { _stdoutDone = true; },
    );
    return _stdout!;
  }
  io.Stdout? _stdout;

  io.IOSink get stderr {
    if (_stderr != null) {
      return _stderr!;
    }
    _stderr = _stderrOverride ?? io.stderr;
    _stderr!.done.then(
      (void _) { _stderrDone = true; },
      onError: (Object err, StackTrace st) { _stderrDone = true; },
    );
    return _stderr!;
  }
  io.IOSink? _stderr;

  bool get hasTerminal => io.stdout.hasTerminal;

  static bool? _stdinHasTerminal;

  bool get stdinHasTerminal {
    if (_stdinHasTerminal != null) {
      return _stdinHasTerminal!;
    }
    if (stdin is! io.Stdin) {
      return _stdinHasTerminal = false;
    }
    final io.Stdin ioStdin = stdin as io.Stdin;
    if (!ioStdin.hasTerminal) {
      return _stdinHasTerminal = false;
    }
    try {
      final bool currentEchoMode = ioStdin.echoMode;
      ioStdin.echoMode = !currentEchoMode;
      ioStdin.echoMode = currentEchoMode;
    } on io.StdinException {
      return _stdinHasTerminal = false;
    }
    return _stdinHasTerminal = true;
  }

  int? get terminalColumns => hasTerminal ? stdout.terminalColumns : null;
  int? get terminalLines => hasTerminal ? stdout.terminalLines : null;
  bool get supportsAnsiEscapes => hasTerminal && stdout.supportsAnsiEscapes;

  void stderrWrite(
    String message, {
    void Function(String, dynamic, StackTrace)? fallback,
  }) {
    if (!_stderrDone) {
      _stdioWrite(stderr, message, fallback: fallback);
      return;
    }
    fallback == null ? print(message) : fallback(
      message,
      const io.StdoutException('stderr is done'),
      StackTrace.current,
    );
  }

  void stdoutWrite(
    String message, {
    void Function(String, dynamic, StackTrace)? fallback,
  }) {
    if (!_stdoutDone) {
      _stdioWrite(stdout, message, fallback: fallback);
      return;
    }
    fallback == null ? print(message) : fallback(
      message,
      const io.StdoutException('stdout is done'),
      StackTrace.current,
    );
  }

  // Helper for [stderrWrite] and [stdoutWrite].
  void _stdioWrite(io.IOSink sink, String message, {
    void Function(String, dynamic, StackTrace)? fallback,
  }) {
    asyncGuard<void>(() async {
      sink.write(message);
    }, onError: (Object error, StackTrace stackTrace) {
      if (fallback == null) {
        print(message);
      } else {
        fallback(message, error, stackTrace);
      }
    });
  }

  Future<void> addStdoutStream(Stream<List<int>> stream) => stdout.addStream(stream);

  Future<void> addStderrStream(Stream<List<int>> stream) => stderr.addStream(stream);
}

abstract class ProcessInfo {
  factory ProcessInfo(FileSystem fs) => _DefaultProcessInfo(fs);

  factory ProcessInfo.test(FileSystem fs) => _TestProcessInfo(fs);

  int get currentRss;

  int get maxRss;

  File writePidFile(String pidFile);
}

class _DefaultProcessInfo implements ProcessInfo {
  _DefaultProcessInfo(this._fileSystem);

  final FileSystem _fileSystem;

  @override
  int get currentRss => io.ProcessInfo.currentRss;

  @override
  int get maxRss => io.ProcessInfo.maxRss;

  @override
  File writePidFile(String pidFile) {
    return _fileSystem.file(pidFile)
      ..writeAsStringSync(io.pid.toString());
  }
}

class _TestProcessInfo implements ProcessInfo {
  _TestProcessInfo(this._fileSystem);

  final FileSystem _fileSystem;

  @override
  int currentRss = 1000;

  @override
  int maxRss = 2000;

  @override
  File writePidFile(String pidFile) {
    return _fileSystem.file(pidFile)
      ..writeAsStringSync('12345');
  }
}

class NetworkInterface implements io.NetworkInterface {
  NetworkInterface(this._delegate);

  final io.NetworkInterface _delegate;

  @override
  List<io.InternetAddress> get addresses => _delegate.addresses;

  @override
  int get index => _delegate.index;

  @override
  String get name => _delegate.name;

  @override
  String toString() => "NetworkInterface('$name', $addresses)";
}

typedef NetworkInterfaceLister = Future<List<NetworkInterface>> Function({
  bool includeLoopback,
  bool includeLinkLocal,
  io.InternetAddressType type,
});

NetworkInterfaceLister? _networkInterfaceListerOverride;

// Tests can set up a non-default network interface lister.
@visibleForTesting
void setNetworkInterfaceLister(NetworkInterfaceLister lister) {
  _networkInterfaceListerOverride = lister;
}

@visibleForTesting
void resetNetworkInterfaceLister() {
  _networkInterfaceListerOverride = null;
}

Future<List<NetworkInterface>> listNetworkInterfaces({
  bool includeLoopback = false,
  bool includeLinkLocal = false,
  io.InternetAddressType type = io.InternetAddressType.any,
}) async {
  if (_networkInterfaceListerOverride != null) {
    return _networkInterfaceListerOverride!.call(
      includeLoopback: includeLoopback,
      includeLinkLocal: includeLinkLocal,
      type: type,
    );
  }
  final List<io.NetworkInterface> interfaces = await io.NetworkInterface.list(
    includeLoopback: includeLoopback,
    includeLinkLocal: includeLinkLocal,
    type: type,
  );
  return interfaces.map(
    (io.NetworkInterface interface) => NetworkInterface(interface),
  ).toList();
}