
import 'package:meta/meta.dart';

abstract class Command {
  const Command({ this.timeout });

  Command.deserialize(Map<String, String> json)
    : timeout = _parseTimeout(json);

  static Duration? _parseTimeout(Map<String, String> json) {
    final String? timeout = json['timeout'];
    if (timeout == null) {
      return null;
    }
    return Duration(milliseconds: int.parse(timeout));
  }

  final Duration? timeout;

  String get kind;

  bool get requiresRootWidgetAttached => true;

  @mustCallSuper
  Map<String, String> serialize() {
    final Map<String, String> result = <String, String>{
      'command': kind,
    };
    if (timeout != null) {
      result['timeout'] = '${timeout!.inMilliseconds}';
    }
    return result;
  }
}

abstract class Result {
  const Result();

  static const Result empty = _EmptyResult();

  Map<String, dynamic> toJson();
}

class _EmptyResult extends Result {
  const _EmptyResult();

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{};
}