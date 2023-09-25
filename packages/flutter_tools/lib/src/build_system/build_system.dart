// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:async/async.dart';
import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';
import 'package:meta/meta.dart';
import 'package:pool/pool.dart';
import 'package:process/process.dart';

import '../artifacts.dart';
import '../base/error_handling_io.dart';
import '../base/file_system.dart';
import '../base/logger.dart';
import '../base/platform.dart';
import '../base/utils.dart';
import '../cache.dart';
import '../convert.dart';
import '../reporting/reporting.dart';
import 'depfile.dart';
import 'exceptions.dart';
import 'file_store.dart';
import 'source.dart';

export 'source.dart';

const int kMaxOpenFiles = 64;

class BuildSystemConfig {
  const BuildSystemConfig({this.resourcePoolSize});

  final int? resourcePoolSize;
}

abstract class Target {
  const Target();
  String get name;

  String get analyticsName => name;

  List<Target> get dependencies;

  List<Source> get inputs;

  List<Source> get outputs;

  List<String> get depfiles => const <String>[];

  bool canSkip(Environment environment) => false;

  Future<void> build(Environment environment);

  Node _toNode(Environment environment) {
    final ResolvedFiles inputsFiles = resolveInputs(environment);
    final ResolvedFiles outputFiles = resolveOutputs(environment);
    return Node(
      this,
      inputsFiles.sources,
      outputFiles.sources,
      <Node>[
        for (final Target target in dependencies) target._toNode(environment),
      ],
      environment,
      inputsFiles.containsNewDepfile,
    );
  }

  void clearStamp(Environment environment) {
    final File stamp = _findStampFile(environment);
    ErrorHandlingFileSystem.deleteIfExists(stamp);
  }

  void _writeStamp(
    List<File> inputs,
    List<File> outputs,
    Environment environment,
  ) {
    final File stamp = _findStampFile(environment);
    final List<String> inputPaths = <String>[];
    for (final File input in inputs) {
      inputPaths.add(input.path);
    }
    final List<String> outputPaths = <String>[];
    for (final File output in outputs) {
      outputPaths.add(output.path);
    }
    final Map<String, Object> result = <String, Object>{
      'inputs': inputPaths,
      'outputs': outputPaths,
    };
    if (!stamp.existsSync()) {
      stamp.createSync();
    }
    stamp.writeAsStringSync(json.encode(result));
  }

  ResolvedFiles resolveInputs(Environment environment) {
    return _resolveConfiguration(inputs, depfiles, environment);
  }

  ResolvedFiles resolveOutputs(Environment environment) {
    return _resolveConfiguration(outputs, depfiles, environment, inputs: false);
  }

  T fold<T>(T initialValue, T Function(T previousValue, Target target) combine) {
    final T dependencyResult = dependencies.fold(
        initialValue, (T prev, Target t) => t.fold(prev, combine));
    return combine(dependencyResult, this);
  }

  Map<String, Object> toJson(Environment environment) {
    return <String, Object>{
      'name': name,
      'dependencies': <String>[
        for (final Target target in dependencies) target.name,
      ],
      'inputs': <String>[
        for (final File file in resolveInputs(environment).sources) file.path,
      ],
      'outputs': <String>[
        for (final File file in resolveOutputs(environment).sources) file.path,
      ],
      'stamp': _findStampFile(environment).absolute.path,
    };
  }

  File _findStampFile(Environment environment) {
    final String fileName = '$name.stamp';
    return environment.buildDir.childFile(fileName);
  }

  static ResolvedFiles _resolveConfiguration(
    List<Source> config,
    List<String> depfiles,
    Environment environment, {
    bool inputs = true,
  }) {
    final SourceVisitor collector = SourceVisitor(environment, inputs);
    for (final Source source in config) {
      source.accept(collector);
    }
    depfiles.forEach(collector.visitDepfile);
    return collector;
  }
}

class CompositeTarget extends Target {
  CompositeTarget(this.dependencies);

  @override
  final List<Target> dependencies;

  @override
  String get name => '_composite';

  @override
  Future<void> build(Environment environment) async { }

