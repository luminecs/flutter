import 'dart:core' hide print;
import 'dart:io' hide exit;

import 'package:path/path.dart' as path;
import 'package:shelf/shelf.dart';

import 'browser.dart';
import 'run_command.dart';
import 'test/common.dart';
import 'utils.dart';

final String _bat = Platform.isWindows ? '.bat' : '';
final String _flutterRoot =
    path.dirname(path.dirname(path.dirname(path.fromUri(Platform.script))));
final String _flutter = path.join(_flutterRoot, 'bin', 'flutter$_bat');
final String _testAppDirectory =
    path.join(_flutterRoot, 'dev', 'integration_tests', 'web');
final String _testAppWebDirectory = path.join(_testAppDirectory, 'web');
final String _appBuildDirectory = path.join(_testAppDirectory, 'build', 'web');
final String _target = path.join('lib', 'service_worker_test.dart');
final String _targetWithCachedResources =
    path.join('lib', 'service_worker_test_cached_resources.dart');
final String _targetWithBlockedServiceWorkers =
    path.join('lib', 'service_worker_test_blocked_service_workers.dart');
final String _targetPath = path.join(_testAppDirectory, _target);

enum ServiceWorkerTestType {
  // Mocks how FF disables service workers.
  blockedServiceWorkers,
  // Drops the main.dart.js directly on the page.
  withoutFlutterJs,
  // Uses the standard, promise-based, flutterJS initialization.
  withFlutterJs,
  // Uses the shorthand engineInitializer.autoStart();
  withFlutterJsShort,
  // Uses onEntrypointLoaded callback instead of returned promise.
  withFlutterJsEntrypointLoadedEvent,
  // Same as withFlutterJsEntrypointLoadedEvent, but with TrustedTypes enabled.
  withFlutterJsTrustedTypesOn,
  // Uses custom serviceWorkerVersion.
  withFlutterJsCustomServiceWorkerVersion,
  // Entrypoint generated by `flutter create`.
  generatedEntrypoint,
}

// Run a web service worker test as a standalone Dart program.
Future<void> main() async {
  // When updating this list, also update `dev/bots/test.dart`. This `main()`
  // function is only here for convenience. Adding tests here will not add them
  // to LUCI.
  await runWebServiceWorkerTest(
      headless: false, testType: ServiceWorkerTestType.withoutFlutterJs);
  await runWebServiceWorkerTest(
      headless: false, testType: ServiceWorkerTestType.withFlutterJs);
  await runWebServiceWorkerTest(
      headless: false, testType: ServiceWorkerTestType.withFlutterJsShort);
  await runWebServiceWorkerTest(
      headless: false,
      testType: ServiceWorkerTestType.withFlutterJsEntrypointLoadedEvent);
  await runWebServiceWorkerTest(
      headless: false,
      testType: ServiceWorkerTestType.withFlutterJsTrustedTypesOn);
  await runWebServiceWorkerTestWithCachingResources(
      headless: false, testType: ServiceWorkerTestType.withoutFlutterJs);
  await runWebServiceWorkerTestWithCachingResources(
      headless: false, testType: ServiceWorkerTestType.withFlutterJs);
  await runWebServiceWorkerTestWithCachingResources(
      headless: false, testType: ServiceWorkerTestType.withFlutterJsShort);
  await runWebServiceWorkerTestWithCachingResources(
      headless: false,
      testType: ServiceWorkerTestType.withFlutterJsEntrypointLoadedEvent);
  await runWebServiceWorkerTestWithCachingResources(
      headless: false,
      testType: ServiceWorkerTestType.withFlutterJsTrustedTypesOn);
  await runWebServiceWorkerTestWithGeneratedEntrypoint(headless: false);
  await runWebServiceWorkerTestWithBlockedServiceWorkers(headless: false);
  await runWebServiceWorkerTestWithCustomServiceWorkerVersion(headless: false);

  if (hasError) {
    reportErrorsAndExit('${bold}One or more tests failed.$reset');
  }
  reportSuccessAndExit('${bold}Tests successful.$reset');
}

