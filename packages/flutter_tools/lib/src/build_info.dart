// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:package_config/package_config_types.dart';

import 'artifacts.dart';
import 'base/config.dart';
import 'base/file_system.dart';
import 'base/logger.dart';
import 'base/os.dart';
import 'base/utils.dart';
import 'convert.dart';
import 'globals.dart' as globals;
import 'web/compile.dart';

const bool kIconTreeShakerEnabledDefault = true;

class BuildInfo {
  const BuildInfo(
    this.mode,
    this.flavor, {
    this.trackWidgetCreation = false,
    this.frontendServerStarterPath,
    List<String>? extraFrontEndOptions,
    List<String>? extraGenSnapshotOptions,
    List<String>? fileSystemRoots,
    this.androidProjectArgs = const <String>[],
    this.fileSystemScheme,
    this.buildNumber,
    this.buildName,
    this.splitDebugInfoPath,
    this.dartObfuscation = false,
    List<String>? dartDefines,
    this.bundleSkSLPath,
    List<String>? dartExperiments,
    this.webRenderer = WebRendererMode.auto,
    required this.treeShakeIcons,
    this.performanceMeasurementFile,
    this.dartDefineConfigJsonMap = const <String, Object?>{},
    this.packagesPath = '.dart_tool/package_config.json', // TODO(zanderso): make this required and remove the default.
    this.nullSafetyMode = NullSafetyMode.sound,
    this.codeSizeDirectory,
    this.androidGradleDaemon = true,
    this.packageConfig = PackageConfig.empty,
    this.initializeFromDill,
    this.assumeInitializeFromDillUpToDate = false,
    this.buildNativeAssets = true,
  }) : extraFrontEndOptions = extraFrontEndOptions ?? const <String>[],
       extraGenSnapshotOptions = extraGenSnapshotOptions ?? const <String>[],
       fileSystemRoots = fileSystemRoots ?? const <String>[],
       dartDefines = dartDefines ?? const <String>[],
       dartExperiments = dartExperiments ?? const <String>[];

  final BuildMode mode;

  final NullSafetyMode nullSafetyMode;

  final bool treeShakeIcons;

  final String? flavor;

  final String packagesPath;

  final List<String> fileSystemRoots;
  final String? fileSystemScheme;

  final bool trackWidgetCreation;

  final String? frontendServerStarterPath;

  final List<String> extraFrontEndOptions;

  final List<String> extraGenSnapshotOptions;

  final String? buildNumber;

  final String? buildName;

  final String? splitDebugInfoPath;

  final bool dartObfuscation;

  final String? bundleSkSLPath;

  final List<String> dartDefines;

  final List<String> dartExperiments;

  final WebRendererMode webRenderer;

  final String? performanceMeasurementFile;

  final Map<String, Object?> dartDefineConfigJsonMap;

  final String? codeSizeDirectory;

  final bool androidGradleDaemon;

  final List<String> androidProjectArgs;

  final PackageConfig packageConfig;

  final String? initializeFromDill;

  final bool assumeInitializeFromDillUpToDate;

  final bool buildNativeAssets;

  static const BuildInfo debug = BuildInfo(BuildMode.debug, null, trackWidgetCreation: true, treeShakeIcons: false);
  static const BuildInfo profile = BuildInfo(BuildMode.profile, null, treeShakeIcons: kIconTreeShakerEnabledDefault);
  static const BuildInfo jitRelease = BuildInfo(BuildMode.jitRelease, null, treeShakeIcons: kIconTreeShakerEnabledDefault);
  static const BuildInfo release = BuildInfo(BuildMode.release, null, treeShakeIcons: kIconTreeShakerEnabledDefault);

  bool get isDebug => mode == BuildMode.debug;

  bool get isProfile => mode == BuildMode.profile;

  bool get isRelease => mode == BuildMode.release;

  bool get isJitRelease => mode == BuildMode.jitRelease;

  bool get usesAot => isAotBuildMode(mode);
  bool get supportsEmulator => isEmulatorBuildMode(mode);
  bool get supportsSimulator => isEmulatorBuildMode(mode);
  String get modeName => mode.cliName;
  String get friendlyModeName => getFriendlyModeName(mode);