  @override
  List<Source> get inputs => <Source>[];

  @override
  List<Source> get outputs => <Source>[];
}

class Environment {
  factory Environment({
    required Directory projectDir,
    required Directory outputDir,
    required Directory cacheDir,
    required Directory flutterRootDir,
    required FileSystem fileSystem,
    required Logger logger,
    required Artifacts artifacts,
    required ProcessManager processManager,
    required Platform platform,
    required Usage usage,
    String? engineVersion,
    required bool generateDartPluginRegistry,
    Directory? buildDir,
    Map<String, String> defines = const <String, String>{},
    Map<String, String> inputs = const <String, String>{},
  }) {
    // Compute a unique hash of this build's particular environment.
    // Sort the keys by key so that the result is stable. We always
    // include the engine and dart versions.
    String buildPrefix;
    final List<String> keys = defines.keys.toList()..sort();
    final StringBuffer buffer = StringBuffer();
    // The engine revision is `null` for local or custom engines.
    if (engineVersion != null) {
      buffer.write(engineVersion);
    }
    for (final String key in keys) {
      buffer.write(key);
      buffer.write(defines[key]);
    }
    buffer.write(outputDir.path);
    final String output = buffer.toString();
    final Digest digest = md5.convert(utf8.encode(output));
    buildPrefix = hex.encode(digest.bytes);

    final Directory rootBuildDir = buildDir ?? projectDir.childDirectory('build');
    final Directory buildDirectory = rootBuildDir.childDirectory(buildPrefix);
    return Environment._(
      outputDir: outputDir,
      projectDir: projectDir,
      buildDir: buildDirectory,
      rootBuildDir: rootBuildDir,
      cacheDir: cacheDir,
      defines: defines,
      flutterRootDir: flutterRootDir,
      fileSystem: fileSystem,
      logger: logger,
      artifacts: artifacts,
      processManager: processManager,
      platform: platform,
      usage: usage,
      engineVersion: engineVersion,
      inputs: inputs,
      generateDartPluginRegistry: generateDartPluginRegistry,
    );
  }

  @visibleForTesting
  factory Environment.test(Directory testDirectory, {
    Directory? projectDir,
    Directory? outputDir,
    Directory? cacheDir,
    Directory? flutterRootDir,
    Directory? buildDir,
    Map<String, String> defines = const <String, String>{},
    Map<String, String> inputs = const <String, String>{},
    String? engineVersion,
    Platform? platform,
    Usage? usage,
    bool generateDartPluginRegistry = false,
    required FileSystem fileSystem,
    required Logger logger,
    required Artifacts artifacts,
    required ProcessManager processManager,
  }) {
    return Environment(
      projectDir: projectDir ?? testDirectory,
      outputDir: outputDir ?? testDirectory,
      cacheDir: cacheDir ?? testDirectory,
      flutterRootDir: flutterRootDir ?? testDirectory,
      buildDir: buildDir,
      defines: defines,
      inputs: inputs,
      fileSystem: fileSystem,
      logger: logger,
      artifacts: artifacts,
      processManager: processManager,
      platform: platform ?? FakePlatform(),
      usage: usage ?? TestUsage(),
      engineVersion: engineVersion,
      generateDartPluginRegistry: generateDartPluginRegistry,
    );
  }

  Environment._({
    required this.outputDir,
    required this.projectDir,
    required this.buildDir,
    required this.rootBuildDir,
    required this.cacheDir,
    required this.defines,
    required this.flutterRootDir,
    required this.processManager,
    required this.platform,
    required this.logger,
    required this.fileSystem,
    required this.artifacts,
    required this.usage,
    this.engineVersion,
    required this.inputs,
    required this.generateDartPluginRegistry,
  });

  static const String kProjectDirectory = '{PROJECT_DIR}';

  static const String kBuildDirectory = '{BUILD_DIR}';

  static const String kCacheDirectory = '{CACHE_DIR}';

  static const String kFlutterRootDirectory = '{FLUTTER_ROOT}';

  static const String kOutputDirectory = '{OUTPUT_DIR}';

  final Directory projectDir;

