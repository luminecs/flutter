// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Logic for native assets shared between all host OSes.

import 'package:logging/logging.dart' as logging;
import 'package:native_assets_builder/native_assets_builder.dart' hide NativeAssetsBuildRunner;
import 'package:native_assets_builder/native_assets_builder.dart' as native_assets_builder show NativeAssetsBuildRunner;
import 'package:native_assets_cli/native_assets_cli.dart';
import 'package:package_config/package_config_types.dart';

import 'base/common.dart';
import 'base/file_system.dart';
import 'base/logger.dart';
import 'base/platform.dart';
import 'build_info.dart' as build_info;
import 'cache.dart';
import 'features.dart';
import 'globals.dart' as globals;
import 'ios/native_assets.dart';
import 'linux/native_assets.dart';
import 'macos/native_assets.dart';
import 'macos/native_assets_host.dart';
import 'resident_runner.dart';

abstract class NativeAssetsBuildRunner {
  Future<bool> hasPackageConfig();

  Future<List<Package>> packagesWithNativeAssets();

  Future<DryRunResult> dryRun({
    required bool includeParentEnvironment,
    required LinkModePreference linkModePreference,
    required OS targetOs,
    required Uri workingDirectory,
  });

  Future<BuildResult> build({
    required bool includeParentEnvironment,
    required BuildMode buildMode,
    required LinkModePreference linkModePreference,
    required Target target,
    required Uri workingDirectory,
    CCompilerConfig? cCompilerConfig,
    int? targetAndroidNdkApi,
    IOSSdk? targetIOSSdk,
  });

  Future<CCompilerConfig> get cCompilerConfig;
}

class NativeAssetsBuildRunnerImpl implements NativeAssetsBuildRunner {
  NativeAssetsBuildRunnerImpl(
    this.projectUri,
    this.packageConfig,
    this.fileSystem,
    this.logger,
  );

  final Uri projectUri;
  final PackageConfig packageConfig;
  final FileSystem fileSystem;
  final Logger logger;

  late final logging.Logger _logger = logging.Logger('')
    ..onRecord.listen((logging.LogRecord record) {
      final int levelValue = record.level.value;
      final String message = record.message;
      if (levelValue >= logging.Level.SEVERE.value) {
        logger.printError(message);
      } else if (levelValue >= logging.Level.WARNING.value) {
        logger.printWarning(message);
      } else if (levelValue >= logging.Level.INFO.value) {
        logger.printTrace(message);
      } else {
        logger.printTrace(message);
      }
    });

  late final Uri _dartExecutable = fileSystem.directory(Cache.flutterRoot).uri.resolve('bin/dart');

  late final native_assets_builder.NativeAssetsBuildRunner _buildRunner = native_assets_builder.NativeAssetsBuildRunner(
    logger: _logger,
    dartExecutable: _dartExecutable,
  );

  @override
  Future<bool> hasPackageConfig() {
    final File packageConfigJson = fileSystem
        .directory(projectUri.toFilePath())
        .childDirectory('.dart_tool')
        .childFile('package_config.json');
    return packageConfigJson.exists();
  }

  @override
  Future<List<Package>> packagesWithNativeAssets() async {
    final PackageLayout packageLayout = PackageLayout.fromPackageConfig(
      packageConfig,
      projectUri.resolve('.dart_tool/package_config.json'),
    );
    return packageLayout.packagesWithNativeAssets;
  }

  @override
  Future<DryRunResult> dryRun({
    required bool includeParentEnvironment,
    required LinkModePreference linkModePreference,
    required OS targetOs,
    required Uri workingDirectory,
  }) {
    final PackageLayout packageLayout = PackageLayout.fromPackageConfig(
      packageConfig,
      projectUri.resolve('.dart_tool/package_config.json'),
    );
    return _buildRunner.dryRun(
      includeParentEnvironment: includeParentEnvironment,
      linkModePreference: linkModePreference,
      targetOs: targetOs,
      workingDirectory: workingDirectory,
      packageLayout: packageLayout,
    );
  }

  @override
  Future<BuildResult> build({
    required bool includeParentEnvironment,
    required BuildMode buildMode,
    required LinkModePreference linkModePreference,
    required Target target,
    required Uri workingDirectory,
    CCompilerConfig? cCompilerConfig,
    int? targetAndroidNdkApi,
    IOSSdk? targetIOSSdk,
  }) {
    final PackageLayout packageLayout = PackageLayout.fromPackageConfig(
      packageConfig,
      projectUri.resolve('.dart_tool/package_config.json'),
    );
    return _buildRunner.build(
      buildMode: buildMode,
      cCompilerConfig: cCompilerConfig,
      includeParentEnvironment: includeParentEnvironment,
      linkModePreference: linkModePreference,
      target: target,
      targetAndroidNdkApi: targetAndroidNdkApi,
      targetIOSSdk: targetIOSSdk,
      workingDirectory: workingDirectory,
      packageLayout: packageLayout,
    );
  }