// Regression test for https://github.com/flutter/flutter/issues/109093.
//
// Tests the entrypoint that's generated by `flutter create`.
Future<void> runWebServiceWorkerTestWithGeneratedEntrypoint({
  required bool headless,
}) async {
  await _generateEntrypoint();
  await runWebServiceWorkerTestWithCachingResources(
      headless: headless, testType: ServiceWorkerTestType.generatedEntrypoint);
}

Future<void> _generateEntrypoint() async {
  final Directory tempDirectory =
      Directory.systemTemp.createTempSync('flutter_web_generated_entrypoint.');
  await runCommand(
    _flutter,
    <String>['create', 'generated_entrypoint_test'],
    workingDirectory: tempDirectory.path,
  );
  final File generatedEntrypoint = File(path.join(
      tempDirectory.path, 'generated_entrypoint_test', 'web', 'index.html'));
  final String generatedEntrypointCode = generatedEntrypoint.readAsStringSync();
  final File testEntrypoint = File(path.join(
    _testAppWebDirectory,
    _testTypeToIndexFile(ServiceWorkerTestType.generatedEntrypoint),
  ));
  testEntrypoint.writeAsStringSync(generatedEntrypointCode);
  tempDirectory.deleteSync(recursive: true);
}

Future<void> _setAppVersion(int version) async {
  final File targetFile = File(_targetPath);
  await targetFile.writeAsString((await targetFile.readAsString()).replaceFirst(
    RegExp(r'CLOSE\?version=\d+'),
    'CLOSE?version=$version',
  ));
}

String _testTypeToIndexFile(ServiceWorkerTestType type) {
  late String indexFile;
  switch (type) {
    case ServiceWorkerTestType.blockedServiceWorkers:
      indexFile = 'index_with_blocked_service_workers.html';
    case ServiceWorkerTestType.withFlutterJs:
      indexFile = 'index_with_flutterjs.html';
    case ServiceWorkerTestType.withoutFlutterJs:
      indexFile = 'index_without_flutterjs.html';
    case ServiceWorkerTestType.withFlutterJsShort:
      indexFile = 'index_with_flutterjs_short.html';
    case ServiceWorkerTestType.withFlutterJsEntrypointLoadedEvent:
      indexFile = 'index_with_flutterjs_entrypoint_loaded.html';
    case ServiceWorkerTestType.withFlutterJsTrustedTypesOn:
      indexFile = 'index_with_flutterjs_el_tt_on.html';
    case ServiceWorkerTestType.withFlutterJsCustomServiceWorkerVersion:
      indexFile = 'index_with_flutterjs_custom_sw_version.html';
    case ServiceWorkerTestType.generatedEntrypoint:
      indexFile = 'generated_entrypoint.html';
  }
  return indexFile;
}

Future<void> _rebuildApp(
    {required int version,
    required ServiceWorkerTestType testType,
    required String target}) async {
  await _setAppVersion(version);
  await runCommand(
    _flutter,
    <String>['clean'],
    workingDirectory: _testAppDirectory,
  );
  await runCommand(
    'cp',
    <String>[
      _testTypeToIndexFile(testType),
      'index.html',
    ],
    workingDirectory: _testAppWebDirectory,
  );
  await runCommand(
    _flutter,
    <String>['build', 'web', '--web-resources-cdn', '--profile', '-t', target],
    workingDirectory: _testAppDirectory,
    environment: <String, String>{
      'FLUTTER_WEB': 'true',
    },
  );
}

void _expectRequestCounts(
  Map<String, int> expectedCounts,
  Map<String, int> requestedPathCounts,
) {
  expect(requestedPathCounts, expectedCounts);
  requestedPathCounts.clear();
}