  final Directory buildDir;

  final Directory cacheDir;

  final Directory flutterRootDir;

  final Directory outputDir;

  final Map<String, String> defines;

  final Map<String, String> inputs;

  final Directory rootBuildDir;

  final ProcessManager processManager;

  final Platform platform;

  final Logger logger;

  final Artifacts artifacts;

  final FileSystem fileSystem;

  final Usage usage;

  final String? engineVersion;

  final bool generateDartPluginRegistry;

  late final DepfileService depFileService = DepfileService(
    logger: logger,
    fileSystem: fileSystem,
  );
}

class BuildResult {
  BuildResult({
    required this.success,
    this.exceptions = const <String, ExceptionMeasurement>{},
    this.performance = const <String, PerformanceMeasurement>{},
    this.inputFiles = const <File>[],
    this.outputFiles = const <File>[],
  });

  final bool success;
  final Map<String, ExceptionMeasurement> exceptions;
  final Map<String, PerformanceMeasurement> performance;
  final List<File> inputFiles;
  final List<File> outputFiles;

  bool get hasException => exceptions.isNotEmpty;
}

abstract class BuildSystem {
  const BuildSystem();

  Future<BuildResult> build(
    Target target,
    Environment environment, {
    BuildSystemConfig buildSystemConfig = const BuildSystemConfig(),
  });

  Future<BuildResult> buildIncremental(
    Target target,
    Environment environment,
    BuildResult? previousBuild,
  );
}

class FlutterBuildSystem extends BuildSystem {
  const FlutterBuildSystem({
    required FileSystem fileSystem,
    required Platform platform,
    required Logger logger,
  }) : _fileSystem = fileSystem,
       _platform = platform,
       _logger = logger;

  final FileSystem _fileSystem;
  final Platform _platform;
  final Logger _logger;

  @override
  Future<BuildResult> build(
    Target target,
    Environment environment, {
    BuildSystemConfig buildSystemConfig = const BuildSystemConfig(),
  }) async {
    environment.buildDir.createSync(recursive: true);
    environment.outputDir.createSync(recursive: true);

    // Load file store from previous builds.
    final File cacheFile = environment.buildDir.childFile(FileStore.kFileCache);
    final FileStore fileCache = FileStore(
      cacheFile: cacheFile,
      logger: _logger,
    )..initialize();

    // Perform sanity checks on build.
    checkCycles(target);

    final Node node = target._toNode(environment);
    final _BuildInstance buildInstance = _BuildInstance(
      environment: environment,
      fileCache: fileCache,
      buildSystemConfig: buildSystemConfig,
      logger: _logger,
      fileSystem: _fileSystem,
      platform: _platform,
    );
    bool passed = true;
    try {
      passed = await buildInstance.invokeTarget(node);
    } finally {
      // Always persist the file cache to disk.
      fileCache.persist();
    }
    // This is a bit of a hack, due to various parts of
    // the flutter tool writing these files unconditionally. Since Xcode uses
    // timestamps to track files, this leads to unnecessary rebuilds if they
    // are included. Once all the places that write these files have been
    // tracked down and moved into assemble, these checks should be removable.
    // We also remove files under .dart_tool, since these are intermediaries
    // and don't need to be tracked by external systems.
    {
      buildInstance.inputFiles.removeWhere((String path, File file) {
        return path.contains('.flutter-plugins') ||
                       path.contains('xcconfig') ||
                     path.contains('.dart_tool');
      });
      buildInstance.outputFiles.removeWhere((String path, File file) {
        return path.contains('.flutter-plugins') ||
                       path.contains('xcconfig') ||
                     path.contains('.dart_tool');
      });
    }
    trackSharedBuildDirectory(
      environment, _fileSystem, buildInstance.outputFiles,
    );
    environment.buildDir.childFile('outputs.json')
      .writeAsStringSync(json.encode(buildInstance.outputFiles.keys.toList()));

    return BuildResult(
      success: passed,
      exceptions: buildInstance.exceptionMeasurements,
      performance: buildInstance.stepTimings,
      inputFiles: buildInstance.inputFiles.values.toList()
          ..sort((File a, File b) => a.path.compareTo(b.path)),
      outputFiles: buildInstance.outputFiles.values.toList()
          ..sort((File a, File b) => a.path.compareTo(b.path)),
    );
  }

