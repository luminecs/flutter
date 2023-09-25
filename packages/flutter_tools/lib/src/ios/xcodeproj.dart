
import 'package:file/memory.dart';
import 'package:meta/meta.dart';
import 'package:process/process.dart';

import '../base/common.dart';
import '../base/file_system.dart';
import '../base/io.dart';
import '../base/logger.dart';
import '../base/os.dart';
import '../base/platform.dart';
import '../base/process.dart';
import '../base/terminal.dart';
import '../base/utils.dart';
import '../base/version.dart';
import '../build_info.dart';
import '../reporting/reporting.dart';

final RegExp _settingExpr = RegExp(r'(\w+)\s*=\s*(.*)$');
final RegExp _varExpr = RegExp(r'\$\(([^)]*)\)');

class XcodeProjectInterpreter {
  factory XcodeProjectInterpreter({
    required Platform platform,
    required ProcessManager processManager,
    required Logger logger,
    required FileSystem fileSystem,
    required Usage usage,
  }) {
    return XcodeProjectInterpreter._(
      platform: platform,
      processManager: processManager,
      logger: logger,
      fileSystem: fileSystem,
      usage: usage,
    );
  }

  XcodeProjectInterpreter._({
    required Platform platform,
    required ProcessManager processManager,
    required Logger logger,
    required FileSystem fileSystem,
    required Usage usage,
    Version? version,
    String? build,
  }) : _platform = platform,
        _fileSystem = fileSystem,
        _logger = logger,
        _processUtils = ProcessUtils(logger: logger, processManager: processManager),
        _operatingSystemUtils = OperatingSystemUtils(
          fileSystem: fileSystem,
          logger: logger,
          platform: platform,
          processManager: processManager,
        ),
        _version = version,
        _build = build,
        _versionText = version?.toString(),
        _usage = usage;

  factory XcodeProjectInterpreter.test({
    required ProcessManager processManager,
    Version? version = const Version.withText(1000, 0, 0, '1000.0.0'),
    String? build = '13C100',
  }) {
    final Platform platform = FakePlatform(
      operatingSystem: 'macos',
      environment: <String, String>{},
    );
    return XcodeProjectInterpreter._(
      fileSystem: MemoryFileSystem.test(),
      platform: platform,
      processManager: processManager,
      usage: TestUsage(),
      logger: BufferLogger.test(),
      version: version,
      build: build,
    );
  }

  final Platform _platform;
  final FileSystem _fileSystem;
  final ProcessUtils _processUtils;
  final OperatingSystemUtils _operatingSystemUtils;
  final Logger _logger;
  final Usage _usage;
  static final RegExp _versionRegex = RegExp(r'Xcode ([0-9.]+).*Build version (\w+)');

  void _updateVersion() {
    if (!_platform.isMacOS || !_fileSystem.file('/usr/bin/xcodebuild').existsSync()) {
      return;
    }
    try {
      if (_versionText == null) {
        final RunResult result = _processUtils.runSync(
          <String>[...xcrunCommand(), 'xcodebuild', '-version'],
        );
        if (result.exitCode != 0) {
          return;
        }
        _versionText = result.stdout.trim().replaceAll('\n', ', ');
      }
      final Match? match = _versionRegex.firstMatch(versionText!);
      if (match == null) {
        return;
      }
      final String version = match.group(1)!;
      final List<String> components = version.split('.');
      final int majorVersion = int.parse(components[0]);
      final int minorVersion = components.length < 2 ? 0 : int.parse(components[1]);
      final int patchVersion = components.length < 3 ? 0 : int.parse(components[2]);
      _version = Version(majorVersion, minorVersion, patchVersion);
      _build = match.group(2);
    } on ProcessException {
      // Ignored, leave values null.
    }
  }

  bool get isInstalled => version != null;

  String? _versionText;
  String? get versionText {
    if (_versionText == null) {
      _updateVersion();
    }
    return _versionText;
  }

  Version? _version;
  String? _build;
  Version? get version {
    if (_version == null) {
      _updateVersion();
    }
    return _version;
  }

  String? get build {
    if (_build == null) {
      _updateVersion();
    }
    return _build;
  }

