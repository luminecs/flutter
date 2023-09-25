
import 'enum_util.dart';
import 'message.dart';

EnumIndex<TextInputAction> _textInputActionIndex =
    EnumIndex<TextInputAction>(TextInputAction.values);

class SendTextInputAction extends Command {
  const SendTextInputAction(this.textInputAction, {super.timeout});

  SendTextInputAction.deserialize(super.json)
      : textInputAction =
            _textInputActionIndex.lookupBySimpleName(json['action']!),
        super.deserialize();

  final TextInputAction textInputAction;

  @override
  String get kind => 'send_text_input_action';

  @override
  Map<String, String> serialize() => super.serialize()
    ..addAll(<String, String>{
      'action': _textInputActionIndex.toSimpleName(textInputAction),
    });
}

// This class is identical to [TextInputAction](https://api.flutter.dev/flutter/services/TextInputAction.html).
// This class is cloned from `TextInputAction` and must be kept in sync. The cloning is needed
// because importing is not allowed directly.
enum TextInputAction {
  none,

  unspecified,

  done,

  go,

  search,

  send,

  next,

  previous,

  continueAction,

  join,

  route,

  emergencyCall,

  newline,
}