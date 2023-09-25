// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:meta/meta.dart';

import 'application_package.dart';
import 'base/context.dart';
import 'base/dds.dart';
import 'base/file_system.dart';
import 'base/logger.dart';
import 'base/utils.dart';
import 'build_info.dart';
import 'devfs.dart';
import 'device_port_forwarder.dart';
import 'project.dart';
import 'vmservice.dart';

DeviceManager? get deviceManager => context.get<DeviceManager>();

enum Category {
  web._('web'),
  desktop._('desktop'),
  mobile._('mobile');

  const Category._(this.value);

  final String value;

  @override
  String toString() => value;

  static Category? fromString(String category) {
    return const <String, Category>{
      'web': web,
      'desktop': desktop,
      'mobile': mobile,
    }[category];
  }
}

enum PlatformType {
  web._('web'),
  android._('android'),
  ios._('ios'),
  linux._('linux'),
  macos._('macos'),
  windows._('windows'),
  fuchsia._('fuchsia'),
  custom._('custom');

  const PlatformType._(this.value);

  final String value;

  @override
  String toString() => value;

  static PlatformType? fromString(String platformType) {
    return const <String, PlatformType>{
      'web': web,
      'android': android,
      'ios': ios,
      'linux': linux,
      'macos': macos,
      'windows': windows,
      'fuchsia': fuchsia,
      'custom': custom,
    }[platformType];
  }
}

abstract class DeviceManager {
  DeviceManager({
    required Logger logger,
  }) : _logger = logger;

  final Logger _logger;

  List<DeviceDiscovery> get deviceDiscoverers;

  String? _specifiedDeviceId;

  String? get specifiedDeviceId {
    if (_specifiedDeviceId == null || _specifiedDeviceId == 'all') {
      return null;
    }
    return _specifiedDeviceId;
  }

  set specifiedDeviceId(String? id) {
    _specifiedDeviceId = id;
  }

  static const Duration minimumWirelessDeviceDiscoveryTimeout = Duration(
    seconds: 5,
  );

  bool get hasSpecifiedDeviceId => specifiedDeviceId != null;

  bool get hasSpecifiedAllDevices => _specifiedDeviceId == 'all';

  Future<List<Device>> getDevicesById(
    String deviceId, {
    DeviceDiscoveryFilter? filter,
  }) async {
    filter ??= DeviceDiscoveryFilter();

    final String lowerDeviceId = deviceId.toLowerCase();
    bool exactlyMatchesDeviceId(Device device) =>
        device.id.toLowerCase() == lowerDeviceId ||
        device.name.toLowerCase() == lowerDeviceId;
    bool startsWithDeviceId(Device device) =>
        device.id.toLowerCase().startsWith(lowerDeviceId) ||
        device.name.toLowerCase().startsWith(lowerDeviceId);

    // Some discoverers have hard-coded device IDs and return quickly, and others
    // shell out to other processes and can take longer.
    // If an ID was specified, first check if it was a "well-known" device id.
    final Set<String> wellKnownIds = _platformDiscoverers
      .expand((DeviceDiscovery discovery) => discovery.wellKnownIds)
      .toSet();
    final bool hasWellKnownId = hasSpecifiedDeviceId && wellKnownIds.contains(specifiedDeviceId);

    // Process discoverers as they can return results, so if an exact match is
    // found quickly, we don't wait for all the discoverers to complete.
    final List<Device> prefixMatches = <Device>[];
    final Completer<Device> exactMatchCompleter = Completer<Device>();
    final List<Future<List<Device>?>> futureDevices = <Future<List<Device>?>>[
      for (final DeviceDiscovery discoverer in _platformDiscoverers)
        if (!hasWellKnownId || discoverer.wellKnownIds.contains(specifiedDeviceId))
          discoverer
          .devices(filter: filter)
          .then((List<Device> devices) {
            for (final Device device in devices) {
              if (exactlyMatchesDeviceId(device)) {
                exactMatchCompleter.complete(device);
                return null;
              }
              if (startsWithDeviceId(device)) {
                prefixMatches.add(device);
              }
            }
            return null;
          }, onError: (dynamic error, StackTrace stackTrace) {
            // Return matches from other discoverers even if one fails.
            _logger.printTrace('Ignored error discovering $deviceId: $error');
          }),
    ];

    // Wait for an exact match, or for all discoverers to return results.
    await Future.any<Object>(<Future<Object>>[
      exactMatchCompleter.future,
      Future.wait<List<Device>?>(futureDevices),
    ]);

    if (exactMatchCompleter.isCompleted) {
      return <Device>[await exactMatchCompleter.future];
    }
    return prefixMatches;
  }

  Future<List<Device>> getDevices({
    DeviceDiscoveryFilter? filter,
  }) {
    filter ??= DeviceDiscoveryFilter();
    final String? id = specifiedDeviceId;
    if (id == null) {
      return getAllDevices(filter: filter);
    }
    return getDevicesById(id, filter: filter);
  }

