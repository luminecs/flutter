import 'dart:async';
import 'dart:io';

import 'package:dds/dap.dart';
import 'package:file/file.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/convert.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:test/test.dart';

import 'test_client.dart';
import 'test_server.dart';

final bool useInProcessDap = Platform.environment['DAP_TEST_INTERNAL'] == 'true';

final bool verboseLogging = Platform.environment['DAP_TEST_VERBOSE'] == 'true';

const String endOfErrorOutputMarker = '════════════════════════════════════════════════════════════════════════════════';

void expectLines(
  String actual,
  List<Object> expected, {
  bool allowExtras = false,
}) {
  if (allowExtras) {
    expect(
      actual.replaceAll('\r\n', '\n').trim().split('\n'),
      containsAllInOrder(expected),
    );
  } else {
    expect(
      actual.replaceAll('\r\n', '\n').trim().split('\n'),
      equals(expected),
    );
  }
}

class SimpleFlutterRunner {
  SimpleFlutterRunner(this.process) {
    process.stdout.transform(ByteToLineTransformer()).listen(_handleStdout);
    process.stderr.transform(utf8.decoder).listen(_handleStderr);
    unawaited(process.exitCode.then(_handleExitCode));
  }

  final StreamController<String> _output = StreamController<String>.broadcast();

  Stream<String> get output => _output.stream;

  void _handleExitCode(int code) {
      if (!_vmServiceUriCompleter.isCompleted) {
        _vmServiceUriCompleter.completeError('Flutter process ended without producing a VM Service URI');
      }
    }

  void _handleStderr(String err) {
    if (!_vmServiceUriCompleter.isCompleted) {
      _vmServiceUriCompleter.completeError(err);
    }
  }

  void _handleStdout(String outputLine) {
    try {
      final Object? json = jsonDecode(outputLine);
      // Flutter --machine output is wrapped in [brackets] so will deserialize
      // as a list with one item.
      if (json is List && json.length == 1) {
        final Object? message = json.single;
        // Parse the add.debugPort event which contains our VM Service URI.
        if (message is Map<String, Object?> && message['event'] == 'app.debugPort') {
          final String vmServiceUri = (message['params']! as Map<String, Object?>)['wsUri']! as String;
          if (!_vmServiceUriCompleter.isCompleted) {
            _vmServiceUriCompleter.complete(Uri.parse(vmServiceUri));
          }
        }
      }
    } on FormatException {
      // `flutter run` writes a lot of text to stdout that isn't daemon messages
      //  (not valid JSON), so just pass that one for tests that may want it.
      _output.add(outputLine);
    }
  }

  final Process process;
  final Completer<Uri> _vmServiceUriCompleter = Completer<Uri>();
   Future<Uri> get vmServiceUri => _vmServiceUriCompleter.future;

  static Future<SimpleFlutterRunner> start(Directory projectDirectory) async {
    final String flutterToolPath = globals.fs.path.join(Cache.flutterRoot!, 'bin', globals.platform.isWindows ? 'flutter.bat' : 'flutter');

    final List<String> args = <String>[
      'run',
      '--machine',
      '-d',
      'flutter-tester',
    ];

    final Process process = await Process.start(
      flutterToolPath,
      args,
      workingDirectory: projectDirectory.path,
    );

    return SimpleFlutterRunner(process);
  }
}

class DapTestSession {
  DapTestSession._(this.server, this.client);

  DapTestServer server;
  DapTestClient client;

  Future<void> tearDown() async {
    await client.stop();
    await server.stop();
  }

  static Future<DapTestSession> setUp({List<String>? additionalArgs}) async {
    final DapTestServer server = await _startServer(additionalArgs: additionalArgs);
    final DapTestClient client = await DapTestClient.connect(
      server,
      captureVmServiceTraffic: verboseLogging,
      logger: verboseLogging ? print : null,
    );
    return DapTestSession._(server, client);
  }

  static Future<DapTestServer> _startServer({
    Logger? logger,
    List<String>? additionalArgs,
  }) async {
    return useInProcessDap
        ? await InProcessDapTestServer.create(
            logger: logger,
            additionalArgs: additionalArgs,
          )
        : await OutOfProcessDapTestServer.create(
            logger: logger,
            additionalArgs: additionalArgs,
          );
  }
}