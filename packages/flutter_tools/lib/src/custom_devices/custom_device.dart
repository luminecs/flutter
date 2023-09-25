import 'dart:async';

import 'package:meta/meta.dart';
import 'package:process/process.dart';

import '../application_package.dart';
import '../base/common.dart';
import '../base/file_system.dart';
import '../base/io.dart';
import '../base/logger.dart';
import '../base/process.dart';
import '../base/utils.dart';
import '../build_info.dart';
import '../bundle.dart';
import '../bundle_builder.dart';
import '../convert.dart';
import '../device.dart';
import '../device_port_forwarder.dart';
import '../features.dart';
import '../project.dart';
import '../protocol_discovery.dart';
import 'custom_device_config.dart';
import 'custom_device_workflow.dart';
import 'custom_devices_config.dart';

List<String> interpolateCommand(
  List<String> command,
  Map<String, String> replacementValues, {
  Map<String, String> additionalReplacementValues = const <String, String>{}
}) {
  return interpolateStringList(
    command,
    Map<String, String>.of(additionalReplacementValues)
      ..addAll(replacementValues)
  );
}

class CustomDeviceLogReader extends DeviceLogReader {
  CustomDeviceLogReader(this.name);

  @override
  final String name;

  @visibleForTesting
  final StreamController<String> logLinesController = StreamController<String>.broadcast();

  @visibleForTesting
  final List<StreamSubscription<String>> subscriptions = <StreamSubscription<String>>[];

  void listenToProcessOutput(Process process, {Encoding encoding = systemEncoding}) {
    final Converter<List<int>, String> decoder = encoding.decoder;

    subscriptions.add(
      process.stdout.transform<String>(decoder)
        .transform<String>(const LineSplitter())
        .listen(logLinesController.add),
    );

    subscriptions.add(
      process.stderr.transform<String>(decoder)
        .transform<String>(const LineSplitter())
        .listen(logLinesController.add)
    );
  }

  void listenToLinesStream(Stream<String> lines) {
    subscriptions.add(
      lines.listen(logLinesController.add)
    );
  }

  @override
  Future<void> dispose() async {
    final List<Future<void>> futures = <Future<void>>[];

    for (final StreamSubscription<String> subscription in subscriptions) {
      futures.add(subscription.cancel());
    }

    futures.add(logLinesController.close());

    await Future.wait(futures);
  }

  @override
  Stream<String> get logLines => logLinesController.stream;
}

class CustomDevicePortForwarder extends DevicePortForwarder {
  CustomDevicePortForwarder({
    required String deviceName,
    required List<String> forwardPortCommand,
    required RegExp forwardPortSuccessRegex,
    this.numTries,
    required ProcessManager processManager,
    required Logger logger,
    Map<String, String> additionalReplacementValues = const <String, String>{}
  }) : _deviceName = deviceName,
       _forwardPortCommand = forwardPortCommand,
       _forwardPortSuccessRegex = forwardPortSuccessRegex,
       _processManager = processManager,
       _processUtils = ProcessUtils(
         processManager: processManager,
         logger: logger
       ),
       _additionalReplacementValues = additionalReplacementValues;

  final String _deviceName;
  final List<String> _forwardPortCommand;
  final RegExp _forwardPortSuccessRegex;
  final ProcessManager _processManager;
  final ProcessUtils _processUtils;
  final int? numTries;
  final Map<String, String> _additionalReplacementValues;
  final List<ForwardedPort> _forwardedPorts = <ForwardedPort>[];

  @override
  Future<void> dispose() async {
    // copy the list so we don't modify it concurrently
    await Future.wait(List<ForwardedPort>.of(_forwardedPorts).map(unforward));
  }

  Future<ForwardedPort?> tryForward(int devicePort, int hostPort) async {
    final List<String> interpolated = interpolateCommand(
      _forwardPortCommand,
      <String, String>{
        'devicePort': '$devicePort',
        'hostPort': '$hostPort',
      },
      additionalReplacementValues: _additionalReplacementValues
    );

    // launch the forwarding command
    final Process process = await _processUtils.start(interpolated);

    final Completer<ForwardedPort?> completer = Completer<ForwardedPort?>();

    // Read the outputs of the process; if we find a line that matches
    // the configs forwardPortSuccessRegex, we complete with a successfully
    // forwarded port.
    // If that regex never matches, this will potentially run forever
    // and the forwarding will never complete.
    final CustomDeviceLogReader reader = CustomDeviceLogReader(_deviceName)..listenToProcessOutput(process);
    final StreamSubscription<String> logLinesSubscription = reader.logLines.listen((String line) {
      if (_forwardPortSuccessRegex.hasMatch(line) && !completer.isCompleted) {
        completer.complete(
          ForwardedPort.withContext(hostPort, devicePort, process)
        );
      }
    });

    // if the process exits (even with exitCode == 0), that is considered
    // a port forwarding failure and we complete with a null value.
    unawaited(process.exitCode.whenComplete(() {
      if (!completer.isCompleted) {
        completer.complete();
      }
    }));

    unawaited(completer.future.whenComplete(() {
      unawaited(logLinesSubscription.cancel());
      unawaited(reader.dispose());
    }));

    return completer.future;
  }