  Iterable<DeviceDiscovery> get _platformDiscoverers {
    return deviceDiscoverers.where((DeviceDiscovery discoverer) => discoverer.supportsPlatform);
  }

  Future<List<Device>> getAllDevices({
    DeviceDiscoveryFilter? filter,
  }) async {
    filter ??= DeviceDiscoveryFilter();
    final List<List<Device>> devices = await Future.wait<List<Device>>(<Future<List<Device>>>[
      for (final DeviceDiscovery discoverer in _platformDiscoverers)
        discoverer.devices(filter: filter),
    ]);

    return devices.expand<Device>((List<Device> deviceList) => deviceList).toList();
  }

  Future<List<Device>> refreshAllDevices({
    Duration? timeout,
    DeviceDiscoveryFilter? filter,
  }) async {
    filter ??= DeviceDiscoveryFilter();
    final List<List<Device>> devices = await Future.wait<List<Device>>(<Future<List<Device>>>[
      for (final DeviceDiscovery discoverer in _platformDiscoverers)
        discoverer.discoverDevices(filter: filter, timeout: timeout),
    ]);

    return devices.expand<Device>((List<Device> deviceList) => deviceList).toList();
  }

  Future<void> refreshExtendedWirelessDeviceDiscoverers({
    Duration? timeout,
    DeviceDiscoveryFilter? filter,
  }) async {
    await Future.wait<List<Device>>(<Future<List<Device>>>[
      for (final DeviceDiscovery discoverer in _platformDiscoverers)
        if (discoverer.requiresExtendedWirelessDeviceDiscovery)
          discoverer.discoverDevices(timeout: timeout)
    ]);
  }

  bool get canListAnything {
    return _platformDiscoverers.any((DeviceDiscovery discoverer) => discoverer.canListAnything);
  }

  Future<List<String>> getDeviceDiagnostics() async {
    return <String>[
      for (final DeviceDiscovery discoverer in _platformDiscoverers)
        ...await discoverer.getDiagnostics(),
    ];
  }

  DeviceDiscoverySupportFilter deviceSupportFilter({
    bool includeDevicesUnsupportedByProject = false,
  }) {
    FlutterProject? flutterProject;
    if (!includeDevicesUnsupportedByProject) {
      flutterProject = FlutterProject.current();
    }
    if (hasSpecifiedAllDevices) {
      return DeviceDiscoverySupportFilter.excludeDevicesUnsupportedByFlutterOrProjectOrAll(
        flutterProject: flutterProject,
      );
    } else if (!hasSpecifiedDeviceId) {
      return DeviceDiscoverySupportFilter.excludeDevicesUnsupportedByFlutterOrProject(
        flutterProject: flutterProject,
      );
    } else {
      return DeviceDiscoverySupportFilter.excludeDevicesUnsupportedByFlutter();
    }
  }

  Device? getSingleEphemeralDevice(List<Device> devices){
    if (!hasSpecifiedDeviceId) {
      try {
        return devices.singleWhere((Device device) => device.ephemeral);
      } on StateError {
        return null;
      }
    }
    return null;
  }
}

class DeviceDiscoverySupportFilter {
  DeviceDiscoverySupportFilter.excludeDevicesUnsupportedByFlutter()
      : _excludeDevicesNotSupportedByProject = false,
        _excludeDevicesNotSupportedByAll = false,
        _flutterProject = null;

  DeviceDiscoverySupportFilter.excludeDevicesUnsupportedByFlutterOrProject({
    required FlutterProject? flutterProject,
  })  : _flutterProject = flutterProject,
        _excludeDevicesNotSupportedByProject = true,
        _excludeDevicesNotSupportedByAll = false;

  DeviceDiscoverySupportFilter.excludeDevicesUnsupportedByFlutterOrProjectOrAll({
    required FlutterProject? flutterProject,
  })  : _flutterProject = flutterProject,
        _excludeDevicesNotSupportedByProject = true,
        _excludeDevicesNotSupportedByAll = true;

  final FlutterProject? _flutterProject;
  final bool _excludeDevicesNotSupportedByProject;
  final bool _excludeDevicesNotSupportedByAll;

  Future<bool> matchesRequirements(Device device) async {
    final bool meetsSupportByFlutterRequirement = device.isSupported();
    final bool meetsSupportForProjectRequirement = !_excludeDevicesNotSupportedByProject || isDeviceSupportedForProject(device);
    final bool meetsSupportForAllRequirement = !_excludeDevicesNotSupportedByAll || await isDeviceSupportedForAll(device);

    return meetsSupportByFlutterRequirement &&
        meetsSupportForProjectRequirement &&
        meetsSupportForAllRequirement;
  }

