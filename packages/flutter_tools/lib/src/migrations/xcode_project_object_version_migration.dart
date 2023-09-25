
import '../base/file_system.dart';
import '../base/project_migrator.dart';
import '../xcode_project.dart';

class XcodeProjectObjectVersionMigration extends ProjectMigrator {
  XcodeProjectObjectVersionMigration(
    XcodeBasedProject project,
    super.logger,
  )   : _xcodeProjectInfoFile = project.xcodeProjectInfoFile,
        _xcodeProjectSchemeFile = project.xcodeProjectSchemeFile;

  final File _xcodeProjectInfoFile;
  final File _xcodeProjectSchemeFile;

  @override
  void migrate() {
    if (_xcodeProjectInfoFile.existsSync()) {
      processFileLines(_xcodeProjectInfoFile);
    } else {
      logger.printTrace('Xcode project not found, skipping Xcode compatibility migration.');
    }
    if (_xcodeProjectSchemeFile.existsSync()) {
      processFileLines(_xcodeProjectSchemeFile);
    } else {
      logger.printTrace('Runner scheme not found, skipping Xcode compatibility migration.');
    }
  }

  @override
  String? migrateLine(String line) {
    String updatedString = line;
    final Map<Pattern, String> originalToReplacement = <Pattern, String>{
      // objectVersion value has been 46, 50, 51, and 54 in the template.
      RegExp(r'objectVersion = \d+;'): 'objectVersion = 54;',
      // LastUpgradeCheck is in the Xcode project file, not scheme file.
      // Value has been 0730, 0800, 1020, 1300, and 1430 in the template.
      RegExp(r'LastUpgradeCheck = \d+;'): 'LastUpgradeCheck = 1430;',
      // LastUpgradeVersion is in the scheme file, not Xcode project file.
      RegExp(r'LastUpgradeVersion = "\d+"'): 'LastUpgradeVersion = "1430"',
    };

    originalToReplacement.forEach((Pattern original, String replacement) {
      if (line.contains(original)) {
        updatedString = line.replaceAll(original, replacement);
        if (!migrationRequired && updatedString != line) {
          // Only print once.
          logger.printStatus('Updating project for Xcode compatibility.');
        }
      }
    });

    return updatedString;
  }
}