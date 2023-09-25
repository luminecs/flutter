// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:args/command_runner.dart';
import 'package:file/memory.dart';
import 'package:flutter_tools/src/base/common.dart';
import 'package:flutter_tools/src/base/context.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/io.dart';
import 'package:flutter_tools/src/base/platform.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:meta/meta.dart';
import 'package:path/path.dart' as path; // flutter_ignore: package_path_import
import 'package:test/test.dart' as test_package show test;
import 'package:test/test.dart' hide test;

export 'package:path/path.dart' show Context; // flutter_ignore: package_path_import
export 'package:test/test.dart' hide isInstanceOf, test;

void tryToDelete(FileSystemEntity fileEntity) {
  // This should not be necessary, but it turns out that
  // on Windows it's common for deletions to fail due to
  // bogus (we think) "access denied" errors.
  try {
    if (fileEntity.existsSync()) {
      fileEntity.deleteSync(recursive: true);
    }
  } on FileSystemException catch (error) {
    // We print this so that it's visible in the logs, to get an idea of how
    // common this problem is, and if any patterns are ever noticed by anyone.
    // ignore: avoid_print
    print('Failed to delete ${fileEntity.path}: $error');
  }
}

String getFlutterRoot() {
  const Platform platform = LocalPlatform();
  if (platform.environment.containsKey('FLUTTER_ROOT')) {
    return platform.environment['FLUTTER_ROOT']!;
  }

  Error invalidScript() => StateError('Could not determine flutter_tools/ path from script URL (${globals.platform.script}); consider setting FLUTTER_ROOT explicitly.');

  Uri scriptUri;
  switch (platform.script.scheme) {
    case 'file':
      scriptUri = platform.script;
    case 'data':
      final RegExp flutterTools = RegExp(r'(file://[^"]*[/\\]flutter_tools[/\\][^"]+\.dart)', multiLine: true);
      final Match? match = flutterTools.firstMatch(Uri.decodeFull(platform.script.path));
      if (match == null) {
        throw invalidScript();
      }
      scriptUri = Uri.parse(match.group(1)!);
    default:
      throw invalidScript();
  }

  final List<String> parts = path.split(globals.localFileSystem.path.fromUri(scriptUri));
  final int toolsIndex = parts.indexOf('flutter_tools');
  if (toolsIndex == -1) {
    throw invalidScript();
  }
  final String toolsPath = path.joinAll(parts.sublist(0, toolsIndex + 1));
  return path.normalize(path.join(toolsPath, '..', '..'));
}

Future<StringBuffer> capturedConsolePrint(Future<void> Function() body) async {
  final StringBuffer buffer = StringBuffer();
  await runZoned<Future<void>>(() async {
    // Service the event loop.
    await body();
  }, zoneSpecification: ZoneSpecification(print: (Zone self, ZoneDelegate parent, Zone zone, String line) {
    buffer.writeln(line);
  }));
  return buffer;
}

final Matcher throwsAssertionError = throwsA(isA<AssertionError>());

Matcher throwsToolExit({ int? exitCode, Pattern? message }) {
  Matcher matcher = _isToolExit;
  if (exitCode != null) {
    matcher = allOf(matcher, (ToolExit e) => e.exitCode == exitCode);
  }
  if (message != null) {
    matcher = allOf(matcher, (ToolExit e) => e.message?.contains(message) ?? false);
  }
  return throwsA(matcher);
}

final TypeMatcher<ToolExit> _isToolExit = isA<ToolExit>();

Matcher throwsUsageException({Pattern? message }) {
  Matcher matcher = _isUsageException;
  if (message != null) {
    matcher = allOf(matcher, (UsageException e) => e.message.contains(message));
  }
  return throwsA(matcher);
}

final TypeMatcher<UsageException> _isUsageException = isA<UsageException>();

Matcher throwsProcessException({ Pattern? message }) {
  Matcher matcher = _isProcessException;
  if (message != null) {
    matcher = allOf(matcher, (ProcessException e) => e.message.contains(message));
  }
  return throwsA(matcher);
}

final TypeMatcher<ProcessException> _isProcessException = isA<ProcessException>();

