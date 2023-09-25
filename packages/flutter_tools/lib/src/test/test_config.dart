import '../base/file_system.dart';
import '../base/logger.dart';

const String _kTestConfigFileName = 'flutter_test_config.dart';

const String _kProjectRootSentinel = 'pubspec.yaml';

File? findTestConfigFile(File testFile, Logger logger) {
  File? testConfigFile;
  Directory directory = testFile.parent;
  while (directory.path != directory.parent.path) {
    final File configFile = directory.childFile(_kTestConfigFileName);
    if (configFile.existsSync()) {
      logger.printTrace('Discovered $_kTestConfigFileName in ${directory.path}');
      testConfigFile = configFile;
      break;
    }
    if (directory.childFile(_kProjectRootSentinel).existsSync()) {
      logger.printTrace('Stopping scan for $_kTestConfigFileName; '
          'found project root at ${directory.path}');
      break;
    }
    directory = directory.parent;
  }
  return testConfigFile;
}