  Future<bool> isDeviceSupportedForAll(Device device) async {
    final TargetPlatform devicePlatform = await device.targetPlatform;
    return device.isSupported() &&
        devicePlatform != TargetPlatform.fuchsia_arm64 &&
        devicePlatform != TargetPlatform.fuchsia_x64 &&
        devicePlatform != TargetPlatform.web_javascript &&
        isDeviceSupportedForProject(device);
  }

  bool isDeviceSupportedForProject(Device device) {
    if (!device.isSupported()) {
      return false;
    }
    if (_flutterProject == null) {
      return true;
    }
    return device.isSupportedForProject(_flutterProject);
  }
}

class DeviceDiscoveryFilter {
  DeviceDiscoveryFilter({
    this.excludeDisconnected = true,
    this.supportFilter,
    this.deviceConnectionInterface,
  });

  final bool excludeDisconnected;
  final DeviceDiscoverySupportFilter? supportFilter;
  final DeviceConnectionInterface? deviceConnectionInterface;

  Future<bool> matchesRequirements(Device device) async {
    final DeviceDiscoverySupportFilter? localSupportFilter = supportFilter;

    final bool meetsConnectionRequirement = !excludeDisconnected || device.isConnected;
    final bool meetsSupportRequirements = localSupportFilter == null || (await localSupportFilter.matchesRequirements(device));
    final bool meetsConnectionInterfaceRequirement = matchesDeviceConnectionInterface(device, deviceConnectionInterface);

    return meetsConnectionRequirement &&
        meetsSupportRequirements &&
        meetsConnectionInterfaceRequirement;
  }

  Future<List<Device>> filterDevices(List<Device> devices) async {
    devices = <Device>[
      for (final Device device in devices)
        if (await matchesRequirements(device)) device,
    ];
    return devices;
  }

  bool matchesDeviceConnectionInterface(
    Device device,
    DeviceConnectionInterface? deviceConnectionInterface,
  ) {
    if (deviceConnectionInterface == null) {
      return true;
    }
    return device.connectionInterface == deviceConnectionInterface;
  }
}

abstract class DeviceDiscovery {
  bool get supportsPlatform;

  bool get canListAnything;

  bool get requiresExtendedWirelessDeviceDiscovery => false;

  Future<List<Device>> devices({DeviceDiscoveryFilter? filter});

  Future<List<Device>> discoverDevices({
    Duration? timeout,
    DeviceDiscoveryFilter? filter,
  });

  Future<List<String>> getDiagnostics() => Future<List<String>>.value(<String>[]);

  List<String> get wellKnownIds;
}

abstract class PollingDeviceDiscovery extends DeviceDiscovery {
  PollingDeviceDiscovery(this.name);

  static const Duration _pollingInterval = Duration(seconds: 4);
  static const Duration _pollingTimeout = Duration(seconds: 30);

  final String name;

  @protected
  @visibleForTesting
  ItemListNotifier<Device>? deviceNotifier;

  Timer? _timer;

  Future<List<Device>> pollingGetDevices({Duration? timeout});

  void startPolling() {
    if (_timer == null) {
      deviceNotifier ??= ItemListNotifier<Device>();
      // Make initial population the default, fast polling timeout.
      _timer = _initTimer(null, initialCall: true);
    }
  }

  Timer _initTimer(Duration? pollingTimeout, {bool initialCall = false}) {
    // Poll for devices immediately on the initial call for faster initial population.
    return Timer(initialCall ? Duration.zero : _pollingInterval, () async {
      try {
        final List<Device> devices = await pollingGetDevices(timeout: pollingTimeout);
        deviceNotifier!.updateWithNewList(devices);
      } on TimeoutException {
        // Do nothing on a timeout.
      }
      // Subsequent timeouts after initial population should wait longer.
      _timer = _initTimer(_pollingTimeout);
    });
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<List<Device>> devices({DeviceDiscoveryFilter? filter}) {
    return _populateDevices(filter: filter);
  }

  @override
  Future<List<Device>> discoverDevices({
    Duration? timeout,
    DeviceDiscoveryFilter? filter,
  }) {
    return _populateDevices(timeout: timeout, filter: filter, resetCache: true);
  }

  Future<List<Device>> _populateDevices({
    Duration? timeout,
    DeviceDiscoveryFilter? filter,
    bool resetCache = false,
  }) async {
    if (deviceNotifier == null || resetCache) {
      final List<Device> devices = await pollingGetDevices(timeout: timeout);
      // If the cache was populated while the polling was ongoing, do not
      // overwrite the cache unless it's explicitly refreshing the cache.
      if (resetCache) {
        deviceNotifier = ItemListNotifier<Device>.from(devices);
      } else {
        deviceNotifier ??= ItemListNotifier<Device>.from(devices);
      }
    }

    // If a filter is provided, filter cache to only return devices matching.
    if (filter != null) {
      return filter.filterDevices(deviceNotifier!.items);
    }
    return deviceNotifier!.items;
  }

  Stream<Device> get onAdded {
    deviceNotifier ??= ItemListNotifier<Device>();
    return deviceNotifier!.onAdded;
  }

  Stream<Device> get onRemoved {
    deviceNotifier ??= ItemListNotifier<Device>();
    return deviceNotifier!.onRemoved;
  }

  void dispose() => stopPolling();

  @override
  String toString() => '$name device discovery';
}

enum DeviceConnectionInterface {
  attached,
  wireless,
}

abstract class Device {
  Device(this.id, {
    required this.category,
    required this.platformType,
    required this.ephemeral,
  });

