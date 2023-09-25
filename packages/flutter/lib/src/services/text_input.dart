// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show
  FontWeight,
  Offset,
  Rect,
  Size,
  TextAlign,
  TextDirection;

import 'package:flutter/foundation.dart';
import 'package:vector_math/vector_math_64.dart' show Matrix4;

import 'autofill.dart';
import 'clipboard.dart' show Clipboard;
import 'keyboard_inserted_content.dart';
import 'message_codec.dart';
import 'platform_channel.dart';
import 'system_channels.dart';
import 'text_editing.dart';
import 'text_editing_delta.dart';

export 'dart:ui' show Brightness, FontWeight, Offset, Rect, Size, TextAlign, TextDirection, TextPosition, TextRange;

export 'package:vector_math/vector_math_64.dart' show Matrix4;

export 'autofill.dart' show AutofillConfiguration, AutofillScope;
export 'text_editing.dart' show TextSelection;
// TODO(a14n): the following export leads to Segmentation fault, see https://github.com/flutter/flutter/issues/106332
// export 'text_editing_delta.dart' show TextEditingDelta;

enum SmartDashesType {
  disabled,

  enabled,
}

enum SmartQuotesType {
  disabled,

  enabled,
}

@immutable
class TextInputType {
  const TextInputType._(this.index)
    : signed = null,
      decimal = null;

  const TextInputType.numberWithOptions({
    this.signed = false,
    this.decimal = false,
  }) : index = 2;

  final int index;

  final bool? signed;

  final bool? decimal;

  static const TextInputType text = TextInputType._(0);

  static const TextInputType multiline = TextInputType._(1);

  static const TextInputType number = TextInputType.numberWithOptions();

  static const TextInputType phone = TextInputType._(3);

  static const TextInputType datetime = TextInputType._(4);

  static const TextInputType emailAddress = TextInputType._(5);

  static const TextInputType url = TextInputType._(6);

  static const TextInputType visiblePassword = TextInputType._(7);

  static const TextInputType name = TextInputType._(8);

  static const TextInputType streetAddress = TextInputType._(9);

  static const TextInputType none = TextInputType._(10);

  static const List<TextInputType> values = <TextInputType>[
    text, multiline, number, phone, datetime, emailAddress, url, visiblePassword, name, streetAddress, none,
  ];

  // Corresponding string name for each of the [values].
  static const List<String> _names = <String>[
    'text', 'multiline', 'number', 'phone', 'datetime', 'emailAddress', 'url', 'visiblePassword', 'name', 'address', 'none',
  ];

  // Enum value name, this is what enum.toString() would normally return.
  String get _name => 'TextInputType.${_names[index]}';

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'name': _name,
      'signed': signed,
      'decimal': decimal,
    };
  }

  @override
  String toString() {
    return '${objectRuntimeType(this, 'TextInputType')}('
        'name: $_name, '
        'signed: $signed, '
        'decimal: $decimal)';
  }

  @override
  bool operator ==(Object other) {
    return other is TextInputType
        && other.index == index
        && other.signed == signed
        && other.decimal == decimal;
  }

  @override
  int get hashCode => Object.hash(index, signed, decimal);
}

//
// This class has been cloned to `flutter_driver/lib/src/common/action.dart` as `TextInputAction`,
// and must be kept in sync.
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

enum TextCapitalization {
  words,

  sentences,

  characters,

  none,
}

@immutable
class TextInputConfiguration {
  const TextInputConfiguration({
    this.inputType = TextInputType.text,
    this.readOnly = false,
    this.obscureText = false,
    this.autocorrect = true,
    SmartDashesType? smartDashesType,
    SmartQuotesType? smartQuotesType,
    this.enableSuggestions = true,
    this.enableInteractiveSelection = true,
    this.actionLabel,
    this.inputAction = TextInputAction.done,
    this.keyboardAppearance = Brightness.light,
    this.textCapitalization = TextCapitalization.none,
    this.autofillConfiguration = AutofillConfiguration.disabled,
    this.enableIMEPersonalizedLearning = true,
    this.allowedMimeTypes = const <String>[],
    this.enableDeltaModel = false,
  }) : smartDashesType = smartDashesType ?? (obscureText ? SmartDashesType.disabled : SmartDashesType.enabled),
       smartQuotesType = smartQuotesType ?? (obscureText ? SmartQuotesType.disabled : SmartQuotesType.enabled);

  final TextInputType inputType;

  final bool readOnly;

  final bool obscureText;

  final bool autocorrect;

  final AutofillConfiguration autofillConfiguration;

  final SmartDashesType smartDashesType;

  final SmartQuotesType smartQuotesType;

  final bool enableSuggestions;

  final bool enableInteractiveSelection;

  final String? actionLabel;

  final TextInputAction inputAction;

  final TextCapitalization textCapitalization;

  final Brightness keyboardAppearance;

  final bool enableIMEPersonalizedLearning;

  final List<String> allowedMimeTypes;