  static final Expando<FileStore> _incrementalFileStore = Expando<FileStore>();

  @override
  Future<BuildResult> buildIncremental(
    Target target,
    Environment environment,
    BuildResult? previousBuild,
  ) async {
    environment.buildDir.createSync(recursive: true);
    environment.outputDir.createSync(recursive: true);

    FileStore? fileCache;
    if (previousBuild == null || _incrementalFileStore[previousBuild] == null) {
      final File cacheFile = environment.buildDir.childFile(FileStore.kFileCache);
      fileCache = FileStore(
        cacheFile: cacheFile,
        logger: _logger,
        strategy: FileStoreStrategy.timestamp,
      )..initialize();
    } else {
      fileCache = _incrementalFileStore[previousBuild];
    }
    final Node node = target._toNode(environment);
    final _BuildInstance buildInstance = _BuildInstance(
      environment: environment,
      fileCache: fileCache!,
      buildSystemConfig: const BuildSystemConfig(),
      logger: _logger,
      fileSystem: _fileSystem,
      platform: _platform,
    );
    bool passed = true;
    try {
      passed = await buildInstance.invokeTarget(node);
    } finally {
      fileCache.persistIncremental();
    }
    final BuildResult result = BuildResult(
      success: passed,
      exceptions: buildInstance.exceptionMeasurements,
      performance: buildInstance.stepTimings,
    );
    _incrementalFileStore[result] = fileCache;
    return result;
  }

  @visibleForTesting
  void trackSharedBuildDirectory(
    Environment environment,
    FileSystem fileSystem,
    Map<String, File> currentOutputs,
  ) {
    final String currentBuildId = fileSystem.path.basename(environment.buildDir.path);
    final File lastBuildIdFile = environment.outputDir.childFile('.last_build_id');
    if (!lastBuildIdFile.existsSync()) {
      lastBuildIdFile.parent.createSync(recursive: true);
      lastBuildIdFile.writeAsStringSync(currentBuildId);
      // No config file, either output was cleaned or this is the first build.
      return;
    }
    final String lastBuildId = lastBuildIdFile.readAsStringSync().trim();
    if (lastBuildId == currentBuildId) {
      // The last build was the same configuration as the current build
      return;
    }
    // Update the output dir with the latest config.
    lastBuildIdFile
      ..createSync()
      ..writeAsStringSync(currentBuildId);
    final File outputsFile = environment.buildDir
      .parent
      .childDirectory(lastBuildId)
      .childFile('outputs.json');

    if (!outputsFile.existsSync()) {
      // There is no output list. This could happen if the user manually
      // edited .last_config or deleted .dart_tool.
      return;
    }
    final List<String> lastOutputs = (json.decode(outputsFile.readAsStringSync()) as List<Object?>)
      .cast<String>();
    for (final String lastOutput in lastOutputs) {
      if (!currentOutputs.containsKey(lastOutput)) {
        final File lastOutputFile = fileSystem.file(lastOutput);
        ErrorHandlingFileSystem.deleteIfExists(lastOutputFile);
      }
    }
  }
}

class _BuildInstance {
  _BuildInstance({
    required this.environment,
    required this.fileCache,
    required this.buildSystemConfig,
    required this.logger,
    required this.fileSystem,
    Platform? platform,
  })
    : resourcePool = Pool(buildSystemConfig.resourcePoolSize ?? platform?.numberOfProcessors ?? 1);

  final Logger logger;
  final FileSystem fileSystem;
  final BuildSystemConfig buildSystemConfig;
  final Pool resourcePool;
  final Map<String, AsyncMemoizer<bool>> pending = <String, AsyncMemoizer<bool>>{};
  final Environment environment;
  final FileStore fileCache;
  final Map<String, File> inputFiles = <String, File>{};
  final Map<String, File> outputFiles = <String, File>{};

