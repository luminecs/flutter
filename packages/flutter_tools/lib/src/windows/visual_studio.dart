import 'package:meta/meta.dart';
import 'package:process/process.dart';

import '../base/common.dart';
import '../base/file_system.dart';
import '../base/io.dart';
import '../base/logger.dart';
import '../base/platform.dart';
import '../base/process.dart';
import '../base/version.dart';
import '../convert.dart';

class VisualStudio {
  VisualStudio({
    required FileSystem fileSystem,
    required ProcessManager processManager,
    required Platform platform,
    required Logger logger,
  })  : _platform = platform,
        _fileSystem = fileSystem,
        _processUtils =
            ProcessUtils(processManager: processManager, logger: logger),
        _logger = logger;

  final FileSystem _fileSystem;
  final Platform _platform;
  final ProcessUtils _processUtils;
  final Logger _logger;

  final RegExp _vswhereDescriptionProperty =
      RegExp(r'\s*"description"\s*:\s*".*"\s*,?');

  bool get isInstalled => _bestVisualStudioDetails != null;

  bool get isAtLeastMinimumVersion {
    final int? installedMajorVersion = _majorVersion;
    return installedMajorVersion != null &&
        installedMajorVersion >= _minimumSupportedVersion;
  }

  bool get hasNecessaryComponents =>
      _bestVisualStudioDetails?.isUsable ?? false;

  String? get displayName => _bestVisualStudioDetails?.displayName;

  String? get displayVersion => _bestVisualStudioDetails?.catalogDisplayVersion;

  String? get installLocation => _bestVisualStudioDetails?.installationPath;

  String? get fullVersion => _bestVisualStudioDetails?.fullVersion;

  // Properties that determine the status of the installation. There might be
  // Visual Studio versions that don't include them, so default to a "valid" value to
  // avoid false negatives.

  bool get isComplete {
    if (_bestVisualStudioDetails == null) {
      return false;
    }
    return _bestVisualStudioDetails.isComplete ?? true;
  }

  bool get isLaunchable {
    if (_bestVisualStudioDetails == null) {
      return false;
    }
    return _bestVisualStudioDetails.isLaunchable ?? true;
  }

  bool get isPrerelease => _bestVisualStudioDetails?.isPrerelease ?? false;

  bool get isRebootRequired =>
      _bestVisualStudioDetails?.isRebootRequired ?? false;

  String get workloadDescription => 'Desktop development with C++';

  String? getWindows10SDKVersion() {
    final String? sdkLocation = _getWindows10SdkLocation();
    if (sdkLocation == null) {
      return null;
    }
    final Directory sdkIncludeDirectory =
        _fileSystem.directory(sdkLocation).childDirectory('Include');
    if (!sdkIncludeDirectory.existsSync()) {
      return null;
    }
    // The directories in this folder are named by the SDK version.
    Version? highestVersion;
    for (final FileSystemEntity versionEntry
        in sdkIncludeDirectory.listSync()) {
      if (versionEntry.basename.startsWith('10.')) {
        // Version only handles 3 components; strip off the '10.' to leave three
        // components, since they all start with that.
        final Version? version =
            Version.parse(versionEntry.basename.substring(3));
        if (highestVersion == null ||
            (version != null && version > highestVersion)) {
          highestVersion = version;
        }
      }
    }
    if (highestVersion == null) {
      return null;
    }
    return '10.$highestVersion';
  }

  List<String> necessaryComponentDescriptions() {
    return _requiredComponents().values.toList();
  }

  String get minimumVersionDescription {
    return '2019';
  }

  String? get cmakePath {
    final VswhereDetails? details = _bestVisualStudioDetails;
    if (details == null ||
        !details.isUsable ||
        details.installationPath == null) {
      return null;
    }

    return _fileSystem.path.joinAll(<String>[
      details.installationPath!,
      'Common7',
      'IDE',
      'CommonExtensions',
      'Microsoft',
      'CMake',
      'CMake',
      'bin',
      'cmake.exe',
    ]);
  }

  String? get cmakeGenerator {
    // From https://cmake.org/cmake/help/v3.22/manual/cmake-generators.7.html#visual-studio-generators
    switch (_majorVersion) {
      case 17:
        return 'Visual Studio 17 2022';
      case 16:
      default:
        return 'Visual Studio 16 2019';
    }
  }

  int? get _majorVersion =>
      fullVersion != null ? int.tryParse(fullVersion!.split('.')[0]) : null;

  String get _vswherePath {
    const String programFilesEnv = 'PROGRAMFILES(X86)';
    if (!_platform.environment.containsKey(programFilesEnv)) {
      throwToolExit('%$programFilesEnv% environment variable not found.');
    }
    return _fileSystem.path.join(
      _platform.environment[programFilesEnv]!,
      'Microsoft Visual Studio',
      'Installer',
      'vswhere.exe',
    );
  }