  final String id;

  final Category? category;

  final PlatformType? platformType;

  final bool ephemeral;

  bool get isConnected => true;

  DeviceConnectionInterface get connectionInterface =>
      DeviceConnectionInterface.attached;

  bool get isWirelesslyConnected =>
      connectionInterface == DeviceConnectionInterface.wireless;

  String get name;

  bool get supportsStartPaused => true;

  Future<bool> get isLocalEmulator;

  Future<String?> get emulatorId;

  FutureOr<bool> supportsRuntimeMode(BuildMode buildMode) => true;

  // This is soft-deprecated since the logic is not correct expect for iOS simulators.
  Future<bool> get supportsHardwareRendering async {
    return true;
  }

  bool isSupportedForProject(FlutterProject flutterProject);

  Future<bool> isAppInstalled(
    ApplicationPackage app, {
    String? userIdentifier,
  });

  Future<bool> isLatestBuildInstalled(ApplicationPackage app);

  Future<bool> installApp(
    ApplicationPackage app, {
    String? userIdentifier,
  });

  Future<bool> uninstallApp(
    ApplicationPackage app, {
    String? userIdentifier,
  });

  bool isSupported();

  // String meant to be displayed to the user indicating if the device is
  // supported by Flutter, and, if not, why.
  String supportMessage() => isSupported() ? 'Supported' : 'Unsupported';

  Future<TargetPlatform> get targetPlatform;

  Future<String> get targetPlatformDisplayName async =>
      getNameForTargetPlatform(await targetPlatform);

  Future<String> get sdkNameAndVersion;

  DevFSWriter? createDevFSWriter(
    ApplicationPackage? app,
    String? userIdentifier,
  ) {
    return null;
  }

  FutureOr<DeviceLogReader> getLogReader({
    ApplicationPackage? app,
    bool includePastLogs = false,
  });

  DevicePortForwarder? get portForwarder;

  final DartDevelopmentService dds = DartDevelopmentService();

  void clearLogs();

  Future<LaunchResult> startApp(
    covariant ApplicationPackage? package, {
    String? mainPath,
    String? route,
    required DebuggingOptions debuggingOptions,
    Map<String, Object?> platformArgs,
    bool prebuiltApplication = false,
    bool ipv6 = false,
    String? userIdentifier,
  });

  bool get supportsHotReload => true;

  bool get supportsHotRestart => true;

  bool get supportsFlutterExit => true;

  bool get supportsScreenshot => false;

  bool get supportsFastStart => false;

  Future<bool> stopApp(
    ApplicationPackage? app, {
    String? userIdentifier,
  });

  Future<MemoryInfo> queryMemoryInfo() {
    return Future<MemoryInfo>.value(const MemoryInfo.empty());
  }

  Future<void> takeScreenshot(File outputFile) => Future<void>.error('unimplemented');

  @nonVirtual
  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  int get hashCode => id.hashCode;

  @nonVirtual
  @override
  // ignore: avoid_equals_and_hash_code_on_mutable_classes
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Device
        && other.id == id;
  }

  @override
  String toString() => name;

  static Future<List<String>> descriptions(List<Device> devices) async {
    if (devices.isEmpty) {
      return const <String>[];
    }

    // Extract device information
    final List<List<String>> table = <List<String>>[];
    for (final Device device in devices) {
      String supportIndicator = device.isSupported() ? '' : ' (unsupported)';
      final TargetPlatform targetPlatform = await device.targetPlatform;
      if (await device.isLocalEmulator) {
        final String type = targetPlatform == TargetPlatform.ios ? 'simulator' : 'emulator';
        supportIndicator += ' ($type)';
      }
      table.add(<String>[
        '${device.name} (${device.category})',
        device.id,
        await device.targetPlatformDisplayName,
        '${await device.sdkNameAndVersion}$supportIndicator',
      ]);
    }

    // Calculate column widths
    final List<int> indices = List<int>.generate(table[0].length - 1, (int i) => i);
    List<int> widths = indices.map<int>((int i) => 0).toList();
    for (final List<String> row in table) {
      widths = indices.map<int>((int i) => math.max(widths[i], row[i].length)).toList();
    }

    // Join columns into lines of text
    return <String>[
      for (final List<String> row in table)
        indices.map<String>((int i) => row[i].padRight(widths[i])).followedBy(<String>[row.last]).join(' • '),
    ];
  }

  static Future<void> printDevices(List<Device> devices, Logger logger, { String prefix = '' }) async {
    for (final String line in await descriptions(devices)) {
      logger.printStatus('$prefix$line');
    }
  }

