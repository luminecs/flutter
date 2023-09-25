import 'package:archive/archive.dart';

import '../application_package.dart';
import '../base/file_system.dart';
import '../base/utils.dart';
import '../build_info.dart';
import '../cmake.dart';
import '../cmake_project.dart';
import '../globals.dart' as globals;

abstract class WindowsApp extends ApplicationPackage {
  WindowsApp({required String projectBundleId}) : super(id: projectBundleId);

  factory WindowsApp.fromWindowsProject(WindowsProject project) {
    return BuildableWindowsApp(
      project: project,
    );
  }

  static WindowsApp? fromPrebuiltApp(FileSystemEntity applicationBinary) {
    if (!applicationBinary.existsSync()) {
      globals.printError('File "${applicationBinary.path}" does not exist.');
      return null;
    }

    if (applicationBinary.path.endsWith('.exe')) {
      return PrebuiltWindowsApp(
        executable: applicationBinary.path,
        applicationPackage: applicationBinary,
      );
    }

    if (!applicationBinary.path.endsWith('.zip')) {
      // Unknown file type
      globals.printError('Unknown windows application type.');
      return null;
    }

    // Try to unpack as a zip.
    final Directory tempDir = globals.fs.systemTempDirectory.createTempSync('flutter_app.');
    try {
      globals.os.unzip(globals.fs.file(applicationBinary), tempDir);
    } on ArchiveException {
      globals.printError('Invalid prebuilt Windows app. Unable to extract from archive.');
      return null;
    }
    final List<FileSystemEntity> exeFilesFound = <FileSystemEntity>[];
    for (final FileSystemEntity file in tempDir.listSync()) {
      if (file.basename.endsWith('.exe')) {
        exeFilesFound.add(file);
      }
    }

    if (exeFilesFound.isEmpty) {
      globals.printError('Cannot find .exe files in the zip archive.');
      return null;
    }

    if (exeFilesFound.length > 1) {
      globals.printError('Archive "${applicationBinary.path}" contains more than one .exe files.');
      return null;
    }

    return PrebuiltWindowsApp(
      executable: exeFilesFound.single.path,
      applicationPackage: applicationBinary,
    );
  }

  @override
  String get displayName => id;

  String executable(BuildMode buildMode);
}

class PrebuiltWindowsApp extends WindowsApp implements PrebuiltApplicationPackage {
  PrebuiltWindowsApp({
    required String executable,
    required this.applicationPackage,
  }) : _executable = executable,
       super(projectBundleId: executable);

  final String _executable;

  @override
  String executable(BuildMode buildMode) => _executable;

  @override
  String get name => _executable;

  @override
  final FileSystemEntity applicationPackage;
}

class BuildableWindowsApp extends WindowsApp {
  BuildableWindowsApp({
    required this.project,
  }) : super(projectBundleId: project.parent.manifest.appName);

  final WindowsProject project;

  @override
  String executable(BuildMode buildMode) {
    final String? binaryName = getCmakeExecutableName(project);
    return globals.fs.path.join(
        getWindowsBuildDirectory(TargetPlatform.windows_x64),
        'runner',
        sentenceCase(buildMode.cliName),
        '$binaryName.exe',
    );
  }

  @override
  String get name => project.parent.manifest.appName;
}