  static const List<String> _requiredWorkloads = <String>[
    'Microsoft.VisualStudio.Workload.NativeDesktop',
    'Microsoft.VisualStudio.Workload.VCTools',
  ];

  Map<String, String> _requiredComponents([int? majorVersion]) {
    // The description of the C++ toolchain required by the template. The
    // component name is significantly different in different versions.
    // When a new major version of VS is supported, its toolchain description
    // should be added below. It should also be made the default, so that when
    // there is no installation, the message shows the string that will be
    // relevant for the most likely fresh install case).
    String cppToolchainDescription;
    switch (majorVersion ?? _majorVersion) {
      case 16:
      default:
        cppToolchainDescription = 'MSVC v142 - VS 2019 C++ x64/x86 build tools';
    }
    // The 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64' ID is assigned to the latest
    // release of the toolchain, and there can be minor updates within a given version of
    // Visual Studio. Since it changes over time, listing a precise version would become
    // wrong after each VC++ toolchain update, so just instruct people to install the
    // latest version.
    cppToolchainDescription +=
        '\n   - If there are multiple build tool versions available, install the latest';
    // Things which are required by the workload (e.g., MSBuild) don't need to
    // be included here.
    return <String, String>{
      // The C++ toolchain required by the template.
      'Microsoft.VisualStudio.Component.VC.Tools.x86.x64':
          cppToolchainDescription,
      // CMake
      'Microsoft.VisualStudio.Component.VC.CMake.Project':
          'C++ CMake tools for Windows',
    };
  }

  static const int _minimumSupportedVersion = 16; // '16' is VS 2019.

  static const String _vswhereMinVersionArgument = '-version';

  static const String _vswherePrereleaseArgument = '-prerelease';

  static const String _windows10SdkRegistryPath =
      r'HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432Node\Microsoft\Microsoft SDKs\Windows\v10.0';

  static const String _windows10SdkRegistryKey = 'InstallationFolder';

  VswhereDetails? _visualStudioDetails(
      {bool validateRequirements = false,
      List<String>? additionalArguments,
      String? requiredWorkload}) {
    final List<String> requirementArguments = validateRequirements
        ? <String>[
            if (requiredWorkload != null) ...<String>[
              '-requires',
              requiredWorkload,
            ],
            ..._requiredComponents(_minimumSupportedVersion).keys,
          ]
        : <String>[];
    try {
      final List<String> defaultArguments = <String>[
        '-format',
        'json',
        '-products',
        '*',
        '-utf8',
        '-latest',
      ];
      // Ignore replacement characters as vswhere.exe is known to output them.
      // See: https://github.com/flutter/flutter/issues/102451
      const Encoding encoding = Utf8Codec(reportErrors: false);
      final RunResult whereResult = _processUtils.runSync(<String>[
        _vswherePath,
        ...defaultArguments,
        ...?additionalArguments,
        ...requirementArguments,
      ], encoding: encoding);
      if (whereResult.exitCode == 0) {
        final List<Map<String, dynamic>>? installations =
            _tryDecodeVswhereJson(whereResult.stdout);
        if (installations != null && installations.isNotEmpty) {
          return VswhereDetails.fromJson(
              validateRequirements, installations[0]);
        }
      }
    } on ArgumentError {
      // Thrown if vswhere doesn't exist; ignore and return null below.
    } on ProcessException {
      // Ignored, return null below.
    }
    return null;
  }

  List<Map<String, dynamic>>? _tryDecodeVswhereJson(String vswhereJson) {
    List<dynamic>? result;
    FormatException? originalError;
    try {
      // Some versions of vswhere.exe are known to encode their output incorrectly,
      // resulting in invalid JSON in the 'description' property when interpreted
      // as UTF-8. First, try to decode without any pre-processing.
      try {
        result = json.decode(vswhereJson) as List<dynamic>;
      } on FormatException catch (error) {
        // If that fails, remove the 'description' property and try again.
        // See: https://github.com/flutter/flutter/issues/106601
        vswhereJson = vswhereJson.replaceFirst(_vswhereDescriptionProperty, '');

        _logger.printTrace('Failed to decode vswhere.exe JSON output. $error'
            'Retrying after removing the unused description property:\n$vswhereJson');

        originalError = error;
        result = json.decode(vswhereJson) as List<dynamic>;
      }
    } on FormatException {
      // Removing the description property didn't help.
      // Report the original decoding error on the unprocessed JSON.
      _logger.printWarning(
          'Warning: Unexpected vswhere.exe JSON output. $originalError'
          'To see the full JSON, run flutter doctor -vv.');
      return null;
    }

    return result.cast<Map<String, dynamic>>();
  }

