// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'list_tile.dart';
import 'list_tile_theme.dart';
import 'material_state.dart';
import 'switch.dart';
import 'switch_theme.dart';
import 'theme.dart';
import 'theme_data.dart';

// Examples can assume:
// void setState(VoidCallback fn) { }
// bool _isSelected = true;

enum _SwitchListTileType { material, adaptive }

class SwitchListTile extends StatelessWidget {
  const SwitchListTile({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.activeTrackColor,
    this.inactiveThumbColor,
    this.inactiveTrackColor,
    this.activeThumbImage,
    this.onActiveThumbImageError,
    this.inactiveThumbImage,
    this.onInactiveThumbImageError,
    this.thumbColor,
    this.trackColor,
    this.trackOutlineColor,
    this.thumbIcon,
    this.materialTapTargetSize,
    this.dragStartBehavior = DragStartBehavior.start,
    this.mouseCursor,
    this.overlayColor,
    this.splashRadius,
    this.focusNode,
    this.onFocusChange,
    this.autofocus = false,
    this.tileColor,
    this.title,
    this.subtitle,
    this.isThreeLine = false,
    this.dense,
    this.contentPadding,
    this.secondary,
    this.selected = false,
    this.controlAffinity = ListTileControlAffinity.platform,
    this.shape,
    this.selectedTileColor,
    this.visualDensity,
    this.enableFeedback,
    this.hoverColor,
  }) : _switchListTileType = _SwitchListTileType.material,
       applyCupertinoTheme = false,
       assert(activeThumbImage != null || onActiveThumbImageError == null),
       assert(inactiveThumbImage != null || onInactiveThumbImageError == null),
       assert(!isThreeLine || subtitle != null);

  const SwitchListTile.adaptive({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.activeTrackColor,
    this.inactiveThumbColor,
    this.inactiveTrackColor,
    this.activeThumbImage,
    this.onActiveThumbImageError,
    this.inactiveThumbImage,
    this.onInactiveThumbImageError,
    this.thumbColor,
    this.trackColor,
    this.trackOutlineColor,
    this.thumbIcon,
    this.materialTapTargetSize,
    this.dragStartBehavior = DragStartBehavior.start,
    this.mouseCursor,
    this.overlayColor,
    this.splashRadius,
    this.focusNode,
    this.onFocusChange,
    this.autofocus = false,
    this.applyCupertinoTheme,
    this.tileColor,
    this.title,
    this.subtitle,
    this.isThreeLine = false,
    this.dense,
    this.contentPadding,
    this.secondary,
    this.selected = false,
    this.controlAffinity = ListTileControlAffinity.platform,
    this.shape,
    this.selectedTileColor,
    this.visualDensity,
    this.enableFeedback,
    this.hoverColor,
  }) : _switchListTileType = _SwitchListTileType.adaptive,
       assert(!isThreeLine || subtitle != null),
       assert(activeThumbImage != null || onActiveThumbImageError == null),
       assert(inactiveThumbImage != null || onInactiveThumbImageError == null);

  final bool value;

  final ValueChanged<bool>? onChanged;

  final Color? activeColor;

  final Color? activeTrackColor;

  final Color? inactiveThumbColor;

  final Color? inactiveTrackColor;

  final ImageProvider? activeThumbImage;

  final ImageErrorListener? onActiveThumbImageError;

  final ImageProvider? inactiveThumbImage;

  final ImageErrorListener? onInactiveThumbImageError;

  final MaterialStateProperty<Color?>? thumbColor;

  final MaterialStateProperty<Color?>? trackColor;

  final MaterialStateProperty<Color?>? trackOutlineColor;

  final MaterialStateProperty<Icon?>? thumbIcon;

  final MaterialTapTargetSize? materialTapTargetSize;

  final DragStartBehavior dragStartBehavior;

  final MouseCursor? mouseCursor;

  final MaterialStateProperty<Color?>? overlayColor;

  final double? splashRadius;

  final FocusNode? focusNode;

  final ValueChanged<bool>? onFocusChange;

  final bool autofocus;

  final Color? tileColor;

  final Widget? title;

  final Widget? subtitle;

  final Widget? secondary;

  final bool isThreeLine;

  final bool? dense;

  final EdgeInsetsGeometry? contentPadding;

  final bool selected;

  final _SwitchListTileType _switchListTileType;

  final ListTileControlAffinity controlAffinity;

  final ShapeBorder? shape;

  final Color? selectedTileColor;

  final VisualDensity? visualDensity;

  final bool? enableFeedback;

  final Color? hoverColor;

  final bool? applyCupertinoTheme;

  @override
  Widget build(BuildContext context) {
    final Widget control;
    switch (_switchListTileType) {
      case _SwitchListTileType.adaptive:
        control = Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: activeColor,
          activeThumbImage: activeThumbImage,
          inactiveThumbImage: inactiveThumbImage,
          materialTapTargetSize: materialTapTargetSize ?? MaterialTapTargetSize.shrinkWrap,
          activeTrackColor: activeTrackColor,
          inactiveTrackColor: inactiveTrackColor,
          inactiveThumbColor: inactiveThumbColor,
          autofocus: autofocus,
          onFocusChange: onFocusChange,
          onActiveThumbImageError: onActiveThumbImageError,
          onInactiveThumbImageError: onInactiveThumbImageError,
          thumbColor: thumbColor,
          trackColor: trackColor,
          trackOutlineColor: trackOutlineColor,
          thumbIcon: thumbIcon,
          applyCupertinoTheme: applyCupertinoTheme,
          dragStartBehavior: dragStartBehavior,
          mouseCursor: mouseCursor,
          splashRadius: splashRadius,
          overlayColor: overlayColor,
        );

      case _SwitchListTileType.material:
        control = Switch(
          value: value,
          onChanged: onChanged,
          activeColor: activeColor,
          activeThumbImage: activeThumbImage,
          inactiveThumbImage: inactiveThumbImage,
          materialTapTargetSize: materialTapTargetSize ?? MaterialTapTargetSize.shrinkWrap,
          activeTrackColor: activeTrackColor,
          inactiveTrackColor: inactiveTrackColor,
          inactiveThumbColor: inactiveThumbColor,
          autofocus: autofocus,
          onFocusChange: onFocusChange,
          onActiveThumbImageError: onActiveThumbImageError,
          onInactiveThumbImageError: onInactiveThumbImageError,
          thumbColor: thumbColor,
          trackColor: trackColor,
          trackOutlineColor: trackOutlineColor,
          thumbIcon: thumbIcon,
          dragStartBehavior: dragStartBehavior,
          mouseCursor: mouseCursor,
          splashRadius: splashRadius,
          overlayColor: overlayColor,
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
    final SwitchThemeData switchTheme = SwitchTheme.of(context);
    final Set<MaterialState> states = <MaterialState>{
      if (selected) MaterialState.selected,
    };
    final Color effectiveActiveColor = activeColor
      ?? switchTheme.thumbColor?.resolve(states)
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
        contentPadding: contentPadding,
        enabled: onChanged != null,
        onTap: onChanged != null ? () { onChanged!(!value); } : null,
        selected: selected,
        selectedTileColor: selectedTileColor,
        autofocus: autofocus,
        shape: shape,
        tileColor: tileColor,
        visualDensity: visualDensity,
        focusNode: focusNode,
        onFocusChange: onFocusChange,
        enableFeedback: enableFeedback,
        hoverColor: hoverColor,
      ),
    );
  }
}