
import 'package:flutter/foundation.dart';

import 'system_channels.dart';

@immutable
class ClipboardData {
  const ClipboardData({ required String this.text });

  // This is nullable as other clipboard data variants, like images, may be
  // added in the future. Currently, plain text is the only supported variant
  // and this is guaranteed to be non-null.
  final String? text;
}

abstract final class Clipboard {
  // Constants for common [getData] [format] types.

  static const String kTextPlain = 'text/plain';

  static Future<void> setData(ClipboardData data) async {
    await SystemChannels.platform.invokeMethod<void>(
      'Clipboard.setData',
      <String, dynamic>{
        'text': data.text,
      },
    );
  }

  static Future<ClipboardData?> getData(String format) async {
    final Map<String, dynamic>? result = await SystemChannels.platform.invokeMethod(
      'Clipboard.getData',
      format,
    );
    if (result == null) {
      return null;
    }
    return ClipboardData(text: result['text'] as String);
  }

  static Future<bool> hasStrings() async {
    final Map<String, dynamic>? result = await SystemChannels.platform.invokeMethod(
      'Clipboard.hasStrings',
      Clipboard.kTextPlain,
    );
    if (result == null) {
      return false;
    }
    return result['value'] as bool;
  }
}