  TextInputConfiguration copyWith({
    TextInputType? inputType,
    bool? readOnly,
    bool? obscureText,
    bool? autocorrect,
    SmartDashesType? smartDashesType,
    SmartQuotesType? smartQuotesType,
    bool? enableSuggestions,
    bool? enableInteractiveSelection,
    String? actionLabel,
    TextInputAction? inputAction,
    Brightness? keyboardAppearance,
    TextCapitalization? textCapitalization,
    bool? enableIMEPersonalizedLearning,
    List<String>? allowedMimeTypes,
    AutofillConfiguration? autofillConfiguration,
    bool? enableDeltaModel,
  }) {
    return TextInputConfiguration(
      inputType: inputType ?? this.inputType,
      readOnly: readOnly ?? this.readOnly,
      obscureText: obscureText ?? this.obscureText,
      autocorrect: autocorrect ?? this.autocorrect,
      smartDashesType: smartDashesType ?? this.smartDashesType,
      smartQuotesType: smartQuotesType ?? this.smartQuotesType,
      enableSuggestions: enableSuggestions ?? this.enableSuggestions,
      enableInteractiveSelection: enableInteractiveSelection ?? this.enableInteractiveSelection,
      inputAction: inputAction ?? this.inputAction,
      textCapitalization: textCapitalization ?? this.textCapitalization,
      keyboardAppearance: keyboardAppearance ?? this.keyboardAppearance,
      enableIMEPersonalizedLearning: enableIMEPersonalizedLearning?? this.enableIMEPersonalizedLearning,
      allowedMimeTypes: allowedMimeTypes ?? this.allowedMimeTypes,
      autofillConfiguration: autofillConfiguration ?? this.autofillConfiguration,
      enableDeltaModel: enableDeltaModel ?? this.enableDeltaModel,
    );
  }

  final bool enableDeltaModel;

  Map<String, dynamic> toJson() {
    final Map<String, dynamic>? autofill = autofillConfiguration.toJson();
    return <String, dynamic>{
      'inputType': inputType.toJson(),
      'readOnly': readOnly,
      'obscureText': obscureText,
      'autocorrect': autocorrect,
      'smartDashesType': smartDashesType.index.toString(),
      'smartQuotesType': smartQuotesType.index.toString(),
      'enableSuggestions': enableSuggestions,
      'enableInteractiveSelection': enableInteractiveSelection,
      'actionLabel': actionLabel,
      'inputAction': inputAction.toString(),
      'textCapitalization': textCapitalization.toString(),
      'keyboardAppearance': keyboardAppearance.toString(),
      'enableIMEPersonalizedLearning': enableIMEPersonalizedLearning,
      'contentCommitMimeTypes': allowedMimeTypes,
      if (autofill != null) 'autofill': autofill,
      'enableDeltaModel' : enableDeltaModel,
    };
  }
}

TextAffinity? _toTextAffinity(String? affinity) {
  switch (affinity) {
    case 'TextAffinity.downstream':
      return TextAffinity.downstream;
    case 'TextAffinity.upstream':
      return TextAffinity.upstream;
  }
  return null;
}

enum FloatingCursorDragState {
  Start,

  Update,

  End,
}

class RawFloatingCursorPoint {
  RawFloatingCursorPoint({
    this.offset,
    required this.state,
  }) : assert(state != FloatingCursorDragState.Update || offset != null);

  final Offset? offset;

  final FloatingCursorDragState state;
}

@immutable
class TextEditingValue {
  const TextEditingValue({
    this.text = '',
    this.selection = const TextSelection.collapsed(offset: -1),
    this.composing = TextRange.empty,
  });

  factory TextEditingValue.fromJSON(Map<String, dynamic> encoded) {
    final String text = encoded['text'] as String;
    final TextSelection selection = TextSelection(
      baseOffset: encoded['selectionBase'] as int? ?? -1,
      extentOffset: encoded['selectionExtent'] as int? ?? -1,
      affinity: _toTextAffinity(encoded['selectionAffinity'] as String?) ?? TextAffinity.downstream,
      isDirectional: encoded['selectionIsDirectional'] as bool? ?? false,
    );
    final TextRange composing = TextRange(
      start: encoded['composingBase'] as int? ?? -1,
      end: encoded['composingExtent'] as int? ?? -1,
    );
    assert(_textRangeIsValid(selection, text));
    assert(_textRangeIsValid(composing, text));
    return TextEditingValue(
      text: text,
      selection: selection,
      composing: composing,
    );
  }

  final String text;

  final TextSelection selection;

  final TextRange composing;

  static const TextEditingValue empty = TextEditingValue();

  TextEditingValue copyWith({
    String? text,
    TextSelection? selection,
    TextRange? composing,
  }) {
    return TextEditingValue(
      text: text ?? this.text,
      selection: selection ?? this.selection,
      composing: composing ?? this.composing,
    );
  }

  bool get isComposingRangeValid => composing.isValid && composing.isNormalized && composing.end <= text.length;

