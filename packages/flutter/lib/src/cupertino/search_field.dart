import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'button.dart';
import 'colors.dart';
import 'icons.dart';
import 'localizations.dart';
import 'text_field.dart';

export 'package:flutter/services.dart' show SmartDashesType, SmartQuotesType;

class CupertinoSearchTextField extends StatefulWidget {
  // TODO(DanielEdrisian): Localize the 'Search' placeholder.
  // TODO(DanielEdrisian): Must make border radius continuous, see
  // https://github.com/flutter/flutter/issues/13914.
  const CupertinoSearchTextField({
    super.key,
    this.controller,
    this.onChanged,
    this.onSubmitted,
    this.style,
    this.placeholder,
    this.placeholderStyle,
    this.decoration,
    this.backgroundColor,
    this.borderRadius,
    this.keyboardType = TextInputType.text,
    this.padding = const EdgeInsetsDirectional.fromSTEB(5.5, 8, 5.5, 8),
    this.itemColor = CupertinoColors.secondaryLabel,
    this.itemSize = 20.0,
    this.prefixInsets = const EdgeInsetsDirectional.fromSTEB(6, 0, 0, 3),
    this.prefixIcon = const Icon(CupertinoIcons.search),
    this.suffixInsets = const EdgeInsetsDirectional.fromSTEB(0, 0, 5, 2),
    this.suffixIcon = const Icon(CupertinoIcons.xmark_circle_fill),
    this.suffixMode = OverlayVisibilityMode.editing,
    this.onSuffixTap,
    this.restorationId,
    this.focusNode,
    this.smartQuotesType,
    this.smartDashesType,
    this.enableIMEPersonalizedLearning = true,
    this.autofocus = false,
    this.onTap,
    this.autocorrect = true,
    this.enabled,
  })  : assert(
          !((decoration != null) && (backgroundColor != null)),
          'Cannot provide both a background color and a decoration\n'
          'To provide both, use "decoration: BoxDecoration(color: '
          'backgroundColor)"',
        ),
        assert(
          !((decoration != null) && (borderRadius != null)),
          'Cannot provide both a border radius and a decoration\n'
          'To provide both, use "decoration: BoxDecoration(borderRadius: '
          'borderRadius)"',
        );

  final TextEditingController? controller;

  final ValueChanged<String>? onChanged;

  final ValueChanged<String>? onSubmitted;

  final TextStyle? style;

  final String? placeholder;

  final TextStyle? placeholderStyle;

  final BoxDecoration? decoration;

  final Color? backgroundColor;

  // TODO(DanielEdrisian): Must make border radius continuous, see
  // https://github.com/flutter/flutter/issues/13914.
  final BorderRadius? borderRadius;

  final TextInputType? keyboardType;

  final EdgeInsetsGeometry padding;

  final Color itemColor;

  final double itemSize;

  final EdgeInsetsGeometry prefixInsets;

  final Widget prefixIcon;

  final EdgeInsetsGeometry suffixInsets;

  final Icon suffixIcon;

  final OverlayVisibilityMode suffixMode;

  final VoidCallback? onSuffixTap;

  final String? restorationId;

  final FocusNode? focusNode;

  final bool autofocus;

  final VoidCallback? onTap;

  final bool autocorrect;

  final SmartQuotesType? smartQuotesType;

  final SmartDashesType? smartDashesType;

  final bool enableIMEPersonalizedLearning;

  final bool? enabled;

  @override
  State<StatefulWidget> createState() => _CupertinoSearchTextFieldState();
}

class _CupertinoSearchTextFieldState extends State<CupertinoSearchTextField>
    with RestorationMixin {
  final BorderRadius _kDefaultBorderRadius =
      const BorderRadius.all(Radius.circular(9.0));

  RestorableTextEditingController? _controller;

  TextEditingController get _effectiveController =>
      widget.controller ?? _controller!.value;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _createLocalController();
    }
  }

  @override
  void didUpdateWidget(CupertinoSearchTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller == null && oldWidget.controller != null) {
      _createLocalController(oldWidget.controller!.value);
    } else if (widget.controller != null && oldWidget.controller == null) {
      unregisterFromRestoration(_controller!);
      _controller!.dispose();
      _controller = null;
    }
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

  void _defaultOnSuffixTap() {
    final bool textChanged = _effectiveController.text.isNotEmpty;
    _effectiveController.clear();
    if (widget.onChanged != null && textChanged) {
      widget.onChanged!(_effectiveController.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String placeholder = widget.placeholder ??
        CupertinoLocalizations.of(context).searchTextFieldPlaceholderLabel;

    final TextStyle placeholderStyle = widget.placeholderStyle ??
        const TextStyle(color: CupertinoColors.systemGrey);

    // The icon size will be scaled by a factor of the accessibility text scale,
    // to follow the behavior of `UISearchTextField`.
    final double scaledIconSize = MediaQuery.textScalerOf(context).textScaleFactor * widget.itemSize;

    // If decoration was not provided, create a decoration with the provided
    // background color and border radius.
    final BoxDecoration decoration = widget.decoration ??
        BoxDecoration(
          color: widget.backgroundColor ?? CupertinoColors.tertiarySystemFill,
          borderRadius: widget.borderRadius ?? _kDefaultBorderRadius,
        );

    final IconThemeData iconThemeData = IconThemeData(
      color: CupertinoDynamicColor.resolve(widget.itemColor, context),
      size: scaledIconSize,
    );

    final Widget prefix = Padding(
      padding: widget.prefixInsets,
      child: IconTheme(
        data: iconThemeData,
        child: widget.prefixIcon,
      ),
    );

    final Widget suffix = Padding(
      padding: widget.suffixInsets,
      child: CupertinoButton(
        onPressed: widget.onSuffixTap ?? _defaultOnSuffixTap,
        minSize: 0,
        padding: EdgeInsets.zero,
        child: IconTheme(
          data: iconThemeData,
          child: widget.suffixIcon,
        ),
      ),
    );

    return CupertinoTextField(
      controller: _effectiveController,
      decoration: decoration,
      style: widget.style,
      prefix: prefix,
      suffix: suffix,
      keyboardType: widget.keyboardType,
      onTap: widget.onTap,
      enabled: widget.enabled ?? true,
      suffixMode: widget.suffixMode,
      placeholder: placeholder,
      placeholderStyle: placeholderStyle,
      padding: widget.padding,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      autocorrect: widget.autocorrect,
      smartQuotesType: widget.smartQuotesType,
      smartDashesType: widget.smartDashesType,
      enableIMEPersonalizedLearning: widget.enableIMEPersonalizedLearning,
      textInputAction: TextInputAction.search,
    );
  }
}