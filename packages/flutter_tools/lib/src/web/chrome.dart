import 'dart:async';

import 'package:meta/meta.dart';
import 'package:process/process.dart';
import 'package:webkit_inspection_protocol/webkit_inspection_protocol.dart';

import '../base/common.dart';
import '../base/file_system.dart';
import '../base/io.dart';
import '../base/logger.dart';
import '../base/os.dart';
import '../base/platform.dart';
import '../convert.dart';

const String kChromeEnvironment = 'CHROME_EXECUTABLE';

const String kEdgeEnvironment = 'EDGE_ENVIRONMENT';

const String kLinuxExecutable = 'google-chrome';

const String kMacOSExecutable =
    '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome';

const String kWindowsExecutable = r'Google\Chrome\Application\chrome.exe';

const String kWindowsEdgeExecutable = r'Microsoft\Edge\Application\msedge.exe';

const String _kGlibcError = 'Inconsistency detected by ld.so';

typedef BrowserFinder = String Function(Platform, FileSystem);

String findChromeExecutable(Platform platform, FileSystem fileSystem) {
  if (platform.environment.containsKey(kChromeEnvironment)) {
    return platform.environment[kChromeEnvironment]!;
  }
  if (platform.isLinux) {
    return kLinuxExecutable;
  }
  if (platform.isMacOS) {
    return kMacOSExecutable;
  }
  if (platform.isWindows) {
    final List<String> kWindowsPrefixes = <String>[
      if (platform.environment.containsKey('LOCALAPPDATA'))
        platform.environment['LOCALAPPDATA']!,
      if (platform.environment.containsKey('PROGRAMFILES'))
        platform.environment['PROGRAMFILES']!,
      if (platform.environment.containsKey('PROGRAMFILES(X86)'))
        platform.environment['PROGRAMFILES(X86)']!,
    ];
    final String windowsPrefix = kWindowsPrefixes.firstWhere((String prefix) {
      final String path = fileSystem.path.join(prefix, kWindowsExecutable);
      return fileSystem.file(path).existsSync();
    }, orElse: () => '.');
    return fileSystem.path.join(windowsPrefix, kWindowsExecutable);
  }
  throwToolExit('Platform ${platform.operatingSystem} is not supported.');
}

String findEdgeExecutable(Platform platform, FileSystem fileSystem) {
  if (platform.environment.containsKey(kEdgeEnvironment)) {
    return platform.environment[kEdgeEnvironment]!;
  }
  if (platform.isWindows) {
    final List<String> kWindowsPrefixes = <String>[
      if (platform.environment.containsKey('LOCALAPPDATA'))
        platform.environment['LOCALAPPDATA']!,
      if (platform.environment.containsKey('PROGRAMFILES'))
        platform.environment['PROGRAMFILES']!,
      if (platform.environment.containsKey('PROGRAMFILES(X86)'))
        platform.environment['PROGRAMFILES(X86)']!,
    ];
    final String windowsPrefix = kWindowsPrefixes.firstWhere((String prefix) {
      final String path = fileSystem.path.join(prefix, kWindowsEdgeExecutable);
      return fileSystem.file(path).existsSync();
    }, orElse: () => '.');
    return fileSystem.path.join(windowsPrefix, kWindowsEdgeExecutable);
  }
  // Not yet supported for macOS and Linux.
  return '';
}

class ChromiumLauncher {
  ChromiumLauncher({
    required FileSystem fileSystem,
    required Platform platform,
    required ProcessManager processManager,
    required OperatingSystemUtils operatingSystemUtils,
    required BrowserFinder browserFinder,
    required Logger logger,
  }) : _fileSystem = fileSystem,
       _platform = platform,
       _processManager = processManager,
       _operatingSystemUtils = operatingSystemUtils,
       _browserFinder = browserFinder,
       _logger = logger;

  final FileSystem _fileSystem;
  final Platform _platform;
  final ProcessManager _processManager;
  final OperatingSystemUtils _operatingSystemUtils;
  final BrowserFinder _browserFinder;
  final Logger _logger;

  bool get hasChromeInstance => currentCompleter.isCompleted;

  @visibleForTesting
  Completer<Chromium> currentCompleter = Completer<Chromium>();

  bool canFindExecutable() {
    final String chrome = _browserFinder(_platform, _fileSystem);
    try {
      return _processManager.canRun(chrome);
    } on ArgumentError {
      return false;
    }
  }

  String findExecutable() =>  _browserFinder(_platform, _fileSystem);