  @override
  Future<int> forward(int devicePort, {int? hostPort}) async {
    int actualHostPort = (hostPort == 0 || hostPort == null) ? devicePort : hostPort;
    int tries = 0;

    while ((numTries == null) || (tries < numTries!)) {
      // when the desired host port is already forwarded by this Forwarder,
      // choose another one
      while (_forwardedPorts.any((ForwardedPort port) => port.hostPort == actualHostPort)) {
        actualHostPort += 1;
      }

      final ForwardedPort? port = await tryForward(devicePort, actualHostPort);

      if (port != null) {
        _forwardedPorts.add(port);
        return actualHostPort;
      } else {
        // null value means the forwarding failed (for whatever reason)
        // increase port by one and try again
        actualHostPort += 1;
        tries += 1;
      }
    }

    throw ToolExit('Forwarding port for custom device $_deviceName failed after $tries tries.');
  }

  @override
  List<ForwardedPort> get forwardedPorts => List<ForwardedPort>.unmodifiable(_forwardedPorts);

  @override
  Future<void> unforward(ForwardedPort forwardedPort) async {
    assert(_forwardedPorts.contains(forwardedPort));

    // since a forwarded port represents a running process launched with
    // the forwardPortCommand, unforwarding is as easy as killing the process
    final int? pid = forwardedPort.context?.pid;
    if (pid != null) {
      _processManager.killPid(pid);
    }
    _forwardedPorts.remove(forwardedPort);
  }
}

class CustomDeviceAppSession {
  CustomDeviceAppSession({
    required this.name,
    required CustomDevice device,
    required ApplicationPackage appPackage,
    required Logger logger,
    required ProcessManager processManager
  }) : _appPackage = appPackage,
       _device = device,
       _logger = logger,
       _processManager = processManager,
       _processUtils = ProcessUtils(
         processManager: processManager,
         logger: logger
       ),
       logReader = CustomDeviceLogReader(name);

  final String name;
  final CustomDevice _device;
  final ApplicationPackage _appPackage;
  final Logger _logger;
  final ProcessManager _processManager;
  final ProcessUtils _processUtils;
  final CustomDeviceLogReader logReader;

  Process? _process;
  int? _forwardedHostPort;

  List<String> _getEngineOptions(DebuggingOptions debuggingOptions, bool traceStartup, String? route) {
    final String dartVmFlags = computeDartVmFlags(debuggingOptions);
    return <String>[
      if (traceStartup)
        'trace-startup=true',
      if (route != null)
        'route=$route',
      if (debuggingOptions.enableDartProfiling)
        'enable-dart-profiling=true',
      if (debuggingOptions.enableSoftwareRendering)
        'enable-software-rendering=true',
      if (debuggingOptions.skiaDeterministicRendering)
        'skia-deterministic-rendering=true',
      if (debuggingOptions.traceSkia)
        'trace-skia=true',
      if (debuggingOptions.traceAllowlist != null)
        'trace-allowlist=${debuggingOptions.traceAllowlist}',
      if (debuggingOptions.traceSystrace)
        'trace-systrace=true',
      if (debuggingOptions.endlessTraceBuffer)
        'endless-trace-buffer=true',
      if (debuggingOptions.dumpSkpOnShaderCompilation)
        'dump-skp-on-shader-compilation=true',
      if (debuggingOptions.cacheSkSL) 'cache-sksl=true',
      if (debuggingOptions.purgePersistentCache)
        'purge-persistent-cache=true',
      if (debuggingOptions.debuggingEnabled) ...<String>[
        if (debuggingOptions.deviceVmServicePort != null)
          'vm-service-port=${debuggingOptions.deviceVmServicePort}',
        if (debuggingOptions.buildInfo.isDebug) ...<String>[
          'enable-checked-mode=true',
          'verify-entry-points=true',
        ],
        if (debuggingOptions.startPaused)
          'start-paused=true',
        if (debuggingOptions.disableServiceAuthCodes)
          'disable-service-auth-codes=true',
        if (dartVmFlags.isNotEmpty)
          'dart-flags=$dartVmFlags',
        if (debuggingOptions.useTestFonts)
          'use-test-fonts=true',
        if (debuggingOptions.verboseSystemLogs)
          'verbose-logging=true',
      ],
    ];
  }