  List<String> xcrunCommand() {
    final List<String> xcrunCommand = <String>[];
    if (_operatingSystemUtils.hostPlatform == HostPlatform.darwin_arm64) {
      // Force Xcode commands to run outside Rosetta.
      xcrunCommand.addAll(<String>[
        '/usr/bin/arch',
        '-arm64e',
      ]);
    }
    xcrunCommand.add('xcrun');
    return xcrunCommand;
  }

  Future<Map<String, String>> getBuildSettings(
    String projectPath, {
    required XcodeProjectBuildContext buildContext,
    Duration timeout = const Duration(minutes: 1),
  }) async {
    final Status status = _logger.startSpinner();
    final String? scheme = buildContext.scheme;
    final String? configuration = buildContext.configuration;
    final String? target = buildContext.target;
    final String? deviceId = buildContext.deviceId;
    final List<String> showBuildSettingsCommand = <String>[
      ...xcrunCommand(),
      'xcodebuild',
      '-project',
      _fileSystem.path.absolute(projectPath),
      if (scheme != null)
        ...<String>['-scheme', scheme],
      if (configuration != null)
        ...<String>['-configuration', configuration],
      if (target != null)
        ...<String>['-target', target],
      if (buildContext.environmentType == EnvironmentType.simulator)
        ...<String>['-sdk', 'iphonesimulator'],
      '-destination',
      if (buildContext.isWatch && buildContext.environmentType == EnvironmentType.physical)
        'generic/platform=watchOS'
      else if (buildContext.isWatch)
        'generic/platform=watchOS Simulator'
      else if (deviceId != null)
        'id=$deviceId'
      else if (buildContext.environmentType == EnvironmentType.physical)
        'generic/platform=iOS'
      else
        'generic/platform=iOS Simulator',
      '-showBuildSettings',
      'BUILD_DIR=${_fileSystem.path.absolute(getIosBuildDirectory())}',
      ...environmentVariablesAsXcodeBuildSettings(_platform),
    ];
    try {
      // showBuildSettings is reported to occasionally timeout. Here, we give it
      // a lot of wiggle room (locally on Flutter Gallery, this takes ~1s).
      // When there is a timeout, we retry once.
      final RunResult result = await _processUtils.run(
        showBuildSettingsCommand,
        throwOnError: true,
        workingDirectory: projectPath,
        timeout: timeout,
        timeoutRetries: 1,
      );
      final String out = result.stdout.trim();
      return parseXcodeBuildSettings(out);
    } on Exception catch (error) {
      if (error is ProcessException && error.toString().contains('timed out')) {
        BuildEvent('xcode-show-build-settings-timeout',
          type: 'ios',
          command: showBuildSettingsCommand.join(' '),
          flutterUsage: _usage,
        ).send();
      }
      _logger.printTrace('Unexpected failure to get Xcode build settings: $error.');
      return const <String, String>{};
    } finally {
      status.stop();
    }
  }

  Future<String?> pluginsBuildSettingsOutput(
      Directory podXcodeProject, {
        Duration timeout = const Duration(minutes: 1),
      }) async {
    if (!podXcodeProject.existsSync()) {
      // No plugins.
      return null;
    }
    final Status status = _logger.startSpinner();
    final String buildDirectory = _fileSystem.path.absolute(getIosBuildDirectory());
    final List<String> showBuildSettingsCommand = <String>[
      ...xcrunCommand(),
      'xcodebuild',
      '-alltargets',
      '-sdk',
      'iphonesimulator',
      '-project',
      podXcodeProject.path,
      '-showBuildSettings',
      'BUILD_DIR=$buildDirectory',
      'OBJROOT=$buildDirectory',
    ];
    try {
      // showBuildSettings is reported to occasionally timeout. Here, we give it
      // a lot of wiggle room (locally on Flutter Gallery, this takes ~1s).
      // When there is a timeout, we retry once.
      final RunResult result = await _processUtils.run(
        showBuildSettingsCommand,
        throwOnError: true,
        workingDirectory: podXcodeProject.path,
        timeout: timeout,
        timeoutRetries: 1,
      );

      // Return the stdout only. Do not parse with parseXcodeBuildSettings, `-alltargets` prints the build settings
      // for all targets (one per plugin), so it would require a Map of Maps.
      return result.stdout.trim();
    } on Exception catch (error) {
      if (error is ProcessException && error.toString().contains('timed out')) {
        BuildEvent('xcode-show-build-settings-timeout',
          type: 'ios',
          command: showBuildSettingsCommand.join(' '),
          flutterUsage: _usage,
        ).send();
      }
      _logger.printTrace('Unexpected failure to get Pod Xcode project build settings: $error.');
      return null;
    } finally {
      status.stop();
    }
  }

