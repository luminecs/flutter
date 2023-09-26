import 'base/file_system.dart';
import 'base/utils.dart';
import 'platform_plugins.dart';
import 'project.dart';

abstract class CmakeBasedProject {
  FlutterProject get parent;

  bool existsSync();

  File get cmakeFile;

  File get managedCmakeFile;

  File get generatedCmakeConfigFile;

  File get generatedPluginCmakeFile;

  Directory get pluginSymlinkDirectory;
}

class WindowsProject extends FlutterProjectPlatform
    implements CmakeBasedProject {
  WindowsProject.fromFlutter(this.parent);

  @override
  final FlutterProject parent;

  @override
  String get pluginConfigKey => WindowsPlugin.kConfigKey;

  String get _childDirectory => 'windows';

  @override
  bool existsSync() =>
      _editableDirectory.existsSync() && cmakeFile.existsSync();

  @override
  File get cmakeFile => _editableDirectory.childFile('CMakeLists.txt');

  @override
  File get managedCmakeFile => managedDirectory.childFile('CMakeLists.txt');

  @override
  File get generatedCmakeConfigFile =>
      ephemeralDirectory.childFile('generated_config.cmake');

  @override
  File get generatedPluginCmakeFile =>
      managedDirectory.childFile('generated_plugins.cmake');

  File get runnerCmakeFile => runnerDirectory.childFile('CMakeLists.txt');

  File get runnerFlutterWindowFile =>
      runnerDirectory.childFile('flutter_window.cpp');

  File get runnerResourceFile => runnerDirectory.childFile('Runner.rc');

  @override
  Directory get pluginSymlinkDirectory =>
      ephemeralDirectory.childDirectory('.plugin_symlinks');

  Directory get _editableDirectory =>
      parent.directory.childDirectory(_childDirectory);

  Directory get managedDirectory =>
      _editableDirectory.childDirectory('flutter');

  Directory get ephemeralDirectory =>
      managedDirectory.childDirectory('ephemeral');

  Directory get runnerDirectory => _editableDirectory.childDirectory('runner');

  Future<void> ensureReadyForPlatformSpecificTooling() async {}
}

class LinuxProject extends FlutterProjectPlatform implements CmakeBasedProject {
  LinuxProject.fromFlutter(this.parent);

  @override
  final FlutterProject parent;

  @override
  String get pluginConfigKey => LinuxPlugin.kConfigKey;

  static final RegExp _applicationIdPattern =
      RegExp(r'''^\s*set\s*\(\s*APPLICATION_ID\s*"(.*)"\s*\)\s*$''');

  Directory get _editableDirectory => parent.directory.childDirectory('linux');

  Directory get managedDirectory =>
      _editableDirectory.childDirectory('flutter');

  Directory get ephemeralDirectory =>
      managedDirectory.childDirectory('ephemeral');

  @override
  bool existsSync() => _editableDirectory.existsSync();

  @override
  File get cmakeFile => _editableDirectory.childFile('CMakeLists.txt');

  @override
  File get managedCmakeFile => managedDirectory.childFile('CMakeLists.txt');

  @override
  File get generatedCmakeConfigFile =>
      ephemeralDirectory.childFile('generated_config.cmake');

  @override
  File get generatedPluginCmakeFile =>
      managedDirectory.childFile('generated_plugins.cmake');

  @override
  Directory get pluginSymlinkDirectory =>
      ephemeralDirectory.childDirectory('.plugin_symlinks');

  Future<void> ensureReadyForPlatformSpecificTooling() async {}

  String? get applicationId {
    return firstMatchInFile(cmakeFile, _applicationIdPattern)?.group(1);
  }
}
