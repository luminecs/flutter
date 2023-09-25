
import '../artifacts.dart';
import '../base/file_system.dart';
import '../build_info.dart';
import 'build_system.dart';
import 'exceptions.dart';

abstract class ResolvedFiles {
  bool get containsNewDepfile;

  List<File> get sources;
}

class SourceVisitor implements ResolvedFiles {
  SourceVisitor(this.environment, [ this.inputs = true ]);

  final Environment environment;

  final bool inputs;

  @override
  final List<File> sources = <File>[];

  @override
  bool get containsNewDepfile => _containsNewDepfile;
  bool _containsNewDepfile = false;

  // depfile logic adopted from https://github.com/flutter/flutter/blob/7065e4330624a5a216c8ffbace0a462617dc1bf5/dev/devicelab/lib/framework/apk_utils.dart#L390
  void visitDepfile(String name) {
    final File depfile = environment.buildDir.childFile(name);
    if (!depfile.existsSync()) {
      _containsNewDepfile = true;
      return;
    }
    final String contents = depfile.readAsStringSync();
    final List<String> colonSeparated = contents.split(': ');
    if (colonSeparated.length != 2) {
      environment.logger.printError('Invalid depfile: ${depfile.path}');
      return;
    }
    if (inputs) {
      sources.addAll(_processList(colonSeparated[1].trim()));
    } else {
      sources.addAll(_processList(colonSeparated[0].trim()));
    }
  }

  final RegExp _separatorExpr = RegExp(r'([^\\]) ');
  final RegExp _escapeExpr = RegExp(r'\\(.)');

  Iterable<File> _processList(String rawText) {
    return rawText
    // Put every file on right-hand side on the separate line
        .replaceAllMapped(_separatorExpr, (Match match) => '${match.group(1)}\n')
        .split('\n')
    // Expand escape sequences, so that '\ ', for example,ß becomes ' '
        .map<String>((String path) => path.replaceAllMapped(_escapeExpr, (Match match) => match.group(1)!).trim())
        .where((String path) => path.isNotEmpty)
        .toSet()
        .map(environment.fileSystem.file);
  }

  void visitPattern(String pattern, bool optional) {
    // perform substitution of the environmental values and then
    // of the local values.
    final List<String> segments = <String>[];
    final List<String> rawParts = pattern.split('/');
    final bool hasWildcard = rawParts.last.contains('*');
    String? wildcardFile;
    if (hasWildcard) {
      wildcardFile = rawParts.removeLast();
    }
    // If the pattern does not start with an env variable, then we have nothing
    // to resolve it to, error out.
    switch (rawParts.first) {
      case Environment.kProjectDirectory:
        segments.addAll(
          environment.fileSystem.path.split(environment.projectDir.resolveSymbolicLinksSync()));
      case Environment.kBuildDirectory:
        segments.addAll(environment.fileSystem.path.split(
          environment.buildDir.resolveSymbolicLinksSync()));
      case Environment.kCacheDirectory:
        segments.addAll(
          environment.fileSystem.path.split(environment.cacheDir.resolveSymbolicLinksSync()));
      case Environment.kFlutterRootDirectory:
        // flutter root will not contain a symbolic link.
        segments.addAll(
          environment.fileSystem.path.split(environment.flutterRootDir.absolute.path));
      case Environment.kOutputDirectory:
        segments.addAll(
          environment.fileSystem.path.split(environment.outputDir.resolveSymbolicLinksSync()));
      default:
        throw InvalidPatternException(pattern);
    }
    rawParts.skip(1).forEach(segments.add);
    final String filePath = environment.fileSystem.path.joinAll(segments);
    if (!hasWildcard) {
      if (optional && !environment.fileSystem.isFileSync(filePath)) {
        return;
      }
      sources.add(environment.fileSystem.file(
        environment.fileSystem.path.normalize(filePath)));
      return;
    }
    // Perform a simple match by splitting the wildcard containing file one
    // the `*`. For example, for `/*.dart`, we get [.dart]. We then check
    // that part of the file matches. If there are values before and after
    // the `*` we need to check that both match without overlapping. For
    // example, `foo_*_.dart`. We want to match `foo_b_.dart` but not
    // `foo_.dart`. To do so, we first subtract the first section from the
    // string if the first segment matches.
    final List<String> wildcardSegments = wildcardFile?.split('*') ?? <String>[];
    if (wildcardSegments.length > 2) {
      throw InvalidPatternException(pattern);
    }
    if (!environment.fileSystem.directory(filePath).existsSync()) {
      environment.fileSystem.directory(filePath).createSync(recursive: true);
    }
    for (final FileSystemEntity entity in environment.fileSystem.directory(filePath).listSync()) {
      final String filename = environment.fileSystem.path.basename(entity.path);
      if (wildcardSegments.isEmpty) {
        sources.add(environment.fileSystem.file(entity.absolute));
      } else if (wildcardSegments.length == 1) {
        if (filename.startsWith(wildcardSegments[0]) ||
            filename.endsWith(wildcardSegments[0])) {
          sources.add(environment.fileSystem.file(entity.absolute));
        }
      } else if (filename.startsWith(wildcardSegments[0])) {
        if (filename.substring(wildcardSegments[0].length).endsWith(wildcardSegments[1])) {
          sources.add(environment.fileSystem.file(entity.absolute));
        }
      }
    }
  }