  @override
  late final Future<CCompilerConfig> cCompilerConfig = () {
    if (globals.platform.isMacOS || globals.platform.isIOS) {
      return cCompilerConfigMacOS();
    }
    if (globals.platform.isLinux) {
      return cCompilerConfigLinux();
    }
    throwToolExit(
      'Native assets feature not yet implemented for Linux, Windows and Android.',
    );
  }();
}

Future<Uri> writeNativeAssetsYaml(
  Iterable<Asset> assets,
  Uri yamlParentDirectory,
  FileSystem fileSystem,
) async {
  globals.logger.printTrace('Writing native_assets.yaml.');
  final String nativeAssetsDartContents = assets.toNativeAssetsFile();
  final Directory parentDirectory = fileSystem.directory(yamlParentDirectory);
  if (!await parentDirectory.exists()) {
    await parentDirectory.create(recursive: true);
  }
  final File nativeAssetsFile = parentDirectory.childFile('native_assets.yaml');
  await nativeAssetsFile.writeAsString(nativeAssetsDartContents);
  globals.logger.printTrace('Writing ${nativeAssetsFile.path} done.');
  return nativeAssetsFile.uri;
}

BuildMode nativeAssetsBuildMode(build_info.BuildMode buildMode) {
  switch (buildMode) {
    case build_info.BuildMode.debug:
      return BuildMode.debug;
    case build_info.BuildMode.jitRelease:
    case build_info.BuildMode.profile:
    case build_info.BuildMode.release:
      return BuildMode.release;
  }
}

Future<bool> hasNoPackageConfig(NativeAssetsBuildRunner buildRunner) async {
  final bool packageConfigExists = await buildRunner.hasPackageConfig();
  if (!packageConfigExists) {
    globals.logger.printTrace('No package config found. Skipping native assets compilation.');
  }
  return !packageConfigExists;
}

Future<bool> isDisabledAndNoNativeAssets(NativeAssetsBuildRunner buildRunner) async {
  if (featureFlags.isNativeAssetsEnabled) {
    return false;
  }
  final List<Package> packagesWithNativeAssets = await buildRunner.packagesWithNativeAssets();
  if (packagesWithNativeAssets.isEmpty) {
    return true;
  }
  final String packageNames = packagesWithNativeAssets.map((Package p) => p.name).join(' ');
  throwToolExit(
    'Package(s) $packageNames require the native assets feature to be enabled. '
    'Enable using `flutter config --enable-native-assets`.',
  );
}

Future<void> ensureNoNativeAssetsOrOsIsSupported(
  Uri workingDirectory,
  String os,
  FileSystem fileSystem,
  NativeAssetsBuildRunner buildRunner,
) async {
  if (await hasNoPackageConfig(buildRunner)) {
    return;
  }
  final List<Package> packagesWithNativeAssets = await buildRunner.packagesWithNativeAssets();
  if (packagesWithNativeAssets.isEmpty) {
    return;
  }
  final String packageNames = packagesWithNativeAssets.map((Package p) => p.name).join(' ');
  throwToolExit(
    'Package(s) $packageNames require the native assets feature. '
    'This feature has not yet been implemented for `$os`. '
    'For more info see https://github.com/flutter/flutter/issues/129757.',
  );
}

void ensureNoLinkModeStatic(List<Asset> nativeAssets) {
  final Iterable<Asset> staticAssets = nativeAssets.whereLinkMode(LinkMode.static);
  if (staticAssets.isNotEmpty) {
    final String assetIds = staticAssets.map((Asset a) => a.id).toSet().join(', ');
    throwToolExit(
      'Native asset(s) $assetIds have their link mode set to static, '
      'but this is not yet supported. '
      'For more info see https://github.com/dart-lang/sdk/issues/49418.',
    );
  }
}

Uri nativeAssetsBuildUri(Uri projectUri, OS os) {
  final String buildDir = build_info.getBuildDirectory();
  return projectUri.resolve('$buildDir/native_assets/$os/');
}

