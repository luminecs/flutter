import 'framework.dart';

enum ContextMenuButtonType {
  cut,

  copy,

  paste,

  selectAll,

  delete,

  lookUp,

  searchWeb,

  share,

  liveTextInput,

  custom,
}

@immutable
class ContextMenuButtonItem {
  const ContextMenuButtonItem({
    required this.onPressed,
    this.type = ContextMenuButtonType.custom,
    this.label,
  });

  final VoidCallback? onPressed;

  final ContextMenuButtonType type;

  final String? label;

  ContextMenuButtonItem copyWith({
    VoidCallback? onPressed,
    ContextMenuButtonType? type,
    String? label,
  }) {
    return ContextMenuButtonItem(
      onPressed: onPressed ?? this.onPressed,
      type: type ?? this.type,
      label: label ?? this.label,
    );
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is ContextMenuButtonItem
        && other.label == label
        && other.onPressed == onPressed
        && other.type == type;
  }

  @override
  int get hashCode => Object.hash(label, onPressed, type);

  @override
  String toString() => 'ContextMenuButtonItem $type, $label';
}