Future<void> _waitForAppToLoad(Map<String, int> waitForCounts,
    Map<String, int> requestedPathCounts, AppServer? server) async {
  print('Waiting for app to load $waitForCounts');
  await Future.any(<Future<Object?>>[
    () async {
      while (!waitForCounts.entries.every((MapEntry<String, int> entry) =>
          (requestedPathCounts[entry.key] ?? 0) >= entry.value)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }(),
    server!.onChromeError.then((String error) {
      throw Exception('Chrome error: $error');
    }),
  ]);
}

void expect(Object? actual, Object? expected) {
  final Matcher matcher = wrapMatcher(expected);
  // matchState needs to be of type <Object?, Object?>, see https://github.com/flutter/flutter/issues/99522
  final Map<Object?, Object?> matchState = <Object?, Object?>{};
  if (matcher.matches(actual, matchState)) {
    return;
  }
  final StringDescription mismatchDescription = StringDescription();
  matcher.describeMismatch(actual, mismatchDescription, matchState, true);
  throw TestFailure(mismatchDescription.toString());
}

Future<void> runWebServiceWorkerTest({
  required bool headless,
  required ServiceWorkerTestType testType,
}) async {
  final Map<String, int> requestedPathCounts = <String, int>{};
  void expectRequestCounts(Map<String, int> expectedCounts) =>
      _expectRequestCounts(expectedCounts, requestedPathCounts);

  AppServer? server;
  Future<void> waitForAppToLoad(Map<String, int> waitForCounts) async =>
      _waitForAppToLoad(waitForCounts, requestedPathCounts, server);

  String? reportedVersion;

  Future<void> startAppServer({
    required String cacheControl,
  }) async {
    final int serverPort = await findAvailablePortAndPossiblyCauseFlakyTests();
    final int browserDebugPort =
        await findAvailablePortAndPossiblyCauseFlakyTests();
    server = await AppServer.start(
      headless: headless,
      cacheControl: cacheControl,
      // TODO(yjbanov): use a better port disambiguation strategy than trying
      //                to guess what ports other tests use.
      appUrl: 'http://localhost:$serverPort/index.html',
      serverPort: serverPort,
      browserDebugPort: browserDebugPort,
      appDirectory: _appBuildDirectory,
      additionalRequestHandlers: <Handler>[
        (Request request) {
          final String requestedPath = request.url.path;
          requestedPathCounts.putIfAbsent(requestedPath, () => 0);
          requestedPathCounts[requestedPath] =
              requestedPathCounts[requestedPath]! + 1;
          if (requestedPath == 'CLOSE') {
            reportedVersion = request.url.queryParameters['version'];
            return Response.ok('OK');
          }
          return Response.notFound('');
        },
      ],
    );
  }

  // Preserve old index.html as index_og.html so we can restore it later for other tests
  await runCommand(
    'mv',
    <String>[
      'index.html',
      'index_og.html',
    ],
    workingDirectory: _testAppWebDirectory,
  );

  final bool shouldExpectFlutterJs =
      testType != ServiceWorkerTestType.withoutFlutterJs;

  print(
      'BEGIN runWebServiceWorkerTest(headless: $headless, testType: $testType)');

  try {
    // Attempt to load a different version of the service worker!
    await _rebuildApp(version: 1, testType: testType, target: _target);

    print('Call update() on the current web worker');
    await startAppServer(cacheControl: 'max-age=0');
    await waitForAppToLoad(<String, int>{
      if (shouldExpectFlutterJs) 'flutter.js': 1,
      'CLOSE': 1,
    });
    expect(reportedVersion, '1');
    reportedVersion = null;

    await server!.chrome.reloadPage(ignoreCache: true);
    await waitForAppToLoad(<String, int>{
      if (shouldExpectFlutterJs) 'flutter.js': 2,
      'CLOSE': 2,
    });
    expect(reportedVersion, '1');
    reportedVersion = null;

    await _rebuildApp(version: 2, testType: testType, target: _target);

    await server!.chrome.reloadPage(ignoreCache: true);
    await waitForAppToLoad(<String, int>{
      if (shouldExpectFlutterJs) 'flutter.js': 3,
      'CLOSE': 3,
    });
    expect(reportedVersion, '2');

    reportedVersion = null;
    requestedPathCounts.clear();
    await server!.stop();

    // Caching server
    await _rebuildApp(version: 1, testType: testType, target: _target);

    print('With cache: test first page load');
    await startAppServer(cacheControl: 'max-age=3600');
    await waitForAppToLoad(<String, int>{
      'CLOSE': 1,
      'flutter_service_worker.js': 1,
    });

    expectRequestCounts(<String, int>{
      // Even though the server is caching index.html is downloaded twice,
      // once by the initial page load, and once by the service worker.
      // Other resources are loaded once only by the service worker.
      'index.html': 2,
      if (shouldExpectFlutterJs) 'flutter.js': 1,
      'main.dart.js': 1,
      'flutter_service_worker.js': 1,
      'assets/FontManifest.json': 1,
      'assets/AssetManifest.json': 1,
      'assets/fonts/MaterialIcons-Regular.otf': 1,
      'CLOSE': 1,
      // In headless mode Chrome does not load 'manifest.json' and 'favicon.ico'.
      if (!headless) ...<String, int>{
        'manifest.json': 1,
        'favicon.ico': 1,
      },
    });
    expect(reportedVersion, '1');
    reportedVersion = null;

    print('With cache: test page reload');
    await server!.chrome.reloadPage();
    await waitForAppToLoad(<String, int>{
      'CLOSE': 1,
      'flutter_service_worker.js': 1,
    });

    expectRequestCounts(<String, int>{
      'flutter_service_worker.js': 1,
      'CLOSE': 1,
    });
    expect(reportedVersion, '1');
    reportedVersion = null;

    print('With cache: test page reload after rebuild');
    await _rebuildApp(version: 2, testType: testType, target: _target);

    // Since we're caching, we need to ignore cache when reloading the page.
    await server!.chrome.reloadPage(ignoreCache: true);
    await waitForAppToLoad(<String, int>{
      'CLOSE': 1,
      'flutter_service_worker.js': 2,
    });
    expectRequestCounts(<String, int>{
      'index.html': 2,
      if (shouldExpectFlutterJs) 'flutter.js': 1,
      'flutter_service_worker.js': 2,
      'main.dart.js': 1,
      'assets/AssetManifest.json': 1,
      'assets/FontManifest.json': 1,
      'CLOSE': 1,
      if (!headless) 'favicon.ico': 1,
    });

    expect(reportedVersion, '2');
    reportedVersion = null;
    await server!.stop();

    // Non-caching server
    print('No cache: test first page load');
    await _rebuildApp(version: 3, testType: testType, target: _target);
    await startAppServer(cacheControl: 'max-age=0');
    await waitForAppToLoad(<String, int>{
      'CLOSE': 1,
      'flutter_service_worker.js': 1,
    });

    expectRequestCounts(<String, int>{
      'index.html': 2,
      if (shouldExpectFlutterJs) 'flutter.js': 1,
      'main.dart.js': 1,
      'assets/FontManifest.json': 1,
      'flutter_service_worker.js': 1,
      'assets/AssetManifest.json': 1,
      'assets/fonts/MaterialIcons-Regular.otf': 1,
      'CLOSE': 1,
      // In headless mode Chrome does not load 'manifest.json' and 'favicon.ico'.
      if (!headless) ...<String, int>{
        'manifest.json': 1,
        'favicon.ico': 1,
      },
    });

    expect(reportedVersion, '3');
    reportedVersion = null;

    print('No cache: test page reload');
    await server!.chrome.reloadPage();
    await waitForAppToLoad(<String, int>{
      'CLOSE': 1,
      if (shouldExpectFlutterJs) 'flutter.js': 1,
      'flutter_service_worker.js': 1,
    });

    expectRequestCounts(<String, int>{
      if (shouldExpectFlutterJs) 'flutter.js': 1,
      'flutter_service_worker.js': 1,
      'CLOSE': 1,
      if (!headless) 'manifest.json': 1,
    });
    expect(reportedVersion, '3');
    reportedVersion = null;

    print('No cache: test page reload after rebuild');
    await _rebuildApp(version: 4, testType: testType, target: _target);

    // TODO(yjbanov): when running Chrome with DevTools protocol, for some
    // reason a hard refresh is still required. This works without a hard
    // refresh when running Chrome manually as normal. At the time of writing
    // this test I wasn't able to figure out what's wrong with the way we run
    // Chrome from tests.
    await server!.chrome.reloadPage(ignoreCache: true);
    await waitForAppToLoad(<String, int>{
      'CLOSE': 1,
      'flutter_service_worker.js': 1,
    });
    expectRequestCounts(<String, int>{
      'index.html': 2,
      if (shouldExpectFlutterJs) 'flutter.js': 1,
      'flutter_service_worker.js': 2,
      'main.dart.js': 1,
      'assets/AssetManifest.json': 1,
      'assets/FontManifest.json': 1,
      'CLOSE': 1,
      if (!headless) ...<String, int>{
        'manifest.json': 1,
        'favicon.ico': 1,
      },
    });

    expect(reportedVersion, '4');
    reportedVersion = null;
  } finally {
    await runCommand(
      'mv',
      <String>[
        'index_og.html',
        'index.html',
      ],
      workingDirectory: _testAppWebDirectory,
    );
    await _setAppVersion(1);
    await server?.stop();
  }

  print(
      'END runWebServiceWorkerTest(headless: $headless, testType: $testType)');
}

Future<void> runWebServiceWorkerTestWithCachingResources(
    {required bool headless, required ServiceWorkerTestType testType}) async {
  final Map<String, int> requestedPathCounts = <String, int>{};
  void expectRequestCounts(Map<String, int> expectedCounts) =>
      _expectRequestCounts(expectedCounts, requestedPathCounts);

  AppServer? server;
  Future<void> waitForAppToLoad(Map<String, int> waitForCounts) async =>
      _waitForAppToLoad(waitForCounts, requestedPathCounts, server);

  Future<void> startAppServer({
    required String cacheControl,
  }) async {
    final int serverPort = await findAvailablePortAndPossiblyCauseFlakyTests();
    final int browserDebugPort =
        await findAvailablePortAndPossiblyCauseFlakyTests();
    server = await AppServer.start(
      headless: headless,
      cacheControl: cacheControl,
      // TODO(yjbanov): use a better port disambiguation strategy than trying
      //                to guess what ports other tests use.
      appUrl: 'http://localhost:$serverPort/index.html',
      serverPort: serverPort,
      browserDebugPort: browserDebugPort,
      appDirectory: _appBuildDirectory,
      additionalRequestHandlers: <Handler>[
        (Request request) {
          final String requestedPath = request.url.path;
          requestedPathCounts.putIfAbsent(requestedPath, () => 0);
          requestedPathCounts[requestedPath] =
              requestedPathCounts[requestedPath]! + 1;
          if (requestedPath == 'assets/fonts/MaterialIcons-Regular.otf') {
            return Response.internalServerError();
          }
          return Response.notFound('');
        },
      ],
    );
  }

  // Preserve old index.html as index_og.html so we can restore it later for other tests
  await runCommand(
    'mv',
    <String>[
      'index.html',
      'index_og.html',
    ],
    workingDirectory: _testAppWebDirectory,
  );

  final bool shouldExpectFlutterJs =
      testType != ServiceWorkerTestType.withoutFlutterJs;

  print(
      'BEGIN runWebServiceWorkerTestWithCachingResources(headless: $headless, testType: $testType)');

  try {
    // Caching server
    await _rebuildApp(
        version: 1, testType: testType, target: _targetWithCachedResources);

    print('With cache: test first page load');
    await startAppServer(cacheControl: 'max-age=3600');
    await waitForAppToLoad(<String, int>{
      'assets/fonts/MaterialIcons-Regular.otf': 1,
      'flutter_service_worker.js': 1,
    });

    expectRequestCounts(<String, int>{
      // Even though the server is caching index.html is downloaded twice,
      // once by the initial page load, and once by the service worker.
      // Other resources are loaded once only by the service worker.
      'index.html': 2,
      if (shouldExpectFlutterJs) 'flutter.js': 1,
      'main.dart.js': 1,
      'flutter_service_worker.js': 1,
      'assets/FontManifest.json': 1,
      'assets/AssetManifest.json': 1,
      'assets/fonts/MaterialIcons-Regular.otf': 1,
      // In headless mode Chrome does not load 'manifest.json' and 'favicon.ico'.
      if (!headless) ...<String, int>{
        'manifest.json': 1,
        'favicon.ico': 1,
      },
    });

    print('With cache: test first page reload');
    await server!.chrome.reloadPage();
    await waitForAppToLoad(<String, int>{
      'assets/fonts/MaterialIcons-Regular.otf': 1,
      'flutter_service_worker.js': 1,
    });
    expectRequestCounts(<String, int>{
      'assets/fonts/MaterialIcons-Regular.otf': 1,
      'flutter_service_worker.js': 1,
    });

    print('With cache: test second page reload');
    await server!.chrome.reloadPage();
    await waitForAppToLoad(<String, int>{
      'assets/fonts/MaterialIcons-Regular.otf': 1,
      'flutter_service_worker.js': 1,
    });
    expectRequestCounts(<String, int>{
      'assets/fonts/MaterialIcons-Regular.otf': 1,
      'flutter_service_worker.js': 1,
    });

    print('With cache: test third page reload');
    await server!.chrome.reloadPage();
    await waitForAppToLoad(<String, int>{
      'assets/fonts/MaterialIcons-Regular.otf': 1,
      'flutter_service_worker.js': 1,
    });
    expectRequestCounts(<String, int>{
      'assets/fonts/MaterialIcons-Regular.otf': 1,
      'flutter_service_worker.js': 1,
    });

    print('With cache: test page reload after rebuild');
    await _rebuildApp(
        version: 1, testType: testType, target: _targetWithCachedResources);

    // Since we're caching, we need to ignore cache when reloading the page.
    await server!.chrome.reloadPage(ignoreCache: true);
    await waitForAppToLoad(<String, int>{
      'assets/fonts/MaterialIcons-Regular.otf': 1,
      'flutter_service_worker.js': 1,
    });
    expectRequestCounts(<String, int>{
      'index.html': 2,
      if (shouldExpectFlutterJs) 'flutter.js': 1,
      'main.dart.js': 1,
      'flutter_service_worker.js': 2,
      'assets/FontManifest.json': 1,
      'assets/AssetManifest.json': 1,
      'assets/fonts/MaterialIcons-Regular.otf': 1,
      // In headless mode Chrome does not load 'manifest.json' and 'favicon.ico'.
      if (!headless) ...<String, int>{
        'favicon.ico': 1,
      },
    });
  } finally {
    await runCommand(
      'mv',
      <String>[
        'index_og.html',
        'index.html',
      ],
      workingDirectory: _testAppWebDirectory,
    );
    await server?.stop();
  }

  print(
      'END runWebServiceWorkerTestWithCachingResources(headless: $headless, testType: $testType)');
}

Future<void> runWebServiceWorkerTestWithBlockedServiceWorkers(
    {required bool headless}) async {
  final Map<String, int> requestedPathCounts = <String, int>{};
  void expectRequestCounts(Map<String, int> expectedCounts) =>
      _expectRequestCounts(expectedCounts, requestedPathCounts);

  AppServer? server;
  Future<void> waitForAppToLoad(Map<String, int> waitForCounts) async =>
      _waitForAppToLoad(waitForCounts, requestedPathCounts, server);

  Future<void> startAppServer({
    required String cacheControl,
  }) async {
    final int serverPort = await findAvailablePortAndPossiblyCauseFlakyTests();
    final int browserDebugPort =
        await findAvailablePortAndPossiblyCauseFlakyTests();
    server = await AppServer.start(
      headless: headless,
      cacheControl: cacheControl,
      // TODO(yjbanov): use a better port disambiguation strategy than trying
      //                to guess what ports other tests use.
      appUrl: 'http://localhost:$serverPort/index.html',
      serverPort: serverPort,
      browserDebugPort: browserDebugPort,
      appDirectory: _appBuildDirectory,
      additionalRequestHandlers: <Handler>[
        (Request request) {
          final String requestedPath = request.url.path;
          requestedPathCounts.putIfAbsent(requestedPath, () => 0);
          requestedPathCounts[requestedPath] =
              requestedPathCounts[requestedPath]! + 1;
          if (requestedPath == 'CLOSE') {
            return Response.ok('OK');
          }
          return Response.notFound('');
        },
      ],
    );
  }

  // Preserve old index.html as index_og.html so we can restore it later for other tests
  await runCommand(
    'mv',
    <String>[
      'index.html',
      'index_og.html',
    ],
    workingDirectory: _testAppWebDirectory,
  );

  print(
      'BEGIN runWebServiceWorkerTestWithBlockedServiceWorkers(headless: $headless)');
  try {
    await _rebuildApp(
        version: 1,
        testType: ServiceWorkerTestType.blockedServiceWorkers,
        target: _targetWithBlockedServiceWorkers);

    print('Ensure app starts (when service workers are blocked)');
    await startAppServer(cacheControl: 'max-age=3600');
    await waitForAppToLoad(<String, int>{
      'CLOSE': 1,
    });
    expectRequestCounts(<String, int>{
      'index.html': 1,
      'flutter.js': 1,
      'main.dart.js': 1,
      'assets/FontManifest.json': 1,
      'assets/fonts/MaterialIcons-Regular.otf': 1,
      'CLOSE': 1,
      // In headless mode Chrome does not load 'manifest.json' and 'favicon.ico'.
      if (!headless) ...<String, int>{
        'manifest.json': 1,
        'favicon.ico': 1,
      },
    });
  } finally {
    await runCommand(
      'mv',
      <String>[
        'index_og.html',
        'index.html',
      ],
      workingDirectory: _testAppWebDirectory,
    );
    await server?.stop();
  }
  print(
      'END runWebServiceWorkerTestWithBlockedServiceWorkers(headless: $headless)');
}

Future<void> runWebServiceWorkerTestWithCustomServiceWorkerVersion({
  required bool headless,
}) async {
  final Map<String, int> requestedPathCounts = <String, int>{};
  void expectRequestCounts(Map<String, int> expectedCounts) =>
      _expectRequestCounts(expectedCounts, requestedPathCounts);

  AppServer? server;
  Future<void> waitForAppToLoad(Map<String, int> waitForCounts) async =>
      _waitForAppToLoad(waitForCounts, requestedPathCounts, server);

  Future<void> startAppServer({
    required String cacheControl,
  }) async {
    final int serverPort = await findAvailablePortAndPossiblyCauseFlakyTests();
    final int browserDebugPort =
        await findAvailablePortAndPossiblyCauseFlakyTests();
    server = await AppServer.start(
      headless: headless,
      cacheControl: cacheControl,
      // TODO(yjbanov): use a better port disambiguation strategy than trying
      //                to guess what ports other tests use.
      appUrl: 'http://localhost:$serverPort/index.html',
      serverPort: serverPort,
      browserDebugPort: browserDebugPort,
      appDirectory: _appBuildDirectory,
      additionalRequestHandlers: <Handler>[
        (Request request) {
          final String requestedPath = request.url.path;
          requestedPathCounts.putIfAbsent(requestedPath, () => 0);
          requestedPathCounts[requestedPath] =
              requestedPathCounts[requestedPath]! + 1;
          if (requestedPath == 'CLOSE') {
            return Response.ok('OK');
          }
          return Response.notFound('');
        },
      ],
    );
  }

  // Preserve old index.html as index_og.html so we can restore it later for other tests
  await runCommand(
    'mv',
    <String>[
      'index.html',
      'index_og.html',
    ],
    workingDirectory: _testAppWebDirectory,
  );

  print(
      'BEGIN runWebServiceWorkerTestWithCustomServiceWorkerVersion(headless: $headless)');
  try {
    await _rebuildApp(
        version: 1,
        testType: ServiceWorkerTestType.withFlutterJsCustomServiceWorkerVersion,
        target: _target);

    print('Test page load');
    await startAppServer(cacheControl: 'max-age=0');
    await waitForAppToLoad(<String, int>{
      'CLOSE': 1,
      'flutter_service_worker.js': 1,
      'assets/fonts/MaterialIcons-Regular.otf': 1,
    });
    expectRequestCounts(<String, int>{
      'index.html': 2,
      'flutter.js': 1,
      'main.dart.js': 1,
      'CLOSE': 1,
      'flutter_service_worker.js': 1,
      'assets/FontManifest.json': 1,
      'assets/AssetManifest.json': 1,
      'assets/fonts/MaterialIcons-Regular.otf': 1,
      // In headless mode Chrome does not load 'manifest.json' and 'favicon.ico'.
      if (!headless) ...<String, int>{
        'manifest.json': 1,
        'favicon.ico': 1,
      },
    });

    print('Test page reload, ensure service worker is not reloaded');
    await server!.chrome.reloadPage(ignoreCache: true);
    await waitForAppToLoad(<String, int>{
      'CLOSE': 1,
      'flutter.js': 1,
    });
    expectRequestCounts(<String, int>{
      'index.html': 1,
      'flutter.js': 1,
      'main.dart.js': 1,
      'assets/FontManifest.json': 1,
      'assets/fonts/MaterialIcons-Regular.otf': 1,
      'CLOSE': 1,
      // In headless mode Chrome does not load 'manifest.json' and 'favicon.ico'.
      if (!headless) ...<String, int>{
        'manifest.json': 1,
        'favicon.ico': 1,
      },
    });

    print(
        'Test page reload after rebuild, ensure service worker is not reloaded');
    await _rebuildApp(
        version: 1,
        testType: ServiceWorkerTestType.withFlutterJsCustomServiceWorkerVersion,
        target: _target);
    await server!.chrome.reloadPage(ignoreCache: true);
    await waitForAppToLoad(<String, int>{
      'CLOSE': 1,
      'flutter.js': 1,
    });
    expectRequestCounts(<String, int>{
      'index.html': 1,
      'flutter.js': 1,
      'main.dart.js': 1,
      'assets/FontManifest.json': 1,
      'assets/fonts/MaterialIcons-Regular.otf': 1,
      'CLOSE': 1,
      // In headless mode Chrome does not load 'manifest.json' and 'favicon.ico'.
      if (!headless) ...<String, int>{
        'manifest.json': 1,
        'favicon.ico': 1,
      },
    });
  } finally {
    await runCommand(
      'mv',
      <String>[
        'index_og.html',
        'index.html',
      ],
      workingDirectory: _testAppWebDirectory,
    );
    await server?.stop();
  }
  print(
      'END runWebServiceWorkerTestWithCustomServiceWorkerVersion(headless: $headless)');
}
