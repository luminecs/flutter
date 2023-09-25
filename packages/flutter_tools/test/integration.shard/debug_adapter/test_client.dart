// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:dds/dap.dart';
import 'package:flutter_tools/src/debug_adapters/flutter_adapter_args.dart';

import 'test_server.dart';

class DapTestClient {
  DapTestClient._(
    this._channel,
    this._logger, {
    this.captureVmServiceTraffic = false,
  }) {
    // Set up a future that will complete when the 'dart.debuggerUris' event is
    // emitted by the debug adapter so tests have easy access to it.
    vmServiceUri = event('dart.debuggerUris').then<Uri?>((Event event) {
      final Map<String, Object?> body = event.body! as Map<String, Object?>;
      return Uri.parse(body['vmServiceUri']! as String);
    }).then(
      (Uri? uri) => uri,
      onError: (Object? e) => null,
    );

    _subscription = _channel.listen(
      _handleMessage,
      onDone: () {
        if (_pendingRequests.isNotEmpty) {
          _logger?.call(
              'Application terminated without a response to ${_pendingRequests.length} requests');
        }
        _pendingRequests.forEach((int id, _OutgoingRequest request) => request.completer.completeError(
            'Application terminated without a response to request $id (${request.name})'));
        _pendingRequests.clear();
      },
    );
  }

  final ByteStreamServerChannel _channel;
  late final StreamSubscription<String> _subscription;
  final Logger? _logger;
  final bool captureVmServiceTraffic;
  final Map<int, _OutgoingRequest> _pendingRequests = <int, _OutgoingRequest>{};
  final StreamController<Event> _eventController = StreamController<Event>.broadcast();
  int _seq = 1;
  late final Future<Uri?> vmServiceUri;

  Stream<OutputEventBody> get outputEvents => events('output')
      .map((Event e) => OutputEventBody.fromJson(e.body! as Map<String, Object?>));

  Stream<StoppedEventBody> get stoppedEvents => events('stopped')
      .map((Event e) => StoppedEventBody.fromJson(e.body! as Map<String, Object?>));

  Stream<String> get output => outputEvents.map((OutputEventBody output) => output.output);

  Stream<String> get stdoutOutput => outputEvents
      .where((OutputEventBody output) => output.category == 'stdout')
      .map((OutputEventBody output) => output.output);

  Future<Response> custom(String name, [Object? args]) async {
    return sendRequest(args, overrideCommand: name);
  }

  Future<Event> event(String event) => _eventController.stream.firstWhere(
      (Event e) => e.event == event,
      orElse: () => throw Exception('Did not receive $event event before stream closed'));

  Stream<Event> events(String event) {
    return _eventController.stream.where((Event e) => e.event == event);
  }

  Stream<Event> progressEvents() {
    const Set<String> progressEvents = <String>{'progressStart', 'progressUpdate', 'progressEnd'};
    return _eventController.stream.where((Event e) => progressEvents.contains(e.event));
  }

  Stream<Map<String, Object?>> get serviceExtensionAddedEvents =>
      events('dart.serviceExtensionAdded')
          .map((Event e) => e.body! as Map<String, Object?>);

  Stream<Map<String, Object?>> get serviceExtensionStateChangedEvents =>
      events('flutter.serviceExtensionStateChanged')
          .map((Event e) => e.body! as Map<String, Object?>);

  Stream<Map<String, Object?>> get testNotificationEvents =>
      events('dart.testNotification')
          .map((Event e) => e.body! as Map<String, Object?>);

  Future<Response> hotReload() {
    return custom('hotReload');
  }

  Future<Response> customSyntaxHotReload() {
    return custom(r'$/hotReload');
  }

  Future<Response> hotRestart() {
    return custom('hotRestart');
  }

  Future<Response> initialize({
    String exceptionPauseMode = 'None',
    bool? supportsRunInTerminalRequest,
    bool? supportsProgressReporting,
  }) async {
    final List<ProtocolMessage> responses = await Future.wait(<Future<ProtocolMessage>>[
      event('initialized'),
      sendRequest(InitializeRequestArguments(
        adapterID: 'test',
        supportsRunInTerminalRequest: supportsRunInTerminalRequest,
        supportsProgressReporting: supportsProgressReporting,
      )),
      sendRequest(
        SetExceptionBreakpointsArguments(
          filters: <String>[exceptionPauseMode],
        ),
      ),
    ]);
    await sendRequest(ConfigurationDoneArguments());
    return responses[1] as Response; // Return the initialize response.
  }

