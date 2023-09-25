import 'package:yaml/yaml.dart';

import 'base/file_system.dart';
import 'base/logger.dart';
import 'base/utils.dart';
import 'features.dart';
import 'project.dart';
import 'template.dart';
import 'version.dart';

enum FlutterProjectType implements CliEnum {
  app,

  skeleton,

  module,

  package,

  packageFfi,

  plugin,

  pluginFfi;

  @override
  String get cliName => snakeCase(name);

  @override
  String get helpText => switch (this) {
        FlutterProjectType.app => '(default) Generate a Flutter application.',
        FlutterProjectType.skeleton =>
          'Generate a List View / Detail View Flutter application that follows community best practices.',
        FlutterProjectType.package =>
          'Generate a shareable Flutter project containing modular Dart code.',
        FlutterProjectType.plugin =>
          'Generate a shareable Flutter project containing an API '
          'in Dart code with a platform-specific implementation through method channels for Android, iOS, '
          'Linux, macOS, Windows, web, or any combination of these.',
        FlutterProjectType.pluginFfi =>
          'Generate a shareable Flutter project containing an API '
          'in Dart code with a platform-specific implementation through dart:ffi for Android, iOS, '
          'Linux, macOS, Windows, or any combination of these.',
        FlutterProjectType.packageFfi =>
          'Generate a shareable Dart/Flutter project containing an API '
          'in Dart code with a platform-specific implementation through dart:ffi for Android, iOS, '
          'Linux, macOS, and Windows.',
        FlutterProjectType.module =>
          'Generate a project to add a Flutter module to an existing Android or iOS application.',
      };

  static FlutterProjectType? fromCliName(String value) {
    for (final FlutterProjectType type in FlutterProjectType.values) {
      if (value == type.cliName) {
        return type;
      }
    }
    return null;
  }

  static List<FlutterProjectType> get enabledValues {
    return <FlutterProjectType>[
      for (final FlutterProjectType value in values)
        if (value == FlutterProjectType.packageFfi) ...<FlutterProjectType>[
          if (featureFlags.isNativeAssetsEnabled) value
        ] else
          value,
    ];
  }
}

  bool _validateMetadataMap(YamlMap map, Map<String, Type> validations, Logger logger) {
    bool isValid = true;
    for (final MapEntry<String, Object> entry in validations.entries) {
      if (!map.keys.contains(entry.key)) {
        isValid = false;
        logger.printTrace('The key `${entry.key}` was not found');
        break;
      }
      final Object? metadataValue = map[entry.key];
      if (metadataValue.runtimeType != entry.value) {
        isValid = false;
        logger.printTrace('The value of key `${entry.key}` in .metadata was expected to be ${entry.value} but was ${metadataValue.runtimeType}');
        break;
      }
    }
    return isValid;
  }

class FlutterProjectMetadata {
  FlutterProjectMetadata(this.file, Logger logger) : _logger = logger,
                                                     migrateConfig = MigrateConfig() {
    if (!file.existsSync()) {
      _logger.printTrace('No .metadata file found at ${file.path}.');
      // Create a default empty metadata.
      return;
    }
    Object? yamlRoot;
    try {
      yamlRoot = loadYaml(file.readAsStringSync());
    } on YamlException {
      // Handled in _validate below.
    }
    if (yamlRoot is! YamlMap) {
      _logger.printTrace('.metadata file at ${file.path} was empty or malformed.');
      return;
    }
    if (_validateMetadataMap(yamlRoot, <String, Type>{'version': YamlMap}, _logger)) {
      final Object? versionYamlMap = yamlRoot['version'];
      if (versionYamlMap is YamlMap && _validateMetadataMap(versionYamlMap, <String, Type>{
            'revision': String,
            'channel': String,
          }, _logger)) {
        _versionRevision = versionYamlMap['revision'] as String?;
        _versionChannel = versionYamlMap['channel'] as String?;
      }
    }
    if (_validateMetadataMap(yamlRoot, <String, Type>{'project_type': String}, _logger)) {
      _projectType = FlutterProjectType.fromCliName(yamlRoot['project_type'] as String);
    }
    final Object? migrationYaml = yamlRoot['migration'];
    if (migrationYaml is YamlMap) {
      migrateConfig.parseYaml(migrationYaml, _logger);
    }
  }

  FlutterProjectMetadata.explicit({
    required this.file,
    required String? versionRevision,
    required String? versionChannel,
    required FlutterProjectType? projectType,
    required this.migrateConfig,
    required Logger logger,
  }) : _logger = logger,
       _versionChannel = versionChannel,
       _versionRevision = versionRevision,
       _projectType = projectType;

  static const String kFileName = '.metadata';

  String? _versionRevision;
  String? get versionRevision => _versionRevision;

  String? _versionChannel;
  String? get versionChannel => _versionChannel;

  FlutterProjectType? _projectType;
  FlutterProjectType? get projectType => _projectType;

  MigrateConfig migrateConfig;

  final Logger _logger;

  final File file;

  void writeFile({File? outputFile}) {
    outputFile = outputFile ?? file;
    outputFile
      ..createSync(recursive: true)
      ..writeAsStringSync(toString(), flush: true);
  }

