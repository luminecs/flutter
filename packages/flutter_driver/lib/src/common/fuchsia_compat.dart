// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:fuchsia_remote_debug_protocol/fuchsia_remote_debug_protocol.dart';

import 'error.dart';

class _DummyPortForwarder implements PortForwarder {
  _DummyPortForwarder(this._port, this._remotePort);

  final int _port;
  final int _remotePort;

  @override
  int get port => _port;

  @override
  int get remotePort => _remotePort;

  @override
  String get openPortAddress => InternetAddress.loopbackIPv4.address;

  @override
  Future<void> stop() async { }
}

class _DummySshCommandRunner implements SshCommandRunner {
  _DummySshCommandRunner();

  void _log(String message) {
    driverLog('_DummySshCommandRunner', message);
  }

  @override
  String get sshConfigPath => '';

  @override
  String get address => InternetAddress.loopbackIPv4.address;

  @override
  String get interface => '';

  @override
  Future<List<String>> run(String command) async {
    try {
      final List<String> splitCommand = command.split(' ');
      final String exe = splitCommand[0];
      final List<String> args = splitCommand.skip(1).toList();
      // This needs to remain async in the event that this command attempts to
      // access something (like the hub) that requires interaction with this
      // process's event loop. A specific example is attempting to run `find`, a
      // synchronous command, on this own process's `out` directory. As `find`
      // will wait indefinitely for the `out` directory to be serviced, causing
      // a deadlock.
      final ProcessResult r = await Process.run(exe, args);
      return (r.stdout as String).split('\n');
    } on ProcessException catch (e) {
      _log("Error running '$command': $e");
    }
    return <String>[];
  }
}

Future<PortForwarder> _dummyPortForwardingFunction(
  String address,
  int remotePort, [
  String? interface,
  String? configFile,
]) async {
  return _DummyPortForwarder(remotePort, remotePort);
}

abstract final class FuchsiaCompat {
  static void _init() {
    fuchsiaPortForwardingFunction = _dummyPortForwardingFunction;
  }

  static void cleanup() {
    restoreFuchsiaPortForwardingFunction();
  }

  static Future<FuchsiaRemoteConnection> connect() async {
    FuchsiaCompat._init();
    return FuchsiaRemoteConnection.connectWithSshCommandRunner(
        _DummySshCommandRunner());
  }
}