  String? get lowerCasedFlavor => flavor?.toLowerCase();

  String? get uncapitalizedFlavor => _uncapitalize(flavor);

  Map<String, String> toBuildSystemEnvironment() {
    // packagesPath and performanceMeasurementFile are not passed into
    // the Environment map.
    return <String, String>{
      kBuildMode: mode.cliName,
      if (dartDefines.isNotEmpty)
        kDartDefines: encodeDartDefines(dartDefines),
      kDartObfuscation: dartObfuscation.toString(),
      if (frontendServerStarterPath != null)
        kFrontendServerStarterPath: frontendServerStarterPath!,
      if (extraFrontEndOptions.isNotEmpty)
        kExtraFrontEndOptions: extraFrontEndOptions.join(','),
      if (extraGenSnapshotOptions.isNotEmpty)
        kExtraGenSnapshotOptions: extraGenSnapshotOptions.join(','),
      if (splitDebugInfoPath != null)
        kSplitDebugInfo: splitDebugInfoPath!,
      kTrackWidgetCreation: trackWidgetCreation.toString(),
      kIconTreeShakerFlag: treeShakeIcons.toString(),
      if (bundleSkSLPath != null)
        kBundleSkSLPath: bundleSkSLPath!,
      if (codeSizeDirectory != null)
        kCodeSizeDirectory: codeSizeDirectory!,
      if (fileSystemRoots.isNotEmpty)
        kFileSystemRoots: fileSystemRoots.join(','),
      if (fileSystemScheme != null)
        kFileSystemScheme: fileSystemScheme!,
      if (buildName != null)
        kBuildName: buildName!,
      if (buildNumber != null)
        kBuildNumber: buildNumber!,
    };
  }


  Map<String, String> toEnvironmentConfig() {
    final Map<String, String> map = <String, String>{};
    dartDefineConfigJsonMap.forEach((String key, Object? value) {
      map[key] = '$value';
    });
    final Map<String, String> environmentMap = <String, String>{
      if (dartDefines.isNotEmpty)
        'DART_DEFINES': encodeDartDefines(dartDefines),
      'DART_OBFUSCATION': dartObfuscation.toString(),
      if (frontendServerStarterPath != null)
        'FRONTEND_SERVER_STARTER_PATH': frontendServerStarterPath!,
      if (extraFrontEndOptions.isNotEmpty)
        'EXTRA_FRONT_END_OPTIONS': extraFrontEndOptions.join(','),
      if (extraGenSnapshotOptions.isNotEmpty)
        'EXTRA_GEN_SNAPSHOT_OPTIONS': extraGenSnapshotOptions.join(','),
      if (splitDebugInfoPath != null)
        'SPLIT_DEBUG_INFO': splitDebugInfoPath!,
      'TRACK_WIDGET_CREATION': trackWidgetCreation.toString(),
      'TREE_SHAKE_ICONS': treeShakeIcons.toString(),
      if (performanceMeasurementFile != null)
        'PERFORMANCE_MEASUREMENT_FILE': performanceMeasurementFile!,
      if (bundleSkSLPath != null)
        'BUNDLE_SKSL_PATH': bundleSkSLPath!,
      'PACKAGE_CONFIG': packagesPath,
      if (codeSizeDirectory != null)
        'CODE_SIZE_DIRECTORY': codeSizeDirectory!,
    };
    map.forEach((String key, String value) {
      if (environmentMap.containsKey(key)) {
        globals.printWarning(
            'The key: [$key] already exists, you cannot use environment variables that have been used by the system!');
      } else {
        // System priority is greater than user priority
        environmentMap[key] = value;
      }
    });
    return environmentMap;
  }

