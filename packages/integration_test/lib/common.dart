import 'dart:async';
import 'dart:convert';

typedef ScreenshotCallback = Future<bool> Function(String name, List<int> image, [Map<String, Object?>? args]);


class Response {
  Response.allTestsPassed({this.data})
      : _allTestsPassed = true,
        _failureDetails = null;

  Response.someTestsFailed(this._failureDetails, {this.data})
      : _allTestsPassed = false;

  Response.toolException({String? ex})
      : _allTestsPassed = false,
        _failureDetails = <Failure>[Failure('ToolException', ex)];

  Response.webDriverCommand({this.data})
      : _allTestsPassed = false,
        _failureDetails = null;

  final List<Failure>? _failureDetails;

  final bool _allTestsPassed;

  Map<String, dynamic>? data;

  bool get allTestsPassed => _allTestsPassed;

  String get formattedFailureDetails =>
      _allTestsPassed ? '' : formatFailures(_failureDetails!);

  List<Failure>? get failureDetails => _failureDetails;

  String toJson() => json.encode(<String, dynamic>{
        'result': allTestsPassed.toString(),
        'failureDetails': _failureDetailsAsString(),
        if (data != null) 'data': data,
      });

  static Response fromJson(String source) {
    final Map<String, dynamic> responseJson = json.decode(source) as Map<String, dynamic>;
    if ((responseJson['result'] as String?) == 'true') {
      return Response.allTestsPassed(data: responseJson['data'] as Map<String, dynamic>?);
    } else {
      return Response.someTestsFailed(
        _failureDetailsFromJson(responseJson['failureDetails'] as List<dynamic>),
        data: responseJson['data'] as Map<String, dynamic>?,
      );
    }
  }

  String formatFailures(List<Failure> failureDetails) {
    if (failureDetails.isEmpty) {
      return '';
    }

    final StringBuffer sb = StringBuffer();
    int failureCount = 1;
    for (final Failure failure in failureDetails) {
      sb.writeln('Failure in method: ${failure.methodName}');
      sb.writeln(failure.details);
      sb.writeln('end of failure $failureCount\n\n');
      failureCount++;
    }
    return sb.toString();
  }

  List<String> _failureDetailsAsString() {
    final List<String> list = <String>[];
    if (_failureDetails == null || _failureDetails.isEmpty) {
      return list;
    }

    for (final Failure failure in _failureDetails) {
      list.add(failure.toJson());
    }

    return list;
  }

  static List<Failure> _failureDetailsFromJson(List<dynamic> list) {
    return list.map((dynamic s) {
      return Failure.fromJsonString(s as String);
    }).toList();
  }
}

class Failure {
  Failure(this.methodName, this.details);

  final String methodName;

  final String? details;

  String toJson() {
    return json.encode(<String, String?>{
      'methodName': methodName,
      'details': details,
    });
  }

  @override
  String toString() => toJson();

  static Failure fromJsonString(String jsonString) {
    final Map<String, dynamic> failure = json.decode(jsonString) as Map<String, dynamic>;
    return Failure(failure['methodName'] as String, failure['details'] as String?);
  }
}

class DriverTestMessage {
  DriverTestMessage.error()
      : _isSuccess = false,
        _isPending = false;

  DriverTestMessage.pending()
      : _isSuccess = false,
        _isPending = true;

  DriverTestMessage.complete()
      : _isSuccess = true,
        _isPending = false;

  final bool _isSuccess;
  final bool _isPending;

  // /// Status of this message.
  // ///
  // /// The status will be use to notify `integration_test` of driver side's
  // /// state.
  // String get status => _status;

  bool get isSuccess => _isSuccess;

  bool get isPending => _isPending;

  @override
  String toString() {
    if (isPending) {
      return 'pending';
    } else if (isSuccess) {
      return 'complete';
    } else {
      return 'error';
    }
  }

  static DriverTestMessage fromString(String status) {
    switch (status) {
      case 'error':
        return DriverTestMessage.error();
      case 'pending':
        return DriverTestMessage.pending();
      case 'complete':
        return DriverTestMessage.complete();
      default:
        throw StateError('This type of status does not exist: $status');
    }
  }
}

enum WebDriverCommandType {
  ack,

  noop,

  screenshot,
}

class WebDriverCommand {
  WebDriverCommand.noop()
      : type = WebDriverCommandType.noop,
        values = <String, dynamic>{};

  WebDriverCommand.screenshot(String screenshotName, [Map<String, Object?>? args])
      : type = WebDriverCommandType.screenshot,
        values = <String, dynamic>{
          'screenshot_name': screenshotName,
          if (args != null) 'args': args,
        };

  final WebDriverCommandType type;

  final Map<String, dynamic> values;

  static Map<String, dynamic> typeToMap(WebDriverCommandType type) => <String, dynamic>{
    'web_driver_command': '$type',
  };
}

abstract class CallbackManager {
  Future<Map<String, dynamic>> callback(
      Map<String, String> params, IntegrationTestResults testRunner);

   Future<Map<String, dynamic>> takeScreenshot(String screenshot, [Map<String, Object?>? args]);

  Future<void> convertFlutterSurfaceToImage();

  void cleanup();
}

abstract class IntegrationTestResults {
  List<Failure> get failureMethodsDetails;

  Map<String, dynamic>? get reportData;

  Completer<bool> get allTestsPassed;
}