  TextEditingValue replaced(TextRange replacementRange, String replacementString) {
    if (!replacementRange.isValid) {
      return this;
    }
    final String newText = text.replaceRange(replacementRange.start, replacementRange.end, replacementString);

    if (replacementRange.end - replacementRange.start == replacementString.length) {
      return copyWith(text: newText);
    }

    int adjustIndex(int originalIndex) {
      // The length added by adding the replacementString.
      final int replacedLength = originalIndex <= replacementRange.start && originalIndex < replacementRange.end ? 0 : replacementString.length;
      // The length removed by removing the replacementRange.
      final int removedLength = originalIndex.clamp(replacementRange.start, replacementRange.end) - replacementRange.start; // ignore_clamp_double_lint
      return originalIndex + replacedLength - removedLength;
    }

    final TextSelection adjustedSelection = TextSelection(
      baseOffset: adjustIndex(selection.baseOffset),
      extentOffset: adjustIndex(selection.extentOffset),
    );
    final TextRange adjustedComposing = TextRange(
      start: adjustIndex(composing.start),
      end: adjustIndex(composing.end),
    );
    assert(_textRangeIsValid(adjustedSelection, newText));
    assert(_textRangeIsValid(adjustedComposing, newText));
    return TextEditingValue(
      text: newText,
      selection: adjustedSelection,
      composing: adjustedComposing,
    );
  }

  Map<String, dynamic> toJSON() {
    assert(_textRangeIsValid(selection, text));
    assert(_textRangeIsValid(composing, text));
    return <String, dynamic>{
      'text': text,
      'selectionBase': selection.baseOffset,
      'selectionExtent': selection.extentOffset,
      'selectionAffinity': selection.affinity.toString(),
      'selectionIsDirectional': selection.isDirectional,
      'composingBase': composing.start,
      'composingExtent': composing.end,
    };
  }

  @override
  String toString() => '${objectRuntimeType(this, 'TextEditingValue')}(text: \u2524$text\u251C, selection: $selection, composing: $composing)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is TextEditingValue
        && other.text == text
        && other.selection == selection
        && other.composing == composing;
  }

  @override
  int get hashCode => Object.hash(
    text.hashCode,
    selection.hashCode,
    composing.hashCode,
  );

  // Verify that the given range is within the text.
  //
  // The verification can't be perform during the constructor of
  // [TextEditingValue], which are `const` and are allowed to retrieve
  // properties of [TextRange]s. [TextEditingValue] should perform this
  // wherever it is building other values (such as toJson) or is built in a
  // non-const way (such as fromJson).
  static bool _textRangeIsValid(TextRange range, String text) {
    if (range.start == -1 && range.end == -1) {
      return true;
    }
    assert(range.start >= 0 && range.start <= text.length,
        'Range start ${range.start} is out of text of length ${text.length}');
    assert(range.end >= 0 && range.end <= text.length,
        'Range end ${range.end} is out of text of length ${text.length}');
    return true;
  }
}

enum SelectionChangedCause {
  tap,

  doubleTap,

  longPress,

  forcePress,

  keyboard,

  toolbar,

  drag,

  scribble,
}

mixin TextSelectionDelegate {
  TextEditingValue get textEditingValue;

  void userUpdateTextEditingValue(TextEditingValue value, SelectionChangedCause cause);

  void hideToolbar([bool hideHandles = true]);

  void bringIntoView(TextPosition position);

  bool get cutEnabled => true;

  bool get copyEnabled => true;

  bool get pasteEnabled => true;

  bool get selectAllEnabled => true;

  bool get lookUpEnabled => true;

  bool get searchWebEnabled => true;

  bool get shareEnabled => true;

  bool get liveTextInputEnabled => false;

  void cutSelection(SelectionChangedCause cause);

  Future<void> pasteText(SelectionChangedCause cause);

  void selectAll(SelectionChangedCause cause);

  void copySelection(SelectionChangedCause cause);
}

mixin TextInputClient {
  TextEditingValue? get currentTextEditingValue;

  AutofillScope? get currentAutofillScope;

  void updateEditingValue(TextEditingValue value);

  void performAction(TextInputAction action);

  void insertContent(KeyboardInsertedContent content) {}

  void performPrivateCommand(String action, Map<String, dynamic> data);

  void updateFloatingCursor(RawFloatingCursorPoint point);

  void showAutocorrectionPromptRect(int start, int end);

  void connectionClosed();

  void didChangeInputControl(TextInputControl? oldControl, TextInputControl? newControl) {}

  void showToolbar() {}

  void insertTextPlaceholder(Size size) {}

  void removeTextPlaceholder() {}

  void performSelector(String selectorName) {}
}

abstract class ScribbleClient {
  String get elementIdentifier;

  void onScribbleFocus(Offset offset);

  bool isInScribbleRect(Rect rect);

  Rect get bounds;
}

