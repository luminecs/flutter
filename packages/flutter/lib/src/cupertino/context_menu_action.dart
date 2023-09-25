import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'colors.dart';

class CupertinoContextMenuAction extends StatefulWidget {
  const CupertinoContextMenuAction({
    super.key,
    required this.child,
    this.isDefaultAction = false,
    this.isDestructiveAction = false,
    this.onPressed,
    this.trailingIcon,
  });

  final Widget child;

  final bool isDefaultAction;

  final bool isDestructiveAction;

  final VoidCallback? onPressed;

  final IconData? trailingIcon;

  @override
  State<CupertinoContextMenuAction> createState() => _CupertinoContextMenuActionState();
}

class _CupertinoContextMenuActionState extends State<CupertinoContextMenuAction> {
  static const Color _kBackgroundColor = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF1F1F1),
    darkColor: Color(0xFF212122),
  );
  static const Color _kBackgroundColorPressed = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFDDDDDD),
    darkColor: Color(0xFF3F3F40),
  );
  static const double _kButtonHeight = 43;
  static const TextStyle _kActionSheetActionStyle = TextStyle(
    fontFamily: '.SF UI Text',
    inherit: false,
    fontSize: 16.0,
    fontWeight: FontWeight.w400,
    color: CupertinoColors.black,
    textBaseline: TextBaseline.alphabetic,
  );

  final GlobalKey _globalKey = GlobalKey();
  bool _isPressed = false;

  void onTapDown(TapDownDetails details) {
    setState(() {
      _isPressed = true;
    });
  }

  void onTapUp(TapUpDetails details) {
    setState(() {
      _isPressed = false;
    });
  }

  void onTapCancel() {
    setState(() {
      _isPressed = false;
    });
  }

  TextStyle get _textStyle {
    if (widget.isDefaultAction) {
      return _kActionSheetActionStyle.copyWith(
        fontWeight: FontWeight.w600,
      );
    }
    if (widget.isDestructiveAction) {
      return _kActionSheetActionStyle.copyWith(
        color: CupertinoColors.destructiveRed,
      );
    }
    return _kActionSheetActionStyle.copyWith(
      color: CupertinoDynamicColor.resolve(CupertinoColors.label, context)
    );
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.onPressed != null && kIsWeb ? SystemMouseCursors.click : MouseCursor.defer,
      child: GestureDetector(
        key: _globalKey,
        onTapDown: onTapDown,
        onTapUp: onTapUp,
        onTapCancel: onTapCancel,
        onTap: widget.onPressed,
        behavior: HitTestBehavior.opaque,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: _kButtonHeight,
          ),
          child: Semantics(
            button: true,
            child: Container(
              decoration: BoxDecoration(
                color: _isPressed
                  ? CupertinoDynamicColor.resolve(_kBackgroundColorPressed, context)
                  : CupertinoDynamicColor.resolve(_kBackgroundColor, context),
              ),
              padding: const EdgeInsets.only(
                top: 8,
                bottom: 8,
                left: 15.5,
                right: 17.5,
              ),
              child: DefaultTextStyle(
                style: _textStyle,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Flexible(
                      child: widget.child,
                    ),
                    if (widget.trailingIcon != null)
                      Icon(
                        widget.trailingIcon,
                        color: _textStyle.color,
                        size: 21.0,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}