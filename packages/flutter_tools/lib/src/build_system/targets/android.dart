import '../../artifacts.dart';
import '../../base/build.dart';
import '../../base/deferred_component.dart';
import '../../base/file_system.dart';
import '../../build_info.dart';
import '../../globals.dart' as globals show xcode;
import '../../project.dart';
import '../build_system.dart';
import '../depfile.dart';
import '../exceptions.dart';
import 'assets.dart';
import 'common.dart';
import 'icon_tree_shaker.dart';
import 'shader_compiler.dart';

abstract class AndroidAssetBundle extends Target {
  const AndroidAssetBundle();

  @override
  List<Source> get inputs => const <Source>[
        Source.pattern('{BUILD_DIR}/app.dill'),
        ...IconTreeShaker.inputs,
      ];

  @override
  List<Source> get outputs => const <Source>[];

  @override
  List<String> get depfiles => <String>[
        'flutter_assets.d',
      ];

  @override
  Future<void> build(Environment environment) async {
    final String? buildModeEnvironment = environment.defines[kBuildMode];
    if (buildModeEnvironment == null) {
      throw MissingDefineException(kBuildMode, name);
    }
    final BuildMode buildMode = BuildMode.fromCliName(buildModeEnvironment);
    final Directory outputDirectory = environment.outputDir
        .childDirectory('flutter_assets')
      ..createSync(recursive: true);

    // Only copy the prebuilt runtimes and kernel blob in debug mode.
    if (buildMode == BuildMode.debug) {
      final String vmSnapshotData = environment.artifacts
          .getArtifactPath(Artifact.vmSnapshotData, mode: BuildMode.debug);
      final String isolateSnapshotData = environment.artifacts
          .getArtifactPath(Artifact.isolateSnapshotData, mode: BuildMode.debug);
      environment.buildDir
          .childFile('app.dill')
          .copySync(outputDirectory.childFile('kernel_blob.bin').path);
      environment.fileSystem
          .file(vmSnapshotData)
          .copySync(outputDirectory.childFile('vm_snapshot_data').path);
      environment.fileSystem
          .file(isolateSnapshotData)
          .copySync(outputDirectory.childFile('isolate_snapshot_data').path);
    }
    final Depfile assetDepfile = await copyAssets(
      environment,
      outputDirectory,
      targetPlatform: TargetPlatform.android,
      buildMode: buildMode,
      shaderTarget: ShaderTarget.impellerAndroid,
    );
    environment.depFileService.writeToFile(
      assetDepfile,
      environment.buildDir.childFile('flutter_assets.d'),
    );
  }

  @override
  List<Target> get dependencies => const <Target>[
        KernelSnapshot(),
      ];
}

class DebugAndroidApplication extends AndroidAssetBundle {
  const DebugAndroidApplication();

  @override
  String get name => 'debug_android_application';

  @override
  List<Source> get inputs => <Source>[
        ...super.inputs,
        const Source.artifact(Artifact.vmSnapshotData, mode: BuildMode.debug),
        const Source.artifact(Artifact.isolateSnapshotData,
            mode: BuildMode.debug),
      ];

  @override
  List<Source> get outputs => <Source>[
        ...super.outputs,
        const Source.pattern('{OUTPUT_DIR}/flutter_assets/vm_snapshot_data'),
        const Source.pattern(
            '{OUTPUT_DIR}/flutter_assets/isolate_snapshot_data'),
        const Source.pattern('{OUTPUT_DIR}/flutter_assets/kernel_blob.bin'),
      ];
}

class AotAndroidAssetBundle extends AndroidAssetBundle {
  const AotAndroidAssetBundle();

  @override
  String get name => 'aot_android_asset_bundle';
}

class ProfileAndroidApplication extends CopyFlutterAotBundle {
  const ProfileAndroidApplication();

  @override
  String get name => 'profile_android_application';

  @override
  List<Target> get dependencies => const <Target>[
        AotElfProfile(TargetPlatform.android_arm),
        AotAndroidAssetBundle(),
      ];
}

class ReleaseAndroidApplication extends CopyFlutterAotBundle {
  const ReleaseAndroidApplication();

  @override
  String get name => 'release_android_application';

  @override
  List<Target> get dependencies => const <Target>[
        AotElfRelease(TargetPlatform.android_arm),
        AotAndroidAssetBundle(),
      ];
}

class AndroidAot extends AotElfBase {
  const AndroidAot(this.targetPlatform, this.buildMode);

  String get _androidAbiName {
    return getAndroidArchForName(getNameForTargetPlatform(targetPlatform))
        .archName;
  }

  @override
  String get name => 'android_aot_${buildMode.cliName}_'
      '${getNameForTargetPlatform(targetPlatform)}';