  Future<Chromium> launch(String url, {
    bool headless = false,
    int? debugPort,
    bool skipCheck = false,
    Directory? cacheDir,
    List<String> webBrowserFlags = const <String>[],
  }) async {
    if (currentCompleter.isCompleted) {
      throwToolExit('Only one instance of chrome can be started.');
    }

    if (_logger.isVerbose) {
      _logger.printTrace('Launching Chromium (url = $url, headless = $headless, skipCheck = $skipCheck, debugPort = $debugPort)');
    }

    final String chromeExecutable = _browserFinder(_platform, _fileSystem);

    if (_logger.isVerbose) {
      _logger.printTrace('Will use Chromium executable at $chromeExecutable');

      if (!_platform.isWindows) {
        // The "--version" argument is not supported on Windows.
        final ProcessResult versionResult = await _processManager.run(<String>[chromeExecutable, '--version']);
        _logger.printTrace('Using ${versionResult.stdout}');
      }
    }


    final Directory userDataDir = _fileSystem.systemTempDirectory
      .createTempSync('flutter_tools_chrome_device.');

    if (cacheDir != null) {
      // Seed data dir with previous state.
      _restoreUserSessionInformation(cacheDir, userDataDir);
    }

    final int port = debugPort ?? await _operatingSystemUtils.findFreePort();
    final List<String> args = <String>[
      chromeExecutable,
      // Using a tmp directory ensures that a new instance of chrome launches
      // allowing for the remote debug port to be enabled.
      '--user-data-dir=${userDataDir.path}',
      '--remote-debugging-port=$port',
      // When the DevTools has focus we don't want to slow down the application.
      '--disable-background-timer-throttling',
      // Since we are using a temp profile, disable features that slow the
      // Chrome launch.
      '--disable-extensions',
      '--disable-popup-blocking',
      '--bwsi',
      '--no-first-run',
      '--no-default-browser-check',
      '--disable-default-apps',
      '--disable-translate',
      if (headless)
        ...<String>[
          '--headless',
          '--disable-gpu',
          '--no-sandbox',
          '--window-size=2400,1800',
        ],
      ...webBrowserFlags,
      url,
    ];

    final Process? process = await _spawnChromiumProcess(args, chromeExecutable);

    // When the process exits, copy the user settings back to the provided data-dir.
    if (process != null && cacheDir != null) {
      unawaited(process.exitCode.whenComplete(() {
        _cacheUserSessionInformation(userDataDir, cacheDir);
        // cleanup temp dir
        try {
          userDataDir.deleteSync(recursive: true);
        } on FileSystemException {
          // ignore
        }
      }));
    }
    return connect(Chromium(
      port,
      ChromeConnection('localhost', port),
      url: url,
      process: process,
      chromiumLauncher: this,
    ), skipCheck);
  }

  Future<Process?> _spawnChromiumProcess(List<String> args, String chromeExecutable) async {
    if (_operatingSystemUtils.hostPlatform == HostPlatform.darwin_arm64) {
      final ProcessResult result = _processManager.runSync(<String>['file', chromeExecutable]);
      // Check if ARM Chrome is installed.
      // Mach-O 64-bit executable arm64
      if ((result.stdout as String).contains('arm64')) {
        _logger.printTrace('Found ARM Chrome installation at $chromeExecutable, forcing native launch.');
        // If so, force Chrome to launch natively.
        args.insertAll(0, <String>['/usr/bin/arch', '-arm64']);
      }
    }

    // Keep attempting to launch the browser until one of:
    // - Chrome launched successfully, in which case we just return from the loop.
    // - The tool reached the maximum retry count, in which case we throw ToolExit.
    const int kMaxRetries = 3;
    int retry = 0;
    while (true) {
      final Process process = await _processManager.start(args);

      process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((String line) {
          _logger.printTrace('[CHROME]: $line');
        });

      // Wait until the DevTools are listening before trying to connect. This is
      // only required for flutter_test --platform=chrome and not flutter run.
      bool hitGlibcBug = false;
      bool shouldRetry = false;
      final List<String> errors = <String>[];
      await process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .map((String line) {
          _logger.printTrace('[CHROME]: $line');
          errors.add('[CHROME]:$line');
          if (line.contains(_kGlibcError)) {
            hitGlibcBug = true;
            shouldRetry = true;
          }
          return line;
        })
        .firstWhere((String line) => line.startsWith('DevTools listening'), orElse: () {
          if (hitGlibcBug) {
            _logger.printTrace(
              'Encountered glibc bug https://sourceware.org/bugzilla/show_bug.cgi?id=19329. '
              'Will try launching browser again.',
            );
            // Return value unused.
            return '';
          }
          if (retry >= kMaxRetries) {
            errors.forEach(_logger.printError);
            _logger.printError('Failed to launch browser after $kMaxRetries tries. Command used to launch it: ${args.join(' ')}');
            throw ToolExit(
              'Failed to launch browser. Make sure you are using an up-to-date '
              'Chrome or Edge. Otherwise, consider using -d web-server instead '
              'and filing an issue at https://github.com/flutter/flutter/issues.',
            );
          }
          shouldRetry = true;
          return '';
        });

      if (!hitGlibcBug && !shouldRetry) {
        return process;
      }
      retry += 1;

      // A precaution that avoids accumulating browser processes, in case the
      // glibc bug doesn't cause the browser to quit and we keep looping and
      // launching more processes.
      unawaited(process.exitCode.timeout(const Duration(seconds: 1), onTimeout: () {
        process.kill();
        // sigterm
        return 15;
      }));
    }
  }

