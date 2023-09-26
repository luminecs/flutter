import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:metrics_center/metrics_center.dart';

Future<FlutterDestination> connectFlutterDestination() async {
  const String kTokenPath = 'TOKEN_PATH';
  const String kGcpProject = 'GCP_PROJECT';
  final Map<String, String> env = Platform.environment;
  final bool isTesting = env['IS_TESTING'] == 'true';
  if (env.containsKey(kTokenPath) && env.containsKey(kGcpProject)) {
    return FlutterDestination.makeFromAccessToken(
      File(env[kTokenPath]!).readAsStringSync(),
      env[kGcpProject]!,
      isTesting: isTesting,
    );
  }
  return FlutterDestination.makeFromCredentialsJson(
    jsonDecode(env['BENCHMARK_GCP_CREDENTIALS']!) as Map<String, dynamic>,
    isTesting: isTesting,
  );
}

List<MetricPoint> parse(Map<String, dynamic> resultsJson,
    Map<String, dynamic> benchmarkTags, String taskName) {
  print('Results to upload to skia perf: $resultsJson');
  print('Benchmark tags to upload to skia perf: $benchmarkTags');
  final List<String> scoreKeys =
      (resultsJson['BenchmarkScoreKeys'] as List<dynamic>?)?.cast<String>() ??
          const <String>[];
  final Map<String, dynamic> resultData =
      resultsJson['ResultData'] as Map<String, dynamic>? ??
          const <String, dynamic>{};
  final String gitBranch = (resultsJson['CommitBranch'] as String).trim();
  final String gitSha = (resultsJson['CommitSha'] as String).trim();
  final List<MetricPoint> metricPoints = <MetricPoint>[];
  for (final String scoreKey in scoreKeys) {
    Map<String, String> tags = <String, String>{
      kGithubRepoKey: kFlutterFrameworkRepo,
      kGitRevisionKey: gitSha,
      'branch': gitBranch,
      kNameKey: taskName,
      kSubResultKey: scoreKey,
    };
    // Append additional benchmark tags, which will surface in Skia Perf dashboards.
    tags = mergeMaps<String, String>(
        tags,
        benchmarkTags.map((String key, dynamic value) =>
            MapEntry<String, String>(key, value.toString())));
    metricPoints.add(
      MetricPoint(
        (resultData[scoreKey] as num).toDouble(),
        tags,
      ),
    );
  }
  return metricPoints;
}

Future<void> upload(
  FlutterDestination metricsDestination,
  List<MetricPoint> metricPoints,
  int commitTimeSinceEpoch,
  String taskName,
) async {
  await metricsDestination.update(
    metricPoints,
    DateTime.fromMillisecondsSinceEpoch(
      commitTimeSinceEpoch,
      isUtc: true,
    ),
    taskName,
  );
}

Future<void> uploadToSkiaPerf(String? resultsPath, String? commitTime,
    String? taskName, String? benchmarkTags) async {
  int commitTimeSinceEpoch;
  if (resultsPath == null) {
    return;
  }
  if (commitTime != null) {
    commitTimeSinceEpoch = 1000 * int.parse(commitTime);
  } else {
    commitTimeSinceEpoch = DateTime.now().millisecondsSinceEpoch;
  }
  taskName = taskName ?? 'default';
  final Map<String, dynamic> benchmarkTagsMap =
      jsonDecode(benchmarkTags ?? '{}') as Map<String, dynamic>;
  final File resultFile = File(resultsPath);
  Map<String, dynamic> resultsJson = <String, dynamic>{};
  resultsJson =
      json.decode(await resultFile.readAsString()) as Map<String, dynamic>;
  final List<MetricPoint> metricPoints =
      parse(resultsJson, benchmarkTagsMap, taskName);
  final FlutterDestination metricsDestination =
      await connectFlutterDestination();
  await upload(
    metricsDestination,
    metricPoints,
    commitTimeSinceEpoch,
    metricFileName(taskName, benchmarkTagsMap),
  );
}

String metricFileName(
  String taskName,
  Map<String, dynamic> benchmarkTagsMap,
) {
  final StringBuffer fileName = StringBuffer(taskName);
  if (benchmarkTagsMap.containsKey('arch')) {
    fileName
      ..write('_')
      ..write(_fileNameFormat(benchmarkTagsMap['arch'] as String));
  }
  if (benchmarkTagsMap.containsKey('host_type')) {
    fileName
      ..write('_')
      ..write(_fileNameFormat(benchmarkTagsMap['host_type'] as String));
  }
  if (benchmarkTagsMap.containsKey('device_type')) {
    fileName
      ..write('_')
      ..write(_fileNameFormat(benchmarkTagsMap['device_type'] as String));
  }
  return fileName.toString();
}

String _fileNameFormat(String fileName) {
  return fileName.replaceAll(RegExp('[^a-zA-Z0-9]'), '');
}