@immutable
class SelectionRect {
  const SelectionRect({
    required this.position,
    required this.bounds,
    this.direction = TextDirection.ltr,
  });

  final int position;

  final Rect bounds;

  final TextDirection direction;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (runtimeType != other.runtimeType) {
      return false;
    }
    return other is SelectionRect
        && other.position == position
        && other.bounds == bounds
        && other.direction == direction;
  }

  @override
  int get hashCode => Object.hash(position, bounds);

  @override
  String toString() => 'SelectionRect($position, $bounds)';
}

mixin DeltaTextInputClient implements TextInputClient {
  void updateEditingValueWithDeltas(List<TextEditingDelta> textEditingDeltas);
}

class TextInputConnection {
  TextInputConnection._(this._client)
      : _id = _nextId++;

  Size? _cachedSize;
  Matrix4? _cachedTransform;
  Rect? _cachedRect;
  Rect? _cachedCaretRect;
  List<SelectionRect> _cachedSelectionRects = <SelectionRect>[];

  static int _nextId = 1;
  final int _id;

  @visibleForTesting
  static void debugResetId({int to = 1}) {
    assert(() {
      _nextId = to;
      return true;
    }());
  }

  final TextInputClient _client;

  bool get attached => TextInput._instance._currentConnection == this;

  bool get scribbleInProgress => TextInput._instance.scribbleInProgress;

  void show() {
    assert(attached);
    TextInput._instance._show();
  }

  void requestAutofill() {
    assert(attached);
    TextInput._instance._requestAutofill();
  }

  void updateConfig(TextInputConfiguration configuration) {
    assert(attached);
    TextInput._instance._updateConfig(configuration);
  }

  void setEditingState(TextEditingValue value) {
    assert(attached);
    TextInput._instance._setEditingState(value);
  }

  void setEditableSizeAndTransform(Size editableBoxSize, Matrix4 transform) {
    if (editableBoxSize != _cachedSize || transform != _cachedTransform) {
      _cachedSize = editableBoxSize;
      _cachedTransform = transform;
      TextInput._instance._setEditableSizeAndTransform(editableBoxSize, transform);
    }
  }

  void setComposingRect(Rect rect) {
    if (rect == _cachedRect) {
      return;
    }
    _cachedRect = rect;
    final Rect validRect = rect.isFinite ? rect : Offset.zero & const Size(-1, -1);
    TextInput._instance._setComposingTextRect(validRect);
  }

  void setCaretRect(Rect rect) {
    if (rect == _cachedCaretRect) {
      return;
    }
    _cachedCaretRect = rect;
    final Rect validRect = rect.isFinite ? rect : Offset.zero & const Size(-1, -1);
    TextInput._instance._setCaretRect(validRect);
  }

  void setSelectionRects(List<SelectionRect> selectionRects) {
    if (!listEquals(_cachedSelectionRects, selectionRects)) {
      _cachedSelectionRects = selectionRects;
      TextInput._instance._setSelectionRects(selectionRects);
    }
  }

  void setStyle({
    required String? fontFamily,
    required double? fontSize,
    required FontWeight? fontWeight,
    required TextDirection textDirection,
    required TextAlign textAlign,
  }) {
    assert(attached);

    TextInput._instance._setStyle(
      fontFamily: fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      textDirection: textDirection,
      textAlign: textAlign,
    );
  }

  void close() {
    if (attached) {
      TextInput._instance._clearClient();
    }
    assert(!attached);
  }

  void connectionClosedReceived() {
    TextInput._instance._currentConnection = null;
    assert(!attached);
  }
}

TextInputAction _toTextInputAction(String action) {
  switch (action) {
    case 'TextInputAction.none':
      return TextInputAction.none;
    case 'TextInputAction.unspecified':
      return TextInputAction.unspecified;
    case 'TextInputAction.go':
      return TextInputAction.go;
    case 'TextInputAction.search':
      return TextInputAction.search;
    case 'TextInputAction.send':
      return TextInputAction.send;
    case 'TextInputAction.next':
      return TextInputAction.next;
    case 'TextInputAction.previous':
      return TextInputAction.previous;
    case 'TextInputAction.continueAction':
      return TextInputAction.continueAction;
    case 'TextInputAction.join':
      return TextInputAction.join;
    case 'TextInputAction.route':
      return TextInputAction.route;
    case 'TextInputAction.emergencyCall':
      return TextInputAction.emergencyCall;
    case 'TextInputAction.done':
      return TextInputAction.done;
    case 'TextInputAction.newline':
      return TextInputAction.newline;
  }
  throw FlutterError.fromParts(<DiagnosticsNode>[ErrorSummary('Unknown text input action: $action')]);
}

FloatingCursorDragState _toTextCursorAction(String state) {
  switch (state) {
    case 'FloatingCursorDragState.start':
      return FloatingCursorDragState.Start;
    case 'FloatingCursorDragState.update':
      return FloatingCursorDragState.Update;
    case 'FloatingCursorDragState.end':
      return FloatingCursorDragState.End;
  }
  throw FlutterError.fromParts(<DiagnosticsNode>[ErrorSummary('Unknown text cursor action: $state')]);
}