  void visitArtifact(Artifact artifact, TargetPlatform? platform, BuildMode? mode) {
    // This is not a local engine.
    if (environment.engineVersion != null) {
      sources.add(environment.flutterRootDir
        .childDirectory('bin')
        .childDirectory('internal')
        .childFile('engine.version'),
      );
      return;
    }
    final String path = environment.artifacts
      .getArtifactPath(artifact, platform: platform, mode: mode);
    if (environment.fileSystem.isDirectorySync(path)) {
      sources.addAll(<File>[
        for (final FileSystemEntity entity in environment.fileSystem.directory(path).listSync(recursive: true))
          if (entity is File)
            entity,
      ]);
      return;
    }
    sources.add(environment.fileSystem.file(path));
  }

  void visitHostArtifact(HostArtifact artifact) {
    // This is not a local engine.
    if (environment.engineVersion != null) {
      sources.add(environment.flutterRootDir
        .childDirectory('bin')
        .childDirectory('internal')
        .childFile('engine.version'),
      );
      return;
    }
    final FileSystemEntity entity = environment.artifacts.getHostArtifact(artifact);
    if (entity is Directory) {
      sources.addAll(<File>[
        for (final FileSystemEntity entity in entity.listSync(recursive: true))
          if (entity is File)
            entity,
      ]);
      return;
    }
    sources.add(entity as File);
  }
}

abstract class Source {
  const factory Source.pattern(String pattern, { bool optional }) = _PatternSource;

  const factory Source.artifact(Artifact artifact, {TargetPlatform? platform, BuildMode? mode}) = _ArtifactSource;

  const factory Source.hostArtifact(HostArtifact artifact) = _HostArtifactSource;

  void accept(SourceVisitor visitor);

  bool get implicit;
}

class _PatternSource implements Source {
  const _PatternSource(this.value, { this.optional = false });

  final String value;
  final bool optional;

  @override
  void accept(SourceVisitor visitor) => visitor.visitPattern(value, optional);

  @override
  bool get implicit => value.contains('*');
}

class _ArtifactSource implements Source {
  const _ArtifactSource(this.artifact, { this.platform, this.mode });

  final Artifact artifact;
  final TargetPlatform? platform;
  final BuildMode? mode;

  @override
  void accept(SourceVisitor visitor) => visitor.visitArtifact(artifact, platform, mode);

  @override
  bool get implicit => false;
}

class _HostArtifactSource implements Source {
  const _HostArtifactSource(this.artifact);

  final HostArtifact artifact;

  @override
  void accept(SourceVisitor visitor) => visitor.visitHostArtifact(artifact);

  @override
  bool get implicit => false;
}