  static List<String> devicesPlatformTypes(List<Device> devices) {
    return devices
        .map(
          (Device d) => d.platformType.toString(),
        ).toSet().toList()..sort();
  }

  Future<Map<String, Object>> toJson() async {
    final bool isLocalEmu = await isLocalEmulator;
    return <String, Object>{
      'name': name,
      'id': id,
      'isSupported': isSupported(),
      'targetPlatform': getNameForTargetPlatform(await targetPlatform),
      'emulator': isLocalEmu,
      'sdk': await sdkNameAndVersion,
      'capabilities': <String, Object>{
        'hotReload': supportsHotReload,
        'hotRestart': supportsHotRestart,
        'screenshot': supportsScreenshot,
        'fastStart': supportsFastStart,
        'flutterExit': supportsFlutterExit,
        'hardwareRendering': isLocalEmu && await supportsHardwareRendering,
        'startPaused': supportsStartPaused,
      },
    };
  }

  Future<void> dispose();
}

abstract class MemoryInfo {
  const MemoryInfo();

  const factory MemoryInfo.empty() = _NoMemoryInfo;

  Map<String, Object> toJson();
}

class _NoMemoryInfo implements MemoryInfo {
  const _NoMemoryInfo();

  @override
  Map<String, Object> toJson() => <String, Object>{};
}

enum ImpellerStatus {
  platformDefault._(null),
  enabled._(true),
  disabled._(false);

  const ImpellerStatus._(this.asBool);

  factory ImpellerStatus.fromBool(bool? b) {
    if (b == null) {
      return platformDefault;
    }
    return b ? enabled : disabled;
  }

  final bool? asBool;
}

class DebuggingOptions {
  DebuggingOptions.enabled(
    this.buildInfo, {
    this.startPaused = false,
    this.disableServiceAuthCodes = false,
    this.enableDds = true,
    this.cacheStartupProfile = false,
    this.dartEntrypointArgs = const <String>[],
    this.dartFlags = '',
    this.enableSoftwareRendering = false,
    this.skiaDeterministicRendering = false,
    this.traceSkia = false,
    this.traceAllowlist,
    this.traceSkiaAllowlist,
    this.traceSystrace = false,
    this.endlessTraceBuffer = false,
    this.dumpSkpOnShaderCompilation = false,
    this.cacheSkSL = false,
    this.purgePersistentCache = false,
    this.useTestFonts = false,
    this.verboseSystemLogs = false,
    this.hostVmServicePort,
    this.disablePortPublication = false,
    this.deviceVmServicePort,
    this.ddsPort,
    this.devToolsServerAddress,
    this.hostname,
    this.port,
    this.webEnableExposeUrl,
    this.webUseSseForDebugProxy = true,
    this.webUseSseForDebugBackend = true,
    this.webUseSseForInjectedClient = true,
    this.webRunHeadless = false,
    this.webBrowserDebugPort,
    this.webBrowserFlags = const <String>[],
    this.webEnableExpressionEvaluation = false,
    this.webLaunchUrl,
    this.vmserviceOutFile,
    this.fastStart = false,
    this.nullAssertions = false,
    this.nativeNullAssertions = false,
    this.enableImpeller = ImpellerStatus.platformDefault,
    this.enableVulkanValidation = false,
    this.impellerForceGL = false,
    this.uninstallFirst = false,
    this.serveObservatory = false,
    this.enableDartProfiling = true,
    this.enableEmbedderApi = false,
    this.usingCISystem = false,
   }) : debuggingEnabled = true;

  DebuggingOptions.disabled(this.buildInfo, {
      this.dartEntrypointArgs = const <String>[],
      this.port,
      this.hostname,
      this.webEnableExposeUrl,
      this.webUseSseForDebugProxy = true,
      this.webUseSseForDebugBackend = true,
      this.webUseSseForInjectedClient = true,
      this.webRunHeadless = false,
      this.webBrowserDebugPort,
      this.webBrowserFlags = const <String>[],
      this.webLaunchUrl,
      this.cacheSkSL = false,
      this.traceAllowlist,
      this.enableImpeller = ImpellerStatus.platformDefault,
      this.enableVulkanValidation = false,
      this.impellerForceGL = false,
      this.uninstallFirst = false,
      this.enableDartProfiling = true,
      this.enableEmbedderApi = false,
      this.usingCISystem = false,
    }) : debuggingEnabled = false,
      useTestFonts = false,
      startPaused = false,
      dartFlags = '',
      disableServiceAuthCodes = false,
      enableDds = true,
      cacheStartupProfile = false,
      enableSoftwareRendering = false,
      skiaDeterministicRendering = false,
      traceSkia = false,
      traceSkiaAllowlist = null,
      traceSystrace = false,
      endlessTraceBuffer = false,
      dumpSkpOnShaderCompilation = false,
      purgePersistentCache = false,
      verboseSystemLogs = false,
      hostVmServicePort = null,
      disablePortPublication = false,
      deviceVmServicePort = null,
      ddsPort = null,
      devToolsServerAddress = null,
      vmserviceOutFile = null,
      fastStart = false,
      webEnableExpressionEvaluation = false,
      nullAssertions = false,
      nativeNullAssertions = false,
      serveObservatory = false;

