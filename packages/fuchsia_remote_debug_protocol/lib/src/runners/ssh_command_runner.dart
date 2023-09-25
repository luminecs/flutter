import 'dart:io' show ProcessResult;

import 'package:meta/meta.dart';
import 'package:process/process.dart';

import '../common/logging.dart';
import '../common/network.dart';

class SshCommandError extends Error {
  SshCommandError(this.message);

  final String message;

  @override
  String toString() {
    return '$SshCommandError: $message\n${super.stackTrace}';
  }
}

class SshCommandRunner {
  SshCommandRunner({
    required this.address,
    this.interface = '',
    this.sshConfigPath,
  }) : _processManager = const LocalProcessManager() {
    validateAddress(address);
  }

  @visibleForTesting
  SshCommandRunner.withProcessManager(
    this._processManager, {
    required this.address,
    this.interface = '',
    this.sshConfigPath,
  }) {
    validateAddress(address);
  }

  final Logger _log = Logger('SshCommandRunner');

  final ProcessManager _processManager;

  final String address;

  final String? sshConfigPath;

  final String interface;

  Future<List<String>> run(String command) async {
    final List<String> args = <String>[
      'ssh',
      if (sshConfigPath != null)
        ...<String>['-F', sshConfigPath!],
      if (isIpV6Address(address))
        ...<String>['-6', if (interface.isEmpty) address else '$address%$interface']
      else
        address,
      command,
    ];
    _log.fine('Running command through SSH: ${args.join(' ')}');
    final ProcessResult result = await _processManager.run(args);
    if (result.exitCode != 0) {
      throw SshCommandError(
          'Command failed: $command\nstdout: ${result.stdout}\nstderr: ${result.stderr}');
    }
    _log.fine('SSH command stdout in brackets:[${result.stdout}]');
    return (result.stdout as String).split('\n');
  }
}