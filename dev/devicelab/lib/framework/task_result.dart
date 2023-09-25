import 'dart:convert';
import 'dart:io';

class TaskResult {
  TaskResult.buildOnly()
      : succeeded = true,
        data = null,
        detailFiles = null,
        benchmarkScoreKeys = null,
        message = 'No tests run';

  TaskResult.success(this.data, {
    this.benchmarkScoreKeys = const <String>[],
    this.detailFiles = const <String>[],
    this.message = 'success',
  })
      : succeeded = true {
    const JsonEncoder prettyJson = JsonEncoder.withIndent('  ');
    if (benchmarkScoreKeys != null) {
      for (final String key in benchmarkScoreKeys!) {
        if (!data!.containsKey(key)) {
          throw 'Invalid benchmark score key "$key". It does not exist in task '
              'result data ${prettyJson.convert(data)}';
        } else if (data![key] is! num) {
          throw 'Invalid benchmark score for key "$key". It is expected to be a num '
              'but was ${(data![key] as Object).runtimeType}: ${prettyJson.convert(data![key])}';
        }
      }
    }
  }

  factory TaskResult.successFromFile(File file, {
    List<String> benchmarkScoreKeys = const <String>[],
    List<String> detailFiles = const <String>[],
  }) {
    return TaskResult.success(
      json.decode(file.readAsStringSync()) as Map<String, dynamic>?,
      benchmarkScoreKeys: benchmarkScoreKeys,
      detailFiles: detailFiles,
    );
  }

  factory TaskResult.fromJson(Map<String, dynamic> json) {
    final bool success = json['success'] as bool;
    if (success) {
      final List<String> benchmarkScoreKeys = (json['benchmarkScoreKeys'] as List<dynamic>? ?? <String>[]).cast<String>();
      final List<String> detailFiles = (json['detailFiles'] as List<dynamic>? ?? <String>[]).cast<String>();
      return TaskResult.success(json['data'] as Map<String, dynamic>?,
        benchmarkScoreKeys: benchmarkScoreKeys,
        detailFiles: detailFiles,
        message: json['reason'] as String?,
      );
    }

    return TaskResult.failure(json['reason'] as String?);
  }

  TaskResult.failure(this.message)
      : succeeded = false,
        data = null,
        detailFiles = null,
        benchmarkScoreKeys = null;

  final bool succeeded;

  final Map<String, dynamic>? data;

  final List<String>? detailFiles;

  final List<String>? benchmarkScoreKeys;

  bool get failed => !succeeded;

  final String? message;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = <String, dynamic>{
      'success': succeeded,
    };

    if (succeeded) {
      json['data'] = data;
      json['detailFiles'] = detailFiles;
      json['benchmarkScoreKeys'] = benchmarkScoreKeys;
    }

    if (message != null || !succeeded) {
      json['reason'] = message;
    }

    return json;
  }

  @override
  String toString() => message ?? '';
}

class TaskResultCheckProcesses extends TaskResult {
  TaskResultCheckProcesses() : super.success(null);
}