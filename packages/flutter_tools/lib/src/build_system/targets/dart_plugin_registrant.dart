import 'package:meta/meta.dart';
import 'package:package_config/package_config.dart';

import '../../base/file_system.dart';
import '../../build_info.dart';
import '../../dart/package_map.dart';
import '../../flutter_plugins.dart';
import '../../project.dart';
import '../build_system.dart';

class DartPluginRegistrantTarget extends Target {
  const DartPluginRegistrantTarget() : _project = null;

  @visibleForTesting
  factory DartPluginRegistrantTarget.test(FlutterProject project) {
    return DartPluginRegistrantTarget._(project);
  }

  DartPluginRegistrantTarget._(this._project);

  final FlutterProject? _project;

  @override
  Future<void> build(Environment environment) async {
    assert(environment.generateDartPluginRegistry);
    final FlutterProject project =
        _project ?? FlutterProject.fromDirectory(environment.projectDir);
    final PackageConfig packageConfig = await loadPackageConfigWithLogging(
      project.packageConfigFile,
      logger: environment.logger,
    );
    final String targetFilePath = environment.defines[kTargetFile] ??
        environment.fileSystem.path.join('lib', 'main.dart');
    final File mainFile = environment.fileSystem.file(targetFilePath);
    final Uri mainFileUri = mainFile.absolute.uri;
    final String mainFileUriString =
        packageConfig.toPackageUri(mainFileUri)?.toString() ??
            mainFileUri.toString();

    await generateMainDartWithPluginRegistrant(
      project,
      packageConfig,
      mainFileUriString,
      mainFile,
    );
  }

  @override
  bool canSkip(Environment environment) {
    if (!environment.generateDartPluginRegistry) {
      return true;
    }
    final String? platformName = environment.defines[kTargetPlatform];
    final TargetPlatform? targetPlatform =
        platformName == null ? null : getTargetPlatformForName(platformName);
    // TODO(stuartmorgan): Investigate removing this check entirely; ideally the
    // source generation step shouldn't be platform dependent, and the generated
    // code should just do the right thing on every platform.
    // Failing that, consider throwing if `targetPlatform` isn't set and finding
    // all violations, as it's not consistently set here.
    return targetPlatform == TargetPlatform.fuchsia_arm64 ||
        targetPlatform == TargetPlatform.fuchsia_x64 ||
        targetPlatform == TargetPlatform.web_javascript;
  }

  @override
  List<Target> get dependencies => <Target>[];

  @override
  List<Source> get inputs => <Source>[
        const Source.pattern('{PROJECT_DIR}/.dart_tool/package_config_subset'),
      ];

  @override
  String get name => 'gen_dart_plugin_registrant';

  @override
  List<Source> get outputs => <Source>[
        const Source.pattern(
          '{PROJECT_DIR}/.dart_tool/flutter_build/dart_plugin_registrant.dart',
          optional: true,
        ),
      ];
}
