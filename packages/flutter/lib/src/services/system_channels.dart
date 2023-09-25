import 'dart:ui';

import 'message_codecs.dart';
import 'platform_channel.dart';

export 'platform_channel.dart' show BasicMessageChannel, MethodChannel;

abstract final class SystemChannels {
  static const MethodChannel navigation = OptionalMethodChannel(
      'flutter/navigation',
      JSONMethodCodec(),
  );

  static const MethodChannel platform = OptionalMethodChannel(
      'flutter/platform',
      JSONMethodCodec(),
  );

  static const MethodChannel textInput = OptionalMethodChannel(
      'flutter/textinput',
      JSONMethodCodec(),
  );

  static const MethodChannel spellCheck = OptionalMethodChannel(
      'flutter/spellcheck',
  );

  static const MethodChannel undoManager = OptionalMethodChannel(
    'flutter/undomanager',
    JSONMethodCodec(),
  );

  static const BasicMessageChannel<Object?> keyEvent = BasicMessageChannel<Object?>(
      'flutter/keyevent',
      JSONMessageCodec(),
  );

  static const BasicMessageChannel<String?> lifecycle = BasicMessageChannel<String?>(
      'flutter/lifecycle',
      StringCodec(),
  );

  static const BasicMessageChannel<Object?> system = BasicMessageChannel<Object?>(
      'flutter/system',
      JSONMessageCodec(),
  );

  static const BasicMessageChannel<Object?> accessibility = BasicMessageChannel<Object?>(
    'flutter/accessibility',
    StandardMessageCodec(),
  );

  static const MethodChannel platform_views = MethodChannel(
    'flutter/platform_views',
  );

  static const MethodChannel skia = MethodChannel(
    'flutter/skia',
    JSONMethodCodec(),
  );

  static const MethodChannel mouseCursor = OptionalMethodChannel(
    'flutter/mousecursor',
  );

  static const MethodChannel restoration = OptionalMethodChannel(
    'flutter/restoration',
  );

  static const MethodChannel deferredComponent = OptionalMethodChannel(
    'flutter/deferredcomponent',
  );

  static const MethodChannel localization = OptionalMethodChannel(
    'flutter/localization',
    JSONMethodCodec(),
  );

  static const MethodChannel menu = OptionalMethodChannel('flutter/menu');

  static const MethodChannel contextMenu = OptionalMethodChannel(
    'flutter/contextmenu',
    JSONMethodCodec(),
  );

  static const MethodChannel keyboard = OptionalMethodChannel(
    'flutter/keyboard',
  );
}