Future<Uri?> dryRunNativeAssets({
  required Uri projectUri,
  required FileSystem fileSystem,
  required NativeAssetsBuildRunner buildRunner,
  required List<FlutterDevice> flutterDevices,
}) async {
  if (flutterDevices.length != 1) {
    return dryRunNativeAssetsMultipeOSes(
      projectUri: projectUri,
      fileSystem: fileSystem,
      targetPlatforms: flutterDevices.map((FlutterDevice d) => d.targetPlatform).nonNulls,
      buildRunner: buildRunner,
    );
  }
  final FlutterDevice flutterDevice = flutterDevices.single;
  final build_info.TargetPlatform targetPlatform = flutterDevice.targetPlatform!;

  final Uri? nativeAssetsYaml;
  switch (targetPlatform) {
    case build_info.TargetPlatform.darwin:
      nativeAssetsYaml = await dryRunNativeAssetsMacOS(
        projectUri: projectUri,
        fileSystem: fileSystem,
        buildRunner: buildRunner,
      );
    case build_info.TargetPlatform.ios:
      nativeAssetsYaml = await dryRunNativeAssetsIOS(
        projectUri: projectUri,
        fileSystem: fileSystem,
        buildRunner: buildRunner,
      );
    case build_info.TargetPlatform.tester:
      if (const LocalPlatform().isMacOS) {
        nativeAssetsYaml = await dryRunNativeAssetsMacOS(
          projectUri: projectUri,
          flutterTester: true,
          fileSystem: fileSystem,
          buildRunner: buildRunner,
        );
      } else if (const LocalPlatform().isLinux) {
        nativeAssetsYaml = await dryRunNativeAssetsLinux(
          projectUri: projectUri,
          flutterTester: true,
          fileSystem: fileSystem,
          buildRunner: buildRunner,
        );
      } else {
        await ensureNoNativeAssetsOrOsIsSupported(
          projectUri,
          const LocalPlatform().operatingSystem,
          fileSystem,
          buildRunner,
        );
        nativeAssetsYaml = null;
      }
    case build_info.TargetPlatform.linux_arm64:
    case build_info.TargetPlatform.linux_x64:
      nativeAssetsYaml = await dryRunNativeAssetsLinux(
        projectUri: projectUri,
        fileSystem: fileSystem,
        buildRunner: buildRunner,
      );
    case build_info.TargetPlatform.android_arm:
    case build_info.TargetPlatform.android_arm64:
    case build_info.TargetPlatform.android_x64:
    case build_info.TargetPlatform.android_x86:
    case build_info.TargetPlatform.android:
    case build_info.TargetPlatform.fuchsia_arm64:
    case build_info.TargetPlatform.fuchsia_x64:
    case build_info.TargetPlatform.web_javascript:
    case build_info.TargetPlatform.windows_x64:
      await ensureNoNativeAssetsOrOsIsSupported(
        projectUri,
        targetPlatform.toString(),
        fileSystem,
        buildRunner,
      );
      nativeAssetsYaml = null;
  }
  return nativeAssetsYaml;
}

Future<Uri?> dryRunNativeAssetsMultipeOSes({
  required NativeAssetsBuildRunner buildRunner,
  required Uri projectUri,
  required FileSystem fileSystem,
  required Iterable<build_info.TargetPlatform> targetPlatforms,
}) async {
  if (await hasNoPackageConfig(buildRunner) || await isDisabledAndNoNativeAssets(buildRunner)) {
    return null;
  }

  final Uri buildUri_ = buildUriMultiple(projectUri);
  final Iterable<Asset> nativeAssetPaths = <Asset>[
    if (targetPlatforms.contains(build_info.TargetPlatform.darwin) ||
        (targetPlatforms.contains(build_info.TargetPlatform.tester) && OS.current == OS.macOS))
      ...await dryRunNativeAssetsMacOSInternal(fileSystem, projectUri, false, buildRunner),
    if (targetPlatforms.contains(build_info.TargetPlatform.linux_arm64) ||
        targetPlatforms.contains(build_info.TargetPlatform.linux_x64) ||
        (targetPlatforms.contains(build_info.TargetPlatform.tester) && OS.current == OS.linux))
      ...await dryRunNativeAssetsLinuxInternal(fileSystem, projectUri, false, buildRunner),
    if (targetPlatforms.contains(build_info.TargetPlatform.ios))
      ...await dryRunNativeAssetsIOSInternal(fileSystem, projectUri, buildRunner)
  ];
  final Uri nativeAssetsUri = await writeNativeAssetsYaml(nativeAssetPaths, buildUri_, fileSystem);
  return nativeAssetsUri;
}

Uri buildUriMultiple(Uri projectUri) {
  final String buildDir = build_info.getBuildDirectory();
  return projectUri.resolve('$buildDir/native_assets/multiple/');
}