RawFloatingCursorPoint _toTextPoint(FloatingCursorDragState state, Map<String, dynamic> encoded) {
  assert(encoded['X'] != null, 'You must provide a value for the horizontal location of the floating cursor.');
  assert(encoded['Y'] != null, 'You must provide a value for the vertical location of the floating cursor.');
  final Offset offset = state == FloatingCursorDragState.Update
    ? Offset((encoded['X'] as num).toDouble(), (encoded['Y'] as num).toDouble())
    : Offset.zero;
  return RawFloatingCursorPoint(offset: offset, state: state);
}

class TextInput {
  TextInput._() {
    _channel = SystemChannels.textInput;
    _channel.setMethodCallHandler(_loudlyHandleTextInputInvocation);
  }

  @visibleForTesting
  static void setChannel(MethodChannel newChannel) {
    assert(() {
      _instance._channel = newChannel..setMethodCallHandler(_instance._loudlyHandleTextInputInvocation);
      return true;
    }());
  }

  static final TextInput _instance = TextInput._();

  static void _addInputControl(TextInputControl control) {
    if (control != _PlatformTextInputControl.instance) {
      _instance._inputControls.add(control);
    }
  }

  static void _removeInputControl(TextInputControl control) {
    if (control != _PlatformTextInputControl.instance) {
      _instance._inputControls.remove(control);
    }
  }

  static void setInputControl(TextInputControl? newControl) {
    final TextInputControl? oldControl = _instance._currentControl;
    if (newControl == oldControl) {
      return;
    }
    if (newControl != null) {
      _addInputControl(newControl);
    }
    if (oldControl != null) {
      _removeInputControl(oldControl);
    }
    _instance._currentControl = newControl;
    final TextInputClient? client = _instance._currentConnection?._client;
    client?.didChangeInputControl(oldControl, newControl);
  }

  static void restorePlatformInputControl() {
    setInputControl(_PlatformTextInputControl.instance);
  }

  TextInputControl? _currentControl = _PlatformTextInputControl.instance;
  final Set<TextInputControl> _inputControls = <TextInputControl>{
    _PlatformTextInputControl.instance,
  };

  static const List<TextInputAction> _androidSupportedInputActions = <TextInputAction>[
    TextInputAction.none,
    TextInputAction.unspecified,
    TextInputAction.done,
    TextInputAction.send,
    TextInputAction.go,
    TextInputAction.search,
    TextInputAction.next,
    TextInputAction.previous,
    TextInputAction.newline,
  ];

  static const List<TextInputAction> _iOSSupportedInputActions = <TextInputAction>[
    TextInputAction.unspecified,
    TextInputAction.done,
    TextInputAction.send,
    TextInputAction.go,
    TextInputAction.search,
    TextInputAction.next,
    TextInputAction.newline,
    TextInputAction.continueAction,
    TextInputAction.join,
    TextInputAction.route,
    TextInputAction.emergencyCall,
  ];

  static void ensureInitialized() {
    _instance; // ignore: unnecessary_statements
  }

  static TextInputConnection attach(TextInputClient client, TextInputConfiguration configuration) {
    final TextInputConnection connection = TextInputConnection._(client);
    _instance._attach(connection, configuration);
    return connection;
  }

  // This method actually notifies the embedding of the client. It is utilized
  // by [attach] and by [_handleTextInputInvocation] for the
  // `TextInputClient.requestExistingInputState` method.
  void _attach(TextInputConnection connection, TextInputConfiguration configuration) {
    assert(_debugEnsureInputActionWorksOnPlatform(configuration.inputAction));
    _currentConnection = connection;
    _currentConfiguration = configuration;
    _setClient(connection._client, configuration);
  }

  static bool _debugEnsureInputActionWorksOnPlatform(TextInputAction inputAction) {
    assert(() {
      if (kIsWeb) {
        // TODO(flutterweb): what makes sense here?
        return true;
      }
      if (Platform.isIOS) {
        assert(
          _iOSSupportedInputActions.contains(inputAction),
          'The requested TextInputAction "$inputAction" is not supported on iOS.',
        );
      } else if (Platform.isAndroid) {
        assert(
          _androidSupportedInputActions.contains(inputAction),
          'The requested TextInputAction "$inputAction" is not supported on Android.',
        );
      }
      return true;
    }());
    return true;
  }

  late MethodChannel _channel;

  TextInputConnection? _currentConnection;
  late TextInputConfiguration _currentConfiguration;

  final Map<String, ScribbleClient> _scribbleClients = <String, ScribbleClient>{};
  bool _scribbleInProgress = false;

  @visibleForTesting
  static Map<String, ScribbleClient> get scribbleClients => TextInput._instance._scribbleClients;

  bool get scribbleInProgress => _scribbleInProgress;