  List<String> toGradleConfig() {
    // PACKAGE_CONFIG not currently supported.
    final List<String> result = <String>[
      if (dartDefines.isNotEmpty)
        '-Pdart-defines=${encodeDartDefines(dartDefines)}',
      '-Pdart-obfuscation=$dartObfuscation',
      if (frontendServerStarterPath != null)
        '-Pfrontend-server-starter-path=$frontendServerStarterPath',
      if (extraFrontEndOptions.isNotEmpty)
        '-Pextra-front-end-options=${extraFrontEndOptions.join(',')}',
      if (extraGenSnapshotOptions.isNotEmpty)
        '-Pextra-gen-snapshot-options=${extraGenSnapshotOptions.join(',')}',
      if (splitDebugInfoPath != null)
        '-Psplit-debug-info=$splitDebugInfoPath',
      '-Ptrack-widget-creation=$trackWidgetCreation',
      '-Ptree-shake-icons=$treeShakeIcons',
      if (performanceMeasurementFile != null)
        '-Pperformance-measurement-file=$performanceMeasurementFile',
      if (bundleSkSLPath != null)
        '-Pbundle-sksl-path=$bundleSkSLPath',
      if (codeSizeDirectory != null)
        '-Pcode-size-directory=$codeSizeDirectory',
      for (final String projectArg in androidProjectArgs)
        '-P$projectArg',
    ];
    final Iterable<String> gradleConfKeys = result.map((final String gradleConf) => gradleConf.split('=')[0].substring(2));
    dartDefineConfigJsonMap.forEach((String key, Object? value) {
      if (gradleConfKeys.contains(key)) {
        globals.printWarning(
            'The key: [$key] already exists, you cannot use gradle variables that have been used by the system!');
      } else {
        result.add('-P$key=$value');
      }
    });
    return result;
  }
}

class AndroidBuildInfo {
  const AndroidBuildInfo(
    this.buildInfo, {
    this.targetArchs = const <AndroidArch>[
      AndroidArch.armeabi_v7a,
      AndroidArch.arm64_v8a,
      AndroidArch.x86_64,
    ],
    this.splitPerAbi = false,
    this.fastStart = false,
    this.multidexEnabled = false,
  });

  // The build info containing the mode and flavor.
  final BuildInfo buildInfo;

  final bool splitPerAbi;

  final Iterable<AndroidArch> targetArchs;

  final bool fastStart;

  final bool multidexEnabled;
}

enum BuildMode {
  debug,

  profile,

  release,

  jitRelease;

  factory BuildMode.fromCliName(String value) => values.singleWhere(
        (BuildMode element) => element.cliName == value,
        orElse: () =>
            throw ArgumentError('$value is not a supported build mode'),
      );

  static const Set<BuildMode> releaseModes = <BuildMode>{
    release,
    jitRelease,
  };
  static const Set<BuildMode> jitModes = <BuildMode>{
    debug,
    jitRelease,
  };

  bool get isRelease => releaseModes.contains(this);

  bool get isJit => jitModes.contains(this);

  bool get isPrecompiled => !isJit;

  String get cliName => snakeCase(name);

  @override
  String toString() => cliName;
}

enum EnvironmentType {
  physical,
  simulator,
}

String? validatedBuildNumberForPlatform(TargetPlatform targetPlatform, String? buildNumber, Logger logger) {
  if (buildNumber == null) {
    return null;
  }
  if (targetPlatform == TargetPlatform.ios ||
      targetPlatform == TargetPlatform.darwin) {
    // See CFBundleVersion at https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html
    final RegExp disallowed = RegExp(r'[^\d\.]');
    String tmpBuildNumber = buildNumber.replaceAll(disallowed, '');
    if (tmpBuildNumber.isEmpty) {
      return null;
    }
    final List<String> segments = tmpBuildNumber
        .split('.')
        .where((String segment) => segment.isNotEmpty)
        .toList();
    if (segments.isEmpty) {
      segments.add('0');
    }
    tmpBuildNumber = segments.join('.');
    if (tmpBuildNumber != buildNumber) {
      logger.printTrace('Invalid build-number: $buildNumber for iOS/macOS, overridden by $tmpBuildNumber.\n'
          'See CFBundleVersion at https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html');
    }
    return tmpBuildNumber;
  }
  if (targetPlatform == TargetPlatform.android_arm ||
      targetPlatform == TargetPlatform.android_arm64 ||
      targetPlatform == TargetPlatform.android_x64 ||
      targetPlatform == TargetPlatform.android_x86) {
    // See versionCode at https://developer.android.com/studio/publish/versioning
    final RegExp disallowed = RegExp(r'[^\d]');
    String tmpBuildNumberStr = buildNumber.replaceAll(disallowed, '');
    int tmpBuildNumberInt = int.tryParse(tmpBuildNumberStr) ?? 0;
    if (tmpBuildNumberInt < 1) {
      tmpBuildNumberInt = 1;
    }
    tmpBuildNumberStr = tmpBuildNumberInt.toString();
    if (tmpBuildNumberStr != buildNumber) {
      logger.printTrace('Invalid build-number: $buildNumber for Android, overridden by $tmpBuildNumberStr.\n'
          'See versionCode at https://developer.android.com/studio/publish/versioning');
    }
    return tmpBuildNumberStr;
  }
  return buildNumber;
}

