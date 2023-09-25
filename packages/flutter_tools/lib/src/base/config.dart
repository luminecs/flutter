import 'package:file/memory.dart';
import 'package:meta/meta.dart';

import '../convert.dart';
import 'error_handling_io.dart';
import 'file_system.dart';
import 'logger.dart';
import 'platform.dart';
import 'utils.dart';

class Config {
  factory Config(
    String name, {
    required FileSystem fileSystem,
    required Logger logger,
    required Platform platform
  }) {
    return Config._common(
      name,
      fileSystem: fileSystem,
      logger: logger,
      platform: platform
    );
  }

  factory Config.managed(
    String name, {
    required FileSystem fileSystem,
    required Logger logger,
    required Platform platform
  }) {
    return Config._common(
      name,
      fileSystem: fileSystem,
      logger: logger,
      platform: platform,
      managed: true
    );
  }

  factory Config._common(
    String name, {
    required FileSystem fileSystem,
    required Logger logger,
    required Platform platform,
    bool managed = false
  }) {
    final String filePath = _configPath(platform, fileSystem, name);
    final File file = fileSystem.file(filePath);
    file.parent.createSync(recursive: true);
    return Config.createForTesting(file, logger, managed: managed);
  }

  factory Config.test({
    String name = 'test',
    Directory? directory,
    Logger? logger,
    bool managed = false
  }) {
    directory ??= MemoryFileSystem.test().directory('/');
    return Config.createForTesting(
      directory.childFile('.${kConfigDir}_$name'),
      logger ?? BufferLogger.test(),
      managed: managed
    );
  }

  @visibleForTesting
  Config.createForTesting(File file, Logger logger, {bool managed = false}) : _file = file, _logger = logger {
    if (!_file.existsSync()) {
      return;
    }
    try {
      ErrorHandlingFileSystem.noExitOnFailure(() {
        _values = castStringKeyedMap(json.decode(_file.readAsStringSync())) ?? <String, Object>{};
      });
    } on FormatException {
      _logger
        ..printError('Failed to decode preferences in ${_file.path}.')
        ..printError(
          'You may need to reapply any previously saved configuration '
          'with the "flutter config" command.',
        );

      if (managed) {
        rethrow;
      } else {
        try {
          _file.deleteSync();
        } on FileSystemException {
          // ignore
        }
      }
    } on Exception catch (err) {
      _logger
        ..printError('Could not read preferences in ${file.path}.\n$err')
        ..printError(
          'You may need to resolve the error above and reapply any previously '
          'saved configuration with the "flutter config" command.',
        );

      if (managed) {
        rethrow;
      }
    }
  }


  static const String kConfigDir = 'flutter';

  static const String kXdgConfigHome = 'XDG_CONFIG_HOME';

  static const String kXdgConfigFallback = '.config';

  static const String kFlutterSettings = 'settings';

  final Logger _logger;

  File _file;

  String get configPath => _file.path;

  Map<String, dynamic> _values = <String, Object>{};

  Iterable<String> get keys => _values.keys;

  bool containsKey(String key) => _values.containsKey(key);

  Object? getValue(String key) => _values[key];

  void setValue(String key, Object value) {
    _values[key] = value;
    _flushValues();
  }

  void removeValue(String key) {
    _values.remove(key);
    _flushValues();
  }

  void _flushValues() {
    String json = const JsonEncoder.withIndent('  ').convert(_values);
    json = '$json\n';
    _file.writeAsStringSync(json);
  }

  // Reads the process environment to find the current user's home directory.
  //
  // If the searched environment variables are not set, '.' is returned instead.
  //
  // This is different from [FileSystemUtils.homeDirPath].
  static String _userHomePath(Platform platform) {
    final String envKey = platform.isWindows ? 'APPDATA' : 'HOME';
    return platform.environment[envKey] ?? '.';
  }

  static String _configPath(
      Platform platform, FileSystem fileSystem, String name) {
    final String homeDirFile =
        fileSystem.path.join(_userHomePath(platform), '.${kConfigDir}_$name');
    if (platform.isLinux || platform.isMacOS) {
      if (fileSystem.isFileSync(homeDirFile)) {
        return homeDirFile;
      }
      final String configDir = platform.environment[kXdgConfigHome] ??
          fileSystem.path.join(_userHomePath(platform), '.config', kConfigDir);
      return fileSystem.path.join(configDir, name);
    }
    return homeDirFile;
  }
}