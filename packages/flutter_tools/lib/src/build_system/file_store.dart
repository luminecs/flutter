import 'dart:collection';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../base/file_system.dart';
import '../base/logger.dart';
import '../base/utils.dart';
import '../convert.dart';
import 'hash.dart';

class FileStorage {
  FileStorage(this.version, this.files);

  factory FileStorage.fromBuffer(Uint8List buffer) {
    final Map<String, dynamic>? json = castStringKeyedMap(jsonDecode(utf8.decode(buffer)));
    if (json == null) {
      throw Exception('File storage format invalid');
    }
    final int version = json['version'] as int;
    final List<Map<String, dynamic>> rawCachedFiles = (json['files'] as List<dynamic>).cast<Map<String, dynamic>>();
    final List<FileHash> cachedFiles = <FileHash>[
      for (final Map<String, dynamic> rawFile in rawCachedFiles) FileHash._fromJson(rawFile),
    ];
    return FileStorage(version, cachedFiles);
  }

  final int version;
  final List<FileHash> files;

  List<int> toBuffer() {
    final Map<String, Object> json = <String, Object>{
      'version': version,
      'files': <Object>[
        for (final FileHash file in files) file.toJson(),
      ],
    };
    return utf8.encode(jsonEncode(json));
  }
}

class FileHash {
  FileHash(this.path, this.hash);

  factory FileHash._fromJson(Map<String, dynamic> json) {
    if (!json.containsKey('path') || !json.containsKey('hash')) {
      throw Exception('File storage format invalid');
    }
    return FileHash(json['path']! as String, json['hash']! as String);
  }

  final String path;
  final String hash;

  Object toJson() {
    return <String, Object>{
      'path': path,
      'hash': hash,
    };
  }
}

enum FileStoreStrategy {
  hash,

  timestamp,
}

class FileStore {
  FileStore({
    required File cacheFile,
    required Logger logger,
    FileStoreStrategy strategy = FileStoreStrategy.hash,
  }) : _logger = logger,
       _strategy = strategy,
       _cacheFile = cacheFile;

  final File _cacheFile;
  final Logger _logger;
  final FileStoreStrategy _strategy;

  final HashMap<String, String> previousAssetKeys = HashMap<String, String>();
  final HashMap<String, String> currentAssetKeys = HashMap<String, String>();

  // The name of the file which stores the file hashes.
  static const String kFileCache = '.filecache';

  // The current version of the file cache storage format.
  static const int _kVersion = 2;

  void initialize() {
    _logger.printTrace('Initializing file store');
    if (!_cacheFile.existsSync()) {
      return;
    }
    Uint8List data;
    try {
      data = _cacheFile.readAsBytesSync();
    } on FileSystemException catch (err) {
      _logger.printError(
        'Failed to read file store at ${_cacheFile.path} due to $err.\n'
        'Build artifacts will not be cached. Try clearing the cache directories '
        'with "flutter clean"',
      );
      return;
    }

    FileStorage fileStorage;
    try {
      fileStorage = FileStorage.fromBuffer(data);
    } on Exception catch (err) {
      _logger.printTrace('Filestorage format changed: $err');
      _cacheFile.deleteSync();
      return;
    }
    if (fileStorage.version != _kVersion) {
      _logger.printTrace('file cache format updating, clearing old hashes.');
      _cacheFile.deleteSync();
      return;
    }
    for (final FileHash fileHash in fileStorage.files) {
      previousAssetKeys[fileHash.path] = fileHash.hash;
    }
    _logger.printTrace('Done initializing file store');
  }

  void persist() {
    _logger.printTrace('Persisting file store');
    if (!_cacheFile.existsSync()) {
      _cacheFile.createSync(recursive: true);
    }
    final List<FileHash> fileHashes = <FileHash>[];
    for (final MapEntry<String, String> entry in currentAssetKeys.entries) {
      fileHashes.add(FileHash(entry.key, entry.value));
    }
    final FileStorage fileStorage = FileStorage(
      _kVersion,
      fileHashes,
    );
    final List<int> buffer = fileStorage.toBuffer();
    try {
      _cacheFile.writeAsBytesSync(buffer);
    } on FileSystemException catch (err) {
      _logger.printError(
        'Failed to persist file store at ${_cacheFile.path} due to $err.\n'
        'Build artifacts will not be cached. Try clearing the cache directories '
        'with "flutter clean"',
      );
    }
    _logger.printTrace('Done persisting file store');
  }

  void persistIncremental() {
    previousAssetKeys.clear();
    previousAssetKeys.addAll(currentAssetKeys);
    currentAssetKeys.clear();
  }

  List<File> diffFileList(List<File> files) {
    final List<File> dirty = <File>[];
    switch (_strategy) {
      case FileStoreStrategy.hash:
        for (final File file in files) {
          _hashFile(file, dirty);
        }
      case FileStoreStrategy.timestamp:
        for (final File file in files) {
          _checkModification(file, dirty);
        }
    }
    return dirty;
  }

  void _checkModification(File file, List<File> dirty) {
    final String absolutePath = file.path;
    final String? previousTime = previousAssetKeys[absolutePath];

    // If the file is missing it is assumed to be dirty.
    if (!file.existsSync()) {
      currentAssetKeys.remove(absolutePath);
      previousAssetKeys.remove(absolutePath);
      dirty.add(file);
      return;
    }
    final String modifiedTime = file.lastModifiedSync().toString();
    if (modifiedTime != previousTime) {
      dirty.add(file);
    }
    currentAssetKeys[absolutePath] = modifiedTime;
  }

  // 64k is the same sized buffer used by dart:io for `File.openRead`.
  static final Uint8List _readBuffer = Uint8List(64 * 1024);

  void _hashFile(File file, List<File> dirty) {
    final String absolutePath = file.path;
    final String? previousHash = previousAssetKeys[absolutePath];
    // If the file is missing it is assumed to be dirty.
    if (!file.existsSync()) {
      currentAssetKeys.remove(absolutePath);
      previousAssetKeys.remove(absolutePath);
      dirty.add(file);
      return;
    }
    final int fileBytes = file.lengthSync();
    final Md5Hash hash = Md5Hash();
    RandomAccessFile? openFile;
    try {
      openFile = file.openSync();
      int bytes = 0;
      while (bytes < fileBytes) {
        final int bytesRead = openFile.readIntoSync(_readBuffer);
        hash.addChunk(_readBuffer, bytesRead);
        bytes += bytesRead;
      }
    } finally {
      openFile?.closeSync();
    }
    final Digest digest = Digest(hash.finalize().buffer.asUint8List());
    final String currentHash = digest.toString();
    if (currentHash != previousHash) {
      dirty.add(file);
    }
    currentAssetKeys[absolutePath] = currentHash;
  }
}