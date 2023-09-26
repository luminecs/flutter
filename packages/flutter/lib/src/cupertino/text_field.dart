import 'dart:ui' as ui show BoxHeightStyle, BoxWidthStyle;

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'adaptive_text_selection_toolbar.dart';
import 'colors.dart';
import 'desktop_text_selection.dart';
import 'icons.dart';
import 'magnifier.dart';
import 'spell_check_suggestions_toolbar.dart';
import 'text_selection.dart';
import 'theme.dart';

export 'package:flutter/services.dart'
    show
        SmartDashesType,
        SmartQuotesType,
        TextCapitalization,
        TextInputAction,
        TextInputType;

const TextStyle _kDefaultPlaceholderStyle = TextStyle(
  fontWeight: FontWeight.w400,
  color: CupertinoColors.placeholderText,
);

// Value inspected from Xcode 11 & iOS 13.0 Simulator.
const BorderSide _kDefaultRoundedBorderSide = BorderSide(
  color: CupertinoDynamicColor.withBrightness(
    color: Color(0x33000000),
    darkColor: Color(0x33FFFFFF),
  ),
  width: 0.0,
);
const Border _kDefaultRoundedBorder = Border(
  top: _kDefaultRoundedBorderSide,
  bottom: _kDefaultRoundedBorderSide,
  left: _kDefaultRoundedBorderSide,
  right: _kDefaultRoundedBorderSide,
);

const BoxDecoration _kDefaultRoundedBorderDecoration = BoxDecoration(
  color: CupertinoDynamicColor.withBrightness(
    color: CupertinoColors.white,
    darkColor: CupertinoColors.black,
  ),
  border: _kDefaultRoundedBorder,
  borderRadius: BorderRadius.all(Radius.circular(5.0)),
);

const Color _kDisabledBackground = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFFAFAFA),
  darkColor: Color(0xFF050505),
);

// Value inspected from Xcode 12 & iOS 14.0 Simulator.
// Note it may not be consistent with https://developer.apple.com/design/resources/.
const CupertinoDynamicColor _kClearButtonColor =
    CupertinoDynamicColor.withBrightness(
  color: Color(0x33000000),
  darkColor: Color(0x33FFFFFF),
);

// An eyeballed value that moves the cursor slightly left of where it is
// rendered for text on Android so it's positioning more accurately matches the
// native iOS text cursor positioning.
//
// This value is in device pixels, not logical pixels as is typically used
// throughout the codebase.
const int _iOSHorizontalCursorOffsetPixels = -2;

enum OverlayVisibilityMode {
  never,

  editing,

  notEditing,

  always,
}

class _CupertinoTextFieldSelectionGestureDetectorBuilder
    extends TextSelectionGestureDetectorBuilder {
  _CupertinoTextFieldSelectionGestureDetectorBuilder({
    required _CupertinoTextFieldState state,
  })  : _state = state,
        super(delegate: state);

  final _CupertinoTextFieldState _state;

  @override
  void onSingleTapUp(TapDragUpDetails details) {
    // Because TextSelectionGestureDetector listens to taps that happen on
    // widgets in front of it, tapping the clear button will also trigger
    // this handler. If the clear button widget recognizes the up event,
    // then do not handle it.
    if (_state._clearGlobalKey.currentContext != null) {
      final RenderBox renderBox = _state._clearGlobalKey.currentContext!
          .findRenderObject()! as RenderBox;
      final Offset localOffset =
          renderBox.globalToLocal(details.globalPosition);
      if (renderBox.hitTest(BoxHitTestResult(), position: localOffset)) {
        return;
      }
    }
    super.onSingleTapUp(details);
    _state._requestKeyboard();
    _state.widget.onTap?.call();
  }

  @override
  void onDragSelectionEnd(TapDragEndDetails details) {
    _state._requestKeyboard();
    super.onDragSelectionEnd(details);
  }
}