  DebuggingOptions._({
    required this.buildInfo,
    required this.debuggingEnabled,
    required this.startPaused,
    required this.dartFlags,
    required this.dartEntrypointArgs,
    required this.disableServiceAuthCodes,
    required this.enableDds,
    required this.cacheStartupProfile,
    required this.enableSoftwareRendering,
    required this.skiaDeterministicRendering,
    required this.traceSkia,
    required this.traceAllowlist,
    required this.traceSkiaAllowlist,
    required this.traceSystrace,
    required this.endlessTraceBuffer,
    required this.dumpSkpOnShaderCompilation,
    required this.cacheSkSL,
    required this.purgePersistentCache,
    required this.useTestFonts,
    required this.verboseSystemLogs,
    required this.hostVmServicePort,
    required this.deviceVmServicePort,
    required this.disablePortPublication,
    required this.ddsPort,
    required this.devToolsServerAddress,
    required this.port,
    required this.hostname,
    required this.webEnableExposeUrl,
    required this.webUseSseForDebugProxy,
    required this.webUseSseForDebugBackend,
    required this.webUseSseForInjectedClient,
    required this.webRunHeadless,
    required this.webBrowserDebugPort,
    required this.webBrowserFlags,
    required this.webEnableExpressionEvaluation,
    required this.webLaunchUrl,
    required this.vmserviceOutFile,
    required this.fastStart,
    required this.nullAssertions,
    required this.nativeNullAssertions,
    required this.enableImpeller,
    required this.enableVulkanValidation,
    required this.impellerForceGL,
    required this.uninstallFirst,
    required this.serveObservatory,
    required this.enableDartProfiling,
    required this.enableEmbedderApi,
    required this.usingCISystem,
  });

  final bool debuggingEnabled;

  final BuildInfo buildInfo;
  final bool startPaused;
  final String dartFlags;
  final List<String> dartEntrypointArgs;
  final bool disableServiceAuthCodes;
  final bool enableDds;
  final bool cacheStartupProfile;
  final bool enableSoftwareRendering;
  final bool skiaDeterministicRendering;
  final bool traceSkia;
  final String? traceAllowlist;
  final String? traceSkiaAllowlist;
  final bool traceSystrace;
  final bool endlessTraceBuffer;
  final bool dumpSkpOnShaderCompilation;
  final bool cacheSkSL;
  final bool purgePersistentCache;
  final bool useTestFonts;
  final bool verboseSystemLogs;
  final int? hostVmServicePort;
  final int? deviceVmServicePort;
  final bool disablePortPublication;
  final int? ddsPort;
  final Uri? devToolsServerAddress;
  final String? port;
  final String? hostname;
  final bool? webEnableExposeUrl;
  final bool webUseSseForDebugProxy;
  final bool webUseSseForDebugBackend;
  final bool webUseSseForInjectedClient;
  final ImpellerStatus enableImpeller;
  final bool enableVulkanValidation;
  final bool impellerForceGL;
  final bool serveObservatory;
  final bool enableDartProfiling;
  final bool enableEmbedderApi;
  final bool usingCISystem;

  final bool uninstallFirst;

  final bool webRunHeadless;

  final int? webBrowserDebugPort;

  final List<String> webBrowserFlags;

  final bool webEnableExpressionEvaluation;

  final String? webLaunchUrl;

  final String? vmserviceOutFile;
  final bool fastStart;

  final bool nullAssertions;

  final bool nativeNullAssertions;

