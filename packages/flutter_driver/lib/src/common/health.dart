import 'enum_util.dart';
import 'message.dart';

class GetHealth extends Command {
  const GetHealth({super.timeout});

  GetHealth.deserialize(super.json) : super.deserialize();

  @override
  String get kind => 'get_health';

  @override
  bool get requiresRootWidgetAttached => false;
}

enum HealthStatus {
  ok,

  bad,
}

final EnumIndex<HealthStatus> _healthStatusIndex =
    EnumIndex<HealthStatus>(HealthStatus.values);

class Health extends Result {
  const Health(this.status);

  final HealthStatus status;

  static Health fromJson(Map<String, dynamic> json) {
    return Health(
        _healthStatusIndex.lookupBySimpleName(json['status'] as String));
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'status': _healthStatusIndex.toSimpleName(status),
      };
}
