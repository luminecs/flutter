import 'dart:async';
import 'dart:typed_data';

import 'package:async/async.dart';
import 'package:http_multi_server/http_multi_server.dart';
import 'package:package_config/package_config.dart';
import 'package:pool/pool.dart';
import 'package:process/process.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_static/shelf_static.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test_core/src/platform.dart'; // ignore: implementation_imports
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:webkit_inspection_protocol/webkit_inspection_protocol.dart'
    hide StackTrace;

import '../artifacts.dart';
import '../base/common.dart';
import '../base/file_system.dart';
import '../base/io.dart';
import '../base/logger.dart';
import '../build_info.dart';
import '../cache.dart';
import '../convert.dart';
import '../dart/package_map.dart';
import '../project.dart';
import '../web/bootstrap.dart';
import '../web/chrome.dart';
import '../web/compile.dart';
import '../web/memory_fs.dart';
import 'flutter_web_goldens.dart';
import 'test_compiler.dart';
import 'test_time_recorder.dart';

class FlutterWebPlatform extends PlatformPlugin {
  FlutterWebPlatform._(
    this._server,
    this._config,
    this._root, {
    FlutterProject? flutterProject,
    String? shellPath,
    this.updateGoldens,
    this.nullAssertions,
    required this.buildInfo,
    required this.webMemoryFS,
    required FileSystem fileSystem,
    required PackageConfig flutterToolPackageConfig,
    required ChromiumLauncher chromiumLauncher,
    required Logger logger,
    required Artifacts? artifacts,
    required ProcessManager processManager,
    TestTimeRecorder? testTimeRecorder,
  })  : _fileSystem = fileSystem,
        _flutterToolPackageConfig = flutterToolPackageConfig,
        _chromiumLauncher = chromiumLauncher,
        _logger = logger,
        _artifacts = artifacts {
    final shelf.Cascade cascade = shelf.Cascade()
        .add(_webSocketHandler.handler)
        .add(createStaticHandler(
          fileSystem.path.join(Cache.flutterRoot!, 'packages', 'flutter_tools'),
          serveFilesOutsidePath: true,
        ))
        .add(_handleStaticArtifact)
        .add(_localCanvasKitHandler)
        .add(_goldenFileHandler)
        .add(_wrapperHandler)
        .add(_handleTestRequest)
        .add(createStaticHandler(
          fileSystem.path.join(fileSystem.currentDirectory.path, 'test'),
          serveFilesOutsidePath: true,
        ))
        .add(_packageFilesHandler);
    _server.mount(cascade.handler);
    _testGoldenComparator = TestGoldenComparator(
      shellPath,
      () => TestCompiler(buildInfo, flutterProject,
          testTimeRecorder: testTimeRecorder),
      fileSystem: _fileSystem,
      logger: _logger,
      processManager: processManager,
      webRenderer: _rendererMode,
    );
  }

  final WebMemoryFS webMemoryFS;
  final BuildInfo buildInfo;
  final FileSystem _fileSystem;
  final PackageConfig _flutterToolPackageConfig;
  final ChromiumLauncher _chromiumLauncher;
  final Logger _logger;
  final Artifacts? _artifacts;
  final bool? updateGoldens;
  final bool? nullAssertions;
  final OneOffHandler _webSocketHandler = OneOffHandler();
  final AsyncMemoizer<void> _closeMemo = AsyncMemoizer<void>();
  final String _root;

  final Pool _suiteLock = Pool(1);

  BrowserManager? _browserManager;
  late TestGoldenComparator _testGoldenComparator;

  static Future<FlutterWebPlatform> start(
    String root, {
    FlutterProject? flutterProject,
    String? shellPath,
    bool updateGoldens = false,
    bool pauseAfterLoad = false,
    bool nullAssertions = false,
    required BuildInfo buildInfo,
    required WebMemoryFS webMemoryFS,
    required FileSystem fileSystem,
    required Logger logger,
    required ChromiumLauncher chromiumLauncher,
    required Artifacts? artifacts,
    required ProcessManager processManager,
    TestTimeRecorder? testTimeRecorder,
  }) async {
    final shelf_io.IOServer server =
        shelf_io.IOServer(await HttpMultiServer.loopback(0));
    final PackageConfig packageConfig = await loadPackageConfigWithLogging(
      fileSystem.file(fileSystem.path.join(
        Cache.flutterRoot!,
        'packages',
        'flutter_tools',
        '.dart_tool',
        'package_config.json',
      )),
      logger: logger,
    );
    return FlutterWebPlatform._(
      server,
      Configuration.current.change(pauseAfterLoad: pauseAfterLoad),
      root,
      flutterProject: flutterProject,
      shellPath: shellPath,
      updateGoldens: updateGoldens,
      buildInfo: buildInfo,
      webMemoryFS: webMemoryFS,
      flutterToolPackageConfig: packageConfig,
      fileSystem: fileSystem,
      chromiumLauncher: chromiumLauncher,
      artifacts: artifacts,
      logger: logger,
      nullAssertions: nullAssertions,
      processManager: processManager,
      testTimeRecorder: testTimeRecorder,
    );
  }

