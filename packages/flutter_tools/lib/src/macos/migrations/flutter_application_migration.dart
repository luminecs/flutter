
import '../../base/file_system.dart';
import '../../base/project_migrator.dart';
import '../../globals.dart' as globals;
import '../../ios/plist_parser.dart';
import '../../xcode_project.dart';

class FlutterApplicationMigration extends ProjectMigrator {
  FlutterApplicationMigration(
    MacOSProject project,
    super.logger,
  ) : _infoPlistFile = project.defaultHostInfoPlist;

  final File _infoPlistFile;

  @override
  void migrate() {
    if (_infoPlistFile.existsSync()) {
      final String? principalClass =
          globals.plistParser.getValueFromFile<String>(_infoPlistFile.path, PlistParser.kNSPrincipalClassKey);
      if (principalClass == null || principalClass == 'NSApplication') {
        // No NSPrincipalClass defined, or already converted. No migration
        // needed.
        return;
      }
      if (principalClass != 'FlutterApplication') {
        // If the principal class wasn't already migrated to
        // FlutterApplication, there's no need to revert the migration.
        return;
      }
      logger.printStatus('Updating ${_infoPlistFile.basename} to use NSApplication instead of FlutterApplication.');
      final bool success = globals.plistParser.replaceKey(_infoPlistFile.path, key: PlistParser.kNSPrincipalClassKey, value: 'NSApplication');
      if (!success) {
        logger.printError('Updating ${_infoPlistFile.basename} failed.');
      }
    }
  }
}