import '../application_package.dart';
import '../base/file_system.dart';
import '../build_info.dart';
import '../cmake.dart';
import '../cmake_project.dart';
import '../globals.dart' as globals;

abstract class LinuxApp extends ApplicationPackage {
  LinuxApp({required String projectBundleId}) : super(id: projectBundleId);

  factory LinuxApp.fromLinuxProject(LinuxProject project) {
    return BuildableLinuxApp(
      project: project,
    );
  }

  factory LinuxApp.fromPrebuiltApp(FileSystemEntity applicationBinary) {
    return PrebuiltLinuxApp(
      executable: applicationBinary.path,
    );
  }

  @override
  String get displayName => id;

  String executable(BuildMode buildMode);
}

class PrebuiltLinuxApp extends LinuxApp {
  PrebuiltLinuxApp({
    required String executable,
  })  : _executable = executable,
        super(projectBundleId: executable);

  final String _executable;

  @override
  String executable(BuildMode buildMode) => _executable;

  @override
  String get name => _executable;
}

class BuildableLinuxApp extends LinuxApp {
  BuildableLinuxApp({required this.project})
      : super(projectBundleId: project.parent.manifest.appName);

  final LinuxProject project;

  @override
  String executable(BuildMode buildMode) {
    final String? binaryName = getCmakeExecutableName(project);
    return globals.fs.path.join(
      getLinuxBuildDirectory(),
      buildMode.cliName,
      'bundle',
      binaryName,
    );
  }

  @override
  String get name => project.parent.manifest.appName;
}