String? validatedBuildNameForPlatform(TargetPlatform targetPlatform, String? buildName, Logger logger) {
  if (buildName == null) {
    return null;
  }
  if (targetPlatform == TargetPlatform.ios ||
      targetPlatform == TargetPlatform.darwin) {
    // See CFBundleShortVersionString at https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html
    final RegExp disallowed = RegExp(r'[^\d\.]');
    String tmpBuildName = buildName.replaceAll(disallowed, '');
    if (tmpBuildName.isEmpty) {
      return null;
    }
    final List<String> segments = tmpBuildName
        .split('.')
        .where((String segment) => segment.isNotEmpty)
        .toList();
    while (segments.length < 3) {
      segments.add('0');
    }
    tmpBuildName = segments.join('.');
    if (tmpBuildName != buildName) {
      logger.printTrace('Invalid build-name: $buildName for iOS/macOS, overridden by $tmpBuildName.\n'
          'See CFBundleShortVersionString at https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html');
    }
    return tmpBuildName;
  }
  if (targetPlatform == TargetPlatform.android ||
      targetPlatform == TargetPlatform.android_arm ||
      targetPlatform == TargetPlatform.android_arm64 ||
      targetPlatform == TargetPlatform.android_x64 ||
      targetPlatform == TargetPlatform.android_x86) {
    // See versionName at https://developer.android.com/studio/publish/versioning
    return buildName;
  }
  return buildName;
}

String getFriendlyModeName(BuildMode mode) {
  return snakeCase(mode.cliName).replaceAll('_', ' ');
}

// Returns true if the selected build mode uses ahead-of-time compilation.
bool isAotBuildMode(BuildMode mode) {
  return mode == BuildMode.profile || mode == BuildMode.release;
}

// Returns true if the given build mode can be used on emulators / simulators.
bool isEmulatorBuildMode(BuildMode mode) {
  return mode == BuildMode.debug;
}

enum TargetPlatform {
  android,
  ios,
  darwin,
  linux_x64,
  linux_arm64,
  windows_x64,
  fuchsia_arm64,
  fuchsia_x64,
  tester,
  web_javascript,
  // The arch specific android target platforms are soft-deprecated.
  // Instead of using TargetPlatform as a combination arch + platform
  // the code will be updated to carry arch information in [DarwinArch]
  // and [AndroidArch].
  android_arm,
  android_arm64,
  android_x64,
  android_x86;

  String get fuchsiaArchForTargetPlatform {
    switch (this) {
      case TargetPlatform.fuchsia_arm64:
        return 'arm64';
      case TargetPlatform.fuchsia_x64:
        return 'x64';
      case TargetPlatform.android:
      case TargetPlatform.android_arm:
      case TargetPlatform.android_arm64:
      case TargetPlatform.android_x64:
      case TargetPlatform.android_x86:
      case TargetPlatform.darwin:
      case TargetPlatform.ios:
      case TargetPlatform.linux_arm64:
      case TargetPlatform.linux_x64:
      case TargetPlatform.tester:
      case TargetPlatform.web_javascript:
      case TargetPlatform.windows_x64:
        throw UnsupportedError('Unexpected Fuchsia platform $this');
    }
  }

