// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import '../base/common.dart';
import '../base/file_system.dart';
import '../base/io.dart';
import '../base/net.dart';
import '../base/process.dart';
import '../convert.dart';
import '../globals.dart' as globals;

class FuchsiaPM {
  Future<bool> init(String buildPath, String appName) {
    return _runPMCommand(<String>[
      '-o',
      buildPath,
      '-n',
      appName,
      'init',
    ]);
  }

  Future<bool> build(String buildPath, String manifestPath) {
    return _runPMCommand(<String>[
      '-o',
      buildPath,
      '-m',
      manifestPath,
      'build',
    ]);
  }

  Future<bool> archive(String buildPath, String manifestPath) {
    return _runPMCommand(<String>[
      '-o',
      buildPath,
      '-m',
      manifestPath,
      'archive',
    ]);
  }

  Future<bool> newrepo(String repoPath) {
    return _runPMCommand(<String>[
      'newrepo',
      '-repo',
      repoPath,
    ]);
  }

  Future<Process> serve(String repoPath, String host, int port) async {
    final File? pm = globals.fuchsiaArtifacts?.pm;
    if (pm == null) {
      throwToolExit('Fuchsia pm tool not found');
    }
    if (isIPv6Address(host.split('%').first)) {
      host = '[$host]';
    }
    final List<String> command = <String>[
      pm.path,
      'serve',
      '-repo',
      repoPath,
      '-l',
      '$host:$port',
      '-c',
      '2',
    ];
    final Process process = await globals.processUtils.start(command);
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(globals.printTrace);
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(globals.printError);
    return process;
  }

  Future<bool> publish(String repoPath, String packagePath) {
    return _runPMCommand(<String>[
      'publish',
      '-a',
      '-r',
      repoPath,
      '-f',
      packagePath,
    ]);
  }

  Future<bool> _runPMCommand(List<String> args) async {
    final File? pm = globals.fuchsiaArtifacts?.pm;
    if (pm == null) {
      throwToolExit('Fuchsia pm tool not found');
    }
    final List<String> command = <String>[pm.path, ...args];
    final RunResult result = await globals.processUtils.run(command);
    return result.exitCode == 0;
  }
}

class FuchsiaPackageServer {
  factory FuchsiaPackageServer(
      String repo, String name, String host, int port) {
    return FuchsiaPackageServer._(repo, name, host, port);
  }

  FuchsiaPackageServer._(this._repo, this.name, this._host, this._port);

  static const String deviceHost = 'fuchsia.com';
  static const String toolHost = 'flutter-tool';

  final String _repo;
  final String _host;
  final int _port;

  Process? _process;

  // The name used to reference the server by fuchsia-pkg:// urls.
  final String name;

  int get port => _port;

  Future<bool> start() async {
    if (_process != null) {
      globals.printError('$this already started!');
      return false;
    }
    // initialize a new repo.
    final FuchsiaPM? fuchsiaPM = globals.fuchsiaSdk?.fuchsiaPM;
    if (fuchsiaPM == null || !await fuchsiaPM.newrepo(_repo)) {
      globals.printError('Failed to create a new package server repo');
      return false;
    }
    _process = await fuchsiaPM.serve(_repo, _host, _port);
    // Put a completer on _process.exitCode to watch for error.
    unawaited(_process?.exitCode.whenComplete(() {
      // If _process is null, then the server was stopped deliberately.
      if (_process != null) {
        globals.printError('Error running Fuchsia pm tool "serve" command');
      }
    }));
    return true;
  }

  void stop() {
    if (_process != null) {
      _process?.kill();
      _process = null;
    }
  }

  Future<bool> addPackage(File package) async {
    if (_process == null) {
      return false;
    }
    return (await globals.fuchsiaSdk?.fuchsiaPM.publish(_repo, package.path)) ??
        false;
  }

  @override
  String toString() {
    final String p =
        (_process == null) ? 'stopped' : 'running ${_process?.pid}';
    return 'FuchsiaPackageServer at $_host:$_port ($p)';
  }
}