  Future<dynamic> _loudlyHandleTextInputInvocation(MethodCall call) async {
    try {
      return await _handleTextInputInvocation(call);
    } catch (exception, stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception: exception,
        stack: stack,
        library: 'services library',
        context: ErrorDescription('during method call ${call.method}'),
        informationCollector: () => <DiagnosticsNode>[
          DiagnosticsProperty<MethodCall>('call', call, style: DiagnosticsTreeStyle.errorProperty),
        ],
      ));
      rethrow;
    }
  }

  Future<dynamic> _handleTextInputInvocation(MethodCall methodCall) async {
    final String method = methodCall.method;
    if (method == 'TextInputClient.focusElement') {
      final List<dynamic> args = methodCall.arguments as List<dynamic>;
      _scribbleClients[args[0]]?.onScribbleFocus(Offset((args[1] as num).toDouble(), (args[2] as num).toDouble()));
      return;
    } else if (method == 'TextInputClient.requestElementsInRect') {
      final List<double> args = (methodCall.arguments as List<dynamic>).cast<num>().map<double>((num value) => value.toDouble()).toList();
      return _scribbleClients.keys.where((String elementIdentifier) {
        final Rect rect = Rect.fromLTWH(args[0], args[1], args[2], args[3]);
        if (!(_scribbleClients[elementIdentifier]?.isInScribbleRect(rect) ?? false)) {
          return false;
        }
        final Rect bounds = _scribbleClients[elementIdentifier]?.bounds ?? Rect.zero;
        return !(bounds == Rect.zero || bounds.hasNaN || bounds.isInfinite);
      }).map((String elementIdentifier) {
        final Rect bounds = _scribbleClients[elementIdentifier]!.bounds;
        return <dynamic>[elementIdentifier, ...<dynamic>[bounds.left, bounds.top, bounds.width, bounds.height]];
      }).toList();
    } else if (method == 'TextInputClient.scribbleInteractionBegan') {
      _scribbleInProgress = true;
      return;
    } else if (method == 'TextInputClient.scribbleInteractionFinished') {
      _scribbleInProgress = false;
      return;
    }
    if (_currentConnection == null) {
      return;
    }

    // The requestExistingInputState request needs to be handled regardless of
    // the client ID, as long as we have a _currentConnection.
    if (method == 'TextInputClient.requestExistingInputState') {
      _attach(_currentConnection!, _currentConfiguration);
      final TextEditingValue? editingValue = _currentConnection!._client.currentTextEditingValue;
      if (editingValue != null) {
        _setEditingState(editingValue);
      }
      return;
    }

    final List<dynamic> args = methodCall.arguments as List<dynamic>;

    // The updateEditingStateWithTag request (autofill) can come up even to a
    // text field that doesn't have a connection.
    if (method == 'TextInputClient.updateEditingStateWithTag') {
      final TextInputClient client = _currentConnection!._client;
      final AutofillScope? scope = client.currentAutofillScope;
      final Map<String, dynamic> editingValue = args[1] as Map<String, dynamic>;
      for (final String tag in editingValue.keys) {
        final TextEditingValue textEditingValue = TextEditingValue.fromJSON(
          editingValue[tag] as Map<String, dynamic>,
        );
        final AutofillClient? client = scope?.getAutofillClient(tag);
        if (client != null && client.textInputConfiguration.autofillConfiguration.enabled) {
          client.autofill(textEditingValue);
        }
      }

      return;
    }

    final int client = args[0] as int;
    if (client != _currentConnection!._id) {
      // If the client IDs don't match, the incoming message was for a different
      // client.
      bool debugAllowAnyway = false;
      assert(() {
        // In debug builds we allow "-1" as a magical client ID that ignores
        // this verification step so that tests can always get through, even
        // when they are not mocking the engine side of text input.
        if (client == -1) {
          debugAllowAnyway = true;
        }
        return true;
      }());
      if (!debugAllowAnyway) {
        return;
      }
    }

    switch (method) {
      case 'TextInputClient.updateEditingState':
        final TextEditingValue value = TextEditingValue.fromJSON(args[1] as Map<String, dynamic>);
        TextInput._instance._updateEditingValue(value, exclude: _PlatformTextInputControl.instance);
      case 'TextInputClient.updateEditingStateWithDeltas':
        assert(_currentConnection!._client is DeltaTextInputClient, 'You must be using a DeltaTextInputClient if TextInputConfiguration.enableDeltaModel is set to true');
        final List<TextEditingDelta> deltas = <TextEditingDelta>[];

        final Map<String, dynamic> encoded = args[1] as Map<String, dynamic>;

        for (final dynamic encodedDelta in encoded['deltas'] as List<dynamic>) {
          final TextEditingDelta delta = TextEditingDelta.fromJSON(encodedDelta as Map<String, dynamic>);
          deltas.add(delta);
        }

        (_currentConnection!._client as DeltaTextInputClient).updateEditingValueWithDeltas(deltas);
      case 'TextInputClient.performAction':
        if (args[1] as String == 'TextInputAction.commitContent') {
          final KeyboardInsertedContent content = KeyboardInsertedContent.fromJson(args[2] as Map<String, dynamic>);
          _currentConnection!._client.insertContent(content);
        } else {
          _currentConnection!._client.performAction(_toTextInputAction(args[1] as String));
        }
      case 'TextInputClient.performSelectors':
        final List<String> selectors = (args[1] as List<dynamic>).cast<String>();
        selectors.forEach(_currentConnection!._client.performSelector);
      case 'TextInputClient.performPrivateCommand':
        final Map<String, dynamic> firstArg = args[1] as Map<String, dynamic>;
        _currentConnection!._client.performPrivateCommand(
          firstArg['action'] as String,
          firstArg['data'] == null
              ? <String, dynamic>{}
              : firstArg['data'] as Map<String, dynamic>,
        );
      case 'TextInputClient.updateFloatingCursor':
        _currentConnection!._client.updateFloatingCursor(_toTextPoint(
          _toTextCursorAction(args[1] as String),
          args[2] as Map<String, dynamic>,
        ));
      case 'TextInputClient.onConnectionClosed':
        _currentConnection!._client.connectionClosed();
      case 'TextInputClient.showAutocorrectionPromptRect':
        _currentConnection!._client.showAutocorrectionPromptRect(args[1] as int, args[2] as int);
      case 'TextInputClient.showToolbar':
        _currentConnection!._client.showToolbar();
      case 'TextInputClient.insertTextPlaceholder':
        _currentConnection!._client.insertTextPlaceholder(Size((args[1] as num).toDouble(), (args[2] as num).toDouble()));
      case 'TextInputClient.removeTextPlaceholder':
        _currentConnection!._client.removeTextPlaceholder();
      default:
        throw MissingPluginException();
    }
  }

  bool _hidePending = false;

  void _scheduleHide() {
    if (_hidePending) {
      return;
    }
    _hidePending = true;

    // Schedule a deferred task that hides the text input. If someone else
    // shows the keyboard during this update cycle, then the task will do
    // nothing.
    scheduleMicrotask(() {
      _hidePending = false;
      if (_currentConnection == null) {
        _hide();
      }
    });
  }

  void _setClient(TextInputClient client, TextInputConfiguration configuration) {
    for (final TextInputControl control in _inputControls) {
      control.attach(client, configuration);
    }
  }

  void _clearClient() {
    final TextInputClient client = _currentConnection!._client;
    for (final TextInputControl control in _inputControls) {
      control.detach(client);
    }
    _currentConnection = null;
    _scheduleHide();
  }

  void _updateConfig(TextInputConfiguration configuration) {
    for (final TextInputControl control in _inputControls) {
      control.updateConfig(configuration);
    }
  }

  void _setEditingState(TextEditingValue value) {
    for (final TextInputControl control in _inputControls) {
      control.setEditingState(value);
    }
  }

  void _show() {
    for (final TextInputControl control in _inputControls) {
      control.show();
    }
  }

  void _hide() {
    for (final TextInputControl control in _inputControls) {
      control.hide();
    }
  }

  void _setEditableSizeAndTransform(Size editableBoxSize, Matrix4 transform) {
    for (final TextInputControl control in _inputControls) {
      control.setEditableSizeAndTransform(editableBoxSize, transform);
    }
  }

  void _setComposingTextRect(Rect rect) {
    for (final TextInputControl control in _inputControls) {
      control.setComposingRect(rect);
    }
  }

  void _setCaretRect(Rect rect) {
    for (final TextInputControl control in _inputControls) {
      control.setCaretRect(rect);
    }
  }

  void _setSelectionRects(List<SelectionRect> selectionRects) {
    for (final TextInputControl control in _inputControls) {
      control.setSelectionRects(selectionRects);
    }
  }

  void _setStyle({
    required String? fontFamily,
    required double? fontSize,
    required FontWeight? fontWeight,
    required TextDirection textDirection,
    required TextAlign textAlign,
  }) {
    for (final TextInputControl control in _inputControls) {
      control.setStyle(
        fontFamily: fontFamily,
        fontSize: fontSize,
        fontWeight: fontWeight,
        textDirection: textDirection,
        textAlign: textAlign,
      );
    }
  }

  void _requestAutofill() {
    for (final TextInputControl control in _inputControls) {
      control.requestAutofill();
    }
  }

  void _updateEditingValue(TextEditingValue value, {TextInputControl? exclude}) {
    if (_currentConnection == null) {
      return;
    }

    for (final TextInputControl control in _instance._inputControls) {
      if (control != exclude) {
        control.setEditingState(value);
      }
    }
    _instance._currentConnection!._client.updateEditingValue(value);
  }

  static void updateEditingValue(TextEditingValue value) {
    _instance._updateEditingValue(value, exclude: _instance._currentControl);
  }

  static void finishAutofillContext({ bool shouldSave = true }) {
    for (final TextInputControl control in TextInput._instance._inputControls) {
      control.finishAutofillContext(shouldSave: shouldSave);
    }
  }

  static void registerScribbleElement(String elementIdentifier, ScribbleClient scribbleClient) {
    TextInput._instance._scribbleClients[elementIdentifier] = scribbleClient;
  }

  static void unregisterScribbleElement(String elementIdentifier) {
    TextInput._instance._scribbleClients.remove(elementIdentifier);
  }
}

