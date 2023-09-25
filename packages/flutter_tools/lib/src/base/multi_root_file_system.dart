import 'dart:io' as io
    show
        Directory,
        File,
        FileStat,
        FileSystemEntity,
        FileSystemEntityType,
        Link;

import 'package:file/file.dart';
import 'package:meta/meta.dart';
import 'package:path/path.dart' as p; // flutter_ignore: package_path_import

class MultiRootFileSystem extends ForwardingFileSystem {
  MultiRootFileSystem({
    required FileSystem delegate,
    required String scheme,
    required List<String> roots,
  })   : assert(roots.isNotEmpty),
        _scheme = scheme,
        _roots = roots.map((String root) => delegate.path.normalize(root)).toList(),
        super(delegate);

  @visibleForTesting
  FileSystem get fileSystem => delegate;

  final String _scheme;
  final List<String> _roots;

  @override
  File file(dynamic path) => MultiRootFile(
    fileSystem: this,
    delegate: delegate.file(_resolve(path)),
  );

  @override
  Directory directory(dynamic path) => MultiRootDirectory(
    fileSystem: this,
    delegate: delegate.directory(_resolve(path)),
  );

  @override
  Link link(dynamic path) => MultiRootLink(
    fileSystem: this,
    delegate: delegate.link(_resolve(path)),
  );

  @override
  Future<io.FileStat> stat(String path) =>
    delegate.stat(_resolve(path).toString());

  @override
  io.FileStat statSync(String path) =>
    delegate.statSync(_resolve(path).toString());

  @override
  Future<bool> identical(String path1, String path2) =>
    delegate.identical(_resolve(path1).toString(), _resolve(path2).toString());

  @override
  bool identicalSync(String path1, String path2) =>
    delegate.identicalSync(_resolve(path1).toString(), _resolve(path2).toString());

  @override
  Future<io.FileSystemEntityType> type(String path, {bool followLinks = true}) =>
    delegate.type(_resolve(path).toString(), followLinks: followLinks);

  @override
  io.FileSystemEntityType typeSync(String path, {bool followLinks = true}) =>
    delegate.typeSync(_resolve(path).toString(), followLinks: followLinks);

  // Caching the path context here and clearing when the currentDirectory setter
  // is updated works since the flutter tool restricts usage of dart:io directly
  // via the forbidden import tests. Otherwise, the path context's current
  // working directory might get out of sync, leading to unexpected results from
  // methods like `path.relative`.
  @override
  p.Context get path => _cachedPath ??= delegate.path;
  p.Context? _cachedPath;

  @override
  set currentDirectory(dynamic path) {
    _cachedPath = null;
    delegate.currentDirectory = path;
  }

  dynamic _resolve(dynamic path) {
    Uri uri;
    if (path == null) {
      return null;
    } else if (path is String) {
      uri = Uri.parse(path);
    } else if (path is Uri) {
      uri = path;
    } else if (path is FileSystemEntity) {
      uri = path.uri;
    } else {
      throw ArgumentError('Invalid type for "path": ${(path as Object?)?.runtimeType}');
    }

    if (!uri.hasScheme || uri.scheme != _scheme) {
      return path;
    }

    String? firstRootPath;
    final String relativePath = delegate.path.joinAll(uri.pathSegments);
    for (final String root in _roots) {
      final String pathWithRoot = delegate.path.join(root, relativePath);
      if (delegate.typeSync(pathWithRoot, followLinks: false) !=
          FileSystemEntityType.notFound) {
        return pathWithRoot;
      }
      firstRootPath ??= pathWithRoot;
    }

    // If not found, construct the path with the first root.
    return firstRootPath!;
  }

  Uri _toMultiRootUri(Uri uri) {
    if (uri.scheme != 'file') {
      return uri;
    }

    final p.Context pathContext = delegate.path;
    final bool isWindows = pathContext.style == p.Style.windows;
    final String path = uri.toFilePath(windows: isWindows);
    for (final String root in _roots) {
      if (path.startsWith('$root${pathContext.separator}')) {
        String pathWithoutRoot = path.substring(root.length + 1);
        if (isWindows) {
          // Convert the path from Windows style
          pathWithoutRoot = p.url.joinAll(pathContext.split(pathWithoutRoot));
        }
        return Uri.parse('$_scheme:///$pathWithoutRoot');
      }
    }
    return uri;
  }

  @override
  String toString() =>
    'MultiRootFileSystem(scheme = $_scheme, roots = $_roots, delegate = $delegate)';
}

abstract class MultiRootFileSystemEntity<T extends FileSystemEntity,
    D extends io.FileSystemEntity> extends ForwardingFileSystemEntity<T, D> {
  MultiRootFileSystemEntity({
    required this.fileSystem,
    required this.delegate,
  });

  @override
  final D delegate;

  @override
  final MultiRootFileSystem fileSystem;

  @override
  File wrapFile(io.File delegate) => MultiRootFile(
    fileSystem: fileSystem,
    delegate: delegate,
  );

  @override
  Directory wrapDirectory(io.Directory delegate) => MultiRootDirectory(
    fileSystem: fileSystem,
    delegate: delegate,
  );

  @override
  Link wrapLink(io.Link delegate) => MultiRootLink(
    fileSystem: fileSystem,
    delegate: delegate,
  );

  @override
  Uri get uri => fileSystem._toMultiRootUri(delegate.uri);
}

class MultiRootFile extends MultiRootFileSystemEntity<File, io.File>
    // TODO(goderbauer): Fix this ignore when https://github.com/google/file.dart/issues/209 is resolved.
    with ForwardingFile { // ignore: prefer_mixin
  MultiRootFile({
    required super.fileSystem,
    required super.delegate,
  });

  @override
  String toString() =>
    'MultiRootFile(fileSystem = $fileSystem, delegate = $delegate)';
}

class MultiRootDirectory
    extends MultiRootFileSystemEntity<Directory, io.Directory>
    // TODO(goderbauer): Fix this ignore when https://github.com/google/file.dart/issues/209 is resolved.
    with ForwardingDirectory<Directory> { // ignore: prefer_mixin
  MultiRootDirectory({
    required super.fileSystem,
    required super.delegate,
  });

  // For the childEntity methods, we first obtain an instance of the entity
  // from the underlying file system, then invoke childEntity() on it, then
  // wrap in the ErrorHandling version.
  @override
  Directory childDirectory(String basename) =>
    fileSystem.directory(fileSystem.path.join(delegate.path, basename));

  @override
  File childFile(String basename) =>
    fileSystem.file(fileSystem.path.join(delegate.path, basename));

  @override
  Link childLink(String basename) =>
    fileSystem.link(fileSystem.path.join(delegate.path, basename));

  @override
  String toString() =>
    'MultiRootDirectory(fileSystem = $fileSystem, delegate = $delegate)';
}

class MultiRootLink extends MultiRootFileSystemEntity<Link, io.Link>
    // TODO(goderbauer): Fix this ignore when https://github.com/google/file.dart/issues/209 is resolved.
    with ForwardingLink { // ignore: prefer_mixin
  MultiRootLink({
    required super.fileSystem,
    required super.delegate,
  });

  @override
  String toString() =>
    'MultiRootLink(fileSystem = $fileSystem, delegate = $delegate)';
}