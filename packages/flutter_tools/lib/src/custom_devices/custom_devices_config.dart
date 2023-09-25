import 'package:meta/meta.dart';

import '../base/config.dart';
import '../base/file_system.dart';
import '../base/logger.dart';
import '../base/platform.dart';
import '../cache.dart';
import 'custom_device_config.dart';

class CustomDevicesConfig {
  CustomDevicesConfig({
    required Platform platform,
    required FileSystem fileSystem,
    required Logger logger,
  }) : _platform = platform,
       _fileSystem = fileSystem,
       _logger = logger,
       _configLoader = (() => Config.managed(
         _kCustomDevicesConfigName,
         fileSystem: fileSystem,
         logger: logger,
         platform: platform,
       ));

  @visibleForTesting
  CustomDevicesConfig.test({
    required FileSystem fileSystem,
    required Logger logger,
    Directory? directory,
    Platform? platform,
  }) : _platform = platform ?? FakePlatform(),
       _fileSystem = fileSystem,
       _logger = logger,
       _configLoader = (() => Config.test(
         name: _kCustomDevicesConfigName,
         directory: directory,
         logger: logger,
         managed: true
       ));

  static const String _kCustomDevicesConfigName = 'custom_devices.json';
  static const String _kCustomDevicesConfigKey = 'custom-devices';
  static const String _kSchema = r'$schema';
  static const String _kCustomDevices = 'custom-devices';

  final Platform _platform;
  final FileSystem _fileSystem;
  final Logger _logger;
  final Config Function() _configLoader;

  // When the custom devices feature is disabled, CustomDevicesConfig is
  // constructed anyway. So loading the config in the constructor isn't a good
  // idea. (The Config ctor logs any errors)
  //
  // I also didn't want to introduce a FeatureFlags argument to the constructor
  // and conditionally load the config when the feature is enabled, because
  // sometimes we need that Config object even when the feature is disabled.
  // For example inside ensureFileExists, which is used when enabling
  // the feature.
  //
  // Instead, users of this config should handle the feature flags. So for
  // example don't get [devices] when the feature is disabled.
  Config? __config;
  Config get _config {
    __config ??= _configLoader();
    return __config!;
  }

  String get _defaultSchema {
    final Uri uri = _fileSystem
      .directory(Cache.flutterRoot)
      .childDirectory('packages')
      .childDirectory('flutter_tools')
      .childDirectory('static')
      .childFile('custom-devices.schema.json')
      .uri;

    // otherwise it won't contain the Uri schema, so the file:// at the start
    // will be missing
    assert(uri.isAbsolute);

    return uri.toString();
  }

  void ensureFileExists() {
    if (!_fileSystem.file(_config.configPath).existsSync()) {
      _config.setValue(_kSchema, _defaultSchema);
      _config.setValue(_kCustomDevices, <dynamic>[
        CustomDeviceConfig.getExampleForPlatform(_platform).toJson(),
      ]);
    }
  }

  List<dynamic>? _getDevicesJsonValue() {
    final dynamic json = _config.getValue(_kCustomDevicesConfigKey);

    if (json == null) {
      return null;
    } else if (json is! List) {
      const String msg = "Could not load custom devices config. config['$_kCustomDevicesConfigKey'] is not a JSON array.";
      _logger.printError(msg);
      throw const CustomDeviceRevivalException(msg);
    }

    return json;
  }

  List<CustomDeviceConfig> get devices {
    final List<dynamic>? typedListNullable = _getDevicesJsonValue();
    if (typedListNullable == null) {
      return <CustomDeviceConfig>[];
    }

    final List<dynamic> typedList = typedListNullable;
    final List<CustomDeviceConfig> revived = <CustomDeviceConfig>[];
    for (final MapEntry<int, dynamic> entry in typedList.asMap().entries) {
      try {
        revived.add(CustomDeviceConfig.fromJson(entry.value));
      } on CustomDeviceRevivalException catch (e) {
        final String msg = 'Could not load custom device from config index ${entry.key}: $e';
        _logger.printError(msg);
        throw CustomDeviceRevivalException(msg);
      }
    }

    return revived;
  }

  List<CustomDeviceConfig> tryGetDevices() {
    try {
      return devices;
    } on Exception {
      // any Exceptions are logged by [devices] already.
      return <CustomDeviceConfig>[];
    }
  }

  set devices(List<CustomDeviceConfig> configs) {
    _config.setValue(
      _kCustomDevicesConfigKey,
      configs.map<dynamic>((CustomDeviceConfig c) => c.toJson()).toList()
    );
  }

  void add(CustomDeviceConfig config) {
    _config.setValue(
      _kCustomDevicesConfigKey,
      <dynamic>[
        ...?_getDevicesJsonValue(),
        config.toJson(),
      ]
    );
  }

  bool contains(String deviceId) {
    return devices.any((CustomDeviceConfig device) => device.id == deviceId);
  }

  bool remove(String deviceId) {
    final List<CustomDeviceConfig> modifiedDevices = devices;

    // we use this instead of filtering so we can detect if we actually removed
    // anything.
    final CustomDeviceConfig? device = modifiedDevices
      .cast<CustomDeviceConfig?>()
      .firstWhere((CustomDeviceConfig? d) => d!.id == deviceId,
      orElse: () => null
    );

    if (device == null) {
      return false;
    }

    modifiedDevices.remove(device);
    devices = modifiedDevices;
    return true;
  }

  String get configPath => _config.configPath;
}