  String _getEngineOptionsForCmdline(DebuggingOptions debuggingOptions, bool traceStartup, String? route) {
    return _getEngineOptions(debuggingOptions, traceStartup, route).map((String e) => '--$e').join(' ');
  }

  Future<LaunchResult> start({
    String? mainPath,
    String? route,
    required DebuggingOptions debuggingOptions,
    Map<String, Object?> platformArgs = const <String, Object>{},
    bool prebuiltApplication = false,
    bool ipv6 = false,
    String? userIdentifier
  }) async {
    final bool traceStartup = platformArgs['trace-startup'] as bool? ?? false;
    final String? packageName = _appPackage.name;
    if (packageName == null) {
      throw ToolExit('Could not start app, name for $_appPackage is unknown.');
    }
    final List<String> interpolated = interpolateCommand(
      _device._config.runDebugCommand,
      <String, String>{
        'remotePath': '/tmp/',
        'appName': packageName,
        'engineOptions': _getEngineOptionsForCmdline(debuggingOptions, traceStartup, route),
      }
    );

    final Process process = await _processUtils.start(interpolated);
    assert(_process == null);
    _process = process;

    final ProtocolDiscovery discovery = ProtocolDiscovery.vmService(
      logReader,
      portForwarder: _device._config.usesPortForwarding ? _device.portForwarder : null,
      logger: _logger,
      ipv6: ipv6,
    );

    // We need to make the discovery listen to the logReader before the logReader
    // listens to the process output since logReader.lines is a broadcast stream
    // and events may be discarded.
    // Whether that actually happens is another thing since this is all executed
    // in the same microtask AFAICT but this way we're on the safe side.
    logReader.listenToProcessOutput(process);

    final Uri? vmServiceUri = await discovery.uri;
    await discovery.cancel();

    if (_device._config.usesPortForwarding) {
      _forwardedHostPort = vmServiceUri?.port;
    }

    return LaunchResult.succeeded(vmServiceUri: vmServiceUri);
  }

  void _maybeUnforwardPort() {
    if (_forwardedHostPort != null) {
      final ForwardedPort forwardedPort = _device.portForwarder.forwardedPorts.singleWhere((ForwardedPort forwardedPort) {
        return forwardedPort.hostPort == _forwardedHostPort;
      });

      _forwardedHostPort = null;
      _device.portForwarder.unforward(forwardedPort);
    }
  }

  Future<bool> stop() async {
    if (_process == null) {
      return false;
    }

    _maybeUnforwardPort();
    final bool result = _processManager.killPid(_process!.pid);
    _process = null;
    return result;
  }

  void dispose() {
    if (_process != null) {
      _maybeUnforwardPort();
      _processManager.killPid(_process!.pid);
      _process = null;
    }

    unawaited(logReader.dispose());
  }
}

class CustomDevice extends Device {
  CustomDevice({
    required CustomDeviceConfig config,
    required Logger logger,
    required ProcessManager processManager,
  }) : _config = config,
       _logger = logger,
       _processManager = processManager,
       _processUtils = ProcessUtils(
         processManager: processManager,
         logger: logger
       ),
       _globalLogReader = CustomDeviceLogReader(config.label),
       portForwarder = config.usesPortForwarding ?
         CustomDevicePortForwarder(
           deviceName: config.label,
           forwardPortCommand: config.forwardPortCommand!,
           forwardPortSuccessRegex: config.forwardPortSuccessRegex!,
           processManager: processManager,
           logger: logger,
         ) : const NoOpDevicePortForwarder(),
       super(
         config.id,
         category: Category.mobile,
         ephemeral: true,
         platformType: PlatformType.custom
       );

  final CustomDeviceConfig _config;
  final Logger _logger;
  final ProcessManager _processManager;
  final ProcessUtils _processUtils;
  final Map<ApplicationPackage, CustomDeviceAppSession> _sessions = <ApplicationPackage, CustomDeviceAppSession>{};
  final CustomDeviceLogReader _globalLogReader;

  @override
  final DevicePortForwarder portForwarder;

  CustomDeviceAppSession _getOrCreateAppSession(ApplicationPackage app) {
    return _sessions.putIfAbsent(
      app,
      () {
        final CustomDeviceAppSession session = CustomDeviceAppSession(
          name: name,
          device: this,
          appPackage: app,
          logger: _logger,
          processManager: _processManager
        );

        _globalLogReader.listenToLinesStream(session.logReader.logLines);

        return session;
      }
    );
  }

