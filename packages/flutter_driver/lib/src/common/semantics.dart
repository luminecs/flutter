import 'message.dart';

class SetSemantics extends Command {
  const SetSemantics(this.enabled, { super.timeout });

  SetSemantics.deserialize(super.json)
    : enabled = json['enabled']!.toLowerCase() == 'true',
      super.deserialize();

  final bool enabled;

  @override
  String get kind => 'set_semantics';

  @override
  Map<String, String> serialize() => super.serialize()..addAll(<String, String>{
    'enabled': '$enabled',
  });
}

class SetSemanticsResult extends Result {
  const SetSemanticsResult(this.changedState);

  final bool changedState;

  static SetSemanticsResult fromJson(Map<String, dynamic> json) {
    return SetSemanticsResult(json['changedState'] as bool);
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
    'changedState': changedState,
  };
}