  // Timings collected during target invocation.
  final Map<String, PerformanceMeasurement> stepTimings = <String, PerformanceMeasurement>{};

  // Exceptions caught during the build process.
  final Map<String, ExceptionMeasurement> exceptionMeasurements = <String, ExceptionMeasurement>{};

  Future<bool> invokeTarget(Node node) async {
    final List<bool> results = await Future.wait(node.dependencies.map(invokeTarget));
    if (results.any((bool result) => !result)) {
      return false;
    }
    final AsyncMemoizer<bool> memoizer = pending[node.target.name] ??= AsyncMemoizer<bool>();
    return memoizer.runOnce(() => _invokeInternal(node));
  }

  Future<bool> _invokeInternal(Node node) async {
    final PoolResource resource = await resourcePool.request();
    final Stopwatch stopwatch = Stopwatch()..start();
    bool succeeded = true;
    bool skipped = false;

    // The build system produces a list of aggregate input and output
    // files for the overall build. This list is provided to a hosting build
    // system, such as Xcode, to configure logic for when to skip the
    // rule/phase which contains the flutter build.
    //
    // When looking at the inputs and outputs for the individual rules, we need
    // to be careful to remove inputs that were actually output from previous
    // build steps. This indicates that the file is an intermediary. If
    // these files are included as both inputs and outputs then it isn't
    // possible to construct a DAG describing the build.
    void updateGraph() {
      for (final File output in node.outputs) {
        outputFiles[output.path] = output;
      }
      for (final File input in node.inputs) {
        final String resolvedPath = input.absolute.path;
        if (outputFiles.containsKey(resolvedPath)) {
          continue;
        }
        inputFiles[resolvedPath] = input;
      }
    }

    try {
      // If we're missing a depfile, wait until after evaluating the target to
      // compute changes.
      final bool canSkip = !node.missingDepfile &&
        node.computeChanges(environment, fileCache, fileSystem, logger);

      if (canSkip) {
        skipped = true;
        logger.printTrace('Skipping target: ${node.target.name}');
        updateGraph();
        return succeeded;
      }
      // Clear old inputs. These will be replaced with new inputs/outputs
      // after the target is run. In the case of a runtime skip, each list
      // must be empty to ensure the previous outputs are purged.
      node.inputs.clear();
      node.outputs.clear();

      // Check if we can skip via runtime dependencies.
      final bool runtimeSkip = node.target.canSkip(environment);
      if (runtimeSkip) {
        logger.printTrace('Skipping target: ${node.target.name}');
        skipped = true;
      } else {
        logger.printTrace('${node.target.name}: Starting due to ${node.invalidatedReasons}');
        await node.target.build(environment);
        logger.printTrace('${node.target.name}: Complete');
        node.inputs.addAll(node.target.resolveInputs(environment).sources);
        node.outputs.addAll(node.target.resolveOutputs(environment).sources);
      }

      // If we were missing the depfile, resolve input files after executing the
      // target so that all file hashes are up to date on the next run.
      if (node.missingDepfile) {
        fileCache.diffFileList(node.inputs);
      }

      // Always update hashes for output files.
      fileCache.diffFileList(node.outputs);
      node.target._writeStamp(node.inputs, node.outputs, environment);
      updateGraph();

      // Delete outputs from previous stages that are no longer a part of the
      // build.
      for (final String previousOutput in node.previousOutputs) {
        if (outputFiles.containsKey(previousOutput)) {
          continue;
        }
        final File previousFile = fileSystem.file(previousOutput);
        ErrorHandlingFileSystem.deleteIfExists(previousFile);
      }
    } on Exception catch (exception, stackTrace) {
      node.target.clearStamp(environment);
      succeeded = false;
      skipped = false;
      exceptionMeasurements[node.target.name] = ExceptionMeasurement(
          node.target.name, exception, stackTrace, fatal: true);
    } finally {
      resource.release();
      stopwatch.stop();
      stepTimings[node.target.name] = PerformanceMeasurement(
        target: node.target.name,
        elapsedMilliseconds: stopwatch.elapsedMilliseconds,
        skipped: skipped,
        succeeded: succeeded,
        analyticsName: node.target.analyticsName,
      );
    }
    return succeeded;
  }
}