  Future<bool> tryPing({
    Duration? timeout,
    Map<String, String> replacementValues = const <String, String>{}
  }) async {
    final List<String> interpolated = interpolateCommand(
      _config.pingCommand,
      replacementValues
    );

    final RunResult result = await _processUtils.run(
      interpolated,
      timeout: timeout
    );

    if (result.exitCode != 0) {
      return false;
    }

    // If the user doesn't configure a ping success regex, any ping with exitCode zero
    // is good enough. Otherwise we check if either stdout or stderr have a match of
    // the pingSuccessRegex.
    final RegExp? pingSuccessRegex = _config.pingSuccessRegex;
    return pingSuccessRegex == null
      || pingSuccessRegex.hasMatch(result.stdout)
      || pingSuccessRegex.hasMatch(result.stderr);
  }

  Future<bool> _tryPostBuild({
    required String appName,
    required String localPath,
    Duration? timeout,
    Map<String, String> additionalReplacementValues = const <String, String>{}
  }) async {
    assert(_config.postBuildCommand != null);

    final List<String> interpolated = interpolateCommand(
      _config.postBuildCommand!,
      <String, String>{
        'appName': appName,
        'localPath': localPath,
      },
      additionalReplacementValues: additionalReplacementValues
    );

    try {
      await _processUtils.run(
        interpolated,
        throwOnError: true,
        timeout: timeout
      );
      return true;
    } on ProcessException catch (e) {
      _logger.printError('Error executing postBuild command for custom device $id: $e');
      return false;
    }
  }

  Future<bool> tryUninstall({
    required String appName,
    Duration? timeout,
    Map<String, String> additionalReplacementValues = const <String, String>{}
  }) async {
    final List<String> interpolated = interpolateCommand(
      _config.uninstallCommand,
      <String, String>{
        'appName': appName,
      },
      additionalReplacementValues: additionalReplacementValues
    );

    try {
      await _processUtils.run(
        interpolated,
        throwOnError: true,
        timeout: timeout
      );
      return true;
    } on ProcessException catch (e) {
      _logger.printError('Error executing uninstall command for custom device $id: $e');
      return false;
    }
  }

  Future<bool> tryInstall({
    required String localPath,
    required String appName,
    Duration? timeout,
    Map<String, String> additionalReplacementValues = const <String, String>{}
  }) async {
    final List<String> interpolated = interpolateCommand(
      _config.installCommand,
      <String, String>{
        'localPath': localPath,
        'appName': appName,
      },
      additionalReplacementValues: additionalReplacementValues
    );

    try {
      await _processUtils.run(
        interpolated,
        throwOnError: true,
        timeout: timeout
      );

      return true;
    } on ProcessException catch (e) {
      _logger.printError('Error executing install command for custom device $id: $e');
      return false;
    }
  }

  @override
  void clearLogs() {}

  @override
  Future<void> dispose() async {
    _sessions
      ..forEach((_, CustomDeviceAppSession session) => session.dispose())
      ..clear();
  }

  @override
  Future<String?> get emulatorId async => null;

  @override
  FutureOr<DeviceLogReader> getLogReader({
    ApplicationPackage? app,
    bool includePastLogs = false
  }) {
    if (app != null) {
      return _getOrCreateAppSession(app).logReader;
    }

    return _globalLogReader;
  }

  @override
  Future<bool> installApp(ApplicationPackage app, {String? userIdentifier}) async {
    final String? appName = app.name;
    if (appName == null || !await tryUninstall(appName: appName)) {
      return false;
    }

    final bool result = await tryInstall(
      localPath: getAssetBuildDirectory(),
      appName: appName,
    );

    return result;
  }

  @override
  Future<bool> isAppInstalled(ApplicationPackage app, {String? userIdentifier}) async {
    return false;
  }

  @override
  Future<bool> isLatestBuildInstalled(ApplicationPackage app) async {
    return false;
  }

  @override
  Future<bool> get isLocalEmulator async => false;

  @override
  bool get supportsScreenshot => _config.supportsScreenshotting;

  @override
  Future<void> takeScreenshot(File outputFile) async {
    if (!supportsScreenshot) {
      throw UnsupportedError('Screenshotting is not supported for this device.');
    }

    final List<String> interpolated = interpolateCommand(
      _config.screenshotCommand!,
      <String, String>{},
    );

    final RunResult result = await _processUtils.run(interpolated, throwOnError: true);
    await outputFile.writeAsBytes(base64Decode(result.stdout));
  }