  Future<void> cleanWorkspace(String workspacePath, String scheme, { bool verbose = false }) async {
    await _processUtils.run(<String>[
      ...xcrunCommand(),
      'xcodebuild',
      '-workspace',
      workspacePath,
      '-scheme',
      scheme,
      if (!verbose)
        '-quiet',
      'clean',
      ...environmentVariablesAsXcodeBuildSettings(_platform),
    ], workingDirectory: _fileSystem.currentDirectory.path);
  }

  Future<XcodeProjectInfo?> getInfo(String projectPath, {String? projectFilename}) async {
    // The exit code returned by 'xcodebuild -list' when either:
    // * -project is passed and the given project isn't there, or
    // * no -project is passed and there isn't a project.
    const int missingProjectExitCode = 66;
    // The exit code returned by 'xcodebuild -list' when the project is corrupted.
    const int corruptedProjectExitCode = 74;
    bool allowedFailures(int c) => c == missingProjectExitCode || c == corruptedProjectExitCode;
    final RunResult result = await _processUtils.run(
      <String>[
        ...xcrunCommand(),
        'xcodebuild',
        '-list',
        if (projectFilename != null) ...<String>['-project', projectFilename],
      ],
      throwOnError: true,
      allowedFailures: allowedFailures,
      workingDirectory: projectPath,
    );
    if (allowedFailures(result.exitCode)) {
      // User configuration error, tool exit instead of crashing.
      throwToolExit('Unable to get Xcode project information:\n ${result.stderr}');
    }
    return XcodeProjectInfo.fromXcodeBuildOutput(result.toString(), _logger);
  }
}

List<String> environmentVariablesAsXcodeBuildSettings(Platform platform) {
  const String xcodeBuildSettingPrefix = 'FLUTTER_XCODE_';
  return platform.environment.entries.where((MapEntry<String, String> mapEntry) {
    return mapEntry.key.startsWith(xcodeBuildSettingPrefix);
  }).expand<String>((MapEntry<String, String> mapEntry) {
    // Remove FLUTTER_XCODE_ prefix from the environment variable to get the build setting.
    final String trimmedBuildSettingKey = mapEntry.key.substring(xcodeBuildSettingPrefix.length);
    return <String>['$trimmedBuildSettingKey=${mapEntry.value}'];
  }).toList();
}

Map<String, String> parseXcodeBuildSettings(String showBuildSettingsOutput) {
  final Map<String, String> settings = <String, String>{};
  for (final Match? match in showBuildSettingsOutput.split('\n').map<Match?>(_settingExpr.firstMatch)) {
    if (match != null) {
      settings[match[1]!] = match[2]!;
    }
  }
  return settings;
}

String substituteXcodeVariables(String str, Map<String, String> xcodeBuildSettings) {
  final Iterable<Match> matches = _varExpr.allMatches(str);
  if (matches.isEmpty) {
    return str;
  }

  return str.replaceAllMapped(_varExpr, (Match m) => xcodeBuildSettings[m[1]!] ?? m[0]!);
}

@immutable
class XcodeProjectBuildContext {
  const XcodeProjectBuildContext({
    this.scheme,
    this.configuration,
    this.environmentType = EnvironmentType.physical,
    this.deviceId,
    this.target,
    this.isWatch = false,
  });

  final String? scheme;
  final String? configuration;
  final EnvironmentType environmentType;
  final String? deviceId;
  final String? target;
  final bool isWatch;

  @override
  int get hashCode => Object.hash(scheme, configuration, environmentType, deviceId, target);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) {
      return true;
    }
    return other is XcodeProjectBuildContext &&
        other.scheme == scheme &&
        other.configuration == configuration &&
        other.deviceId == deviceId &&
        other.environmentType == environmentType &&
        other.isWatch == isWatch &&
        other.target == target;
  }
}

