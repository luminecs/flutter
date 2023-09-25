
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:meta/meta.dart';
import 'package:pool/pool.dart';
import 'package:process/process.dart';

import '../../artifacts.dart';
import '../../base/error_handling_io.dart';
import '../../base/file_system.dart';
import '../../base/io.dart';
import '../../base/logger.dart';
import '../../convert.dart';
import '../../devfs.dart';
import '../build_system.dart';

class DevelopmentSceneImporter {
  DevelopmentSceneImporter({
    required SceneImporter sceneImporter,
    required FileSystem fileSystem,
    @visibleForTesting math.Random? random,
  }) : _sceneImporter = sceneImporter,
       _fileSystem = fileSystem,
       _random = random ?? math.Random();

  final SceneImporter _sceneImporter;
  final FileSystem _fileSystem;
  final Pool _compilationPool = Pool(4);
  final math.Random _random;

  Future<DevFSContent?> reimportScene(DevFSContent inputScene) async {
    final File output = _fileSystem.systemTempDirectory.childFile('${_random.nextDouble()}.temp');
    late File inputFile;
    bool cleanupInput = false;
    Uint8List result;
    PoolResource? resource;
    try {
      resource = await _compilationPool.request();
      if (inputScene is DevFSFileContent) {
        inputFile = inputScene.file as File;
      } else {
        inputFile = _fileSystem.systemTempDirectory.childFile('${_random.nextDouble()}.temp');
        inputFile.writeAsBytesSync(await inputScene.contentsAsBytes());
        cleanupInput = true;
      }
      final bool success = await _sceneImporter.importScene(
        input: inputFile,
        outputPath: output.path,
        fatal: false,
      );
      if (!success) {
        return null;
      }
      result = output.readAsBytesSync();
    } finally {
      resource?.release();
      ErrorHandlingFileSystem.deleteIfExists(output);
      if (cleanupInput) {
        ErrorHandlingFileSystem.deleteIfExists(inputFile);
      }
    }
    return DevFSByteContent(result);
  }
}

class SceneImporter {
  SceneImporter({
    required ProcessManager processManager,
    required Logger logger,
    required FileSystem fileSystem,
    required Artifacts artifacts,
  })  : _processManager = processManager,
        _logger = logger,
        _fs = fileSystem,
        _artifacts = artifacts;

  final ProcessManager _processManager;
  final Logger _logger;
  final FileSystem _fs;
  final Artifacts _artifacts;

  static const List<Source> inputs = <Source>[
    Source.pattern(
        '{FLUTTER_ROOT}/packages/flutter_tools/lib/src/build_system/targets/scene_importer.dart'),
    Source.hostArtifact(HostArtifact.scenec),
  ];

  Future<bool> importScene({
    required File input,
    required String outputPath,
    bool fatal = true,
  }) async {
    final File scenec = _fs.file(
      _artifacts.getHostArtifact(HostArtifact.scenec),
    );
    if (!scenec.existsSync()) {
      throw SceneImporterException._(
        'The scenec utility is missing at "${scenec.path}". '
        'Run "flutter doctor".',
      );
    }

    final List<String> cmd = <String>[
      scenec.path,
      '--input=${input.path}',
      '--output=$outputPath',
    ];
    _logger.printTrace('scenec command: $cmd');
    final Process scenecProcess = await _processManager.start(cmd);
    final int code = await scenecProcess.exitCode;
    if (code != 0) {
      final String stdout = await utf8.decodeStream(scenecProcess.stdout);
      final String stderr = await utf8.decodeStream(scenecProcess.stderr);
      _logger.printTrace(stdout);
      _logger.printError(stderr);
      if (fatal) {
        throw SceneImporterException._(
          'Scene import of "${input.path}" to "$outputPath" '
          'failed with exit code $code.\n'
          'scenec stdout:\n$stdout\n'
          'scenec stderr:\n$stderr',
        );
      }
      return false;
    }
    return true;
  }
}

class SceneImporterException implements Exception {
  SceneImporterException._(this.message);

  final String message;

  @override
  String toString() => 'SceneImporterException: $message\n\n';
}