  bool get _closed => _closeMemo.hasRun;

  Uri get testUri => _flutterToolPackageConfig['test']!.packageUriRoot;

  WebRendererMode get _rendererMode {
    return buildInfo.dartDefines.contains('FLUTTER_WEB_USE_SKIA=true')
        ? WebRendererMode.canvaskit
        : WebRendererMode.html;
  }

  NullSafetyMode get _nullSafetyMode {
    return buildInfo.nullSafetyMode == NullSafetyMode.sound
        ? NullSafetyMode.sound
        : NullSafetyMode.unsound;
  }

  final Configuration _config;
  final shelf.Server _server;
  Uri get url => _server.url;

  File get _ahem => _fileSystem.file(_fileSystem.path.join(
        Cache.flutterRoot!,
        'packages',
        'flutter_tools',
        'static',
        'Ahem.ttf',
      ));

  File get _requireJs => _fileSystem.file(_fileSystem.path.join(
        _artifacts!.getArtifactPath(Artifact.engineDartSdkPath,
            platform: TargetPlatform.web_javascript),
        'lib',
        'dev_compiler',
        'amd',
        'require.js',
      ));

  File get _stackTraceMapper => _fileSystem.file(_fileSystem.path.join(
        _artifacts!.getArtifactPath(Artifact.engineDartSdkPath,
            platform: TargetPlatform.web_javascript),
        'lib',
        'dev_compiler',
        'web',
        'dart_stack_trace_mapper.js',
      ));

  File get _dartSdk => _fileSystem.file(_artifacts!.getHostArtifact(
      kDartSdkJsArtifactMap[_rendererMode]![_nullSafetyMode]!));

  File get _dartSdkSourcemaps => _fileSystem.file(_artifacts!.getHostArtifact(
      kDartSdkJsMapArtifactMap[_rendererMode]![_nullSafetyMode]!));

  File get _testDartJs => _fileSystem.file(_fileSystem.path.join(
        testUri.toFilePath(),
        'dart.js',
      ));

  File get _testHostDartJs => _fileSystem.file(_fileSystem.path.join(
        testUri.toFilePath(),
        'src',
        'runner',
        'browser',
        'static',
        'host.dart.js',
      ));

  File _canvasKitFile(String relativePath) {
    final String canvasKitPath = _fileSystem.path.join(
      _artifacts!.getHostArtifact(HostArtifact.flutterWebSdk).path,
      'canvaskit',
    );
    final File canvasKitFile = _fileSystem.file(_fileSystem.path.join(
      canvasKitPath,
      relativePath,
    ));
    return canvasKitFile;
  }

  Future<shelf.Response> _handleTestRequest(shelf.Request request) async {
    if (request.url.path.endsWith('.dart.browser_test.dart.js')) {
      final String leadingPath =
          request.url.path.split('.browser_test.dart.js')[0];
      final String generatedFile =
          '${_fileSystem.path.split(leadingPath).join('_')}.bootstrap.js';
      return shelf.Response.ok(
          generateTestBootstrapFileContents(
              '/$generatedFile', 'require.js', 'dart_stack_trace_mapper.js'),
          headers: <String, String>{
            HttpHeaders.contentTypeHeader: 'text/javascript',
          });
    }
    if (request.url.path.endsWith('.dart.bootstrap.js')) {
      final String leadingPath =
          request.url.path.split('.dart.bootstrap.js')[0];
      final String generatedFile =
          '${_fileSystem.path.split(leadingPath).join('_')}.dart.test.dart.js';
      return shelf.Response.ok(
          generateMainModule(
              nullAssertions: nullAssertions!,
              nativeNullAssertions: true,
              bootstrapModule:
                  '${_fileSystem.path.basename(leadingPath)}.dart.bootstrap',
              entrypoint: '/$generatedFile'),
          headers: <String, String>{
            HttpHeaders.contentTypeHeader: 'text/javascript',
          });
    }
    if (request.url.path.endsWith('.dart.js')) {
      final String path = request.url.path.split('.dart.js')[0];
      return shelf.Response.ok(webMemoryFS.files['$path.dart.lib.js'],
          headers: <String, String>{
            HttpHeaders.contentTypeHeader: 'text/javascript',
          });
    }
    if (request.url.path.endsWith('.lib.js.map')) {
      return shelf.Response.ok(webMemoryFS.sourcemaps[request.url.path],
          headers: <String, String>{
            HttpHeaders.contentTypeHeader: 'text/plain',
          });
    }
    return shelf.Response.notFound('');
  }