class CupertinoTextField extends StatefulWidget {
  const CupertinoTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.undoController,
    this.decoration = _kDefaultRoundedBorderDecoration,
    this.padding = const EdgeInsets.all(7.0),
    this.placeholder,
    this.placeholderStyle = const TextStyle(
      fontWeight: FontWeight.w400,
      color: CupertinoColors.placeholderText,
    ),
    this.prefix,
    this.prefixMode = OverlayVisibilityMode.always,
    this.suffix,
    this.suffixMode = OverlayVisibilityMode.always,
    this.clearButtonMode = OverlayVisibilityMode.never,
    TextInputType? keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.style,
    this.strutStyle,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.textDirection,
    this.readOnly = false,
    @Deprecated(
      'Use `contextMenuBuilder` instead. '
      'This feature was deprecated after v3.3.0-0.5.pre.',
    )
    this.toolbarOptions,
    this.showCursor,
    this.autofocus = false,
    this.obscuringCharacter = '•',
    this.obscureText = false,
    this.autocorrect = true,
    SmartDashesType? smartDashesType,
    SmartQuotesType? smartQuotesType,
    this.enableSuggestions = true,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.maxLength,
    this.maxLengthEnforcement,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.onTapOutside,
    this.inputFormatters,
    this.enabled = true,
    this.cursorWidth = 2.0,
    this.cursorHeight,
    this.cursorRadius = const Radius.circular(2.0),
    this.cursorOpacityAnimates = true,
    this.cursorColor,
    this.selectionHeightStyle = ui.BoxHeightStyle.tight,
    this.selectionWidthStyle = ui.BoxWidthStyle.tight,
    this.keyboardAppearance,
    this.scrollPadding = const EdgeInsets.all(20.0),
    this.dragStartBehavior = DragStartBehavior.start,
    bool? enableInteractiveSelection,
    this.selectionControls,
    this.onTap,
    this.scrollController,
    this.scrollPhysics,
    this.autofillHints = const <String>[],
    this.contentInsertionConfiguration,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
    this.scribbleEnabled = true,
    this.enableIMEPersonalizedLearning = true,
    this.contextMenuBuilder = _defaultContextMenuBuilder,
    this.spellCheckConfiguration,
    this.magnifierConfiguration,
  })  : assert(obscuringCharacter.length == 1),
        smartDashesType = smartDashesType ??
            (obscureText ? SmartDashesType.disabled : SmartDashesType.enabled),
        smartQuotesType = smartQuotesType ??
            (obscureText ? SmartQuotesType.disabled : SmartQuotesType.enabled),
        assert(maxLines == null || maxLines > 0),
        assert(minLines == null || minLines > 0),
        assert(
          (maxLines == null) || (minLines == null) || (maxLines >= minLines),
          "minLines can't be greater than maxLines",
        ),
        assert(
          !expands || (maxLines == null && minLines == null),
          'minLines and maxLines must be null when expands is true.',
        ),
        assert(!obscureText || maxLines == 1,
            'Obscured fields cannot be multiline.'),
        assert(maxLength == null || maxLength > 0),
        // Assert the following instead of setting it directly to avoid surprising the user by silently changing the value they set.
        assert(
          !identical(textInputAction, TextInputAction.newline) ||
              maxLines == 1 ||
              !identical(keyboardType, TextInputType.text),
          'Use keyboardType TextInputType.multiline when using TextInputAction.newline on a multiline TextField.',
        ),
        keyboardType = keyboardType ??
            (maxLines == 1 ? TextInputType.text : TextInputType.multiline),
        enableInteractiveSelection =
            enableInteractiveSelection ?? (!readOnly || !obscureText);

  const CupertinoTextField.borderless({
    super.key,
    this.controller,
    this.focusNode,
    this.undoController,
    this.decoration,
    this.padding = const EdgeInsets.all(7.0),
    this.placeholder,
    this.placeholderStyle = _kDefaultPlaceholderStyle,
    this.prefix,
    this.prefixMode = OverlayVisibilityMode.always,
    this.suffix,
    this.suffixMode = OverlayVisibilityMode.always,
    this.clearButtonMode = OverlayVisibilityMode.never,
    TextInputType? keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.style,
    this.strutStyle,
    this.textAlign = TextAlign.start,
    this.textAlignVertical,
    this.textDirection,
    this.readOnly = false,
    @Deprecated(
      'Use `contextMenuBuilder` instead. '
      'This feature was deprecated after v3.3.0-0.5.pre.',
    )
    this.toolbarOptions,
    this.showCursor,
    this.autofocus = false,
    this.obscuringCharacter = '•',
    this.obscureText = false,
    this.autocorrect = true,
    SmartDashesType? smartDashesType,
    SmartQuotesType? smartQuotesType,
    this.enableSuggestions = true,
    this.maxLines = 1,
    this.minLines,
    this.expands = false,
    this.maxLength,
    this.maxLengthEnforcement,
    this.onChanged,
    this.onEditingComplete,
    this.onSubmitted,
    this.onTapOutside,
    this.inputFormatters,
    this.enabled = true,
    this.cursorWidth = 2.0,
    this.cursorHeight,
    this.cursorRadius = const Radius.circular(2.0),
    this.cursorOpacityAnimates = true,
    this.cursorColor,
    this.selectionHeightStyle = ui.BoxHeightStyle.tight,
    this.selectionWidthStyle = ui.BoxWidthStyle.tight,
    this.keyboardAppearance,
    this.scrollPadding = const EdgeInsets.all(20.0),
    this.dragStartBehavior = DragStartBehavior.start,
    bool? enableInteractiveSelection,
    this.selectionControls,
    this.onTap,
    this.scrollController,
    this.scrollPhysics,
    this.autofillHints = const <String>[],
    this.contentInsertionConfiguration,
    this.clipBehavior = Clip.hardEdge,
    this.restorationId,
    this.scribbleEnabled = true,
    this.enableIMEPersonalizedLearning = true,
    this.contextMenuBuilder = _defaultContextMenuBuilder,
    this.spellCheckConfiguration,
    this.magnifierConfiguration,
  })  : assert(obscuringCharacter.length == 1),
        smartDashesType = smartDashesType ??
            (obscureText ? SmartDashesType.disabled : SmartDashesType.enabled),
        smartQuotesType = smartQuotesType ??
            (obscureText ? SmartQuotesType.disabled : SmartQuotesType.enabled),
        assert(maxLines == null || maxLines > 0),
        assert(minLines == null || minLines > 0),
        assert(
          (maxLines == null) || (minLines == null) || (maxLines >= minLines),
          "minLines can't be greater than maxLines",
        ),
        assert(
          !expands || (maxLines == null && minLines == null),
          'minLines and maxLines must be null when expands is true.',
        ),
        assert(!obscureText || maxLines == 1,
            'Obscured fields cannot be multiline.'),
        assert(maxLength == null || maxLength > 0),
        // Assert the following instead of setting it directly to avoid surprising the user by silently changing the value they set.
        assert(
          !identical(textInputAction, TextInputAction.newline) ||
              maxLines == 1 ||
              !identical(keyboardType, TextInputType.text),
          'Use keyboardType TextInputType.multiline when using TextInputAction.newline on a multiline TextField.',
        ),
        keyboardType = keyboardType ??
            (maxLines == 1 ? TextInputType.text : TextInputType.multiline),
        enableInteractiveSelection =
            enableInteractiveSelection ?? (!readOnly || !obscureText);

  final TextEditingController? controller;

  final FocusNode? focusNode;

  final BoxDecoration? decoration;

  final EdgeInsetsGeometry padding;

  final String? placeholder;

  final TextStyle? placeholderStyle;

  final Widget? prefix;

  final OverlayVisibilityMode prefixMode;

  final Widget? suffix;

  final OverlayVisibilityMode suffixMode;

  final OverlayVisibilityMode clearButtonMode;

  final TextInputType keyboardType;

  final TextInputAction? textInputAction;

  final TextCapitalization textCapitalization;

  final TextStyle? style;

  final StrutStyle? strutStyle;

  final TextAlign textAlign;

  @Deprecated(
    'Use `contextMenuBuilder` instead. '
    'This feature was deprecated after v3.3.0-0.5.pre.',
  )
  final ToolbarOptions? toolbarOptions;

  final TextAlignVertical? textAlignVertical;

  final TextDirection? textDirection;

  final bool readOnly;

  final bool? showCursor;

  final bool autofocus;

  final String obscuringCharacter;

  final bool obscureText;

  final bool autocorrect;

  final SmartDashesType smartDashesType;

  final SmartQuotesType smartQuotesType;

  final bool enableSuggestions;

  final int? maxLines;

  final int? minLines;

  final bool expands;

  final int? maxLength;

  final MaxLengthEnforcement? maxLengthEnforcement;

  final ValueChanged<String>? onChanged;

  final VoidCallback? onEditingComplete;

  final ValueChanged<String>? onSubmitted;

  final TapRegionCallback? onTapOutside;

  final List<TextInputFormatter>? inputFormatters;

  final bool enabled;

  final double cursorWidth;

  final double? cursorHeight;

  final Radius cursorRadius;

  final bool cursorOpacityAnimates;

  final Color? cursorColor;

  final ui.BoxHeightStyle selectionHeightStyle;

  final ui.BoxWidthStyle selectionWidthStyle;

  final Brightness? keyboardAppearance;

  final EdgeInsets scrollPadding;

  final bool enableInteractiveSelection;

  final TextSelectionControls? selectionControls;

  final DragStartBehavior dragStartBehavior;

  final ScrollController? scrollController;

  final ScrollPhysics? scrollPhysics;

  bool get selectionEnabled => enableInteractiveSelection;

  final GestureTapCallback? onTap;

  final Iterable<String>? autofillHints;

  final Clip clipBehavior;

  final String? restorationId;

  final bool scribbleEnabled;

  final bool enableIMEPersonalizedLearning;

  final ContentInsertionConfiguration? contentInsertionConfiguration;

  final EditableTextContextMenuBuilder? contextMenuBuilder;

  static Widget _defaultContextMenuBuilder(
      BuildContext context, EditableTextState editableTextState) {
    return CupertinoAdaptiveTextSelectionToolbar.editableText(
      editableTextState: editableTextState,
    );
  }

  final TextMagnifierConfiguration? magnifierConfiguration;

  final SpellCheckConfiguration? spellCheckConfiguration;

  static const TextStyle cupertinoMisspelledTextStyle = TextStyle(
    decoration: TextDecoration.underline,
    decorationColor: CupertinoColors.systemRed,
    decorationStyle: TextDecorationStyle.dotted,
  );

  @visibleForTesting
  static const Color kMisspelledSelectionColor = Color(0x62ff9699);

  @visibleForTesting
  static Widget defaultSpellCheckSuggestionsToolbarBuilder(
    BuildContext context,
    EditableTextState editableTextState,
  ) {
    return CupertinoSpellCheckSuggestionsToolbar.editableText(
      editableTextState: editableTextState,
    );
  }

  final UndoHistoryController? undoController;

  @override
  State<CupertinoTextField> createState() => _CupertinoTextFieldState();

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<TextEditingController>(
        'controller', controller,
        defaultValue: null));
    properties.add(DiagnosticsProperty<FocusNode>('focusNode', focusNode,
        defaultValue: null));
    properties.add(DiagnosticsProperty<UndoHistoryController>(
        'undoController', undoController,
        defaultValue: null));
    properties
        .add(DiagnosticsProperty<BoxDecoration>('decoration', decoration));
    properties.add(DiagnosticsProperty<EdgeInsetsGeometry>('padding', padding));
    properties.add(StringProperty('placeholder', placeholder));
    properties.add(
        DiagnosticsProperty<TextStyle>('placeholderStyle', placeholderStyle));
    properties.add(DiagnosticsProperty<OverlayVisibilityMode>(
        'prefix', prefix == null ? null : prefixMode));
    properties.add(DiagnosticsProperty<OverlayVisibilityMode>(
        'suffix', suffix == null ? null : suffixMode));
    properties.add(DiagnosticsProperty<OverlayVisibilityMode>(
        'clearButtonMode', clearButtonMode));
    properties.add(DiagnosticsProperty<TextInputType>(
        'keyboardType', keyboardType,
        defaultValue: TextInputType.text));
    properties.add(
        DiagnosticsProperty<TextStyle>('style', style, defaultValue: null));
    properties.add(
        DiagnosticsProperty<bool>('autofocus', autofocus, defaultValue: false));
    properties.add(DiagnosticsProperty<String>(
        'obscuringCharacter', obscuringCharacter,
        defaultValue: '•'));
    properties.add(DiagnosticsProperty<bool>('obscureText', obscureText,
        defaultValue: false));
    properties.add(DiagnosticsProperty<bool>('autocorrect', autocorrect,
        defaultValue: true));
    properties.add(EnumProperty<SmartDashesType>(
        'smartDashesType', smartDashesType,
        defaultValue:
            obscureText ? SmartDashesType.disabled : SmartDashesType.enabled));
    properties.add(EnumProperty<SmartQuotesType>(
        'smartQuotesType', smartQuotesType,
        defaultValue:
            obscureText ? SmartQuotesType.disabled : SmartQuotesType.enabled));
    properties.add(DiagnosticsProperty<bool>(
        'enableSuggestions', enableSuggestions,
        defaultValue: true));
    properties.add(IntProperty('maxLines', maxLines, defaultValue: 1));
    properties.add(IntProperty('minLines', minLines, defaultValue: null));
    properties.add(
        DiagnosticsProperty<bool>('expands', expands, defaultValue: false));
    properties.add(IntProperty('maxLength', maxLength, defaultValue: null));
    properties.add(EnumProperty<MaxLengthEnforcement>(
        'maxLengthEnforcement', maxLengthEnforcement,
        defaultValue: null));
    properties
        .add(DoubleProperty('cursorWidth', cursorWidth, defaultValue: 2.0));
    properties
        .add(DoubleProperty('cursorHeight', cursorHeight, defaultValue: null));
    properties.add(DiagnosticsProperty<Radius>('cursorRadius', cursorRadius,
        defaultValue: null));
    properties.add(DiagnosticsProperty<bool>(
        'cursorOpacityAnimates', cursorOpacityAnimates,
        defaultValue: true));
    properties.add(createCupertinoColorProperty('cursorColor', cursorColor,
        defaultValue: null));
    properties.add(FlagProperty('selectionEnabled',
        value: selectionEnabled,
        defaultValue: true,
        ifFalse: 'selection disabled'));
    properties.add(DiagnosticsProperty<TextSelectionControls>(
        'selectionControls', selectionControls,
        defaultValue: null));
    properties.add(DiagnosticsProperty<ScrollController>(
        'scrollController', scrollController,
        defaultValue: null));
    properties.add(DiagnosticsProperty<ScrollPhysics>(
        'scrollPhysics', scrollPhysics,
        defaultValue: null));
    properties.add(EnumProperty<TextAlign>('textAlign', textAlign,
        defaultValue: TextAlign.start));
    properties.add(DiagnosticsProperty<TextAlignVertical>(
        'textAlignVertical', textAlignVertical,
        defaultValue: null));
    properties.add(EnumProperty<TextDirection>('textDirection', textDirection,
        defaultValue: null));
    properties.add(DiagnosticsProperty<Clip>('clipBehavior', clipBehavior,
        defaultValue: Clip.hardEdge));
    properties.add(DiagnosticsProperty<bool>('scribbleEnabled', scribbleEnabled,
        defaultValue: true));
    properties.add(DiagnosticsProperty<bool>(
        'enableIMEPersonalizedLearning', enableIMEPersonalizedLearning,
        defaultValue: true));
    properties.add(DiagnosticsProperty<SpellCheckConfiguration>(
        'spellCheckConfiguration', spellCheckConfiguration,
        defaultValue: null));
    properties.add(DiagnosticsProperty<List<String>>('contentCommitMimeTypes',
        contentInsertionConfiguration?.allowedMimeTypes ?? const <String>[],
        defaultValue: contentInsertionConfiguration == null
            ? const <String>[]
            : kDefaultContentInsertionMimeTypes));
  }

  static final TextMagnifierConfiguration _iosMagnifierConfiguration =
      TextMagnifierConfiguration(magnifierBuilder: (BuildContext context,
          MagnifierController controller,
          ValueNotifier<MagnifierInfo> magnifierInfo) {
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return CupertinoTextMagnifier(
          controller: controller,
          magnifierInfo: magnifierInfo,
        );
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return null;
    }
  });

  static SpellCheckConfiguration inferIOSSpellCheckConfiguration(
    SpellCheckConfiguration? configuration,
  ) {
    if (configuration == null ||
        configuration == const SpellCheckConfiguration.disabled()) {
      return const SpellCheckConfiguration.disabled();
    }

    return configuration.copyWith(
      misspelledTextStyle: configuration.misspelledTextStyle ??
          CupertinoTextField.cupertinoMisspelledTextStyle,
      misspelledSelectionColor: configuration.misspelledSelectionColor ??
          CupertinoTextField.kMisspelledSelectionColor,
      spellCheckSuggestionsToolbarBuilder:
          configuration.spellCheckSuggestionsToolbarBuilder ??
              CupertinoTextField.defaultSpellCheckSuggestionsToolbarBuilder,
    );
  }
}