  String get simpleName {
    switch (this) {
      case TargetPlatform.linux_x64:
      case TargetPlatform.darwin:
      case TargetPlatform.windows_x64:
        return 'x64';
      case TargetPlatform.linux_arm64:
        return 'arm64';
      case TargetPlatform.android:
      case TargetPlatform.android_arm:
      case TargetPlatform.android_arm64:
      case TargetPlatform.android_x64:
      case TargetPlatform.android_x86:
      case TargetPlatform.fuchsia_arm64:
      case TargetPlatform.fuchsia_x64:
      case TargetPlatform.ios:
      case TargetPlatform.tester:
      case TargetPlatform.web_javascript:
        throw UnsupportedError('Unexpected target platform $this');
    }
  }
}

//
// TODO(cbracken): split TargetPlatform.ios into ios_armv7, ios_arm64.
enum DarwinArch {
  armv7, // Deprecated. Used to display 32-bit unsupported devices.
  arm64,
  x86_64;

  String get dartName {
    return switch (this) {
      DarwinArch.armv7 => 'armv7',
      DarwinArch.arm64 => 'arm64',
      DarwinArch.x86_64 => 'x64'
    };
  }
}

// TODO(zanderso): replace all android TargetPlatform usage with AndroidArch.
enum AndroidArch {
  armeabi_v7a,
  arm64_v8a,
  x86,
  x86_64;

  String get archName {
    return switch (this) {
      AndroidArch.armeabi_v7a => 'armeabi-v7a',
      AndroidArch.arm64_v8a => 'arm64-v8a',
      AndroidArch.x86_64 => 'x86_64',
      AndroidArch.x86 => 'x86'
    };
  }

  String get platformName {
    return switch (this) {
      AndroidArch.armeabi_v7a => 'android-arm',
      AndroidArch.arm64_v8a => 'android-arm64',
      AndroidArch.x86_64 => 'android-x64',
      AndroidArch.x86 => 'android-x86'
    };
  }
}

List<DarwinArch> defaultIOSArchsForEnvironment(
  EnvironmentType environmentType,
  Artifacts artifacts,
) {
  // Handle single-arch local engines.
  final LocalEngineInfo? localEngineInfo = artifacts.localEngineInfo;
  if (localEngineInfo != null) {
    final String localEngineName = localEngineInfo.localTargetName;
    if (localEngineName.contains('_arm64')) {
      return <DarwinArch>[ DarwinArch.arm64 ];
    }
    if (localEngineName.contains('_sim')) {
      return <DarwinArch>[ DarwinArch.x86_64 ];
    }
  } else if (environmentType == EnvironmentType.simulator) {
    return <DarwinArch>[
      DarwinArch.x86_64,
      DarwinArch.arm64,
    ];
  }
  return <DarwinArch>[
    DarwinArch.arm64,
  ];
}

List<DarwinArch> defaultMacOSArchsForEnvironment(Artifacts artifacts) {
  // Handle single-arch local engines.
  final LocalEngineInfo? localEngineInfo = artifacts.localEngineInfo;
  if (localEngineInfo != null) {
    if (localEngineInfo.localTargetName.contains('_arm64')) {
      return <DarwinArch>[ DarwinArch.arm64 ];
    }
    return <DarwinArch>[ DarwinArch.x86_64 ];
  }
  return <DarwinArch>[
    DarwinArch.x86_64,
    DarwinArch.arm64,
  ];
}

DarwinArch getIOSArchForName(String arch) {
  switch (arch) {
    case 'armv7':
    case 'armv7f': // iPhone 4S.
    case 'armv7s': // iPad 4.
      return DarwinArch.armv7;
    case 'arm64':
    case 'arm64e': // iPhone XS/XS Max/XR and higher. arm64 runs on arm64e devices.
      return DarwinArch.arm64;
    case 'x86_64':
      return DarwinArch.x86_64;
  }
  throw Exception('Unsupported iOS arch name "$arch"');
}

DarwinArch getDarwinArchForName(String arch) {
  switch (arch) {
    case 'arm64':
      return DarwinArch.arm64;
    case 'x86_64':
      return DarwinArch.x86_64;
  }
  throw Exception('Unsupported MacOS arch name "$arch"');
}