  Future<shelf.Response> _handleStaticArtifact(shelf.Request request) async {
    if (request.requestedUri.path.contains('require.js')) {
      return shelf.Response.ok(
        _requireJs.openRead(),
        headers: <String, String>{'Content-Type': 'text/javascript'},
      );
    } else if (request.requestedUri.path.contains('ahem.ttf')) {
      return shelf.Response.ok(_ahem.openRead());
    } else if (request.requestedUri.path.contains('dart_sdk.js')) {
      return shelf.Response.ok(
        _dartSdk.openRead(),
        headers: <String, String>{'Content-Type': 'text/javascript'},
      );
    } else if (request.requestedUri.path.contains('dart_sdk.js.map')) {
      return shelf.Response.ok(
        _dartSdkSourcemaps.openRead(),
        headers: <String, String>{'Content-Type': 'text/javascript'},
      );
    } else if (request.requestedUri.path
        .contains('dart_stack_trace_mapper.js')) {
      return shelf.Response.ok(
        _stackTraceMapper.openRead(),
        headers: <String, String>{'Content-Type': 'text/javascript'},
      );
    } else if (request.requestedUri.path.contains('static/dart.js')) {
      return shelf.Response.ok(
        _testDartJs.openRead(),
        headers: <String, String>{'Content-Type': 'text/javascript'},
      );
    } else if (request.requestedUri.path.contains('host.dart.js')) {
      return shelf.Response.ok(
        _testHostDartJs.openRead(),
        headers: <String, String>{'Content-Type': 'text/javascript'},
      );
    } else {
      return shelf.Response.notFound('Not Found');
    }
  }

  FutureOr<shelf.Response> _packageFilesHandler(shelf.Request request) async {
    if (request.requestedUri.pathSegments.first == 'packages') {
      final Uri? fileUri = buildInfo.packageConfig.resolve(Uri(
        scheme: 'package',
        pathSegments: request.requestedUri.pathSegments.skip(1),
      ));
      if (fileUri != null) {
        final String dirname = _fileSystem.path.dirname(fileUri.toFilePath());
        final String basename = _fileSystem.path.basename(fileUri.toFilePath());
        final shelf.Handler handler = createStaticHandler(dirname);
        final shelf.Request modifiedRequest = shelf.Request(
          request.method,
          request.requestedUri.replace(path: basename),
          protocolVersion: request.protocolVersion,
          headers: request.headers,
          handlerPath: request.handlerPath,
          url: request.url.replace(path: basename),
          encoding: request.encoding,
          context: request.context,
        );
        return handler(modifiedRequest);
      }
    }
    return shelf.Response.notFound('Not Found');
  }

  Future<shelf.Response> _goldenFileHandler(shelf.Request request) async {
    if (request.url.path.contains('flutter_goldens')) {
      final Map<String, Object?> body =
          json.decode(await request.readAsString()) as Map<String, Object?>;
      final Uri goldenKey = Uri.parse(body['key']! as String);
      final Uri testUri = Uri.parse(body['testUri']! as String);
      final num width = body['width']! as num;
      final num height = body['height']! as num;
      Uint8List bytes;

      try {
        final ChromeTab chromeTab = (await _browserManager!
            ._browser.chromeConnection
            .getTab((ChromeTab tab) {
          return tab.url.contains(_browserManager!._browser.url!);
        }))!;
        final WipConnection connection = await chromeTab.connect();
        final WipResponse response = await connection
            .sendCommand('Page.captureScreenshot', <String, Object>{
          // Clip the screenshot to include only the element.
          // Prior to taking a screenshot, we are calling `window.render()` in
          // `_matchers_web.dart` to only render the element on screen. That
          // will make sure that the element will always be displayed on the
          // origin of the screen.
          'clip': <String, Object>{
            'x': 0.0,
            'y': 0.0,
            'width': width.toDouble(),
            'height': height.toDouble(),
            'scale': 1.0,
          },
        });
        bytes = base64.decode(response.result!['data'] as String);
      } on WipError catch (ex) {
        _logger.printError('Caught WIPError: $ex');
        return shelf.Response.ok('WIP error: $ex');
      } on FormatException catch (ex) {
        _logger.printError('Caught FormatException: $ex');
        return shelf.Response.ok('Caught exception: $ex');
      }

      final String? errorMessage = await _testGoldenComparator.compareGoldens(
          testUri, bytes, goldenKey, updateGoldens);
      return shelf.Response.ok(errorMessage ?? 'true');
    } else {
      return shelf.Response.notFound('Not Found');
    }
  }