  late final VswhereDetails? _bestVisualStudioDetails = () {
    // First, attempt to find the latest version of Visual Studio that satisfies
    // both the minimum supported version and the required workloads.
    // Check in the order of stable VS, stable BT, pre-release VS, pre-release BT.
    final List<String> minimumVersionArguments = <String>[
      _vswhereMinVersionArgument,
      _minimumSupportedVersion.toString(),
    ];
    for (final bool checkForPrerelease in <bool>[false, true]) {
      for (final String requiredWorkload in _requiredWorkloads) {
        final VswhereDetails? result = _visualStudioDetails(
            validateRequirements: true,
            additionalArguments: checkForPrerelease
                ? <String>[
                    ...minimumVersionArguments,
                    _vswherePrereleaseArgument
                  ]
                : minimumVersionArguments,
            requiredWorkload: requiredWorkload);

        if (result != null) {
          return result;
        }
      }
    }

    // An installation that satisfies requirements could not be found.
    // Fallback to the latest Visual Studio installation.
    return _visualStudioDetails(
        additionalArguments: <String>[_vswherePrereleaseArgument, '-all']);
  }();

  String? _getWindows10SdkLocation() {
    try {
      final RunResult result = _processUtils.runSync(<String>[
        'reg',
        'query',
        _windows10SdkRegistryPath,
        '/v',
        _windows10SdkRegistryKey,
      ]);
      if (result.exitCode == 0) {
        final RegExp pattern = RegExp(r'InstallationFolder\s+REG_SZ\s+(.+)');
        final RegExpMatch? match = pattern.firstMatch(result.stdout);
        if (match != null) {
          return match.group(1)!.trim();
        }
      }
    } on ArgumentError {
      // Thrown if reg somehow doesn't exist; ignore and return null below.
    } on ProcessException {
      // Ignored, return null below.
    }
    return null;
  }

  String? findHighestVersionInSdkDirectory(Directory dir) {
    // This contains subfolders that are named by the SDK version.
    final Directory includeDir = dir.childDirectory('Includes');
    if (!includeDir.existsSync()) {
      return null;
    }
    Version? highestVersion;
    for (final FileSystemEntity versionEntry in includeDir.listSync()) {
      if (!versionEntry.basename.startsWith('10.')) {
        continue;
      }
      // Version only handles 3 components; strip off the '10.' to leave three
      // components, since they all start with that.
      final Version? version =
          Version.parse(versionEntry.basename.substring(3));
      if (highestVersion == null ||
          (version != null && version > highestVersion)) {
        highestVersion = version;
      }
    }
    // Re-add the leading '10.' that was removed for comparison.
    return highestVersion == null ? null : '10.$highestVersion';
  }
}

@visibleForTesting
class VswhereDetails {
  const VswhereDetails({
    required this.meetsRequirements,
    required this.installationPath,
    required this.displayName,
    required this.fullVersion,
    required this.isComplete,
    required this.isLaunchable,
    required this.isRebootRequired,
    required this.isPrerelease,
    required this.catalogDisplayVersion,
  });

  factory VswhereDetails.fromJson(
      bool meetsRequirements, Map<String, dynamic> details) {
    final Map<String, dynamic>? catalog =
        details['catalog'] as Map<String, dynamic>?;

    return VswhereDetails(
      meetsRequirements: meetsRequirements,
      isComplete: details['isComplete'] as bool?,
      isLaunchable: details['isLaunchable'] as bool?,
      isRebootRequired: details['isRebootRequired'] as bool?,
      isPrerelease: details['isPrerelease'] as bool?,

      // Below are strings that must be well-formed without replacement characters.
      installationPath: _validateString(details['installationPath'] as String?),
      fullVersion: _validateString(details['installationVersion'] as String?),

      // Below are strings that are used only for display purposes and are allowed to
      // contain replacement characters.
      displayName: details['displayName'] as String?,
      catalogDisplayVersion:
          catalog == null ? null : catalog['productDisplayVersion'] as String?,
    );
  }

  static String? _validateString(String? value) {
    if (value != null && value.contains('\u{FFFD}')) {
      throwToolExit(
          'Bad UTF-8 encoding (U+FFFD; REPLACEMENT CHARACTER) found in string: $value. '
          'The Flutter team would greatly appreciate if you could file a bug explaining '
          'exactly what you were doing when this happened:\n'
          'https://github.com/flutter/flutter/issues/new/choose\n');
    }

    return value;
  }

  final bool meetsRequirements;

  final String? installationPath;

  final String? displayName;

  final String? fullVersion;

  final bool? isComplete;
  final bool? isLaunchable;
  final bool? isRebootRequired;

  final bool? isPrerelease;

  final String? catalogDisplayVersion;

  bool get isUsable {
    if (!meetsRequirements) {
      return false;
    }

    if (!(isComplete ?? true)) {
      return false;
    }

    if (!(isLaunchable ?? true)) {
      return false;
    }

    if (isRebootRequired ?? false) {
      return false;
    }

    return true;
  }
}
