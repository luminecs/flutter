import 'dart:async';

import '../debug_adapters/server.dart';
import '../globals.dart' as globals;
import '../runner/flutter_command.dart';

class DebugAdapterCommand extends FlutterCommand {
  DebugAdapterCommand({bool verboseHelp = false}) : hidden = !verboseHelp {
    usesIpv6Flag(verboseHelp: verboseHelp);
    addDdsOptions(verboseHelp: verboseHelp);
    argParser.addFlag(
      'test',
      help: 'Whether to use the "flutter test" debug adapter to run tests'
          ' and emit custom events for test progress/results.',
    );
  }

  @override
  final String name = 'debug-adapter';

  @override
  List<String> get aliases => const <String>['debug_adapter'];

  @override
  final String description =
      'Run a Debug Adapter Protocol (DAP) server to communicate with the Flutter tool.';

  @override
  final String category = FlutterCommandCategory.tools;

  @override
  final bool hidden;

  @override
  Future<FlutterCommandResult> runCommand() async {
    final DapServer server = DapServer(
      globals.stdio.stdin,
      globals.stdio.stdout.nonBlocking,
      fileSystem: globals.fs,
      platform: globals.platform,
      ipv6: ipv6 ?? false,
      enableDds: enableDds,
      test: boolArg('test'),
      onError: (Object? e) {
        globals.printError(
          'Input could not be parsed as a Debug Adapter Protocol message.\n'
          'The "flutter debug-adapter" command is intended for use by tooling '
          'that communicates using the Debug Adapter Protocol.\n\n'
          '$e',
        );
      },
    );

    await server.channel.closed;

    return FlutterCommandResult.success();
  }
}