String getNameForTargetPlatform(TargetPlatform platform, {DarwinArch? darwinArch}) {
  switch (platform) {
    case TargetPlatform.android_arm:
      return 'android-arm';
    case TargetPlatform.android_arm64:
      return 'android-arm64';
    case TargetPlatform.android_x64:
      return 'android-x64';
    case TargetPlatform.android_x86:
      return 'android-x86';
    case TargetPlatform.ios:
      if (darwinArch != null) {
        return 'ios-${darwinArch.name}';
      }
      return 'ios';
    case TargetPlatform.darwin:
      if (darwinArch != null) {
        return 'darwin-${darwinArch.name}';
      }
      return 'darwin';
    case TargetPlatform.linux_x64:
      return 'linux-x64';
    case TargetPlatform.linux_arm64:
      return 'linux-arm64';
    case TargetPlatform.windows_x64:
      return 'windows-x64';
    case TargetPlatform.fuchsia_arm64:
      return 'fuchsia-arm64';
    case TargetPlatform.fuchsia_x64:
      return 'fuchsia-x64';
    case TargetPlatform.tester:
      return 'flutter-tester';
    case TargetPlatform.web_javascript:
      return 'web-javascript';
    case TargetPlatform.android:
      return 'android';
  }
}

TargetPlatform getTargetPlatformForName(String platform) {
  switch (platform) {
    case 'android':
      return TargetPlatform.android;
    case 'android-arm':
      return TargetPlatform.android_arm;
    case 'android-arm64':
      return TargetPlatform.android_arm64;
    case 'android-x64':
      return TargetPlatform.android_x64;
    case 'android-x86':
      return TargetPlatform.android_x86;
    case 'fuchsia-arm64':
      return TargetPlatform.fuchsia_arm64;
    case 'fuchsia-x64':
      return TargetPlatform.fuchsia_x64;
    case 'ios':
      return TargetPlatform.ios;
    case 'darwin':
    // For backward-compatibility and also for Tester, where it must match
    // host platform name (HostPlatform.darwin_x64)
    case 'darwin-x64':
    case 'darwin-arm64':
      return TargetPlatform.darwin;
    case 'linux-x64':
      return TargetPlatform.linux_x64;
   case 'linux-arm64':
      return TargetPlatform.linux_arm64;
    case 'windows-x64':
      return TargetPlatform.windows_x64;
    case 'web-javascript':
      return TargetPlatform.web_javascript;
    case 'flutter-tester':
      return TargetPlatform.tester;
  }
  throw Exception('Unsupported platform name "$platform"');
}

AndroidArch getAndroidArchForName(String platform) {
  switch (platform) {
    case 'android-arm':
      return AndroidArch.armeabi_v7a;
    case 'android-arm64':
      return AndroidArch.arm64_v8a;
    case 'android-x64':
      return AndroidArch.x86_64;
    case 'android-x86':
      return AndroidArch.x86;
  }
  throw Exception('Unsupported Android arch name "$platform"');
}

HostPlatform getCurrentHostPlatform() {
  if (globals.platform.isMacOS) {
    return HostPlatform.darwin_x64;
  }
  if (globals.platform.isLinux) {
    // support x64 and arm64 architecture.
    return globals.os.hostPlatform;
  }
  if (globals.platform.isWindows) {
    return HostPlatform.windows_x64;
  }

  globals.printWarning('Unsupported host platform, defaulting to Linux');

  return HostPlatform.linux_x64;
}

FileSystemEntity getWebPlatformBinariesDirectory(Artifacts artifacts, WebRendererMode webRenderer) {
  return artifacts.getHostArtifact(HostArtifact.webPlatformKernelFolder);
}

String getBuildDirectory([Config? config, FileSystem? fileSystem]) {
  // TODO(johnmccutchan): Stop calling this function as part of setting
  // up command line argument processing.
  final Config localConfig = config ?? globals.config;
  final FileSystem localFilesystem = fileSystem ?? globals.fs;

  final String buildDir = localConfig.getValue('build-dir') as String? ?? 'build';
  if (localFilesystem.path.isAbsolute(buildDir)) {
    throw Exception(
        'build-dir config setting in ${globals.config.configPath} must be relative');
  }
  return buildDir;
}