class ExceptionMeasurement {
  ExceptionMeasurement(this.target, this.exception, this.stackTrace, {this.fatal = false});

  final String target;
  final Object? exception;
  final StackTrace stackTrace;

  final bool fatal;

  @override
  String toString() => 'target: $target\nexception:$exception\n$stackTrace';
}

class PerformanceMeasurement {
  PerformanceMeasurement({
    required this.target,
    required this.elapsedMilliseconds,
    required this.skipped,
    required this.succeeded,
    required this.analyticsName,
  });

  final int elapsedMilliseconds;
  final String target;
  final bool skipped;
  final bool succeeded;
  final String analyticsName;
}

void checkCycles(Target initial) {
  void checkInternal(Target target, Set<Target> visited, Set<Target> stack) {
    if (stack.contains(target)) {
      throw CycleException(stack..add(target));
    }
    if (visited.contains(target)) {
      return;
    }
    visited.add(target);
    stack.add(target);
    for (final Target dependency in target.dependencies) {
      checkInternal(dependency, visited, stack);
    }
    stack.remove(target);
  }
  checkInternal(initial, <Target>{}, <Target>{});
}

void verifyOutputDirectories(List<File> outputs, Environment environment, Target target) {
  final String buildDirectory = environment.buildDir.resolveSymbolicLinksSync();
  final String projectDirectory = environment.projectDir.resolveSymbolicLinksSync();
  final List<File> missingOutputs = <File>[];
  for (final File sourceFile in outputs) {
    if (!sourceFile.existsSync()) {
      missingOutputs.add(sourceFile);
      continue;
    }
    final String path = sourceFile.path;
    if (!path.startsWith(buildDirectory) && !path.startsWith(projectDirectory)) {
      throw MisplacedOutputException(path, target.name);
    }
  }
  if (missingOutputs.isNotEmpty) {
    throw MissingOutputException(missingOutputs, target.name);
  }
}

class Node {
  Node(
    this.target,
    this.inputs,
    this.outputs,
    this.dependencies,
    Environment environment,
    this.missingDepfile,
  ) {
    final File stamp = target._findStampFile(environment);

    // If the stamp file doesn't exist, we haven't run this step before and
    // all inputs were added.
    if (!stamp.existsSync()) {
      // No stamp file, not safe to skip.
      _dirty = true;
      return;
    }
    final String content = stamp.readAsStringSync();
    // Something went wrong writing the stamp file.
    if (content.isEmpty) {
      stamp.deleteSync();
      // Malformed stamp file, not safe to skip.
      _dirty = true;
      return;
    }
    Map<String, Object?>? values;
    try {
      values = castStringKeyedMap(json.decode(content));
    } on FormatException {
      // The json is malformed in some way.
      _dirty = true;
      return;
    }
    final Object? inputs = values?['inputs'];
    final Object? outputs = values?['outputs'];
    if (inputs is List<Object?> && outputs is List<Object?>) {
      inputs.cast<String?>().whereType<String>().forEach(previousInputs.add);
      outputs.cast<String?>().whereType<String>().forEach(previousOutputs.add);
    } else {
      // The json is malformed in some way.
      _dirty = true;
    }
  }

  final List<File> inputs;

  final List<File> outputs;

  final bool missingDepfile;

  final Target target;

  final List<Node> dependencies;

  final Set<String> previousOutputs = <String>{};

  final Set<String> previousInputs = <String>{};

  final Map<InvalidatedReasonKind, InvalidatedReason> invalidatedReasons = <InvalidatedReasonKind, InvalidatedReason>{};

  bool get dirty => _dirty;
  bool _dirty = false;

  InvalidatedReason _invalidate(InvalidatedReasonKind kind) {
    return invalidatedReasons[kind] ??= InvalidatedReason(kind);
  }

