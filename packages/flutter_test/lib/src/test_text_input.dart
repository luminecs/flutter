// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'binding.dart';
import 'test_async_utils.dart';
import 'test_text_input_key_handler.dart';

export 'package:flutter/services.dart' show TextEditingValue, TextInputAction;

class TestTextInput {
  TestTextInput({ this.onCleared });

  final VoidCallback? onCleared;

  final List<MethodCall> log = <MethodCall>[];

  void register() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.textInput, _handleTextInputCall);

  void unregister() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.textInput, null);

  bool get isRegistered => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.checkMockMessageHandler(SystemChannels.textInput.name, _handleTextInputCall);

  int? _client;

  bool get hasAnyClients {
    assert(isRegistered);
    return _client != null && _client! > 0;
  }

  Map<String, dynamic>? setClientArgs;

  Map<String, dynamic>? editingState;

  bool get isVisible {
    assert(isRegistered);
    return _isVisible;
  }
  bool _isVisible = false;

  // Platform specific key handler that can process unhandled keyboard events.
  TestTextInputKeyHandler? _keyHandler;

  void reset() {
    log.clear();
    _client = null;
    setClientArgs = null;
    editingState = null;
    _isVisible = false;
  }

  Future<dynamic> _handleTextInputCall(MethodCall methodCall) async {
    log.add(methodCall);
    switch (methodCall.method) {
      case 'TextInput.setClient':
        final List<dynamic> arguments = methodCall.arguments as List<dynamic>;
        _client = arguments[0] as int;
        setClientArgs = arguments[1] as Map<String, dynamic>;
      case 'TextInput.updateConfig':
        setClientArgs = methodCall.arguments as Map<String, dynamic>;
      case 'TextInput.clearClient':
        _client = null;
        _isVisible = false;
        _keyHandler = null;
        onCleared?.call();
      case 'TextInput.setEditingState':
        editingState = methodCall.arguments as Map<String, dynamic>;
      case 'TextInput.show':
        _isVisible = true;
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.macOS) {
          _keyHandler ??= MacOSTestTextInputKeyHandler(_client ?? -1);
        }
      case 'TextInput.hide':
        _isVisible = false;
        _keyHandler = null;
    }
  }

  void hide() {
    assert(isRegistered);
    _isVisible = false;
  }

  void enterText(String text) {
    updateEditingValue(TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    ));
  }

  void updateEditingValue(TextEditingValue value) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.textInput.name,
      SystemChannels.textInput.codec.encodeMethodCall(
        MethodCall(
          'TextInputClient.updateEditingState',
          <dynamic>[_client ?? -1, value.toJSON()],
        ),
      ),
      (ByteData? data) { /* ignored */ },
    );
  }

  Future<void> receiveAction(TextInputAction action) async {
    return TestAsyncUtils.guard(() {
      final Completer<void> completer = Completer<void>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
        SystemChannels.textInput.name,
        SystemChannels.textInput.codec.encodeMethodCall(
          MethodCall(
            'TextInputClient.performAction',
            <dynamic>[_client ?? -1, action.toString()],
          ),
        ),
        (ByteData? data) {
          assert(data != null);
          try {
            // Decoding throws a PlatformException if the data represents an
            // error, and that's all we care about here.
            SystemChannels.textInput.codec.decodeEnvelope(data!);
            // If we reach here then no error was found. Complete without issue.
            completer.complete();
          } catch (error) {
            // An exception occurred as a result of receiveAction()'ing. Report
            // that error.
            completer.completeError(error);
          }
        },
      );
      return completer.future;
    });
  }

  void closeConnection() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.textInput.name,
      SystemChannels.textInput.codec.encodeMethodCall(
        MethodCall(
          'TextInputClient.onConnectionClosed',
           <dynamic>[_client ?? -1],
        ),
      ),
      (ByteData? data) { /* response from framework is discarded */ },
    );
  }

  Future<void> startScribbleInteraction() async {
    assert(isRegistered);
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.textInput.name,
      SystemChannels.textInput.codec.encodeMethodCall(
        MethodCall(
          'TextInputClient.scribbleInteractionBegan',
           <dynamic>[_client ?? -1,]
        ),
      ),
      (ByteData? data) { /* response from framework is discarded */ },
    );
  }

  Future<void> finishScribbleInteraction() async {
    assert(isRegistered);
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.textInput.name,
      SystemChannels.textInput.codec.encodeMethodCall(
        MethodCall(
          'TextInputClient.scribbleInteractionFinished',
           <dynamic>[_client ?? -1,]
        ),
      ),
      (ByteData? data) { /* response from framework is discarded */ },
    );
  }

  Future<void> scribbleFocusElement(String elementIdentifier, Offset offset) async {
    assert(isRegistered);
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.textInput.name,
      SystemChannels.textInput.codec.encodeMethodCall(
        MethodCall(
          'TextInputClient.focusElement',
           <dynamic>[elementIdentifier, offset.dx, offset.dy]
        ),
      ),
      (ByteData? data) { /* response from framework is discarded */ },
    );
  }

  Future<List<List<dynamic>>> scribbleRequestElementsInRect(Rect rect) async {
    assert(isRegistered);
    List<List<dynamic>> response = <List<dynamic>>[];
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.textInput.name,
      SystemChannels.textInput.codec.encodeMethodCall(
        MethodCall(
          'TextInputClient.requestElementsInRect',
           <dynamic>[rect.left, rect.top, rect.width, rect.height]
        ),
      ),
      (ByteData? data) {
        response = (SystemChannels.textInput.codec.decodeEnvelope(data!) as List<dynamic>).map((dynamic element) => element as List<dynamic>).toList();
      },
    );

    return response;
  }

  Future<void> scribbleInsertPlaceholder() async {
    assert(isRegistered);
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.textInput.name,
      SystemChannels.textInput.codec.encodeMethodCall(
        MethodCall(
          'TextInputClient.insertTextPlaceholder',
           <dynamic>[_client ?? -1, 0.0, 0.0]
        ),
      ),
      (ByteData? data) { /* response from framework is discarded */ },
    );
  }

  Future<void> scribbleRemovePlaceholder() async {
    assert(isRegistered);
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.textInput.name,
      SystemChannels.textInput.codec.encodeMethodCall(
        MethodCall(
          'TextInputClient.removeTextPlaceholder',
           <dynamic>[_client ?? -1]
        ),
      ),
      (ByteData? data) { /* response from framework is discarded */ },
    );
  }

  Future<void> handleKeyDownEvent(LogicalKeyboardKey key) async {
    await _keyHandler?.handleKeyDownEvent(key);
  }

  Future<void> handleKeyUpEvent(LogicalKeyboardKey key) async {
    await _keyHandler?.handleKeyUpEvent(key);
  }

  Future<void> handleKeyboardUndo(String direction) async {
    assert(isRegistered);
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.handlePlatformMessage(
      SystemChannels.textInput.name,
      SystemChannels.textInput.codec.encodeMethodCall(
        MethodCall('TextInputClient.handleUndo', <dynamic>[direction]),
      ),
      (ByteData? data) {/* response from framework is discarded */},
    );
  }
}