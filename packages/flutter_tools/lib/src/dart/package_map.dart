import 'dart:typed_data';

import 'package:package_config/package_config.dart';

import '../base/common.dart';
import '../base/file_system.dart';
import '../base/logger.dart';

Future<PackageConfig> loadPackageConfigWithLogging(
  File file, {
  required Logger logger,
  bool throwOnError = true,
}) async {
  final FileSystem fileSystem = file.fileSystem;
  bool didError = false;
  final PackageConfig result =
      await loadPackageConfigUri(file.absolute.uri, loader: (Uri uri) async {
    final File configFile = fileSystem.file(uri);
    if (!configFile.existsSync()) {
      return null;
    }
    return Future<Uint8List>.value(configFile.readAsBytesSync());
  }, onError: (dynamic error) {
    if (!throwOnError) {
      return;
    }
    logger.printTrace(error.toString());
    String message = '${file.path} does not exist.';
    final String pubspecPath = fileSystem.path
        .absolute(fileSystem.path.dirname(file.path), 'pubspec.yaml');
    if (fileSystem.isFileSync(pubspecPath)) {
      message += '\nDid you run "flutter pub get" in this directory?';
    } else {
      message +=
          '\nDid you run this command from the same directory as your pubspec.yaml file?';
    }
    logger.printError(message);
    didError = true;
  });
  if (didError) {
    throwToolExit('');
  }
  return result;
}
