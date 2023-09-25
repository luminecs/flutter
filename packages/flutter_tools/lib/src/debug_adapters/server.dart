
import 'dart:async';

import 'package:dds/dap.dart' hide DapServer;

import '../base/file_system.dart';
import '../base/platform.dart';
import '../debug_adapters/flutter_adapter.dart';
import '../debug_adapters/flutter_adapter_args.dart';
import 'flutter_test_adapter.dart';

class DapServer {
  DapServer(
    Stream<List<int>> input,
    StreamSink<List<int>> output, {
    required FileSystem fileSystem,
    required Platform platform,
    this.ipv6 = false,
    this.enableDds = true,
    this.enableAuthCodes = true,
    bool test = false,
    this.logger,
    void Function(Object? e)? onError,
  }) : channel = ByteStreamServerChannel(input, output, logger) {
    adapter = test
        ? FlutterTestDebugAdapter(
            channel,
            fileSystem: fileSystem,
            platform: platform,
            ipv6: ipv6,
            enableFlutterDds: enableDds,
            enableAuthCodes: enableAuthCodes,
            logger: logger,
            onError: onError,
          )
        : FlutterDebugAdapter(
            channel,
            fileSystem: fileSystem,
            platform: platform,
            enableFlutterDds: enableDds,
            enableAuthCodes: enableAuthCodes,
            logger: logger,
            onError: onError,
          );
  }

  final ByteStreamServerChannel channel;
  late final DartDebugAdapter<FlutterLaunchRequestArguments, FlutterAttachRequestArguments> adapter;
  final bool ipv6;
  final bool enableDds;
  final bool enableAuthCodes;
  final Logger? logger;

  void stop() {
    channel.close();
  }
}