mixin TextInputControl {
  void attach(TextInputClient client, TextInputConfiguration configuration) {}

  void detach(TextInputClient client) {}

  void show() {}

  void hide() {}

  void updateConfig(TextInputConfiguration configuration) {}

  void setEditingState(TextEditingValue value) {}

  void setEditableSizeAndTransform(Size editableBoxSize, Matrix4 transform) {}

  void setComposingRect(Rect rect) {}

  void setCaretRect(Rect rect) {}

  void setSelectionRects(List<SelectionRect> selectionRects) {}

  void setStyle({
    required String? fontFamily,
    required double? fontSize,
    required FontWeight? fontWeight,
    required TextDirection textDirection,
    required TextAlign textAlign,
  }) {}

  void requestAutofill() {}

  void finishAutofillContext({bool shouldSave = true}) {}
}

class _PlatformTextInputControl with TextInputControl {
  _PlatformTextInputControl._();

  static final _PlatformTextInputControl instance = _PlatformTextInputControl._();

  MethodChannel get _channel => TextInput._instance._channel;

  Map<String, dynamic> _configurationToJson(TextInputConfiguration configuration) {
    final Map<String, dynamic> json = configuration.toJson();
    if (TextInput._instance._currentControl != _PlatformTextInputControl.instance) {
      json['inputType'] = TextInputType.none.toJson();
    }
    return json;
  }