class _CupertinoTextFieldState extends State<CupertinoTextField>
    with RestorationMixin, AutomaticKeepAliveClientMixin<CupertinoTextField>
    implements TextSelectionGestureDetectorBuilderDelegate, AutofillClient {
  final GlobalKey _clearGlobalKey = GlobalKey();

  RestorableTextEditingController? _controller;
  TextEditingController get _effectiveController =>
      widget.controller ?? _controller!.value;

  FocusNode? _focusNode;
  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_focusNode ??= FocusNode());

  MaxLengthEnforcement get _effectiveMaxLengthEnforcement =>
      widget.maxLengthEnforcement ??
      LengthLimitingTextInputFormatter.getDefaultMaxLengthEnforcement();

  bool _showSelectionHandles = false;

  late _CupertinoTextFieldSelectionGestureDetectorBuilder
      _selectionGestureDetectorBuilder;

  // API for TextSelectionGestureDetectorBuilderDelegate.
  @override
  bool get forcePressEnabled => true;

  @override
  final GlobalKey<EditableTextState> editableTextKey =
      GlobalKey<EditableTextState>();

  @override
  bool get selectionEnabled => widget.selectionEnabled;
  // End of API for TextSelectionGestureDetectorBuilderDelegate.

  @override
  void initState() {
    super.initState();
    _selectionGestureDetectorBuilder =
        _CupertinoTextFieldSelectionGestureDetectorBuilder(
      state: this,
    );
    if (widget.controller == null) {
      _createLocalController();
    }
    _effectiveFocusNode.canRequestFocus = widget.enabled;
    _effectiveFocusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(CupertinoTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == null && oldWidget.controller != null) {
      _createLocalController(oldWidget.controller!.value);
    } else if (widget.controller != null && oldWidget.controller == null) {
      unregisterFromRestoration(_controller!);
      _controller!.dispose();
      _controller = null;
    }

    if (widget.focusNode != oldWidget.focusNode) {
      (oldWidget.focusNode ?? _focusNode)?.removeListener(_handleFocusChanged);
      (widget.focusNode ?? _focusNode)?.addListener(_handleFocusChanged);
    }
    _effectiveFocusNode.canRequestFocus = widget.enabled;
  }

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    if (_controller != null) {
      _registerController();
    }
  }

  void _registerController() {
    assert(_controller != null);
    registerForRestoration(_controller!, 'controller');
    _controller!.value.addListener(updateKeepAlive);
  }

  void _createLocalController([TextEditingValue? value]) {
    assert(_controller == null);
    _controller = value == null
        ? RestorableTextEditingController()
        : RestorableTextEditingController.fromValue(value);
    if (!restorePending) {
      _registerController();
    }
  }

  @override
  String? get restorationId => widget.restorationId;

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_handleFocusChanged);
    _focusNode?.dispose();
    _controller?.dispose();
    super.dispose();
  }

  EditableTextState get _editableText => editableTextKey.currentState!;

  void _requestKeyboard() {
    _editableText.requestKeyboard();
  }

  void _handleFocusChanged() {
    setState(() {
      // Rebuild the widget on focus change to show/hide the text selection
      // highlight.
    });
  }

  bool _shouldShowSelectionHandles(SelectionChangedCause? cause) {
    // When the text field is activated by something that doesn't trigger the
    // selection overlay, we shouldn't show the handles either.
    if (!_selectionGestureDetectorBuilder.shouldShowSelectionToolbar) {
      return false;
    }

    // On iOS, we don't show handles when the selection is collapsed.
    if (_effectiveController.selection.isCollapsed) {
      return false;
    }

    if (cause == SelectionChangedCause.keyboard) {
      return false;
    }

    if (cause == SelectionChangedCause.scribble) {
      return true;
    }

    if (_effectiveController.text.isNotEmpty) {
      return true;
    }

    return false;
  }

  void _handleSelectionChanged(
      TextSelection selection, SelectionChangedCause? cause) {
    final bool willShowSelectionHandles = _shouldShowSelectionHandles(cause);
    if (willShowSelectionHandles != _showSelectionHandles) {
      setState(() {
        _showSelectionHandles = willShowSelectionHandles;
      });
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
      case TargetPlatform.fuchsia:
      case TargetPlatform.android:
        if (cause == SelectionChangedCause.longPress) {
          _editableText.bringIntoView(selection.extent);
        }
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.fuchsia:
      case TargetPlatform.android:
        break;
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        if (cause == SelectionChangedCause.drag) {
          _editableText.hideToolbar();
        }
    }
  }

  @override
  bool get wantKeepAlive => _controller?.value.text.isNotEmpty ?? false;

  static bool _shouldShowAttachment({
    required OverlayVisibilityMode attachment,
    required bool hasText,
  }) {
    return switch (attachment) {
      OverlayVisibilityMode.never => false,
      OverlayVisibilityMode.always => true,
      OverlayVisibilityMode.editing => hasText,
      OverlayVisibilityMode.notEditing => !hasText,
    };
  }

  // True if any surrounding decoration widgets will be shown.
  bool get _hasDecoration {
    return widget.placeholder != null ||
        widget.clearButtonMode != OverlayVisibilityMode.never ||
        widget.prefix != null ||
        widget.suffix != null;
  }

  // Provide default behavior if widget.textAlignVertical is not set.
  // CupertinoTextField has top alignment by default, unless it has decoration
  // like a prefix or suffix, in which case it's aligned to the center.
  TextAlignVertical get _textAlignVertical {
    if (widget.textAlignVertical != null) {
      return widget.textAlignVertical!;
    }
    return _hasDecoration ? TextAlignVertical.center : TextAlignVertical.top;
  }

  void _onClearButtonTapped() {
    final bool hadText = _effectiveController.text.isNotEmpty;
    _effectiveController.clear();
    if (hadText) {
      // Tapping the clear button is also considered a "user initiated" change
      // (instead of a programmatical one), so call `onChanged` if the text
      // changed as a result.
      widget.onChanged?.call(_effectiveController.text);
    }
  }

  Widget _buildClearButton() {
    return GestureDetector(
      key: _clearGlobalKey,
      onTap: widget.enabled ? _onClearButtonTapped : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6.0),
        child: Icon(
          CupertinoIcons.clear_thick_circled,
          size: 18.0,
          color: CupertinoDynamicColor.resolve(_kClearButtonColor, context),
        ),
      ),
    );
  }

  Widget _addTextDependentAttachments(
      Widget editableText, TextStyle textStyle, TextStyle placeholderStyle) {
    // If there are no surrounding widgets, just return the core editable text
    // part.
    if (!_hasDecoration) {
      return editableText;
    }

    // Otherwise, listen to the current state of the text entry.
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _effectiveController,
      child: editableText,
      builder: (BuildContext context, TextEditingValue text, Widget? child) {
        final bool hasText = text.text.isNotEmpty;
        final String? placeholderText = widget.placeholder;
        final Widget? placeholder = placeholderText == null
            ? null
            // Make the placeholder invisible when hasText is true.
            : Visibility(
                maintainAnimation: true,
                maintainSize: true,
                maintainState: true,
                visible: !hasText,
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: widget.padding,
                    child: Text(
                      placeholderText,
                      // This is to make sure the text field is always tall enough
                      // to accommodate the first line of the placeholder, so the
                      // text does not shrink vertically as you type (however in
                      // rare circumstances, the height may still change when
                      // there's no placeholder text).
                      maxLines: hasText ? 1 : widget.maxLines,
                      overflow: placeholderStyle.overflow,
                      style: placeholderStyle,
                      textAlign: widget.textAlign,
                    ),
                  ),
                ),
              );

        final Widget? prefixWidget = _shouldShowAttachment(
                attachment: widget.prefixMode, hasText: hasText)
            ? widget.prefix
            : null;

        // Show user specified suffix if applicable and fall back to clear button.
        final bool showUserSuffix = _shouldShowAttachment(
            attachment: widget.suffixMode, hasText: hasText);
        final bool showClearButton = _shouldShowAttachment(
            attachment: widget.clearButtonMode, hasText: hasText);
        final Widget? suffixWidget =
            switch ((showUserSuffix, showClearButton)) {
          (false, false) => null,
          (true, false) => widget.suffix,
          (true, true) => widget.suffix ?? _buildClearButton(),
          (false, true) => _buildClearButton(),
        };
        return Row(children: <Widget>[
          // Insert a prefix at the front if the prefix visibility mode matches
          // the current text state.
          if (prefixWidget != null) prefixWidget,
          // In the middle part, stack the placeholder on top of the main EditableText
          // if needed.
          Expanded(
            child: Stack(
              // Ideally this should be baseline aligned. However that comes at
              // the cost of the ability to compute the intrinsic dimensions of
              // this widget.
              // See also https://github.com/flutter/flutter/issues/13715.
              alignment: AlignmentDirectional.center,
              textDirection: widget.textDirection,
              children: <Widget>[
                if (placeholder != null) placeholder,
                editableText,
              ],
            ),
          ),
          if (suffixWidget != null) suffixWidget
        ]);
      },
    );
  }

  // AutofillClient implementation start.
  @override
  String get autofillId => _editableText.autofillId;

  @override
  void autofill(TextEditingValue newEditingValue) =>
      _editableText.autofill(newEditingValue);

  @override
  TextInputConfiguration get textInputConfiguration {
    final List<String>? autofillHints =
        widget.autofillHints?.toList(growable: false);
    final AutofillConfiguration autofillConfiguration = autofillHints != null
        ? AutofillConfiguration(
            uniqueIdentifier: autofillId,
            autofillHints: autofillHints,
            currentEditingValue: _effectiveController.value,
            hintText: widget.placeholder,
          )
        : AutofillConfiguration.disabled;

    return _editableText.textInputConfiguration
        .copyWith(autofillConfiguration: autofillConfiguration);
  }
  // AutofillClient implementation end.

  @override
  Widget build(BuildContext context) {
    super.build(context); // See AutomaticKeepAliveClientMixin.
    assert(debugCheckHasDirectionality(context));
    final TextEditingController controller = _effectiveController;

    TextSelectionControls? textSelectionControls = widget.selectionControls;
    VoidCallback? handleDidGainAccessibilityFocus;
    switch (defaultTargetPlatform) {
      case TargetPlatform.iOS:
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
        textSelectionControls ??= cupertinoTextSelectionHandleControls;

      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        textSelectionControls ??= cupertinoDesktopTextSelectionHandleControls;
        handleDidGainAccessibilityFocus = () {
          // Automatically activate the TextField when it receives accessibility focus.
          if (!_effectiveFocusNode.hasFocus &&
              _effectiveFocusNode.canRequestFocus) {
            _effectiveFocusNode.requestFocus();
          }
        };
    }

    final bool enabled = widget.enabled;
    final Offset cursorOffset = Offset(
        _iOSHorizontalCursorOffsetPixels /
            MediaQuery.devicePixelRatioOf(context),
        0);
    final List<TextInputFormatter> formatters = <TextInputFormatter>[
      ...?widget.inputFormatters,
      if (widget.maxLength != null)
        LengthLimitingTextInputFormatter(
          widget.maxLength,
          maxLengthEnforcement: _effectiveMaxLengthEnforcement,
        ),
    ];
    final CupertinoThemeData themeData = CupertinoTheme.of(context);

    final TextStyle? resolvedStyle = widget.style?.copyWith(
      color: CupertinoDynamicColor.maybeResolve(widget.style?.color, context),
      backgroundColor: CupertinoDynamicColor.maybeResolve(
          widget.style?.backgroundColor, context),
    );

    final TextStyle textStyle =
        themeData.textTheme.textStyle.merge(resolvedStyle);

    final TextStyle? resolvedPlaceholderStyle =
        widget.placeholderStyle?.copyWith(
      color: CupertinoDynamicColor.maybeResolve(
          widget.placeholderStyle?.color, context),
      backgroundColor: CupertinoDynamicColor.maybeResolve(
          widget.placeholderStyle?.backgroundColor, context),
    );

    final TextStyle placeholderStyle =
        textStyle.merge(resolvedPlaceholderStyle);

    final Brightness keyboardAppearance =
        widget.keyboardAppearance ?? CupertinoTheme.brightnessOf(context);
    final Color cursorColor = CupertinoDynamicColor.maybeResolve(
          widget.cursorColor ?? DefaultSelectionStyle.of(context).cursorColor,
          context,
        ) ??
        themeData.primaryColor;

    final Color disabledColor =
        CupertinoDynamicColor.resolve(_kDisabledBackground, context);

    final Color? decorationColor =
        CupertinoDynamicColor.maybeResolve(widget.decoration?.color, context);

    final BoxBorder? border = widget.decoration?.border;
    Border? resolvedBorder = border as Border?;
    if (border is Border) {
      BorderSide resolveBorderSide(BorderSide side) {
        return side == BorderSide.none
            ? side
            : side.copyWith(
                color: CupertinoDynamicColor.resolve(side.color, context));
      }

      resolvedBorder = border.runtimeType != Border
          ? border
          : Border(
              top: resolveBorderSide(border.top),
              left: resolveBorderSide(border.left),
              bottom: resolveBorderSide(border.bottom),
              right: resolveBorderSide(border.right),
            );
    }

    final BoxDecoration? effectiveDecoration = widget.decoration?.copyWith(
      border: resolvedBorder,
      color: enabled ? decorationColor : disabledColor,
    );

    final Color selectionColor = CupertinoDynamicColor.maybeResolve(
          DefaultSelectionStyle.of(context).selectionColor,
          context,
        ) ??
        CupertinoTheme.of(context).primaryColor.withOpacity(0.2);

    // Set configuration as disabled if not otherwise specified. If specified,
    // ensure that configuration uses Cupertino text style for misspelled words
    // unless a custom style is specified.
    final SpellCheckConfiguration spellCheckConfiguration =
        CupertinoTextField.inferIOSSpellCheckConfiguration(
      widget.spellCheckConfiguration,
    );

    final Widget paddedEditable = Padding(
      padding: widget.padding,
      child: RepaintBoundary(
        child: UnmanagedRestorationScope(
          bucket: bucket,
          child: EditableText(
            key: editableTextKey,
            controller: controller,
            undoController: widget.undoController,
            readOnly: widget.readOnly || !enabled,
            toolbarOptions: widget.toolbarOptions,
            showCursor: widget.showCursor,
            showSelectionHandles: _showSelectionHandles,
            focusNode: _effectiveFocusNode,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            textCapitalization: widget.textCapitalization,
            style: textStyle,
            strutStyle: widget.strutStyle,
            textAlign: widget.textAlign,
            textDirection: widget.textDirection,
            autofocus: widget.autofocus,
            obscuringCharacter: widget.obscuringCharacter,
            obscureText: widget.obscureText,
            autocorrect: widget.autocorrect,
            smartDashesType: widget.smartDashesType,
            smartQuotesType: widget.smartQuotesType,
            enableSuggestions: widget.enableSuggestions,
            maxLines: widget.maxLines,
            minLines: widget.minLines,
            expands: widget.expands,
            magnifierConfiguration: widget.magnifierConfiguration ??
                CupertinoTextField._iosMagnifierConfiguration,
            // Only show the selection highlight when the text field is focused.
            selectionColor:
                _effectiveFocusNode.hasFocus ? selectionColor : null,
            selectionControls:
                widget.selectionEnabled ? textSelectionControls : null,
            onChanged: widget.onChanged,
            onSelectionChanged: _handleSelectionChanged,
            onEditingComplete: widget.onEditingComplete,
            onSubmitted: widget.onSubmitted,
            onTapOutside: widget.onTapOutside,
            inputFormatters: formatters,
            rendererIgnoresPointer: true,
            cursorWidth: widget.cursorWidth,
            cursorHeight: widget.cursorHeight,
            cursorRadius: widget.cursorRadius,
            cursorColor: cursorColor,
            cursorOpacityAnimates: widget.cursorOpacityAnimates,
            cursorOffset: cursorOffset,
            paintCursorAboveText: true,
            autocorrectionTextRectColor: selectionColor,
            backgroundCursorColor: CupertinoDynamicColor.resolve(
                CupertinoColors.inactiveGray, context),
            selectionHeightStyle: widget.selectionHeightStyle,
            selectionWidthStyle: widget.selectionWidthStyle,
            scrollPadding: widget.scrollPadding,
            keyboardAppearance: keyboardAppearance,
            dragStartBehavior: widget.dragStartBehavior,
            scrollController: widget.scrollController,
            scrollPhysics: widget.scrollPhysics,
            enableInteractiveSelection: widget.enableInteractiveSelection,
            autofillClient: this,
            clipBehavior: widget.clipBehavior,
            restorationId: 'editable',
            scribbleEnabled: widget.scribbleEnabled,
            enableIMEPersonalizedLearning: widget.enableIMEPersonalizedLearning,
            contentInsertionConfiguration: widget.contentInsertionConfiguration,
            contextMenuBuilder: widget.contextMenuBuilder,
            spellCheckConfiguration: spellCheckConfiguration,
          ),
        ),
      ),
    );

    return Semantics(
      enabled: enabled,
      onTap: !enabled || widget.readOnly
          ? null
          : () {
              if (!controller.selection.isValid) {
                controller.selection =
                    TextSelection.collapsed(offset: controller.text.length);
              }
              _requestKeyboard();
            },
      onDidGainAccessibilityFocus: handleDidGainAccessibilityFocus,
      child: TextFieldTapRegion(
        child: IgnorePointer(
          ignoring: !enabled,
          child: Container(
            decoration: effectiveDecoration,
            color:
                !enabled && effectiveDecoration == null ? disabledColor : null,
            child: _selectionGestureDetectorBuilder.buildGestureDetector(
              behavior: HitTestBehavior.translucent,
              child: Align(
                alignment: Alignment(-1.0, _textAlignVertical.y),
                widthFactor: 1.0,
                heightFactor: 1.0,
                child: _addTextDependentAttachments(
                    paddedEditable, textStyle, placeholderStyle),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
