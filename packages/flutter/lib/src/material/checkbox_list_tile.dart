import 'package:flutter/widgets.dart';

import 'checkbox.dart';
import 'checkbox_theme.dart';
import 'list_tile.dart';
import 'list_tile_theme.dart';
import 'material_state.dart';
import 'theme.dart';
import 'theme_data.dart';

// Examples can assume:
// late bool? _throwShotAway;
// void setState(VoidCallback fn) { }

enum _CheckboxType { material, adaptive }

class CheckboxListTile extends StatelessWidget {
  const CheckboxListTile({
    super.key,
    required this.value,
    required this.onChanged,
    this.mouseCursor,
    this.activeColor,
    this.fillColor,
    this.checkColor,
    this.hoverColor,
    this.overlayColor,
    this.splashRadius,
    this.materialTapTargetSize,
    this.visualDensity,
    this.focusNode,
    this.autofocus = false,
    this.shape,
    this.side,
    this.isError = false,
    this.enabled,
    this.tileColor,
    this.title,
    this.subtitle,
    this.isThreeLine = false,
    this.dense,
    this.secondary,
    this.selected = false,
    this.controlAffinity = ListTileControlAffinity.platform,
    this.contentPadding,
    this.tristate = false,
    this.checkboxShape,
    this.selectedTileColor,
    this.onFocusChange,
    this.enableFeedback,
    this.checkboxSemanticLabel,
  }) : _checkboxType = _CheckboxType.material,
       assert(tristate || value != null),
       assert(!isThreeLine || subtitle != null);

  const CheckboxListTile.adaptive({
    super.key,
    required this.value,
    required this.onChanged,
    this.mouseCursor,
    this.activeColor,
    this.fillColor,
    this.checkColor,
    this.hoverColor,
    this.overlayColor,
    this.splashRadius,
    this.materialTapTargetSize,
    this.visualDensity,
    this.focusNode,
    this.autofocus = false,
    this.shape,
    this.side,
    this.isError = false,
    this.enabled,
    this.tileColor,
    this.title,
    this.subtitle,
    this.isThreeLine = false,
    this.dense,
    this.secondary,
    this.selected = false,
    this.controlAffinity = ListTileControlAffinity.platform,
    this.contentPadding,
    this.tristate = false,
    this.checkboxShape,
    this.selectedTileColor,
    this.onFocusChange,
    this.enableFeedback,
    this.checkboxSemanticLabel,
  }) : _checkboxType = _CheckboxType.adaptive,
       assert(tristate || value != null),
       assert(!isThreeLine || subtitle != null);

  final bool? value;

  final ValueChanged<bool?>? onChanged;

  final MouseCursor? mouseCursor;

  final Color? activeColor;

  final MaterialStateProperty<Color?>? fillColor;

  final Color? checkColor;

  final Color? hoverColor;

  final MaterialStateProperty<Color?>? overlayColor;

  final double? splashRadius;

  final MaterialTapTargetSize? materialTapTargetSize;

  final VisualDensity? visualDensity;


  final FocusNode? focusNode;

  final bool autofocus;

  final ShapeBorder? shape;

  final BorderSide? side;

  final bool isError;

  final Color? tileColor;

  final Widget? title;

  final Widget? subtitle;

  final Widget? secondary;

  final bool isThreeLine;

  final bool? dense;

  final bool selected;

  final ListTileControlAffinity controlAffinity;

  final EdgeInsetsGeometry? contentPadding;

  final bool tristate;

  final OutlinedBorder? checkboxShape;

  final Color? selectedTileColor;

  final ValueChanged<bool>? onFocusChange;

  final bool? enableFeedback;

  final bool? enabled;

  final String? checkboxSemanticLabel;

  final _CheckboxType _checkboxType;

  void _handleValueChange() {
    assert(onChanged != null);
    switch (value) {
      case false:
        onChanged!(true);
      case true:
        onChanged!(tristate ? null : false);
      case null:
        onChanged!(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget control;

    switch (_checkboxType) {
      case _CheckboxType.material:
        control = Checkbox(
          value: value,
          onChanged: enabled ?? true ? onChanged : null,
          mouseCursor: mouseCursor,
          activeColor: activeColor,
          fillColor: fillColor,
          checkColor: checkColor,
          hoverColor: hoverColor,
          overlayColor: overlayColor,
          splashRadius: splashRadius,
          materialTapTargetSize: materialTapTargetSize ?? MaterialTapTargetSize.shrinkWrap,
          autofocus: autofocus,
          tristate: tristate,
          shape: checkboxShape,
          side: side,
          isError: isError,
          semanticLabel: checkboxSemanticLabel,
        );
      case _CheckboxType.adaptive:
        control = Checkbox.adaptive(
          value: value,
          onChanged: enabled ?? true ? onChanged : null,
          mouseCursor: mouseCursor,
          activeColor: activeColor,
          fillColor: fillColor,
          checkColor: checkColor,
          hoverColor: hoverColor,
          overlayColor: overlayColor,
          splashRadius: splashRadius,
          materialTapTargetSize: materialTapTargetSize ?? MaterialTapTargetSize.shrinkWrap,
          autofocus: autofocus,
          tristate: tristate,
          shape: checkboxShape,
          side: side,
          isError: isError,
          semanticLabel: checkboxSemanticLabel,
        );
    }

    Widget? leading, trailing;
    switch (controlAffinity) {
      case ListTileControlAffinity.leading:
        leading = control;
        trailing = secondary;
      case ListTileControlAffinity.trailing:
      case ListTileControlAffinity.platform:
        leading = secondary;
        trailing = control;
    }
    final ThemeData theme = Theme.of(context);
    final CheckboxThemeData checkboxTheme = CheckboxTheme.of(context);
    final Set<MaterialState> states = <MaterialState>{
      if (selected) MaterialState.selected,
    };
    final Color effectiveActiveColor = activeColor
      ?? checkboxTheme.fillColor?.resolve(states)
      ?? theme.colorScheme.secondary;
    return MergeSemantics(
      child: ListTile(
        selectedColor: effectiveActiveColor,
        leading: leading,
        title: title,
        subtitle: subtitle,
        trailing: trailing,
        isThreeLine: isThreeLine,
        dense: dense,
        enabled: enabled ?? onChanged != null,
        onTap: onChanged != null ? _handleValueChange : null,
        selected: selected,
        autofocus: autofocus,
        contentPadding: contentPadding,
        shape: shape,
        selectedTileColor: selectedTileColor,
        tileColor: tileColor,
        visualDensity: visualDensity,
        focusNode: focusNode,
        onFocusChange: onFocusChange,
        enableFeedback: enableFeedback,
      ),
    );
  }
}