  @override
  String toString() {
    return '''
# This file tracks properties of this Flutter project.
# Used by Flutter tool to assess capabilities and perform upgrades etc.
#
# This file should be version controlled and should not be manually edited.

version:
  revision: ${escapeYamlString(_versionRevision ?? '')}
  channel: ${escapeYamlString(_versionChannel ?? kUserBranch)}

project_type: ${projectType == null ? '' : projectType!.cliName}
${migrateConfig.getOutputFileString()}''';
  }

  void populate({
    List<SupportedPlatform>? platforms,
    required Directory projectDirectory,
    String? currentRevision,
    String? createRevision,
    bool create = true,
    bool update = true,
    required Logger logger,
  }) {
    migrateConfig.populate(
      platforms: platforms,
      projectDirectory: projectDirectory,
      currentRevision: currentRevision,
      createRevision: createRevision,
      create: create,
      update: update,
      logger: logger,
    );
  }

  String getFallbackBaseRevision(Logger logger, FlutterVersion flutterVersion) {
    // Use the .metadata file if it exists.
    if (versionRevision != null) {
      return versionRevision!;
    }
    return flutterVersion.frameworkRevision;
  }
}

class MigrateConfig {
  MigrateConfig({
    Map<SupportedPlatform, MigratePlatformConfig>? platformConfigs,
    this.unmanagedFiles = kDefaultUnmanagedFiles
  }) : platformConfigs = platformConfigs ?? <SupportedPlatform, MigratePlatformConfig>{};

  static const List<String> kDefaultUnmanagedFiles = <String>[
    'lib/main.dart',
    'ios/Runner.xcodeproj/project.pbxproj',
  ];

  final Map<SupportedPlatform, MigratePlatformConfig> platformConfigs;

  List<String> unmanagedFiles;

  bool get isEmpty => platformConfigs.isEmpty && (unmanagedFiles.isEmpty || unmanagedFiles == kDefaultUnmanagedFiles);

  void populate({
    List<SupportedPlatform>? platforms,
    required Directory projectDirectory,
    String? currentRevision,
    String? createRevision,
    bool create = true,
    bool update = true,
    required Logger logger,
  }) {
    final FlutterProject flutterProject = FlutterProject.fromDirectory(projectDirectory);
    platforms ??= flutterProject.getSupportedPlatforms(includeRoot: true);

    for (final SupportedPlatform platform in platforms) {
      if (platformConfigs.containsKey(platform)) {
        if (update) {
          platformConfigs[platform]!.baseRevision = currentRevision;
        }
      } else {
        if (create) {
          platformConfigs[platform] = MigratePlatformConfig(platform: platform, createRevision: createRevision, baseRevision: currentRevision);
        }
      }
    }
  }

  String getOutputFileString() {
    String unmanagedFilesString = '';
    for (final String path in unmanagedFiles) {
      unmanagedFilesString += "\n    - '$path'";
    }

    String platformsString = '';
    for (final MapEntry<SupportedPlatform, MigratePlatformConfig> entry in platformConfigs.entries) {
      platformsString += '\n    - platform: ${entry.key.toString().split('.').last}\n      create_revision: ${entry.value.createRevision == null ? 'null' : "${entry.value.createRevision}"}\n      base_revision: ${entry.value.baseRevision == null ? 'null' : "${entry.value.baseRevision}"}';
    }

    return isEmpty ? '' : '''

# Tracks metadata for the flutter migrate command
migration:
  platforms:$platformsString

  # User provided section

  # List of Local paths (relative to this file) that should be
  # ignored by the migrate tool.
  #
  # Files that are not part of the templates will be ignored by default.
  unmanaged_files:$unmanagedFilesString
''';
  }

  void parseYaml(YamlMap map, Logger logger) {
    final Object? platformsYaml = map['platforms'];
    if (_validateMetadataMap(map, <String, Type>{'platforms': YamlList}, logger)) {
      if (platformsYaml is YamlList && platformsYaml.isNotEmpty) {
        for (final YamlMap platformYamlMap in platformsYaml.whereType<YamlMap>()) {
          if (_validateMetadataMap(platformYamlMap, <String, Type>{
                'platform': String,
                'create_revision': String,
                'base_revision': String,
              }, logger)) {
            final SupportedPlatform platformValue = SupportedPlatform.values.firstWhere(
              (SupportedPlatform val) => val.toString() == 'SupportedPlatform.${platformYamlMap['platform'] as String}'
            );
            platformConfigs[platformValue] = MigratePlatformConfig(
              platform: platformValue,
              createRevision: platformYamlMap['create_revision'] as String?,
              baseRevision: platformYamlMap['base_revision'] as String?,
            );
          } else {
            // malformed platform entry
            continue;
          }
        }
      }
    }
    if (_validateMetadataMap(map, <String, Type>{'unmanaged_files': YamlList}, logger)) {
      final Object? unmanagedFilesYaml = map['unmanaged_files'];
      if (unmanagedFilesYaml is YamlList && unmanagedFilesYaml.isNotEmpty) {
        unmanagedFiles = List<String>.from(unmanagedFilesYaml.value.cast<String>());
      }
    }
  }
}

class MigratePlatformConfig {
  MigratePlatformConfig({
    required this.platform,
    this.createRevision,
    this.baseRevision
  });

  SupportedPlatform platform;

  final String? createRevision;

  String? baseRevision;

  bool equals(MigratePlatformConfig other) {
    return platform == other.platform &&
           createRevision == other.createRevision &&
           baseRevision == other.baseRevision;
  }
}