  Future<Response> launch({
    String? program,
    List<String>? args,
    List<String>? toolArgs,
    String? cwd,
    bool? noDebug,
    List<String>? additionalProjectPaths,
    bool? allowAnsiColorOutput,
    bool? debugSdkLibraries,
    bool? debugExternalPackageLibraries,
    bool? evaluateGettersInDebugViews,
    bool? evaluateToStringInDebugViews,
    bool sendLogsToClient = false,
  }) {
    return sendRequest(
      FlutterLaunchRequestArguments(
        noDebug: noDebug,
        program: program,
        cwd: cwd,
        args: args,
        toolArgs: toolArgs,
        additionalProjectPaths: additionalProjectPaths,
        allowAnsiColorOutput: allowAnsiColorOutput,
        debugSdkLibraries: debugSdkLibraries,
        debugExternalPackageLibraries: debugExternalPackageLibraries,
        evaluateGettersInDebugViews: evaluateGettersInDebugViews,
        evaluateToStringInDebugViews: evaluateToStringInDebugViews,
        // When running out of process, VM Service traffic won't be available
        // to the client-side logger, so force logging regardless of
        // `sendLogsToClient` which sends VM Service traffic in a custom event.
        sendLogsToClient: sendLogsToClient || captureVmServiceTraffic,
      ),
      // We can't automatically pick the command when using a custom type
      // (FlutterLaunchRequestArguments).
      overrideCommand: 'launch',
    );
  }

  Future<Response> attach({
    List<String>? toolArgs,
    String? vmServiceUri,
    String? cwd,
    List<String>? additionalProjectPaths,
    bool? debugSdkLibraries,
    bool? debugExternalPackageLibraries,
    bool? evaluateGettersInDebugViews,
    bool? evaluateToStringInDebugViews,
  }) {
    return sendRequest(
      FlutterAttachRequestArguments(
        cwd: cwd,
        toolArgs: toolArgs,
        vmServiceUri: vmServiceUri,
        additionalProjectPaths: additionalProjectPaths,
        debugSdkLibraries: debugSdkLibraries,
        debugExternalPackageLibraries: debugExternalPackageLibraries,
        evaluateGettersInDebugViews: evaluateGettersInDebugViews,
        evaluateToStringInDebugViews: evaluateToStringInDebugViews,
        // When running out of process, VM Service traffic won't be available
        // to the client-side logger, so force logging on which sends VM Service
        // traffic in a custom event.
        sendLogsToClient: captureVmServiceTraffic,
      ),
      // We can't automatically pick the command when using a custom type
      // (FlutterAttachRequestArguments).
      overrideCommand: 'attach',
    );
  }

  Future<Response> sendRequest(Object? arguments,
      {bool allowFailure = false, String? overrideCommand}) {
    final String command = overrideCommand ?? commandTypes[arguments.runtimeType]!;
    final Request request =
        Request(seq: _seq++, command: command, arguments: arguments);
    final Completer<Response> completer = Completer<Response>();
    _pendingRequests[request.seq] =
        _OutgoingRequest(completer, command, allowFailure);
    _channel.sendRequest(request);
    return completer.future;
  }

  Future<Map<String, Object?>> serviceExtensionAdded(String extension) => serviceExtensionAddedEvents.firstWhere(
      (Map<String, Object?> body) => body['extensionRPC'] == extension,
      orElse: () => throw Exception('Did not receive $extension extension added event before stream closed'));

  Future<Map<String, Object?>> serviceExtensionStateChanged(String extension) => serviceExtensionStateChangedEvents.firstWhere(
      (Map<String, Object?> body) => body['extension'] == extension,
      orElse: () => throw Exception('Did not receive $extension extension state changed event before stream closed'));

  Future<void> start({
    String? program,
    String? cwd,
    String exceptionPauseMode = 'None',
    Future<Object?> Function()? launch,
  }) {
    return Future.wait(<Future<Object?>>[
      initialize(exceptionPauseMode: exceptionPauseMode),
      launch?.call() ?? this.launch(program: program, cwd: cwd),
    ], eagerError: true);
  }

