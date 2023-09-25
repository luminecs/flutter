import 'dart:async' show FutureOr;
import 'dart:io' as io show OSError, SocketException;

import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_goldens_client/skia_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:platform/platform.dart';

export 'package:flutter_goldens_client/skia_client.dart';

// If you are here trying to figure out how to use golden files in the Flutter
// repo itself, consider reading this wiki page:
// https://github.com/flutter/flutter/wiki/Writing-a-golden-file-test-for-package%3Aflutter

const String _kFlutterRootKey = 'FLUTTER_ROOT';

Future<void> testExecutable(FutureOr<void> Function() testMain, {String? namePrefix}) async {
  const Platform platform = LocalPlatform();
  if (FlutterPostSubmitFileComparator.isAvailableForEnvironment(platform)) {
    goldenFileComparator = await FlutterPostSubmitFileComparator.fromDefaultComparator(platform, namePrefix: namePrefix);
  } else if (FlutterPreSubmitFileComparator.isAvailableForEnvironment(platform)) {
    goldenFileComparator = await FlutterPreSubmitFileComparator.fromDefaultComparator(platform, namePrefix: namePrefix);
  } else if (FlutterSkippingFileComparator.isAvailableForEnvironment(platform)) {
    goldenFileComparator = FlutterSkippingFileComparator.fromDefaultComparator(
      'Golden file testing is not executed on Cirrus, or LUCI environments outside of flutter/flutter.',
        namePrefix: namePrefix
    );
  } else {
    goldenFileComparator = await FlutterLocalFileComparator.fromDefaultComparator(platform);
  }

  await testMain();
}

abstract class FlutterGoldenFileComparator extends GoldenFileComparator {
  @visibleForTesting
  FlutterGoldenFileComparator(
    this.basedir,
    this.skiaClient, {
    this.fs = const LocalFileSystem(),
    this.platform = const LocalPlatform(),
    this.namePrefix,
  });

  final Uri basedir;

  final SkiaGoldClient skiaClient;

  @visibleForTesting
  final FileSystem fs;

  @visibleForTesting
  final Platform platform;

  final String? namePrefix;

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {
    final File goldenFile = getGoldenFile(golden);
    await goldenFile.parent.create(recursive: true);
    await goldenFile.writeAsBytes(imageBytes, flush: true);
  }

  @override
  Uri getTestUri(Uri key, int? version) => key;

  @protected
  @visibleForTesting
  static Directory getBaseDirectory(
    LocalFileComparator defaultComparator,
    Platform platform, {
    String? suffix,
  }) {
    const FileSystem fs = LocalFileSystem();
    final Directory flutterRoot = fs.directory(platform.environment[_kFlutterRootKey]);
    Directory comparisonRoot;

    if (suffix != null) {
      comparisonRoot = fs.systemTempDirectory.createTempSync(suffix);
    } else {
      comparisonRoot = flutterRoot.childDirectory(
        fs.path.join(
          'bin',
          'cache',
          'pkg',
          'skia_goldens',
        )
      );
    }

    final Directory testDirectory = fs.directory(defaultComparator.basedir);
    final String testDirectoryRelativePath = fs.path.relative(
      testDirectory.path,
      from: flutterRoot.path,
    );
    return comparisonRoot.childDirectory(testDirectoryRelativePath);
  }

  @protected
  File getGoldenFile(Uri uri) {
    final File goldenFile = fs.directory(basedir).childFile(fs.file(uri).path);
    return goldenFile;
  }

  Uri _addPrefix(Uri golden) {
    // Ensure the Uri ends in .png as the SkiaClient expects
    assert(
      golden.toString().split('.').last == 'png',
      'Golden files in the Flutter framework must end with the file extension '
      '.png.'
    );
    return Uri.parse(<String>[
      if (namePrefix != null)
        namePrefix!,
      basedir.pathSegments[basedir.pathSegments.length - 2],
      golden.toString(),
    ].join('.'));
  }
}

class FlutterPostSubmitFileComparator extends FlutterGoldenFileComparator {
  FlutterPostSubmitFileComparator(
    super.basedir,
    super.skiaClient, {
    super.fs,
    super.platform,
    super.namePrefix,
  });

  static Future<FlutterPostSubmitFileComparator> fromDefaultComparator(
    final Platform platform, {
    SkiaGoldClient? goldens,
    LocalFileComparator? defaultComparator,
    String? namePrefix,
  }) async {

    defaultComparator ??= goldenFileComparator as LocalFileComparator;
    final Directory baseDirectory = FlutterGoldenFileComparator.getBaseDirectory(
      defaultComparator,
      platform,
      suffix: 'flutter_goldens_postsubmit.',
    );
    baseDirectory.createSync(recursive: true);

    goldens ??= SkiaGoldClient(baseDirectory);
    await goldens.auth();
    return FlutterPostSubmitFileComparator(baseDirectory.uri, goldens, namePrefix: namePrefix);
  }

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    await skiaClient.imgtestInit();
    golden = _addPrefix(golden);
    await update(golden, imageBytes);
    final File goldenFile = getGoldenFile(golden);

    return skiaClient.imgtestAdd(golden.path, goldenFile);
  }

  static bool isAvailableForEnvironment(Platform platform) {
    final bool luciPostSubmit = platform.environment.containsKey('SWARMING_TASK_ID')
      && platform.environment.containsKey('GOLDCTL')
      // Luci tryjob environments contain this value to inform the [FlutterPreSubmitComparator].
      && !platform.environment.containsKey('GOLD_TRYJOB');

    return luciPostSubmit;
  }
}