  shelf.Response _localCanvasKitHandler(shelf.Request request) {
    final String fullPath = _fileSystem.path.fromUri(request.url);
    if (!fullPath.startsWith('canvaskit/')) {
      return shelf.Response.notFound('Not a CanvasKit file request');
    }

    final String relativePath = fullPath.replaceFirst('canvaskit/', '');
    final String extension = _fileSystem.path.extension(relativePath);
    String contentType;
    switch (extension) {
      case '.js':
        contentType = 'text/javascript';
      case '.wasm':
        contentType = 'application/wasm';
      default:
        final String error =
            'Failed to determine Content-Type for "${request.url.path}".';
        _logger.printError(error);
        return shelf.Response.internalServerError(body: error);
    }

    return shelf.Response.ok(
      _canvasKitFile(relativePath).openRead(),
      headers: <String, Object>{
        HttpHeaders.contentTypeHeader: contentType,
      },
    );
  }

  // A handler that serves wrapper files used to bootstrap tests.
  shelf.Response _wrapperHandler(shelf.Request request) {
    final String path = _fileSystem.path.fromUri(request.url);
    if (path.endsWith('.html')) {
      final String test = '${_fileSystem.path.withoutExtension(path)}.dart';
      final String scriptBase =
          htmlEscape.convert(_fileSystem.path.basename(test));
      final String link = '<link rel="x-dart-test" href="$scriptBase">';
      return shelf.Response.ok('''
        <!DOCTYPE html>
        <html>
        <head>
          <title>${htmlEscape.convert(test)} Test</title>
          <script>
            window.flutterConfiguration = {
              canvasKitBaseUrl: "/canvaskit/"
            };
          </script>
          $link
          <script src="static/dart.js"></script>
        </head>
        </html>
      ''', headers: <String, String>{'Content-Type': 'text/html'});
    }
    return shelf.Response.notFound('Not found.');
  }

  @override
  Future<RunnerSuite> load(
    String path,
    SuitePlatform platform,
    SuiteConfiguration suiteConfig,
    Object message,
  ) async {
    if (_closed) {
      throw StateError('Load called on a closed FlutterWebPlatform');
    }
    final PoolResource lockResource = await _suiteLock.request();

    final Runtime browser = platform.runtime;
    try {
      _browserManager = await _launchBrowser(browser);
    } on Error catch (_) {
      await _suiteLock.close();
      rethrow;
    }

    if (_closed) {
      throw StateError('Load called on a closed FlutterWebPlatform');
    }

    final String pathFromTest = _fileSystem.path
        .relative(path, from: _fileSystem.path.join(_root, 'test'));
    final Uri suiteUrl = url.resolveUri(_fileSystem.path
        .toUri('${_fileSystem.path.withoutExtension(pathFromTest)}.html'));
    final String relativePath = _fileSystem.path.relative(
        _fileSystem.path.normalize(path),
        from: _fileSystem.currentDirectory.path);
    final RunnerSuite suite = await _browserManager!
        .load(relativePath, suiteUrl, suiteConfig, message, onDone: () async {
      await _browserManager!.close();
      _browserManager = null;
      lockResource.release();
    });
    if (_closed) {
      throw StateError('Load called on a closed FlutterWebPlatform');
    }
    return suite;
  }

