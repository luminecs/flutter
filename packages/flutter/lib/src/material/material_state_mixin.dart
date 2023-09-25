// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'material_state.dart';

@optionalTypeArgs
mixin MaterialStateMixin<T extends StatefulWidget> on State<T> {
  @protected
  Set<MaterialState> materialStates = <MaterialState>{};

  @protected
  ValueChanged<bool> updateMaterialState(MaterialState key, {ValueChanged<bool>? onChanged}) {
    return (bool value) {
      if (materialStates.contains(key) == value) {
        return;
      }
      setMaterialState(key, value);
      onChanged?.call(value);
    };
  }

  @protected
  void setMaterialState(MaterialState state, bool isSet) {
    return isSet ? addMaterialState(state) : removeMaterialState(state);
  }

  @protected
  void addMaterialState(MaterialState state) {
    if (materialStates.add(state)) {
      setState((){});
    }
  }

  @protected
  void removeMaterialState(MaterialState state) {
    if (materialStates.remove(state)) {
      setState((){});
    }
  }

  bool get isDisabled => materialStates.contains(MaterialState.disabled);

  bool get isDragged => materialStates.contains(MaterialState.dragged);

  bool get isErrored => materialStates.contains(MaterialState.error);

  bool get isFocused => materialStates.contains(MaterialState.focused);

  bool get isHovered => materialStates.contains(MaterialState.hovered);

  bool get isPressed => materialStates.contains(MaterialState.pressed);

  bool get isScrolledUnder => materialStates.contains(MaterialState.scrolledUnder);

  bool get isSelected => materialStates.contains(MaterialState.selected);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<Set<MaterialState>>('materialStates', materialStates, defaultValue: <MaterialState>{}));
  }
}