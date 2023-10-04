import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:meta/meta.dart';
import 'package:platform/platform.dart';

HostAgent get hostAgent => HostAgent(
    platform: const LocalPlatform(), fileSystem: const LocalFileSystem());

class HostAgent {
  HostAgent({required Platform platform, required FileSystem fileSystem})
      : _platform = platform,
        _fileSystem = fileSystem;

  final Platform _platform;
  final FileSystem _fileSystem;

  Directory? get dumpDirectory {
    if (_dumpDirectory == null) {
      // Set in LUCI recipe.
      final String? directoryPath = _platform.environment['FLUTTER_LOGS_DIR'];
      if (directoryPath != null) {
        _dumpDirectory = _fileSystem.directory(directoryPath)
          ..createSync(recursive: true);
        print('Found FLUTTER_LOGS_DIR dump directory ${_dumpDirectory?.path}');
      }
    }
    return _dumpDirectory;
  }

  static Directory? _dumpDirectory;

  @visibleForTesting
  void resetDumpDirectory() {
    _dumpDirectory = null;
  }
}