  Future<void> stop() async {
    _channel.close();
    await _subscription.cancel();
  }

  Future<Response> terminate() => sendRequest(TerminateArguments());

  Future<void> _handleMessage(Object? message) async {
    if (message is Response) {
      final _OutgoingRequest? pendingRequest = _pendingRequests.remove(message.requestSeq);
      if (pendingRequest == null) {
        return;
      }
      final Completer<Response> completer = pendingRequest.completer;
      if (message.success || pendingRequest.allowFailure) {
        completer.complete(message);
      } else {
        completer.completeError(message);
      }
    } else if (message is Event && !_eventController.isClosed) {
      _eventController.add(message);

      // When we see a terminated event, close the event stream so if any
      // tests are waiting on something that will never come, they fail at
      // a useful location.
      if (message.event == 'terminated') {
        unawaited(_eventController.close());
      }
    }
  }

  static Future<DapTestClient> connect(
    DapTestServer server, {
    bool captureVmServiceTraffic = false,
    Logger? logger,
  }) async {
    final ByteStreamServerChannel channel = ByteStreamServerChannel(server.stream, server.sink, logger);
    return DapTestClient._(channel, logger,
        captureVmServiceTraffic: captureVmServiceTraffic);
  }
}

class TestEvents {
  TestEvents({
    required this.output,
    required this.testNotifications,
  });

  final List<OutputEventBody> output;
  final List<Map<String, Object?>> testNotifications;
}

class _OutgoingRequest {
  _OutgoingRequest(this.completer, this.name, this.allowFailure);

  final Completer<Response> completer;
  final String name;
  final bool allowFailure;
}

extension DapTestClientExtension on DapTestClient {
  Future<List<OutputEventBody>> collectAllOutput({
    String? program,
    String? cwd,
    Future<void> Function()? start,
    Future<Response> Function()? launch,
    bool skipInitialPubGetOutput = true
  }) async {
    assert(
      start == null || launch == null,
      'Only one of "start" or "launch" may be provided',
    );
    final Future<List<OutputEventBody>> outputEventsFuture = outputEvents.toList();

    // Don't await these, in case they don't complete (eg. an error prevents
    // the app from starting).
    if (start != null) {
      unawaited(start());
    } else {
      unawaited(this.start(program: program, cwd: cwd, launch: launch));
    }

    final List<OutputEventBody> output = await outputEventsFuture;

    // Integration tests may trigger "flutter pub get" at the start based of
    // `pubspec/yaml` and `.dart_tool/package_config.json`.
    // See
    //  https://github.com/flutter/flutter/pull/91300
    //  https://github.com/flutter/flutter/issues/120015
    return skipInitialPubGetOutput
        ? output
            .skipWhile((OutputEventBody output) =>
                output.output.startsWith('Running "flutter pub get"') ||
                output.output.startsWith('Resolving dependencies') ||
                output.output.startsWith('Got dependencies'))
            .toList()
        : output;
  }

  Future<TestEvents> collectTestOutput({
    String? program,
    String? cwd,
    Future<Response> Function()? start,
    Future<Object?> Function()? launch,
  }) async {
    assert(
      start == null || launch == null,
      'Only one of "start" or "launch" may be provided',
    );

    final Future<List<OutputEventBody>> outputEventsFuture = outputEvents.toList();
    final Future<List<Map<String, Object?>>> testNotificationEventsFuture = testNotificationEvents.toList();

    if (start != null) {
      await start();
    } else {
      await this.start(program: program, cwd: cwd, launch: launch);
    }

    return TestEvents(
      output: await outputEventsFuture,
      testNotifications: await testNotificationEventsFuture,
    );
  }

  Future<void> setBreakpoint(String filePath, int line) async {
    await sendRequest(
      SetBreakpointsArguments(
        source: Source(path: filePath),
        breakpoints: <SourceBreakpoint>[
          SourceBreakpoint(line: line),
        ],
      ),
    );
  }

  Future<Response> continue_(int threadId) =>
      sendRequest(ContinueArguments(threadId: threadId));

  Future<void> clearBreakpoints(String filePath) async {
    await sendRequest(
      SetBreakpointsArguments(
        source: Source(path: filePath),
        breakpoints: <SourceBreakpoint>[],
      ),
    );
  }

}