Future<void> expectToolExitLater(Future<dynamic> future, Matcher messageMatcher) async {
  try {
    await future;
    fail('ToolExit expected, but nothing thrown');
  } on ToolExit catch (e) {
    expect(e.message, messageMatcher);
  // Catch all exceptions to give a better test failure message.
  } catch (e, trace) { // ignore: avoid_catches_without_on_clauses
    fail('ToolExit expected, got $e\n$trace');
  }
}

Future<void> expectReturnsNormallyLater(Future<dynamic> future) async {
  try {
    await future;
  // Catch all exceptions to give a better test failure message.
  } catch (e, trace) { // ignore: avoid_catches_without_on_clauses
    fail('Expected to run with no exceptions, got $e\n$trace');
  }
}

Matcher containsIgnoringWhitespace(String toSearch) {
  return predicate(
    (String source) {
      return collapseWhitespace(source).contains(collapseWhitespace(toSearch));
    },
    'contains "$toSearch" ignoring whitespace.',
  );
}

@isTest
void test(String description, FutureOr<void> Function() body, {
  String? testOn,
  dynamic skip,
  List<String>? tags,
  Map<String, dynamic>? onPlatform,
  int? retry,
}) {
  test_package.test(
    description,
    () async {
      addTearDown(() async {
        await globals.localFileSystem.dispose();
      });

      return body();
    },
    skip: skip,
    tags: tags,
    onPlatform: onPlatform,
    retry: retry,
    testOn: testOn,
    // We don't support "timeout"; see ../../dart_test.yaml which
    // configures all tests to have a 15 minute timeout which should
    // definitely be enough.
  );
}

@isTest
void testWithoutContext(String description, FutureOr<void> Function() body, {
  String? testOn,
  dynamic skip,
  List<String>? tags,
  Map<String, dynamic>? onPlatform,
  int? retry,
}) {
  return test(
    description, () async {
      return runZoned(body, zoneValues: <Object, Object>{
        contextKey: const _NoContext(),
      });
    },
    skip: skip,
    tags: tags,
    onPlatform: onPlatform,
    retry: retry,
    testOn: testOn,
    // We don't support "timeout"; see ../../dart_test.yaml which
    // configures all tests to have a 15 minute timeout which should
    // definitely be enough.
  );
}

class _NoContext implements AppContext {
  const _NoContext();

  @override
  T get<T>() {
    throw UnsupportedError(
      'context.get<$T> is not supported in test methods. '
      'Use Testbed or testUsingContext if accessing Zone injected '
      'values.'
    );
  }

  @override
  String get name => 'No Context';

  @override
  Future<V> run<V>({
    required FutureOr<V> Function() body,
    String? name,
    Map<Type, Generator>? overrides,
    Map<Type, Generator>? fallbacks,
    ZoneSpecification? zoneSpecification,
  }) async {
    return body();
  }
}

class FileExceptionHandler {
  final Map<String, Map<FileSystemOp, FileSystemException>> _contextErrors = <String, Map<FileSystemOp, FileSystemException>>{};
  final Map<FileSystemOp, FileSystemException> _tempErrors = <FileSystemOp, FileSystemException>{};
  static final RegExp _tempDirectoryEnd = RegExp('rand[0-9]+');

  void addError(FileSystemEntity entity, FileSystemOp operation, FileSystemException exception) {
    final String path = entity.path;
    _contextErrors[path] ??= <FileSystemOp, FileSystemException>{};
    _contextErrors[path]![operation] = exception;
  }

  void addTempError(FileSystemOp operation, FileSystemException exception) {
    _tempErrors[operation] = exception;
  }

  void opHandle(String path, FileSystemOp operation) {
    if (path.startsWith('.tmp_') || _tempDirectoryEnd.firstMatch(path) != null) {
      final FileSystemException? exception = _tempErrors[operation];
      if (exception != null) {
        throw exception;
      }
    }
    final Map<FileSystemOp, FileSystemException>? exceptions = _contextErrors[path];
    if (exceptions == null) {
      return;
    }
    final FileSystemException? exception = exceptions[operation];
    if (exception == null) {
      return;
    }
    throw exception;
  }
}