  List<String> getIOSLaunchArguments(
    EnvironmentType environmentType,
    String? route,
    Map<String, Object?> platformArgs, {
    bool ipv6 = false,
    DeviceConnectionInterface interfaceType = DeviceConnectionInterface.attached,
    bool isCoreDevice = false,
  }) {
    final String dartVmFlags = computeDartVmFlags(this);
    return <String>[
      if (enableDartProfiling) '--enable-dart-profiling',
      if (disableServiceAuthCodes) '--disable-service-auth-codes',
      if (disablePortPublication) '--disable-vm-service-publication',
      if (startPaused) '--start-paused',
      // Wrap dart flags in quotes for physical devices
      if (environmentType == EnvironmentType.physical && dartVmFlags.isNotEmpty)
        '--dart-flags="$dartVmFlags"',
      if (environmentType == EnvironmentType.simulator && dartVmFlags.isNotEmpty)
        '--dart-flags=$dartVmFlags',
      if (useTestFonts) '--use-test-fonts',
      // Core Devices (iOS 17 devices) are debugged through Xcode so don't
      // include these flags, which are used to check if the app was launched
      // via Flutter CLI and `ios-deploy`.
      if (debuggingEnabled && !isCoreDevice) ...<String>[
        '--enable-checked-mode',
        '--verify-entry-points',
      ],
      if (enableSoftwareRendering) '--enable-software-rendering',
      if (traceSystrace) '--trace-systrace',
      if (skiaDeterministicRendering) '--skia-deterministic-rendering',
      if (traceSkia) '--trace-skia',
      if (traceAllowlist != null) '--trace-allowlist="$traceAllowlist"',
      if (traceSkiaAllowlist != null) '--trace-skia-allowlist="$traceSkiaAllowlist"',
      if (endlessTraceBuffer) '--endless-trace-buffer',
      if (dumpSkpOnShaderCompilation) '--dump-skp-on-shader-compilation',
      if (verboseSystemLogs) '--verbose-logging',
      if (cacheSkSL) '--cache-sksl',
      if (purgePersistentCache) '--purge-persistent-cache',
      if (route != null) '--route=$route',
      if (platformArgs['trace-startup'] as bool? ?? false) '--trace-startup',
      if (enableImpeller == ImpellerStatus.enabled) '--enable-impeller=true',
      if (enableImpeller == ImpellerStatus.disabled) '--enable-impeller=false',
      if (environmentType == EnvironmentType.physical && deviceVmServicePort != null)
        '--vm-service-port=$deviceVmServicePort',
      // The simulator "device" is actually on the host machine so no ports will be forwarded.
      // Use the suggested host port.
      if (environmentType == EnvironmentType.simulator && hostVmServicePort != null)
        '--vm-service-port=$hostVmServicePort',
      // Tell the VM service to listen on all interfaces, don't restrict to the loopback.
      if (interfaceType == DeviceConnectionInterface.wireless)
        '--vm-service-host=${ipv6 ? '::0' : '0.0.0.0'}',
      if (enableEmbedderApi) '--enable-embedder-api',
    ];
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'debuggingEnabled': debuggingEnabled,
    'startPaused': startPaused,
    'dartFlags': dartFlags,
    'dartEntrypointArgs': dartEntrypointArgs,
    'disableServiceAuthCodes': disableServiceAuthCodes,
    'enableDds': enableDds,
    'cacheStartupProfile': cacheStartupProfile,
    'enableSoftwareRendering': enableSoftwareRendering,
    'skiaDeterministicRendering': skiaDeterministicRendering,
    'traceSkia': traceSkia,
    'traceAllowlist': traceAllowlist,
    'traceSkiaAllowlist': traceSkiaAllowlist,
    'traceSystrace': traceSystrace,
    'endlessTraceBuffer': endlessTraceBuffer,
    'dumpSkpOnShaderCompilation': dumpSkpOnShaderCompilation,
    'cacheSkSL': cacheSkSL,
    'purgePersistentCache': purgePersistentCache,
    'useTestFonts': useTestFonts,
    'verboseSystemLogs': verboseSystemLogs,
    'hostVmServicePort': hostVmServicePort,
    'deviceVmServicePort': deviceVmServicePort,
    'disablePortPublication': disablePortPublication,
    'ddsPort': ddsPort,
    'devToolsServerAddress': devToolsServerAddress.toString(),
    'port': port,
    'hostname': hostname,
    'webEnableExposeUrl': webEnableExposeUrl,
    'webUseSseForDebugProxy': webUseSseForDebugProxy,
    'webUseSseForDebugBackend': webUseSseForDebugBackend,
    'webUseSseForInjectedClient': webUseSseForInjectedClient,
    'webRunHeadless': webRunHeadless,
    'webBrowserDebugPort': webBrowserDebugPort,
    'webBrowserFlags': webBrowserFlags,
    'webEnableExpressionEvaluation': webEnableExpressionEvaluation,
    'webLaunchUrl': webLaunchUrl,
    'vmserviceOutFile': vmserviceOutFile,
    'fastStart': fastStart,
    'nullAssertions': nullAssertions,
    'nativeNullAssertions': nativeNullAssertions,
    'enableImpeller': enableImpeller.asBool,
    'enableVulkanValidation': enableVulkanValidation,
    'impellerForceGL': impellerForceGL,
    'serveObservatory': serveObservatory,
    'enableDartProfiling': enableDartProfiling,
    'enableEmbedderApi': enableEmbedderApi,
    'usingCISystem': usingCISystem,
  };