  bool computeChanges(
    Environment environment,
    FileStore fileStore,
    FileSystem fileSystem,
    Logger logger,
  ) {
    final Set<String> currentOutputPaths = <String>{
      for (final File file in outputs) file.path,
    };
    // For each input, first determine if we've already computed the key
    // for it. Then collect it to be sent off for diffing as a group.
    final List<File> sourcesToDiff = <File>[];
    final List<File> missingInputs = <File>[];
    for (final File file in inputs) {
      if (!file.existsSync()) {
        missingInputs.add(file);
        continue;
      }

      final String absolutePath = file.path;
      final String? previousAssetKey = fileStore.previousAssetKeys[absolutePath];
      if (fileStore.currentAssetKeys.containsKey(absolutePath)) {
        final String? currentHash = fileStore.currentAssetKeys[absolutePath];
        if (currentHash != previousAssetKey) {
          final InvalidatedReason reason = _invalidate(InvalidatedReasonKind.inputChanged);
          reason.data.add(absolutePath);
          _dirty = true;
        }
      } else {
        sourcesToDiff.add(file);
      }
    }

    // For each output, first determine if we've already computed the key
    // for it. Then collect it to be sent off for hashing as a group.
    for (final String previousOutput in previousOutputs) {
      // output paths changed.
      if (!currentOutputPaths.contains(previousOutput)) {
        _dirty = true;
        final InvalidatedReason reason = _invalidate(InvalidatedReasonKind.outputSetChanged);
        reason.data.add(previousOutput);
        // if this isn't a current output file there is no reason to compute the key.
        continue;
      }
      final File file = fileSystem.file(previousOutput);
      if (!file.existsSync()) {
        final InvalidatedReason reason = _invalidate(InvalidatedReasonKind.outputMissing);
        reason.data.add(file.path);
        _dirty = true;
        continue;
      }
      final String absolutePath = file.path;
      final String? previousHash = fileStore.previousAssetKeys[absolutePath];
      if (fileStore.currentAssetKeys.containsKey(absolutePath)) {
        final String? currentHash = fileStore.currentAssetKeys[absolutePath];
        if (currentHash != previousHash) {
          final InvalidatedReason reason = _invalidate(InvalidatedReasonKind.outputChanged);
          reason.data.add(absolutePath);
          _dirty = true;
        }
      } else {
        sourcesToDiff.add(file);
      }
    }

    // If we depend on a file that doesn't exist on disk, mark the build as
    // dirty. if the rule is not correctly specified, this will result in it
    // always being rerun.
    if (missingInputs.isNotEmpty) {
      _dirty = true;
      final String missingMessage = missingInputs.map((File file) => file.path).join(', ');
      logger.printTrace('invalidated build due to missing files: $missingMessage');
      final InvalidatedReason reason = _invalidate(InvalidatedReasonKind.inputMissing);
      reason.data.addAll(missingInputs.map((File file) => file.path));
    }

    // If we have files to diff, compute them asynchronously and then
    // update the result.
    if (sourcesToDiff.isNotEmpty) {
      final List<File> dirty = fileStore.diffFileList(sourcesToDiff);
      if (dirty.isNotEmpty) {
        final InvalidatedReason reason = _invalidate(InvalidatedReasonKind.inputChanged);
        reason.data.addAll(dirty.map((File file) => file.path));
        _dirty = true;
      }
    }
    return !_dirty;
  }
}

class InvalidatedReason {
  InvalidatedReason(this.kind);

  final InvalidatedReasonKind kind;
  final List<String> data = <String>[];

  @override
  String toString() {
    return switch (kind) {
      InvalidatedReasonKind.inputMissing => 'The following inputs were missing: ${data.join(',')}',
      InvalidatedReasonKind.inputChanged => 'The following inputs have updated contents: ${data.join(',')}',
      InvalidatedReasonKind.outputChanged => 'The following outputs have updated contents: ${data.join(',')}',
      InvalidatedReasonKind.outputMissing => 'The following outputs were missing: ${data.join(',')}',
      InvalidatedReasonKind.outputSetChanged => 'The following outputs were removed from the output set: ${data.join(',')}'
    };
  }
}

enum InvalidatedReasonKind {
  inputMissing,

  inputChanged,

  outputChanged,

  outputMissing,

  outputSetChanged,
}