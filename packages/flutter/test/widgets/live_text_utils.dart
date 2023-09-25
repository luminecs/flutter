import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

class LiveTextInputTester {
  LiveTextInputTester() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, _handler);
  }

  bool mockLiveTextInputEnabled = false;

  Future<Object?> _handler(MethodCall methodCall) async {
    // Need to set Clipboard.hasStrings method handler because when showing the tool bar,
    // the Clipboard.hasStrings will also be invoked. If this isn't handled,
    // an exception will be thrown.
    if (methodCall.method == 'Clipboard.hasStrings') {
      return <String, bool>{'value': true};
    }
    if (methodCall.method == 'LiveText.isLiveTextInputAvailable') {
      return mockLiveTextInputEnabled;
    }
    return false;
  }

  void dispose() {
    assert(TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.checkMockMessageHandler(SystemChannels.platform.name, _handler));
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null);
  }
}

Finder findLiveTextButton() => find.byWidgetPredicate((Widget widget) =>
  widget is CustomPaint &&
  '${widget.painter?.runtimeType}' == '_LiveTextIconPainter',
);