class XcodeProjectInfo {
  const XcodeProjectInfo(
    this.targets,
    this.buildConfigurations,
    this.schemes,
    Logger logger
  ) : _logger = logger;

  factory XcodeProjectInfo.fromXcodeBuildOutput(String output, Logger logger) {
    final List<String> targets = <String>[];
    final List<String> buildConfigurations = <String>[];
    final List<String> schemes = <String>[];
    List<String>? collector;
    for (final String line in output.split('\n')) {
      if (line.isEmpty) {
        collector = null;
        continue;
      } else if (line.endsWith('Targets:')) {
        collector = targets;
        continue;
      } else if (line.endsWith('Build Configurations:')) {
        collector = buildConfigurations;
        continue;
      } else if (line.endsWith('Schemes:')) {
        collector = schemes;
        continue;
      }
      collector?.add(line.trim());
    }
    if (schemes.isEmpty) {
      schemes.add('Runner');
    }
    return XcodeProjectInfo(targets, buildConfigurations, schemes, logger);
  }

  final List<String> targets;
  final List<String> buildConfigurations;
  final List<String> schemes;
  final Logger _logger;

  bool get definesCustomSchemes => !(schemes.contains('Runner') && schemes.length == 1);

  @visibleForTesting
  static String expectedSchemeFor(BuildInfo? buildInfo) {
    return sentenceCase(buildInfo?.flavor ?? 'runner');
  }

  static String expectedBuildConfigurationFor(BuildInfo buildInfo, String scheme) {
    final String baseConfiguration = _baseConfigurationFor(buildInfo);
    if (buildInfo.flavor == null) {
      return baseConfiguration;
    }
    return '$baseConfiguration-$scheme';
  }

  bool hasBuildConfigurationForBuildMode(String buildMode) {
    buildMode = buildMode.toLowerCase();
    for (final String name in buildConfigurations) {
      if (name.toLowerCase() == buildMode) {
        return true;
      }
    }
    return false;
  }

  String? schemeFor(BuildInfo? buildInfo) {
    final String expectedScheme = expectedSchemeFor(buildInfo);
    if (schemes.contains(expectedScheme)) {
      return expectedScheme;
    }
    return _uniqueMatch(schemes, (String candidate) {
      return candidate.toLowerCase() == expectedScheme.toLowerCase();
    });
  }

  Never reportFlavorNotFoundAndExit() {
    _logger.printError('');
    if (definesCustomSchemes) {
      _logger.printError('The Xcode project defines schemes: ${schemes.join(', ')}');
      throwToolExit('You must specify a --flavor option to select one of the available schemes.');
    } else {
      throwToolExit('The Xcode project does not define custom schemes. You cannot use the --flavor option.');
    }
  }

  String? buildConfigurationFor(BuildInfo? buildInfo, String scheme) {
    if (buildInfo == null) {
      return null;
    }
    final String expectedConfiguration = expectedBuildConfigurationFor(buildInfo, scheme);
    if (hasBuildConfigurationForBuildMode(expectedConfiguration)) {
      return expectedConfiguration;
    }
    final String baseConfiguration = _baseConfigurationFor(buildInfo);
    return _uniqueMatch(buildConfigurations, (String candidate) {
      candidate = candidate.toLowerCase();
      if (buildInfo.flavor == null) {
        return candidate == expectedConfiguration.toLowerCase();
      }
      return candidate.contains(baseConfiguration.toLowerCase()) && candidate.contains(scheme.toLowerCase());
    });
  }

  static String _baseConfigurationFor(BuildInfo buildInfo) {
    if (buildInfo.isDebug) {
      return 'Debug';
    }
    if (buildInfo.isProfile) {
      return 'Profile';
    }
    return 'Release';
  }

  static String? _uniqueMatch(Iterable<String> strings, bool Function(String s) matches) {
    final List<String> options = strings.where(matches).toList();
    if (options.length == 1) {
      return options.first;
    }
    return null;
  }

  @override
  String toString() {
    return 'XcodeProjectInfo($targets, $buildConfigurations, $schemes)';
  }
}