  Future<BrowserManager> _launchBrowser(Runtime browser) {
    if (_browserManager != null) {
      throw StateError('Another browser is currently running.');
    }

    final Completer<WebSocketChannel> completer =
        Completer<WebSocketChannel>.sync();
    final String path =
        _webSocketHandler.create(webSocketHandler(completer.complete));
    final Uri webSocketUrl = url.replace(scheme: 'ws').resolve(path);
    final Uri hostUrl = url
        .resolve('static/index.html')
        .replace(queryParameters: <String, String>{
      'managerUrl': webSocketUrl.toString(),
      'debug': _config.pauseAfterLoad.toString(),
    });

    _logger.printTrace('Serving tests at $hostUrl');

    return BrowserManager.start(
      _chromiumLauncher,
      browser,
      hostUrl,
      completer.future,
      headless: !_config.pauseAfterLoad,
    );
  }

  @override
  Future<void> closeEphemeral() async {
    if (_browserManager != null) {
      await _browserManager!.close();
    }
  }

  @override
  Future<void> close() => _closeMemo.runOnce(() async {
        await Future.wait<void>(<Future<dynamic>>[
          if (_browserManager != null) _browserManager!.close(),
          _server.close(),
          _testGoldenComparator.close(),
        ]);
      });
}

class OneOffHandler {
  final Map<String, shelf.Handler> _handlers = <String, shelf.Handler>{};

  int _counter = 0;

  shelf.Handler get handler => _onRequest;

  String create(shelf.Handler handler) {
    final String path = _counter.toString();
    _handlers[path] = handler;
    _counter++;
    return path;
  }

  FutureOr<shelf.Response> _onRequest(shelf.Request request) {
    final List<String> components = request.url.path.split('/');
    if (components.isEmpty) {
      return shelf.Response.notFound(null);
    }
    final String path = components.removeAt(0);
    final FutureOr<shelf.Response> Function(shelf.Request)? handler =
        _handlers.remove(path);
    if (handler == null) {
      return shelf.Response.notFound(null);
    }
    return handler(request.change(path: path));
  }
}

class BrowserManager {
  BrowserManager._(this._browser, this._runtime, WebSocketChannel webSocket) {
    // The duration should be short enough that the debugging console is open as
    // soon as the user is done setting breakpoints, but long enough that a test
    // doing a lot of synchronous work doesn't trigger a false positive.
    //
    // Start this canceled because we don't want it to start ticking until we
    // get some response from the iframe.
    _timer = RestartableTimer(const Duration(seconds: 3), () {
      for (final RunnerSuiteController controller in _controllers) {
        controller.setDebugging(true);
      }
    })
      ..cancel();

    // Whenever we get a message, no matter which child channel it's for, we know
    // the browser is still running code which means the user isn't debugging.
    _channel = MultiChannel<dynamic>(
      webSocket
          .cast<String>()
          .transform(jsonDocument)
          .changeStream((Stream<Object?> stream) {
        return stream.map((Object? message) {
          if (!_closed) {
            _timer.reset();
          }
          for (final RunnerSuiteController controller in _controllers) {
            controller.setDebugging(false);
          }

          return message;
        });
      }),
    );

    _environment = _loadBrowserEnvironment();
    _channel.stream.listen(_onMessage, onDone: close);
  }

  final Chromium _browser;
  final Runtime _runtime;

  late MultiChannel<dynamic> _channel;

  int _suiteID = 0;

  bool _closed = false;

  CancelableCompleter<dynamic>? _pauseCompleter;

  final StreamController<dynamic> _onRestartController =
      StreamController<dynamic>.broadcast();

  late Future<_BrowserEnvironment> _environment;

  final Set<RunnerSuiteController> _controllers = <RunnerSuiteController>{};

  // A timer that's reset whenever we receive a message from the browser.
  //
  // Because the browser stops running code when the user is actively debugging,
  // this lets us detect whether they're debugging reasonably accurately.
  late RestartableTimer _timer;

  final AsyncMemoizer<dynamic> _closeMemoizer = AsyncMemoizer<dynamic>();

