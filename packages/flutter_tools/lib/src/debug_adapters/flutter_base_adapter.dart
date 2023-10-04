import 'dart:async';

import 'package:dds/dap.dart' hide PidTracker;
import 'package:vm_service/vm_service.dart' as vm;

import '../base/file_system.dart';
import '../base/io.dart';
import '../base/platform.dart';
import '../cache.dart';
import 'flutter_adapter_args.dart';
import 'mixins.dart';

abstract class FlutterBaseDebugAdapter extends DartDebugAdapter<
    FlutterLaunchRequestArguments,
    FlutterAttachRequestArguments> with PidTracker {
  FlutterBaseDebugAdapter(
    super.channel, {
    required this.fileSystem,
    required this.platform,
    super.ipv6,
    this.enableFlutterDds = true,
    super.enableAuthCodes,
    super.logger,
    super.onError,
  })  : flutterSdkRoot = Cache.flutterRoot!,
        // Always disable in the DAP layer as it's handled in the spawned
        // 'flutter' process.
        super(enableDds: false) {
    configureOrgDartlangSdkMappings();
  }

  FileSystem fileSystem;
  Platform platform;
  Process? process;

  final String flutterSdkRoot;

  final bool enableFlutterDds;

  @override
  final FlutterLaunchRequestArguments Function(Map<String, Object?> obj)
      parseLaunchArgs = FlutterLaunchRequestArguments.fromJson;

  @override
  final FlutterAttachRequestArguments Function(Map<String, Object?> obj)
      parseAttachArgs = FlutterAttachRequestArguments.fromJson;

  @override
  bool get terminateOnVmServiceClose => false;

  bool get enableDebugger {
    final DartCommonLaunchAttachRequestArguments args = this.args;
    if (args is FlutterLaunchRequestArguments) {
      // Invert DAP's noDebug flag, treating it as false (so _do_ debug) if not
      // provided.
      return !(args.noDebug ?? false);
    }

    // Otherwise (attach), always debug.
    return true;
  }

  void configureOrgDartlangSdkMappings() {
    // Clear original Dart SDK mappings because they're not valid here.
    orgDartlangSdkMappings.clear();

    // 'dart:ui' maps to /flutter/lib/ui
    final String flutterRoot = fileSystem.path
        .join(flutterSdkRoot, 'bin', 'cache', 'pkg', 'sky_engine', 'lib', 'ui');
    orgDartlangSdkMappings[flutterRoot] =
        Uri.parse('org-dartlang-sdk:///flutter/lib/ui');

    // The rest of the Dart SDK maps to /third_party/dart/sdk
    final String dartRoot = fileSystem.path
        .join(flutterSdkRoot, 'bin', 'cache', 'pkg', 'sky_engine');
    orgDartlangSdkMappings[dartRoot] =
        Uri.parse('org-dartlang-sdk:///third_party/dart/sdk');
  }

  @override
  Future<void> debuggerConnected(vm.VM vmInfo) async {
    // Usually we'd capture the pid from the VM here and record it for
    // terminating, however for Flutter apps it may be running on a remote
    // device so it's not valid to terminate a process with that pid locally.
    // For attach, pids should never be collected as terminateRequest() should
    // not terminate the debugee.
  }

  @override
  Future<void> disconnectImpl() async {
    if (isAttach) {
      await handleDetach();
    }
    terminatePids(ProcessSignal.sigkill);
  }

  Future<void> launchAsProcess({
    required String executable,
    required List<String> processArgs,
    required Map<String, String>? env,
  }) async {
    final Process process = await (
      String executable,
      List<String> processArgs, {
      required Map<String, String>? env,
    }) async {
      logger?.call('Spawning $executable with $processArgs in ${args.cwd}');
      final Process process = await Process.start(
        executable,
        processArgs,
        workingDirectory: args.cwd,
        environment: env,
      );
      pidsToTerminate.add(process.pid);
      return process;
    }(executable, processArgs, env: env);
    this.process = process;

    process.stdout.transform(ByteToLineTransformer()).listen(handleStdout);
    process.stderr.listen(handleStderr);
    unawaited(process.exitCode.then(handleExitCode));
  }

  void handleExitCode(int code);
  void handleStderr(List<int> data);
  void handleStdout(String data);
}