  static DebuggingOptions fromJson(Map<String, Object?> json, BuildInfo buildInfo) =>
    DebuggingOptions._(
      buildInfo: buildInfo,
      debuggingEnabled: json['debuggingEnabled']! as bool,
      startPaused: json['startPaused']! as bool,
      dartFlags: json['dartFlags']! as String,
      dartEntrypointArgs: (json['dartEntrypointArgs']! as List<dynamic>).cast<String>(),
      disableServiceAuthCodes: json['disableServiceAuthCodes']! as bool,
      enableDds: json['enableDds']! as bool,
      cacheStartupProfile: json['cacheStartupProfile']! as bool,
      enableSoftwareRendering: json['enableSoftwareRendering']! as bool,
      skiaDeterministicRendering: json['skiaDeterministicRendering']! as bool,
      traceSkia: json['traceSkia']! as bool,
      traceAllowlist: json['traceAllowlist'] as String?,
      traceSkiaAllowlist: json['traceSkiaAllowlist'] as String?,
      traceSystrace: json['traceSystrace']! as bool,
      endlessTraceBuffer: json['endlessTraceBuffer']! as bool,
      dumpSkpOnShaderCompilation: json['dumpSkpOnShaderCompilation']! as bool,
      cacheSkSL: json['cacheSkSL']! as bool,
      purgePersistentCache: json['purgePersistentCache']! as bool,
      useTestFonts: json['useTestFonts']! as bool,
      verboseSystemLogs: json['verboseSystemLogs']! as bool,
      hostVmServicePort: json['hostVmServicePort'] as int? ,
      deviceVmServicePort: json['deviceVmServicePort'] as int?,
      disablePortPublication: json['disablePortPublication']! as bool,
      ddsPort: json['ddsPort'] as int?,
      devToolsServerAddress: json['devToolsServerAddress'] != null ? Uri.parse(json['devToolsServerAddress']! as String) : null,
      port: json['port'] as String?,
      hostname: json['hostname'] as String?,
      webEnableExposeUrl: json['webEnableExposeUrl'] as bool?,
      webUseSseForDebugProxy: json['webUseSseForDebugProxy']! as bool,
      webUseSseForDebugBackend: json['webUseSseForDebugBackend']! as bool,
      webUseSseForInjectedClient: json['webUseSseForInjectedClient']! as bool,
      webRunHeadless: json['webRunHeadless']! as bool,
      webBrowserDebugPort: json['webBrowserDebugPort'] as int?,
      webBrowserFlags: (json['webBrowserFlags']! as List<dynamic>).cast<String>(),
      webEnableExpressionEvaluation: json['webEnableExpressionEvaluation']! as bool,
      webLaunchUrl: json['webLaunchUrl'] as String?,
      vmserviceOutFile: json['vmserviceOutFile'] as String?,
      fastStart: json['fastStart']! as bool,
      nullAssertions: json['nullAssertions']! as bool,
      nativeNullAssertions: json['nativeNullAssertions']! as bool,
      enableImpeller: ImpellerStatus.fromBool(json['enableImpeller'] as bool?),
      enableVulkanValidation: (json['enableVulkanValidation'] as bool?) ?? false,
      impellerForceGL: (json['impellerForceGL'] as bool?) ?? false,
      uninstallFirst: (json['uninstallFirst'] as bool?) ?? false,
      serveObservatory: (json['serveObservatory'] as bool?) ?? false,
      enableDartProfiling: (json['enableDartProfiling'] as bool?) ?? true,
      enableEmbedderApi: (json['enableEmbedderApi'] as bool?) ?? false,
      usingCISystem: (json['usingCISystem'] as bool?) ?? false,
    );
}

class LaunchResult {
  LaunchResult.succeeded({ Uri? vmServiceUri, Uri? observatoryUri }) :
    started = true,
    vmServiceUri = vmServiceUri ?? observatoryUri;

  LaunchResult.failed()
    : started = false,
      vmServiceUri = null;

  bool get hasVmService => vmServiceUri != null;

  final bool started;
  final Uri? vmServiceUri;

  @override
  String toString() {
    final StringBuffer buf = StringBuffer('started=$started');
    if (vmServiceUri != null) {
      buf.write(', vmService=$vmServiceUri');
    }
    return buf.toString();
  }
}

abstract class DeviceLogReader {
  String get name;

  Stream<String> get logLines;

  FlutterVmService? connectedVMService;

  @override
  String toString() => name;

  int? appPid;

  // Clean up resources allocated by log reader e.g. subprocesses
  void dispose();
}

class DiscoveredApp {
  DiscoveredApp(this.id, this.vmServicePort);
  final String id;
  final int vmServicePort;
}

// An empty device log reader
class NoOpDeviceLogReader implements DeviceLogReader {
  NoOpDeviceLogReader(String? nameOrNull) : name = nameOrNull ?? '';

  @override
  final String name;

  @override
  int? appPid;

  @override
  FlutterVmService? connectedVMService;

  @override
  Stream<String> get logLines => const Stream<String>.empty();

  @override
  void dispose() { }
}

String computeDartVmFlags(DebuggingOptions debuggingOptions) {
  return <String>[
    if (debuggingOptions.dartFlags.isNotEmpty)
      debuggingOptions.dartFlags,
    if (debuggingOptions.nullAssertions)
      '--null_assertions',
  ].join(',');
}