class FlutterPreSubmitFileComparator extends FlutterGoldenFileComparator {
  FlutterPreSubmitFileComparator(
    super.basedir,
    super.skiaClient, {
    super.fs,
    super.platform,
    super.namePrefix,
  });

  static Future<FlutterGoldenFileComparator> fromDefaultComparator(
    final Platform platform, {
    SkiaGoldClient? goldens,
    LocalFileComparator? defaultComparator,
    Directory? testBasedir,
    String? namePrefix,
  }) async {

    defaultComparator ??= goldenFileComparator as LocalFileComparator;
    final Directory baseDirectory = testBasedir ?? FlutterGoldenFileComparator.getBaseDirectory(
      defaultComparator,
      platform,
      suffix: 'flutter_goldens_presubmit.',
    );

    if (!baseDirectory.existsSync()) {
      baseDirectory.createSync(recursive: true);
    }

    goldens ??= SkiaGoldClient(baseDirectory);

    await goldens.auth();
    return FlutterPreSubmitFileComparator(
      baseDirectory.uri,
      goldens, platform: platform,
      namePrefix: namePrefix,
    );
  }

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    await skiaClient.tryjobInit();
    golden = _addPrefix(golden);
    await update(golden, imageBytes);
    final File goldenFile = getGoldenFile(golden);

    await skiaClient.tryjobAdd(golden.path, goldenFile);

    // This will always return true since golden file test failures are managed
    // in pre-submit checks by the flutter-gold status check.
    return true;
  }

  static bool isAvailableForEnvironment(Platform platform) {
    final bool luciPreSubmit = platform.environment.containsKey('SWARMING_TASK_ID')
      && platform.environment.containsKey('GOLDCTL')
      && platform.environment.containsKey('GOLD_TRYJOB');
    return luciPreSubmit;
  }
}

class FlutterSkippingFileComparator extends FlutterGoldenFileComparator {
  FlutterSkippingFileComparator(
    super.basedir,
    super.skiaClient,
    this.reason, {
    super.namePrefix,
  });

  final String reason;

  static FlutterSkippingFileComparator fromDefaultComparator(
    String reason, {
    LocalFileComparator? defaultComparator,
    String? namePrefix,
  }) {
    defaultComparator ??= goldenFileComparator as LocalFileComparator;
    const FileSystem fs = LocalFileSystem();
    final Uri basedir = defaultComparator.basedir;
    final SkiaGoldClient skiaClient = SkiaGoldClient(fs.directory(basedir));
    return FlutterSkippingFileComparator(basedir, skiaClient, reason, namePrefix: namePrefix);
  }

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    // Ideally we would use markTestSkipped here but in some situations,
    // comparators are called outside of tests.
    // See also: https://github.com/flutter/flutter/issues/91285
    // ignore: avoid_print
    print('Skipping "$golden" test: $reason');
    return true;
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {}

  static bool isAvailableForEnvironment(Platform platform) {
    return platform.environment.containsKey('SWARMING_TASK_ID')
      // Some builds are still being run on Cirrus, we should skip these.
      || platform.environment.containsKey('CIRRUS_CI');
  }
}

class FlutterLocalFileComparator extends FlutterGoldenFileComparator with LocalComparisonOutput {
  FlutterLocalFileComparator(
    super.basedir,
    super.skiaClient, {
    super.fs,
    super.platform,
  });

  static Future<FlutterGoldenFileComparator> fromDefaultComparator(
    final Platform platform, {
    SkiaGoldClient? goldens,
    LocalFileComparator? defaultComparator,
    Directory? baseDirectory,
  }) async {
    defaultComparator ??= goldenFileComparator as LocalFileComparator;
    baseDirectory ??= FlutterGoldenFileComparator.getBaseDirectory(
      defaultComparator,
      platform,
    );

    if (!baseDirectory.existsSync()) {
      baseDirectory.createSync(recursive: true);
    }

    goldens ??= SkiaGoldClient(baseDirectory);
    try {
      // Check if we can reach Gold.
      await goldens.getExpectationForTest('');
    } on io.OSError catch (_) {
      return FlutterSkippingFileComparator(
        baseDirectory.uri,
        goldens,
        'OSError occurred, could not reach Gold. '
          'Switching to FlutterSkippingGoldenFileComparator.',
      );
    } on io.SocketException catch (_) {
      return FlutterSkippingFileComparator(
        baseDirectory.uri,
        goldens,
        'SocketException occurred, could not reach Gold. '
          'Switching to FlutterSkippingGoldenFileComparator.',
      );
    }

    return FlutterLocalFileComparator(baseDirectory.uri, goldens);
  }

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    golden = _addPrefix(golden);
    final String testName = skiaClient.cleanTestName(golden.path);
    late String? testExpectation;
    testExpectation = await skiaClient.getExpectationForTest(testName);

    if (testExpectation == null || testExpectation.isEmpty) {
      // There is no baseline for this test.
      // Ideally we would use markTestSkipped here but in some situations,
      // comparators are called outside of tests.
      // See also: https://github.com/flutter/flutter/issues/91285
      // ignore: avoid_print
      print(
        'No expectations provided by Skia Gold for test: $golden. '
        'This may be a new test. If this is an unexpected result, check '
        'https://flutter-gold.skia.org.\n'
        'Validate image output found at $basedir'
      );
      update(golden, imageBytes);
      return true;
    }

    ComparisonResult result;
    final List<int> goldenBytes = await skiaClient.getImageBytes(testExpectation);

    result = await GoldenFileComparator.compareLists(
      imageBytes,
      goldenBytes,
    );

    if (result.passed) {
      return true;
    }

    final String error = await generateFailureOutput(result, golden, basedir);
    throw FlutterError(error);
  }
}