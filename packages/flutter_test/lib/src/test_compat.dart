
import 'dart:async';

import 'package:meta/meta.dart';
import 'package:test_api/scaffolding.dart' show Timeout;
import 'package:test_api/src/backend/declarer.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/group.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/group_entry.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/invoker.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/live_test.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/message.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/runtime.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/state.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/suite.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/suite_platform.dart'; // ignore: implementation_imports
import 'package:test_api/src/backend/test.dart'; // ignore: implementation_imports

// ignore: deprecated_member_use
export 'package:test_api/fake.dart' show Fake;

Declarer? _localDeclarer;
Declarer get _declarer {
  final Declarer? declarer = Zone.current[#test.declarer] as Declarer?;
  if (declarer != null) {
    return declarer;
  }
  // If no declarer is defined, this test is being run via `flutter run -t test_file.dart`.
  if (_localDeclarer == null) {
    _localDeclarer = Declarer();
    Future<void>(() {
      Invoker.guard<Future<void>>(() async {
        final _Reporter reporter = _Reporter(color: false); // disable color when run directly.
        // ignore: recursive_getters, this self-call is safe since it will just fetch the declarer instance
        final Group group = _declarer.build();
        final Suite suite = Suite(group, SuitePlatform(Runtime.vm));
        await _runGroup(suite, group, <Group>[], reporter);
        reporter._onDone();
      });
    });
  }
  return _localDeclarer!;
}

Future<void> _runGroup(Suite suiteConfig, Group group, List<Group> parents, _Reporter reporter) async {
  parents.add(group);
  try {
    final bool skipGroup = group.metadata.skip;
    bool setUpAllSucceeded = true;
    if (!skipGroup && group.setUpAll != null) {
      final LiveTest liveTest = group.setUpAll!.load(suiteConfig, groups: parents);
      await _runLiveTest(suiteConfig, liveTest, reporter, countSuccess: false);
      setUpAllSucceeded = liveTest.state.result.isPassing;
    }
    if (setUpAllSucceeded) {
      for (final GroupEntry entry in group.entries) {
        if (entry is Group) {
          await _runGroup(suiteConfig, entry, parents, reporter);
        } else if (entry.metadata.skip) {
          await _runSkippedTest(suiteConfig, entry as Test, parents, reporter);
        } else {
          final Test test = entry as Test;
          await _runLiveTest(suiteConfig, test.load(suiteConfig, groups: parents), reporter);
        }
      }
    }
    // Even if we're closed or setUpAll failed, we want to run all the
    // teardowns to ensure that any state is properly cleaned up.
    if (!skipGroup && group.tearDownAll != null) {
      final LiveTest liveTest = group.tearDownAll!.load(suiteConfig, groups: parents);
      await _runLiveTest(suiteConfig, liveTest, reporter, countSuccess: false);
    }
  } finally {
    parents.remove(group);
  }
}

Future<void> _runLiveTest(Suite suiteConfig, LiveTest liveTest, _Reporter reporter, { bool countSuccess = true }) async {
  reporter._onTestStarted(liveTest);
  // Schedule a microtask to ensure that [onTestStarted] fires before the
  // first [LiveTest.onStateChange] event.
  await Future<void>.microtask(liveTest.run);
  // Once the test finishes, use await null to do a coarse-grained event
  // loop pump to avoid starving non-microtask events.
  await null;
  final bool isSuccess = liveTest.state.result.isPassing;
  if (isSuccess) {
    reporter.passed.add(liveTest);
  } else {
    reporter.failed.add(liveTest);
  }
}

Future<void> _runSkippedTest(Suite suiteConfig, Test test, List<Group> parents, _Reporter reporter) async {
  final LocalTest skipped = LocalTest(test.name, test.metadata, () { }, trace: test.trace);
  if (skipped.metadata.skipReason != null) {
    reporter.log('Skip: ${skipped.metadata.skipReason}');
  }
  final LiveTest liveTest = skipped.load(suiteConfig);
  reporter._onTestStarted(liveTest);
  reporter.skipped.add(skipped);
}

// TODO(nweiz): This and other top-level functions should throw exceptions if
// they're called after the declarer has finished declaring.
@isTest
void test(
  Object description,
  dynamic Function() body, {
  String? testOn,
  Timeout? timeout,
  dynamic skip,
  dynamic tags,
  Map<String, dynamic>? onPlatform,
  int? retry,
}) {
  _declarer.test(
    description.toString(),
    body,
    testOn: testOn,
    timeout: timeout,
    skip: skip,
    onPlatform: onPlatform,
    tags: tags,
    retry: retry,
  );
}

@isTestGroup
void group(Object description, void Function() body, { dynamic skip, int? retry }) {
  _declarer.group(description.toString(), body, skip: skip, retry: retry);
}

void setUp(dynamic Function() body) {
  _declarer.setUp(body);
}

void tearDown(dynamic Function() body) {
  _declarer.tearDown(body);
}

void setUpAll(dynamic Function() body) {
  _declarer.setUpAll(body);
}

void tearDownAll(dynamic Function() body) {
  _declarer.tearDownAll(body);
}


class _Reporter {
  _Reporter({bool color = true, bool printPath = true})
    : _printPath = printPath,
      _green = color ? '\u001b[32m' : '',
      _red = color ? '\u001b[31m' : '',
      _yellow = color ? '\u001b[33m' : '',
      _bold = color ? '\u001b[1m' : '',
      _noColor = color ? '\u001b[0m' : '';

  final List<LiveTest> passed = <LiveTest>[];
  final List<LiveTest> failed = <LiveTest>[];
  final List<Test> skipped = <Test>[];

  final String _green;

  final String _red;

  final String _yellow;

  final String _bold;

  final String _noColor;

  final bool _printPath;

  final Stopwatch _stopwatch = Stopwatch();

  int? _lastProgressPassed;

  int? _lastProgressSkipped;

  int? _lastProgressFailed;

  String? _lastProgressMessage;

  String? _lastProgressSuffix;

  final Set<StreamSubscription<void>> _subscriptions = <StreamSubscription<void>>{};

  void _onTestStarted(LiveTest liveTest) {
    if (!_stopwatch.isRunning) {
      _stopwatch.start();
    }
    _progressLine(_description(liveTest));
    _subscriptions.add(liveTest.onStateChange.listen((State state) => _onStateChange(liveTest, state)));
    _subscriptions.add(liveTest.onError.listen((AsyncError error) => _onError(liveTest, error.error, error.stackTrace)));
    _subscriptions.add(liveTest.onMessage.listen((Message message) {
      _progressLine(_description(liveTest));
      String text = message.text;
      if (message.type == MessageType.skip) {
        text = '  $_yellow$text$_noColor';
      }
      log(text);
    }));
  }

  void _onStateChange(LiveTest liveTest, State state) {
    if (state.status != Status.complete) {
      return;
    }
  }

  void _onError(LiveTest liveTest, Object error, StackTrace stackTrace) {
    if (liveTest.state.status != Status.complete) {
      return;
    }
    _progressLine(_description(liveTest), suffix: ' $_bold$_red[E]$_noColor');
    log(_indent(error.toString()));
    log(_indent('$stackTrace'));
  }

  void _onDone() {
    final bool success = failed.isEmpty;
    if (!success) {
      _progressLine('Some tests failed.', color: _red);
    } else if (passed.isEmpty) {
      _progressLine('All tests skipped.');
    } else {
      _progressLine('All tests passed!');
    }
  }

  void _progressLine(String message, { String? color, String? suffix }) {
    // Print nothing if nothing has changed since the last progress line.
    if (passed.length == _lastProgressPassed &&
        skipped.length == _lastProgressSkipped &&
        failed.length == _lastProgressFailed &&
        message == _lastProgressMessage &&
        // Don't re-print just because a suffix was removed.
        (suffix == null || suffix == _lastProgressSuffix)) {
      return;
    }
    _lastProgressPassed = passed.length;
    _lastProgressSkipped = skipped.length;
    _lastProgressFailed = failed.length;
    _lastProgressMessage = message;
    _lastProgressSuffix = suffix;

    if (suffix != null) {
      message += suffix;
    }
    color ??= '';
    final Duration duration = _stopwatch.elapsed;
    final StringBuffer buffer = StringBuffer();

    // \r moves back to the beginning of the current line.
    buffer.write('${_timeString(duration)} ');
    buffer.write(_green);
    buffer.write('+');
    buffer.write(passed.length);
    buffer.write(_noColor);

    if (skipped.isNotEmpty) {
      buffer.write(_yellow);
      buffer.write(' ~');
      buffer.write(skipped.length);
      buffer.write(_noColor);
    }

    if (failed.isNotEmpty) {
      buffer.write(_red);
      buffer.write(' -');
      buffer.write(failed.length);
      buffer.write(_noColor);
    }

    buffer.write(': ');
    buffer.write(color);
    buffer.write(message);
    buffer.write(_noColor);

    log(buffer.toString());
  }

  String _timeString(Duration duration) {
    final String minutes = duration.inMinutes.toString().padLeft(2, '0');
    final String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _description(LiveTest liveTest) {
    String name = liveTest.test.name;
    if (_printPath && liveTest.suite.path != null) {
      name = '${liveTest.suite.path}: $name';
    }
    return name;
  }

  void log(String message) {
    // We centralize all the prints in this file through this one method so that
    // in principle we can reroute the output easily should we need to.
    print(message); // ignore: avoid_print
  }
}

String _indent(String string, { int? size, String? first }) {
  size ??= first == null ? 2 : first.length;
  return _prefixLines(string, ' ' * size, first: first);
}

String _prefixLines(String text, String prefix, { String? first, String? last, String? single }) {
  first ??= prefix;
  last ??= prefix;
  single ??= first;
  final List<String> lines = text.split('\n');
  if (lines.length == 1) {
    return '$single$text';
  }
  final StringBuffer buffer = StringBuffer('$first${lines.first}\n');
  // Write out all but the first and last lines with [prefix].
  for (final String line in lines.skip(1).take(lines.length - 2)) {
    buffer.writeln('$prefix$line');
  }
  buffer.write('$last${lines.last}');
  return buffer.toString();
}