  final TargetPlatform targetPlatform;

  final BuildMode buildMode;

  @override
  List<Source> get inputs => <Source>[
        const Source.pattern(
            '{FLUTTER_ROOT}/packages/flutter_tools/lib/src/build_system/targets/android.dart'),
        const Source.pattern('{BUILD_DIR}/app.dill'),
        const Source.artifact(Artifact.engineDartBinary),
        const Source.artifact(Artifact.skyEnginePath),
        Source.artifact(
          Artifact.genSnapshot,
          mode: buildMode,
          platform: targetPlatform,
        ),
      ];

  @override
  List<Source> get outputs => <Source>[
        Source.pattern('{BUILD_DIR}/$_androidAbiName/app.so'),
      ];

  @override
  List<String> get depfiles => <String>[
        'flutter_$name.d',
      ];

  @override
  List<Target> get dependencies => const <Target>[
        KernelSnapshot(),
      ];

  @override
  Future<void> build(Environment environment) async {
    final AOTSnapshotter snapshotter = AOTSnapshotter(
      fileSystem: environment.fileSystem,
      logger: environment.logger,
      xcode: globals.xcode!,
      processManager: environment.processManager,
      artifacts: environment.artifacts,
    );
    final Directory output =
        environment.buildDir.childDirectory(_androidAbiName);
    final String? buildModeEnvironment = environment.defines[kBuildMode];
    if (buildModeEnvironment == null) {
      throw MissingDefineException(kBuildMode, 'aot_elf');
    }
    if (!output.existsSync()) {
      output.createSync(recursive: true);
    }
    final List<String> extraGenSnapshotOptions =
        decodeCommaSeparated(environment.defines, kExtraGenSnapshotOptions);
    final List<File> outputs = <File>[]; // outputs for the depfile
    final String manifestPath =
        '${output.path}${environment.platform.pathSeparator}manifest.json';
    if (environment.defines[kDeferredComponents] == 'true') {
      extraGenSnapshotOptions.add('--loading_unit_manifest=$manifestPath');
      outputs.add(environment.fileSystem.file(manifestPath));
    }
    final BuildMode buildMode = BuildMode.fromCliName(buildModeEnvironment);
    final bool dartObfuscation =
        environment.defines[kDartObfuscation] == 'true';
    final String? codeSizeDirectory = environment.defines[kCodeSizeDirectory];

    if (codeSizeDirectory != null) {
      final File codeSizeFile = environment.fileSystem
          .directory(codeSizeDirectory)
          .childFile('snapshot.$_androidAbiName.json');
      final File precompilerTraceFile = environment.fileSystem
          .directory(codeSizeDirectory)
          .childFile('trace.$_androidAbiName.json');
      extraGenSnapshotOptions
          .add('--write-v8-snapshot-profile-to=${codeSizeFile.path}');
      extraGenSnapshotOptions
          .add('--trace-precompiler-to=${precompilerTraceFile.path}');
    }

    final String? splitDebugInfo = environment.defines[kSplitDebugInfo];
    final int snapshotExitCode = await snapshotter.build(
      platform: targetPlatform,
      buildMode: buildMode,
      mainPath: environment.buildDir.childFile('app.dill').path,
      outputPath: output.path,
      extraGenSnapshotOptions: extraGenSnapshotOptions,
      splitDebugInfo: splitDebugInfo,
      dartObfuscation: dartObfuscation,
    );
    if (snapshotExitCode != 0) {
      throw Exception('AOT snapshotter exited with code $snapshotExitCode');
    }
    if (environment.defines[kDeferredComponents] == 'true') {
      // Parse the manifest for .so paths
      final List<LoadingUnit> loadingUnits =
          LoadingUnit.parseLoadingUnitManifest(
              environment.fileSystem.file(manifestPath), environment.logger);
      for (final LoadingUnit unit in loadingUnits) {
        outputs.add(environment.fileSystem.file(unit.path));
      }
    }
    environment.depFileService.writeToFile(
      Depfile(<File>[], outputs),
      environment.buildDir.childFile('flutter_$name.d'),
      writeEmpty: true,
    );
  }
}

// AndroidAot instances used by the bundle rules below.
const AndroidAot androidArmProfile =
    AndroidAot(TargetPlatform.android_arm, BuildMode.profile);
const AndroidAot androidArm64Profile =
    AndroidAot(TargetPlatform.android_arm64, BuildMode.profile);
const AndroidAot androidx64Profile =
    AndroidAot(TargetPlatform.android_x64, BuildMode.profile);
const AndroidAot androidArmRelease =
    AndroidAot(TargetPlatform.android_arm, BuildMode.release);
const AndroidAot androidArm64Release =
    AndroidAot(TargetPlatform.android_arm64, BuildMode.release);
