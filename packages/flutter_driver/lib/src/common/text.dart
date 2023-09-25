
import 'find.dart';
import 'message.dart';

class GetText extends CommandWithTarget {
  GetText(super.finder, { super.timeout });

  GetText.deserialize(super.json, super.finderFactory) : super.deserialize();

  @override
  String get kind => 'get_text';
}

class GetTextResult extends Result {
  const GetTextResult(this.text);

  final String text;

  static GetTextResult fromJson(Map<String, dynamic> json) {
    return GetTextResult(json['text'] as String);
  }

  @override
  Map<String, dynamic> toJson() => <String, String>{
    'text': text,
  };
}

class EnterText extends Command {
  const EnterText(this.text, { super.timeout });

  EnterText.deserialize(super.json)
    : text = json['text']!,
      super.deserialize();

  final String text;

  @override
  String get kind => 'enter_text';

  @override
  Map<String, String> serialize() => super.serialize()..addAll(<String, String>{
    'text': text,
  });
}

class SetTextEntryEmulation extends Command {
  const SetTextEntryEmulation(this.enabled, { super.timeout });

  SetTextEntryEmulation.deserialize(super.json)
    : enabled = json['enabled'] == 'true',
      super.deserialize();

  final bool enabled;

  @override
  String get kind => 'set_text_entry_emulation';

  @override
  Map<String, String> serialize() => super.serialize()..addAll(<String, String>{
    'enabled': '$enabled',
  });
}