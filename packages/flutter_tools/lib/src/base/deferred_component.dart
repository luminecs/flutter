
import '../base/file_system.dart';
import '../base/logger.dart';
import '../convert.dart';

class DeferredComponent {
  DeferredComponent({
    required this.name,
    this.libraries = const <String>[],
    this.assets = const <Uri>[],
  }) : _assigned = false;

  final String name;

  final List<String> libraries;

  final List<Uri> assets;

  Set<LoadingUnit>? get loadingUnits => _loadingUnits;
  Set<LoadingUnit>? _loadingUnits;

  bool get assigned => _assigned;
  bool _assigned;

  void assignLoadingUnits(List<LoadingUnit> allLoadingUnits) {
    _assigned = true;
    _loadingUnits = <LoadingUnit>{};
    for (final String lib in libraries) {
      for (final LoadingUnit loadingUnit in allLoadingUnits) {
        if (loadingUnit.libraries.contains(lib)) {
          _loadingUnits!.add(loadingUnit);
        }
      }
    }
  }

  @override
  String toString() {
    final StringBuffer out = StringBuffer('\nDeferredComponent: $name\n  Libraries:');
    for (final String lib in libraries) {
      out.write('\n    - $lib');
    }
    if (loadingUnits != null && _assigned) {
      out.write('\n  LoadingUnits:');
      for (final LoadingUnit loadingUnit in loadingUnits!) {
        out.write('\n    - ${loadingUnit.id}');
      }
    }
    out.write('\n  Assets:');
    for (final Uri asset in assets) {
      out.write('\n    - ${asset.path}');
    }
    return out.toString();
  }
}

class LoadingUnit {
  LoadingUnit({
    required this.id,
    required this.libraries,
    this.path,
  });

  final int id;

  final List<String> libraries;

  final String? path;

  @override
  String toString() {
    final StringBuffer out = StringBuffer('\nLoadingUnit $id\n  Libraries:');
    for (final String lib in libraries) {
      out.write('\n  - $lib');
    }
    return out.toString();
  }

  bool equalsIgnoringPath(LoadingUnit other) {
    return other.id == id && other.libraries.toSet().containsAll(libraries);
  }

  static List<LoadingUnit> parseGeneratedLoadingUnits(Directory outputDir, Logger logger, {List<String>? abis}) {
    final List<LoadingUnit> loadingUnits = <LoadingUnit>[];
    final List<FileSystemEntity> files = outputDir.listSync(recursive: true);
    for (final FileSystemEntity fileEntity in files) {
      if (fileEntity is File) {
        final File file = fileEntity;
        // Determine if the abi is one we build.
        bool matchingAbi = abis == null;
        if (abis != null) {
          for (final String abi in abis) {
            if (file.parent.path.endsWith(abi)) {
              matchingAbi = true;
              break;
            }
          }
        }
        if (!file.path.endsWith('manifest.json') || !matchingAbi) {
          continue;
        }
        loadingUnits.addAll(parseLoadingUnitManifest(file, logger));
      }
    }
    return loadingUnits;
  }

  static List<LoadingUnit> parseLoadingUnitManifest(File manifestFile, Logger logger) {
    if (!manifestFile.existsSync()) {
      return <LoadingUnit>[];
    }
    // Read gen_snapshot manifest
    final String fileString = manifestFile.readAsStringSync();
    Map<String, dynamic>? manifest;
    try {
      manifest = jsonDecode(fileString) as Map<String, dynamic>;
    } on FormatException catch (e) {
      logger.printError('Loading unit manifest at `${manifestFile.path}` was invalid JSON:\n$e');
    }
    final List<LoadingUnit> loadingUnits = <LoadingUnit>[];
    // Setup android source directory
    if (manifest != null) {
      for (final dynamic loadingUnitMetadata in manifest['loadingUnits'] as List<dynamic>) {
        final Map<String, dynamic> loadingUnitMap = loadingUnitMetadata as Map<String, dynamic>;
        if (loadingUnitMap['id'] == 1) {
          continue; // Skip base unit
        }
        loadingUnits.add(LoadingUnit(
          id: loadingUnitMap['id'] as int,
          path: loadingUnitMap['path'] as String,
          libraries: List<String>.from(loadingUnitMap['libraries'] as List<dynamic>)),
        );
      }
    }
    return loadingUnits;
  }
}