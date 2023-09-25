import '../../base/file_system.dart';
import '../../base/project_migrator.dart';
import '../../project.dart';

const String _eagerCleanTaskDeclaration = '''
task clean(type: Delete) {
    delete rootProject.buildDir
}
''';

const String _lazyCleanTaskDeclaration = '''
tasks.register("clean", Delete) {
    delete rootProject.buildDir
}
''';

class TopLevelGradleBuildFileMigration extends ProjectMigrator {
  TopLevelGradleBuildFileMigration(
    AndroidProject project,
    super.logger,
  ) : _topLevelGradleBuildFile = project.hostAppGradleRoot.childFile('build.gradle');

  final File _topLevelGradleBuildFile;

  @override
  void migrate() {
    if (!_topLevelGradleBuildFile.existsSync()) {
      logger.printTrace('Top-level Gradle build file not found, skipping migration of task "clean".');
      return;
    }

    processFileLines(_topLevelGradleBuildFile);
  }

  @override
  String migrateFileContents(String fileContents) {
    final String newContents = fileContents.replaceAll(
      _eagerCleanTaskDeclaration,
      _lazyCleanTaskDeclaration,
    );

    if (newContents != fileContents) {
      logger.printTrace('Migrating "clean" Gradle task to lazy declaration style.');
    }

    return newContents;
  }
}