  @override
  void attach(TextInputClient client, TextInputConfiguration configuration) {
    _channel.invokeMethod<void>(
      'TextInput.setClient',
      <Object>[
        TextInput._instance._currentConnection!._id,
        _configurationToJson(configuration),
      ],
    );
  }

  @override
  void detach(TextInputClient client) {
    _channel.invokeMethod<void>('TextInput.clearClient');
  }

  @override
  void updateConfig(TextInputConfiguration configuration) {
    _channel.invokeMethod<void>(
      'TextInput.updateConfig',
      _configurationToJson(configuration),
    );
  }

  @override
  void setEditingState(TextEditingValue value) {
    _channel.invokeMethod<void>(
      'TextInput.setEditingState',
      value.toJSON(),
    );
  }

  @override
  void show() {
    _channel.invokeMethod<void>('TextInput.show');
  }

  @override
  void hide() {
    _channel.invokeMethod<void>('TextInput.hide');
  }

  @override
  void setEditableSizeAndTransform(Size editableBoxSize, Matrix4 transform) {
    _channel.invokeMethod<void>(
      'TextInput.setEditableSizeAndTransform',
      <String, dynamic>{
        'width': editableBoxSize.width,
        'height': editableBoxSize.height,
        'transform': transform.storage,
      },
    );
  }

  @override
  void setComposingRect(Rect rect) {
    _channel.invokeMethod<void>(
      'TextInput.setMarkedTextRect',
      <String, dynamic>{
        'width': rect.width,
        'height': rect.height,
        'x': rect.left,
        'y': rect.top,
      },
    );
  }

  @override
  void setCaretRect(Rect rect) {
    _channel.invokeMethod<void>(
      'TextInput.setCaretRect',
      <String, dynamic>{
        'width': rect.width,
        'height': rect.height,
        'x': rect.left,
        'y': rect.top,
      },
    );
  }

  @override
  void setSelectionRects(List<SelectionRect> selectionRects) {
    _channel.invokeMethod<void>(
      'TextInput.setSelectionRects',
      selectionRects.map((SelectionRect rect) {
        return <num>[
          rect.bounds.left,
          rect.bounds.top,
          rect.bounds.width,
          rect.bounds.height,
          rect.position,
          rect.direction.index,
        ];
      }).toList(),
    );
  }


  @override
  void setStyle({
    required String? fontFamily,
    required double? fontSize,
    required FontWeight? fontWeight,
    required TextDirection textDirection,
    required TextAlign textAlign,
  }) {
    _channel.invokeMethod<void>(
      'TextInput.setStyle',
      <String, dynamic>{
        'fontFamily': fontFamily,
        'fontSize': fontSize,
        'fontWeightIndex': fontWeight?.index,
        'textAlignIndex': textAlign.index,
        'textDirectionIndex': textDirection.index,
      },
    );
  }

  @override
  void requestAutofill() {
    _channel.invokeMethod<void>('TextInput.requestAutofill');
  }

  @override
  void finishAutofillContext({bool shouldSave = true}) {
    _channel.invokeMethod<void>(
      'TextInput.finishAutofillContext',
      shouldSave,
    );
  }
}