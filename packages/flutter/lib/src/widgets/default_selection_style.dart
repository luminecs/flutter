import 'basic.dart';
import 'framework.dart';
import 'inherited_theme.dart';

// Examples can assume:
// late BuildContext context;

class DefaultSelectionStyle extends InheritedTheme {
  const DefaultSelectionStyle({
    super.key,
    this.cursorColor,
    this.selectionColor,
    this.mouseCursor,
    required super.child,
  });

  const DefaultSelectionStyle.fallback({ super.key })
    : cursorColor = null,
      selectionColor = null,
      mouseCursor = null,
      super(child: const _NullWidget());

  static Widget merge({
    Key? key,
    Color? cursorColor,
    Color? selectionColor,
    MouseCursor? mouseCursor,
    required Widget child,
  }) {
    return Builder(
      builder: (BuildContext context) {
        final DefaultSelectionStyle parent = DefaultSelectionStyle.of(context);
        return DefaultSelectionStyle(
          key: key,
          cursorColor: cursorColor ?? parent.cursorColor,
          selectionColor: selectionColor ?? parent.selectionColor,
          mouseCursor: mouseCursor ?? parent.mouseCursor,
          child: child,
        );
      },
    );
  }

  static const Color defaultColor = Color(0x80808080);

  final Color? cursorColor;

  final Color? selectionColor;

  final MouseCursor? mouseCursor;

  static DefaultSelectionStyle of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<DefaultSelectionStyle>() ?? const DefaultSelectionStyle.fallback();
  }

  @override
  Widget wrap(BuildContext context, Widget child) {
    return DefaultSelectionStyle(
      cursorColor: cursorColor,
      selectionColor: selectionColor,
      mouseCursor: mouseCursor,
      child: child
    );
  }

  @override
  bool updateShouldNotify(DefaultSelectionStyle oldWidget) {
    return cursorColor != oldWidget.cursorColor ||
           selectionColor != oldWidget.selectionColor ||
           mouseCursor != oldWidget.mouseCursor;
  }
}

class _NullWidget extends StatelessWidget {
  const _NullWidget();

  @override
  Widget build(BuildContext context) {
    throw FlutterError(
      'A DefaultSelectionStyle constructed with DefaultSelectionStyle.fallback cannot be incorporated into the widget tree, '
      'it is meant only to provide a fallback value returned by DefaultSelectionStyle.of() '
      'when no enclosing default selection style is present in a BuildContext.',
    );
  }
}