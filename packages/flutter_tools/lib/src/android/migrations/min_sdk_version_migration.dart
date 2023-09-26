import 'package:meta/meta.dart';

import '../../base/file_system.dart';
import '../../base/project_migrator.dart';
import '../../project.dart';
import '../gradle_utils.dart';

@visibleForTesting
const String replacementMinSdkText = 'minSdkVersion flutter.minSdkVersion';

@visibleForTesting
const String appGradleNotFoundWarning =
    'Module level build.gradle file not found, skipping minSdkVersion migration.';

class MinSdkVersionMigration extends ProjectMigrator {
  MinSdkVersionMigration(
    AndroidProject project,
    super.logger,
  ) : _project = project;

  final AndroidProject _project;

  @override
  void migrate() {
    // Skip applying migration in modules as the FlutterExtension is not applied.
    if (_project.isModule) {
      return;
    }
    try {
      processFileLines(_project.appGradleFile);
    } on FileSystemException {
      // Skip if we cannot find the app level build.gradle file.
      logger.printTrace(appGradleNotFoundWarning);
    }
  }

  @override
  String migrateFileContents(String fileContents) {
    return fileContents.replaceAll(
        jellyBeanMinSdkVersionMatch, replacementMinSdkText);
  }
}