  static Future<BrowserManager> start(
    ChromiumLauncher chromiumLauncher,
    Runtime runtime,
    Uri url,
    Future<WebSocketChannel> future, {
    bool debug = false,
    bool headless = true,
    List<String> webBrowserFlags = const <String>[],
  }) async {
    final Chromium chrome = await chromiumLauncher.launch(
      url.toString(),
      headless: headless,
      webBrowserFlags: webBrowserFlags,
    );
    final Completer<BrowserManager> completer = Completer<BrowserManager>();

    unawaited(chrome.onExit.then<Object?>(
      (int? browserExitCode) {
        throwToolExit(
            '${runtime.name} exited with code $browserExitCode before connecting.');
      },
    ).then(
      (Object? obj) => obj,
      onError: (Object error, StackTrace stackTrace) {
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
        return null;
      },
    ));
    unawaited(future.then(
      (WebSocketChannel webSocket) {
        if (completer.isCompleted) {
          return;
        }
        completer.complete(BrowserManager._(chrome, runtime, webSocket));
      },
      onError: (Object error, StackTrace stackTrace) {
        chrome.close();
        if (!completer.isCompleted) {
          completer.completeError(error, stackTrace);
        }
      },
    ));

    return completer.future;
  }

  Future<_BrowserEnvironment> _loadBrowserEnvironment() async {
    return _BrowserEnvironment(
        this, null, _browser.chromeConnection.url, _onRestartController.stream);
  }

  Future<RunnerSuite> load(
    String path,
    Uri url,
    SuiteConfiguration suiteConfig,
    Object message, {
    Future<void> Function()? onDone,
  }) async {
    url = url.replace(
        fragment: Uri.encodeFull(jsonEncode(<String, Object>{
      'metadata': suiteConfig.metadata.serialize(),
      'browser': _runtime.identifier,
    })));

    final int suiteID = _suiteID++;
    RunnerSuiteController? controller;
    void closeIframe() {
      if (_closed) {
        return;
      }
      _controllers.remove(controller);
      _channel.sink
          .add(<String, Object>{'command': 'closeSuite', 'id': suiteID});
    }

    // The virtual channel will be closed when the suite is closed, in which
    // case we should unload the iframe.
    final VirtualChannel<dynamic> virtualChannel = _channel.virtualChannel();
    final int suiteChannelID = virtualChannel.id;
    final StreamChannel<dynamic> suiteChannel = virtualChannel.transformStream(
      StreamTransformer<dynamic, dynamic>.fromHandlers(
          handleDone: (EventSink<dynamic> sink) {
        closeIframe();
        sink.close();
        onDone!();
      }),
    );

    _channel.sink.add(<String, Object>{
      'command': 'loadSuite',
      'url': url.toString(),
      'id': suiteID,
      'channel': suiteChannelID,
    });

    try {
      controller = deserializeSuite(path, SuitePlatform(Runtime.chrome),
          suiteConfig, await _environment, suiteChannel, message);

      _controllers.add(controller);
      return await controller.suite;
      // Not limiting to catching Exception because the exception is rethrown.
    } catch (_) {
      // ignore: avoid_catches_without_on_clauses
      closeIframe();
      rethrow;
    }
  }

  CancelableOperation<dynamic> _displayPause() {
    if (_pauseCompleter != null) {
      return _pauseCompleter!.operation;
    }
    _pauseCompleter = CancelableCompleter<dynamic>(onCancel: () {
      _channel.sink.add(<String, String>{'command': 'resume'});
      _pauseCompleter = null;
    });
    _pauseCompleter!.operation.value.whenComplete(() {
      _pauseCompleter = null;
    });
    _channel.sink.add(<String, String>{'command': 'displayPause'});

    return _pauseCompleter!.operation;
  }

  void _onMessage(dynamic message) {
    assert(message is Map<String, dynamic>);
    if (message is Map<String, dynamic>) {
      switch (message['command'] as String?) {
        case 'ping':
          break;
        case 'restart':
          _onRestartController.add(null);
        case 'resume':
          if (_pauseCompleter != null) {
            _pauseCompleter!.complete();
          }
        default:
          // Unreachable.
          assert(false);
          break;
      }
    }
  }

  Future<dynamic> close() {
    return _closeMemoizer.runOnce(() {
      _closed = true;
      _timer.cancel();
      if (_pauseCompleter != null) {
        _pauseCompleter!.complete();
      }
      _pauseCompleter = null;
      _controllers.clear();
      return _browser.close();
    });
  }
}

class _BrowserEnvironment implements Environment {
  _BrowserEnvironment(
    this._manager,
    this.observatoryUrl,
    this.remoteDebuggerUrl,
    this.onRestart,
  );

  final BrowserManager _manager;

  @override
  final bool supportsDebugging = true;

  @override
  final Uri? observatoryUrl;

  @override
  final Uri remoteDebuggerUrl;

  @override
  final Stream<dynamic> onRestart;

  @override
  CancelableOperation<dynamic> displayPause() => _manager._displayPause();
}
