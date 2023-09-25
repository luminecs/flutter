// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';

import 'package:meta/meta.dart';

import 'constants.dart';

class AndroidSemanticsNode {
  AndroidSemanticsNode._(this._values);

  factory AndroidSemanticsNode.deserialize(String value) {
    return AndroidSemanticsNode._(json.decode(value));
  }

  final dynamic _values;
  final List<AndroidSemanticsNode> _children = <AndroidSemanticsNode>[];

  dynamic get _flags => _values['flags'];

  String? get text => _values['text'] as String?;

  String? get contentDescription => _values['contentDescription'] as String?;

  String? get className => _values['className'] as String?;

  int? get id => _values['id'] as int?;

  List<AndroidSemanticsNode> get children => _children;

  bool? get isChecked => _flags['isChecked'] as bool?;

  bool? get isCheckable => _flags['isCheckable'] as bool?;

  bool? get isEditable => _flags['isEditable'] as bool?;

  bool? get isEnabled => _flags['isEnabled'] as bool?;

  bool? get isFocusable => _flags['isFocusable'] as bool?;

  bool? get isFocused => _flags['isFocused'] as bool?;

  bool? get isHeading => _flags['isHeading'] as bool?;

  bool? get isPassword => _flags['isPassword'] as bool?;

  bool? get isLongClickable => _flags['isLongClickable'] as bool?;

  Rect getRect() {
    final dynamic rawRect = _values['rect'];
    if (rawRect == null) {
      return const Rect.fromLTRB(0.0, 0.0, 0.0, 0.0);
    }
    return Rect.fromLTRB(
      (rawRect['left']! as int).toDouble(),
      (rawRect['top']! as int).toDouble(),
      (rawRect['right']! as int).toDouble(),
      (rawRect['bottom']! as int).toDouble(),
    );
  }

  Size getSize() {
    final Rect rect = getRect();
    return Size(rect.bottom - rect.top, rect.right - rect.left);
  }

  List<AndroidSemanticsAction> getActions() {
    final List<int>? actions = (_values['actions'] as List<dynamic>?)?.cast<int>();
    if (actions == null) {
      return const <AndroidSemanticsAction>[];
    }
    final List<AndroidSemanticsAction> convertedActions = <AndroidSemanticsAction>[];
    for (final int id in actions) {
      final AndroidSemanticsAction? action = AndroidSemanticsAction.deserialize(id);
      if (action != null) {
        convertedActions.add(action);
      }
    }
    return convertedActions;
  }

  @override
  String toString() {
    return _values.toString();
  }
}


@immutable
class Rect {
  const Rect.fromLTRB(this.left, this.top, this.right, this.bottom);

  final double top;

  final double left;

  final double right;

  final double bottom;

  @override
  int get hashCode => Object.hash(top, left, right, bottom);

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is Rect
        && other.top == top
        && other.left == left
        && other.right == right
        && other.bottom == bottom;
  }

  @override
  String toString() => 'Rect.fromLTRB($left, $top, $right, $bottom)';
}

@immutable
class Size {
  const Size(this.width, this.height);

  final double width;

  final double height;

  @override
  int get hashCode => Object.hash(width, height);

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is Size
        && other.width == width
        && other.height == height;
  }

  @override
  String toString() => 'Size{$width, $height}';
}