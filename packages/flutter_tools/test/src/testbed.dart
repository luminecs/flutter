import 'dart:async';
import 'dart:io';

import 'package:file/memory.dart';
import 'package:flutter_tools/src/base/context.dart';
import 'package:flutter_tools/src/base/file_system.dart';
import 'package:flutter_tools/src/base/logger.dart';
import 'package:flutter_tools/src/base/os.dart';
import 'package:flutter_tools/src/base/process.dart';
import 'package:flutter_tools/src/base/signals.dart';
import 'package:flutter_tools/src/base/terminal.dart';
import 'package:flutter_tools/src/cache.dart';
import 'package:flutter_tools/src/context_runner.dart';
import 'package:flutter_tools/src/dart/pub.dart';
import 'package:flutter_tools/src/globals.dart' as globals;
import 'package:flutter_tools/src/reporting/reporting.dart';
import 'package:flutter_tools/src/version.dart';

import 'context.dart';
import 'fake_http_client.dart';
import 'fakes.dart';
import 'throwing_pub.dart';

export 'package:flutter_tools/src/base/context.dart' show Generator;

// A default value should be provided if the vast majority of tests should use
// this provider. For example, [BufferLogger], [MemoryFileSystem].
final Map<Type, Generator> _testbedDefaults = <Type, Generator>{
  // Keeps tests fast by avoiding the actual file system.
  FileSystem: () => MemoryFileSystem(
      style: globals.platform.isWindows
          ? FileSystemStyle.windows
          : FileSystemStyle.posix),
  ProcessManager: () => FakeProcessManager.any(),
  Logger: () => BufferLogger(
        terminal: AnsiTerminal(
            stdio: globals.stdio,
            platform: globals.platform), // Danger, using real stdio.
        outputPreferences: OutputPreferences.test(),
      ), // Allows reading logs and prevents stdout.
  OperatingSystemUtils: () => FakeOperatingSystemUtils(),
  OutputPreferences: () =>
      OutputPreferences.test(), // configures BufferLogger to avoid color codes.
  Usage: () =>
      TestUsage(), // prevent addition of analytics from burdening test mocks
  FlutterVersion: () =>
      FakeFlutterVersion(), // prevent requirement to mock git for test runner.
  Signals: () => FakeSignals(), // prevent registering actual signal handlers.
  Pub: () => ThrowingPub(), // prevent accidental invocations of pub.
};

class Testbed {
  Testbed({FutureOr<void> Function()? setup, Map<Type, Generator>? overrides})
      : _setup = setup,
        _overrides = overrides;

  final FutureOr<void> Function()? _setup;
  final Map<Type, Generator>? _overrides;

  Future<T?> run<T>(FutureOr<T> Function() test,
      {Map<Type, Generator>? overrides}) {
    final Map<Type, Generator> testOverrides = <Type, Generator>{
      ..._testbedDefaults,
      // Add the initial setUp overrides
      ...?_overrides,
      // Add the test-specific overrides
      ...?overrides,
    };
    if (testOverrides.containsKey(ProcessUtils)) {
      throw StateError(
          'Do not inject ProcessUtils for testing, use ProcessManager instead.');
    }
    // Cache the original flutter root to restore after the test case.
    final String? originalFlutterRoot = Cache.flutterRoot;
    // Track pending timers to verify that they were correctly cleaned up.
    final Map<Timer, StackTrace> timers = <Timer, StackTrace>{};

    return HttpOverrides.runZoned(() {
      return runInContext<T?>(() {
        return context.run<T?>(
            name: 'testbed',
            overrides: testOverrides,
            zoneSpecification: ZoneSpecification(
              createTimer: (Zone self, ZoneDelegate parent, Zone zone,
                  Duration duration, void Function() timer) {
                final Timer result = parent.createTimer(zone, duration, timer);
                timers[result] = StackTrace.current;
                return result;
              },
              createPeriodicTimer: (Zone self, ZoneDelegate parent, Zone zone,
                  Duration period, void Function(Timer) timer) {
                final Timer result =
                    parent.createPeriodicTimer(zone, period, timer);
                timers[result] = StackTrace.current;
                return result;
              },
            ),
            body: () async {
              Cache.flutterRoot = '';
              if (_setup != null) {
                await _setup.call();
              }
              await test();
              Cache.flutterRoot = originalFlutterRoot;
              for (final MapEntry<Timer, StackTrace> entry in timers.entries) {
                if (entry.key.isActive) {
                  throw StateError(
                      'A Timer was active at the end of a test: ${entry.value}');
                }
              }
              return null;
            });
      });
    }, createHttpClient: (SecurityContext? c) => FakeHttpClient.any());
  }
}