String getAndroidBuildDirectory() {
  // TODO(cbracken): move to android subdir.
  return getBuildDirectory();
}

String getAotBuildDirectory() {
  return globals.fs.path.join(getBuildDirectory(), 'aot');
}

String getAssetBuildDirectory() {
  return globals.fs.path.join(getBuildDirectory(), 'flutter_assets');
}

String getIosBuildDirectory() {
  return globals.fs.path.join(getBuildDirectory(), 'ios');
}

String getMacOSBuildDirectory() {
  return globals.fs.path.join(getBuildDirectory(), 'macos');
}

String getWebBuildDirectory([bool isWasm = false]) {
  return globals.fs.path.join(getBuildDirectory(), isWasm ? 'web_wasm' : 'web');
}

String getLinuxBuildDirectory([TargetPlatform? targetPlatform]) {
  final String arch = (targetPlatform == null) ?
      _getCurrentHostPlatformArchName() :
      targetPlatform.simpleName;
  final String subDirs = 'linux/$arch';
  return globals.fs.path.join(getBuildDirectory(), subDirs);
}

String getWindowsBuildDirectory(TargetPlatform targetPlatform) {
  final String arch = targetPlatform.simpleName;
  return globals.fs.path.join(getBuildDirectory(), 'windows', arch);
}

String getFuchsiaBuildDirectory() {
  return globals.fs.path.join(getBuildDirectory(), 'fuchsia');
}

const String kDartDefines = 'DartDefines';

const String kBuildMode = 'BuildMode';

const String kTargetPlatform = 'TargetPlatform';

const String kTargetFile = 'TargetFile';

const String kTrackWidgetCreation = 'TrackWidgetCreation';

const String kFrontendServerStarterPath = 'FrontendServerStarterPath';

const String kExtraFrontEndOptions = 'ExtraFrontEndOptions';

const String kExtraGenSnapshotOptions = 'ExtraGenSnapshotOptions';

const String kDeferredComponents = 'DeferredComponents';

const String kSplitDebugInfo = 'SplitDebugInfo';

const String kFileSystemScheme = 'FileSystemScheme';

const String kFileSystemRoots = 'FileSystemRoots';

const String kIosArchs = 'IosArchs';

const String kDarwinArchs = 'DarwinArchs';

const String kSdkRoot = 'SdkRoot';

const String kDartObfuscation = 'DartObfuscation';

const String kCodeSizeDirectory = 'CodeSizeDirectory';

const String kCodesignIdentity = 'CodesignIdentity';

const String kIconTreeShakerFlag = 'TreeShakeIcons';

const String kBundleSkSLPath = 'BundleSkSLPath';

const String kBuildName = 'BuildName';

const String kBuildNumber = 'BuildNumber';

const String kXcodeAction = 'Action';

final Converter<String, String> _defineEncoder = utf8.encoder.fuse(base64.encoder);
final Converter<String, String> _defineDecoder = base64.decoder.fuse(utf8.decoder);

String encodeDartDefines(List<String> defines) {
  return defines.map(_defineEncoder.convert).join(',');
}

List<String> decodeCommaSeparated(Map<String, String> environmentDefines, String key) {
  if (!environmentDefines.containsKey(key) || environmentDefines[key]!.isEmpty) {
    return <String>[];
  }
  return environmentDefines[key]!
    .split(',')
    .cast<String>()
    .toList();
}

List<String> decodeDartDefines(Map<String, String> environmentDefines, String key) {
  if (!environmentDefines.containsKey(key) || environmentDefines[key]!.isEmpty) {
    return <String>[];
  }
  return environmentDefines[key]!
    .split(',')
    .map<Object>(_defineDecoder.convert)
    .cast<String>()
    .toList();
}

enum NullSafetyMode {
  sound,
  unsound,
  autodetect,
}

String _getCurrentHostPlatformArchName() {
  final HostPlatform hostPlatform = getCurrentHostPlatform();
  return hostPlatform.platformName;
}

String? _uncapitalize(String? s) {
  if (s == null || s.isEmpty) {
    return s;
  }
  return s.substring(0, 1).toLowerCase() + s.substring(1);
}