const AndroidAot androidx64Release =
    AndroidAot(TargetPlatform.android_x64, BuildMode.release);

class AndroidAotBundle extends Target {
  const AndroidAotBundle(this.dependency);

  final AndroidAot dependency;

  String get _androidAbiName {
    return getAndroidArchForName(
            getNameForTargetPlatform(dependency.targetPlatform))
        .archName;
  }

  @override
  String get name => 'android_aot_bundle_${dependency.buildMode.cliName}_'
      '${getNameForTargetPlatform(dependency.targetPlatform)}';

  TargetPlatform get targetPlatform => dependency.targetPlatform;

  BuildMode get buildMode => dependency.buildMode;

  @override
  List<Source> get inputs => <Source>[
        Source.pattern('{BUILD_DIR}/$_androidAbiName/app.so'),
      ];

  // flutter.gradle has been updated to correctly consume it.
  @override
  List<Source> get outputs => <Source>[
        Source.pattern('{OUTPUT_DIR}/$_androidAbiName/app.so'),
      ];

  @override
  List<String> get depfiles => <String>[
        'flutter_$name.d',
      ];

  @override
  List<Target> get dependencies => <Target>[
        dependency,
        const AotAndroidAssetBundle(),
      ];

  @override
  Future<void> build(Environment environment) async {
    final Directory buildDir =
        environment.buildDir.childDirectory(_androidAbiName);
    final Directory outputDirectory =
        environment.outputDir.childDirectory(_androidAbiName);
    if (!outputDirectory.existsSync()) {
      outputDirectory.createSync(recursive: true);
    }
    final File outputLibFile = buildDir.childFile('app.so');
    outputLibFile.copySync(outputDirectory.childFile('app.so').path);

    final List<File> inputs = <File>[];
    final List<File> outputs = <File>[];
    final File manifestFile = buildDir.childFile('manifest.json');
    if (manifestFile.existsSync()) {
      final File destinationFile = outputDirectory.childFile('manifest.json');
      manifestFile.copySync(destinationFile.path);
      inputs.add(manifestFile);
      outputs.add(destinationFile);
    }
    environment.depFileService.writeToFile(
      Depfile(inputs, outputs),
      environment.buildDir.childFile('flutter_$name.d'),
      writeEmpty: true,
    );
  }
}

// AndroidBundleAot instances.
const AndroidAotBundle androidArmProfileBundle =
    AndroidAotBundle(androidArmProfile);
const AndroidAotBundle androidArm64ProfileBundle =
    AndroidAotBundle(androidArm64Profile);
const AndroidAotBundle androidx64ProfileBundle =
    AndroidAotBundle(androidx64Profile);
const AndroidAotBundle androidArmReleaseBundle =
    AndroidAotBundle(androidArmRelease);
const AndroidAotBundle androidArm64ReleaseBundle =
    AndroidAotBundle(androidArm64Release);
const AndroidAotBundle androidx64ReleaseBundle =
    AndroidAotBundle(androidx64Release);

// Rule that copies split aot library files to the intermediate dirs of each deferred component.
class AndroidAotDeferredComponentsBundle extends Target {
  AndroidAotDeferredComponentsBundle(this.dependency,
      {List<DeferredComponent>? components})
      : _components = components;

  final AndroidAotBundle dependency;

  List<DeferredComponent>? _components;

  String get _androidAbiName {
    return getAndroidArchForName(
            getNameForTargetPlatform(dependency.targetPlatform))
        .archName;
  }

  @override
  String get name =>
      'android_aot_deferred_components_bundle_${dependency.buildMode.cliName}_'
      '${getNameForTargetPlatform(dependency.targetPlatform)}';

  TargetPlatform get targetPlatform => dependency.targetPlatform;

  @override
  List<Source> get inputs => <Source>[
        // Tracking app.so is enough to invalidate the dynamically named
        // loading unit libs as changes to loading units guarantee
        // changes to app.so as well. This task does not actually
        // copy app.so.
        Source.pattern('{OUTPUT_DIR}/$_androidAbiName/app.so'),
        const Source.pattern('{PROJECT_DIR}/pubspec.yaml'),
      ];

  @override
  List<Source> get outputs => const <Source>[];

  @override
  List<String> get depfiles => <String>[
        'flutter_$name.d',
      ];

  @override
  List<Target> get dependencies => <Target>[
        dependency,
      ];