  @override
  bool isSupported() {
    return true;
  }

  @override
  bool isSupportedForProject(FlutterProject flutterProject) {
    return true;
  }

  @override
  FutureOr<bool> supportsRuntimeMode(BuildMode buildMode) {
    return buildMode == BuildMode.debug;
  }

  @override
  String get name => _config.label;

  @override
  Future<String> get sdkNameAndVersion => Future<String>.value(_config.sdkNameAndVersion);

  @override
  Future<LaunchResult> startApp(
    ApplicationPackage package, {
    String? mainPath,
    String? route,
    required DebuggingOptions debuggingOptions,
    Map<String, Object?> platformArgs = const <String, Object>{},
    bool prebuiltApplication = false,
    bool ipv6 = false,
    String? userIdentifier,
    BundleBuilder? bundleBuilder,
  }) async {
    if (!prebuiltApplication) {
      final String assetBundleDir = getAssetBuildDirectory();

      bundleBuilder ??= BundleBuilder();

      // this just builds the asset bundle, it's the same as `flutter build bundle`
      await bundleBuilder.build(
        platform: await targetPlatform,
        buildInfo: debuggingOptions.buildInfo,
        mainPath: mainPath,
        depfilePath: defaultDepfilePath,
        assetDirPath: assetBundleDir,
      );

      // if we have a post build step (needed for some embedders), execute it
      if (_config.postBuildCommand != null) {
        final String? packageName = package.name;
        if (packageName == null) {
          throw ToolExit('Could not start app, name for $package is unknown.');
        }
        await _tryPostBuild(
          appName: packageName,
          localPath: assetBundleDir,
        );
      }
    }

    // install the app on the device
    // (will invoke the uninstall and then the install command internally)
    await installApp(package, userIdentifier: userIdentifier);

    // finally launch the app
    return _getOrCreateAppSession(package).start(
      mainPath: mainPath,
      route: route,
      debuggingOptions: debuggingOptions,
      platformArgs: platformArgs,
      prebuiltApplication: prebuiltApplication,
      ipv6: ipv6,
      userIdentifier: userIdentifier,
    );
  }

  @override
  Future<bool> stopApp(ApplicationPackage? app, {String? userIdentifier}) async {
    if (app == null) {
      return false;
    }
    return _getOrCreateAppSession(app).stop();
  }

  @override
  Future<TargetPlatform> get targetPlatform async => _config.platform ?? TargetPlatform.linux_arm64;

  @override
  Future<bool> uninstallApp(ApplicationPackage app, {String? userIdentifier}) async {
    final String? appName = app.name;
    if (appName == null) {
      return false;
    }
    return tryUninstall(appName: appName);
  }
}

class CustomDevices extends PollingDeviceDiscovery {
  CustomDevices({
    required FeatureFlags featureFlags,
    required ProcessManager processManager,
    required Logger logger,
    required CustomDevicesConfig config
  }) : _customDeviceWorkflow = CustomDeviceWorkflow(
         featureFlags: featureFlags,
       ),
       _logger = logger,
       _processManager = processManager,
       _config = config,
       super('custom devices');

  final CustomDeviceWorkflow  _customDeviceWorkflow;
  final ProcessManager _processManager;
  final Logger _logger;
  final CustomDevicesConfig _config;

  @override
  bool get supportsPlatform => true;

  @override
  bool get canListAnything => _customDeviceWorkflow.canListDevices;

  CustomDevicesConfig get _customDevicesConfig => _config;

  List<CustomDevice> get _enabledCustomDevices {
    return _customDevicesConfig.tryGetDevices()
      .where((CustomDeviceConfig element) => element.enabled)
      .map(
        (CustomDeviceConfig config) => CustomDevice(
          config: config,
          logger: _logger,
          processManager: _processManager
        )
      ).toList();
  }

  @override
  Future<List<Device>> pollingGetDevices({Duration? timeout}) async {
    if (!canListAnything) {
      return const <Device>[];
    }

    final List<CustomDevice> devices = _enabledCustomDevices;

    // maps any custom device to whether its reachable or not.
    final Map<CustomDevice, bool> pingedDevices = Map<CustomDevice, bool>.fromIterables(
      devices,
      await Future.wait(devices.map((CustomDevice e) => e.tryPing(timeout: timeout)))
    );

    // remove all the devices we couldn't reach.
    pingedDevices.removeWhere((_, bool value) => !value);

    // return only the devices.
    return pingedDevices.keys.toList();
  }

  @override
  Future<List<String>> getDiagnostics() async => const <String>[];

  @override
  List<String> get wellKnownIds => const <String>[];
}