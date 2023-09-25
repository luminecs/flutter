
import 'dart:convert';
import 'dart:io';

class TestSpecs {

  TestSpecs({
    required this.path,
    required this.startTime,
  });

  final String path;
  int startTime;
  int? _endTime;

  int get milliseconds {
    return endTime - startTime;
  }

  set endTime(int value) {
    _endTime = value;
  }

  int get endTime {
    if (_endTime == null) {
      return 0;
    }
    return _endTime!;
  }

  String toJson() {
    return json.encode(
      <String, String>{'path': path, 'runtime': milliseconds.toString()}
    );
  }
}

class TestFileReporterResults {
  TestFileReporterResults._({
    required this.allTestSpecs,
    required this.hasFailedTests,
    required this.errors,
  });

  factory TestFileReporterResults.fromFile(File metrics) {
    if (!metrics.existsSync()) {
      throw Exception('${metrics.path} does not exist');
    }

    final Map<int, TestSpecs> testSpecs = <int, TestSpecs>{};
    bool hasFailedTests = true;
    final List<String> errors = <String>[];

    for (final String metric in metrics.readAsLinesSync()) {
      final Map<String, Object?> entry = json.decode(metric) as Map<String, Object?>;
      if (entry.containsKey('suite')) {
        final Map<String, Object?> suite = entry['suite']! as Map<String, Object?>;
        addTestSpec(suite, entry['time']! as int, testSpecs);
      } else if (isMetricDone(entry, testSpecs)) {
        final Map<String, Object?> group = entry['group']! as Map<String, Object?>;
        final int suiteID = group['suiteID']! as int;
        addMetricDone(suiteID, entry['time']! as int, testSpecs);
      } else if (entry.containsKey('error')) {
        final String stackTrace = entry.containsKey('stackTrace') ? entry['stackTrace']! as String : '';
        errors.add('${entry['error']}\n $stackTrace');
      } else if (entry.containsKey('success') && entry['success'] == true) {
        hasFailedTests = false;
      }
    }

    return TestFileReporterResults._(allTestSpecs: testSpecs, hasFailedTests: hasFailedTests, errors: errors);
  }

  final Map<int, TestSpecs> allTestSpecs;
  final bool hasFailedTests;
  final List<String> errors;


  static void addTestSpec(Map<String, Object?> suite, int time, Map<int, TestSpecs> allTestSpecs) {
    allTestSpecs[suite['id']! as int] = TestSpecs(
      path: suite['path']! as String,
      startTime: time,
    );
  }

  static void addMetricDone(int suiteID, int time, Map<int, TestSpecs> allTestSpecs) {
    final TestSpecs testSpec = allTestSpecs[suiteID]!;
    testSpec.endTime = time;
  }

  static bool isMetricDone(Map<String, Object?> entry, Map<int, TestSpecs> allTestSpecs) {
    if (entry.containsKey('group') && entry['type']! as String == 'group') {
      final Map<String, Object?> group = entry['group']! as Map<String, Object?>;
      return allTestSpecs.containsKey(group['suiteID']! as int);
    }
    return false;
  }
}