  @override
  Future<void> build(Environment environment) async {
    _components ??= FlutterProject.current().manifest.deferredComponents ??
        <DeferredComponent>[];
    final List<String> abis = <String>[_androidAbiName];
    final List<LoadingUnit> generatedLoadingUnits =
        LoadingUnit.parseGeneratedLoadingUnits(
            environment.outputDir, environment.logger,
            abis: abis);
    for (final DeferredComponent component in _components!) {
      component.assignLoadingUnits(generatedLoadingUnits);
    }
    final Depfile libDepfile = copyDeferredComponentSoFiles(
        environment,
        _components!,
        generatedLoadingUnits,
        environment.projectDir.childDirectory('build'),
        abis,
        dependency.buildMode);

    final File manifestFile = environment.outputDir
        .childDirectory(_androidAbiName)
        .childFile('manifest.json');
    if (manifestFile.existsSync()) {
      libDepfile.inputs.add(manifestFile);
    }

    environment.depFileService.writeToFile(
      libDepfile,
      environment.buildDir.childFile('flutter_$name.d'),
      writeEmpty: true,
    );
  }
}

Target androidArmProfileDeferredComponentsBundle =
    AndroidAotDeferredComponentsBundle(androidArmProfileBundle);
Target androidArm64ProfileDeferredComponentsBundle =
    AndroidAotDeferredComponentsBundle(androidArm64ProfileBundle);
Target androidx64ProfileDeferredComponentsBundle =
    AndroidAotDeferredComponentsBundle(androidx64ProfileBundle);
Target androidArmReleaseDeferredComponentsBundle =
    AndroidAotDeferredComponentsBundle(androidArmReleaseBundle);
Target androidArm64ReleaseDeferredComponentsBundle =
    AndroidAotDeferredComponentsBundle(androidArm64ReleaseBundle);
Target androidx64ReleaseDeferredComponentsBundle =
    AndroidAotDeferredComponentsBundle(androidx64ReleaseBundle);

Set<String> deferredComponentsTargets = <String>{
  androidArmProfileDeferredComponentsBundle.name,
  androidArm64ProfileDeferredComponentsBundle.name,
  androidx64ProfileDeferredComponentsBundle.name,
  androidArmReleaseDeferredComponentsBundle.name,
  androidArm64ReleaseDeferredComponentsBundle.name,
  androidx64ReleaseDeferredComponentsBundle.name,
};

Depfile copyDeferredComponentSoFiles(
  Environment env,
  List<DeferredComponent> components,
  List<LoadingUnit> loadingUnits,
  Directory buildDir, // generally `<projectDir>/build`
  List<String> abis,
  BuildMode buildMode,
) {
  final List<File> inputs = <File>[];
  final List<File> outputs = <File>[];
  final Set<int> usedLoadingUnits = <int>{};
  // Copy all .so files for loading units that are paired with a deferred component.
  for (final String abi in abis) {
    for (final DeferredComponent component in components) {
      final Set<LoadingUnit>? loadingUnits = component.loadingUnits;
      if (loadingUnits == null || !component.assigned) {
        env.logger.printError(
            'Deferred component require loading units to be assigned.');
        return Depfile(inputs, outputs);
      }
      for (final LoadingUnit unit in loadingUnits) {
        // ensure the abi for the unit is one of the abis we build for.
        final List<String>? splitPath =
            unit.path?.split(env.fileSystem.path.separator);
        if (splitPath == null || splitPath[splitPath.length - 2] != abi) {
          continue;
        }
        usedLoadingUnits.add(unit.id);
        // the deferred_libs directory is added as a source set for the component.
        final File destination = buildDir
            .childDirectory(component.name)
            .childDirectory('intermediates')
            .childDirectory('flutter')
            .childDirectory(buildMode.cliName)
            .childDirectory('deferred_libs')
            .childDirectory(abi)
            .childFile('libapp.so-${unit.id}.part.so');
        if (!destination.existsSync()) {
          destination.createSync(recursive: true);
        }
        final File source = env.fileSystem.file(unit.path);
        source.copySync(destination.path);
        inputs.add(source);
        outputs.add(destination);
      }
    }
  }
  // Copy unused loading units, which are included in the base module.
  for (final String abi in abis) {
    for (final LoadingUnit unit in loadingUnits) {
      if (usedLoadingUnits.contains(unit.id)) {
        continue;
      }
      // ensure the abi for the unit is one of the abis we build for.
      final List<String>? splitPath =
          unit.path?.split(env.fileSystem.path.separator);
      if (splitPath == null || splitPath[splitPath.length - 2] != abi) {
        continue;
      }
      final File destination = env.outputDir
          .childDirectory(abi)
          // Omit 'lib' prefix here as it is added by the gradle task that adds 'lib' to 'app.so'.
          .childFile('app.so-${unit.id}.part.so');
      if (!destination.existsSync()) {
        destination.createSync(recursive: true);
      }
      final File source = env.fileSystem.file(unit.path);
      source.copySync(destination.path);
      inputs.add(source);
      outputs.add(destination);
    }
  }
  return Depfile(inputs, outputs);
}