  // This is a directory which Chrome uses to store cookies, preferences and
  // other session data.
  String get _chromeDefaultPath => _fileSystem.path.join('Default');

  // This is a JSON file which contains configuration from the browser session,
  // such as window position. It is located under the Chrome data-dir folder.
  String get _preferencesPath => _fileSystem.path.join('Default', 'preferences');

  void _cacheUserSessionInformation(Directory userDataDir, Directory cacheDir) {
    final Directory targetChromeDefault = _fileSystem.directory(_fileSystem.path.join(cacheDir.path, _chromeDefaultPath));
    final Directory sourceChromeDefault = _fileSystem.directory(_fileSystem.path.join(userDataDir.path, _chromeDefaultPath));
    if (sourceChromeDefault.existsSync()) {
      targetChromeDefault.createSync(recursive: true);
      try {
        copyDirectory(
          sourceChromeDefault,
          targetChromeDefault,
          shouldCopyDirectory: _isNotCacheDirectory
        );
      } on FileSystemException catch (err) {
        // This is a best-effort update. Display the message in case the failure is relevant.
        // one possible example is a file lock due to multiple running chrome instances.
        _logger.printError('Failed to save Chrome preferences: $err');
      }
    }

    final File targetPreferencesFile = _fileSystem.file(_fileSystem.path.join(cacheDir.path, _preferencesPath));
    final File sourcePreferencesFile = _fileSystem.file(_fileSystem.path.join(userDataDir.path, _preferencesPath));

    if (sourcePreferencesFile.existsSync()) {
       targetPreferencesFile.parent.createSync(recursive: true);
       // If the file contains a crash string, remove it to hide the popup on next run.
       final String contents = sourcePreferencesFile.readAsStringSync();
       targetPreferencesFile.writeAsStringSync(contents
           .replaceFirst('"exit_type":"Crashed"', '"exit_type":"Normal"'));
    }
  }

  void _restoreUserSessionInformation(Directory cacheDir, Directory userDataDir) {
    final Directory sourceChromeDefault = _fileSystem.directory(_fileSystem.path.join(cacheDir.path, _chromeDefaultPath));
    final Directory targetChromeDefault = _fileSystem.directory(_fileSystem.path.join(userDataDir.path, _chromeDefaultPath));
    try {
      if (sourceChromeDefault.existsSync()) {
        targetChromeDefault.createSync(recursive: true);
        copyDirectory(
          sourceChromeDefault,
          targetChromeDefault,
          shouldCopyDirectory: _isNotCacheDirectory,
        );
      }
    } on FileSystemException catch (err) {
      _logger.printError('Failed to restore Chrome preferences: $err');
    }
  }

  // Cache, Code Cache, and GPUCache are nearly 1GB of data
  bool _isNotCacheDirectory(Directory directory) {
    return !directory.path.endsWith('Cache') &&
           !directory.path.endsWith('Code Cache') &&
           !directory.path.endsWith('GPUCache');
  }

  @visibleForTesting
  Future<Chromium> connect(Chromium chrome, bool skipCheck) async {
    // The connection is lazy. Try a simple call to make sure the provided
    // connection is valid.
    if (!skipCheck) {
      try {
        await _getFirstTab(chrome);
      } on Exception catch (error, stackTrace) {
        _logger.printError('$error', stackTrace: stackTrace);
        await chrome.close();
        throwToolExit(
            'Unable to connect to Chrome debug port: ${chrome.debugPort}\n $error');
      }
    }
    currentCompleter.complete(chrome);
    return chrome;
  }

  //
  // TODO(ianh): remove the timeouts here, they violate our style guide.
  // (We should just keep waiting forever, and print a warning when it's
  // taking too long.)
  Future<ChromeTab?> _getFirstTab(Chromium chrome) async {
    const Duration retryFor = Duration(seconds: 2);
    const int attempts = 5;

    for (int i = 1; i <= attempts; i++) {
      try {
        final List<ChromeTab> tabs =
          await chrome.chromeConnection.getTabs(retryFor: retryFor);

        if (tabs.isNotEmpty) {
          return tabs.first;
        }
        if (i == attempts) {
          return null;
        }
      } on ConnectionException catch (_) {
        if (i == attempts) {
          rethrow;
        }
      }
      await Future<void>.delayed(const Duration(milliseconds: 25));
    }
    return null;
  }

  Future<Chromium> get connectedInstance => currentCompleter.future;
}

class Chromium {
  Chromium(
    this.debugPort,
    this.chromeConnection, {
    this.url,
    Process? process,
    required ChromiumLauncher chromiumLauncher,
  })  : _process = process,
        _chromiumLauncher = chromiumLauncher;

  final String? url;
  final int debugPort;
  final Process? _process;
  final ChromeConnection chromeConnection;
  final ChromiumLauncher _chromiumLauncher;

  Future<int?> get onExit async => _process?.exitCode;

  Future<void> close() async {
    if (_chromiumLauncher.hasChromeInstance) {
      _chromiumLauncher.currentCompleter = Completer<Chromium>();
    }
    chromeConnection.close();
    _process?.kill();
    await _process?.exitCode;
  }
}