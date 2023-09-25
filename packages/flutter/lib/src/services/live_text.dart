
import 'system_channels.dart';

class LiveText {
  // This class is not meant to be instantiated or extended; this constructor
  // prevents instantiation and extension.
  LiveText._();

  static Future<bool> isLiveTextInputAvailable() async {
    final bool supportLiveTextInput =
        await SystemChannels.platform.invokeMethod('LiveText.isLiveTextInputAvailable') ?? false;
    return supportLiveTextInput;
  }

  static void startLiveTextInput() {
    SystemChannels.textInput.invokeMethod('TextInput.startLiveTextInput');
  }
}