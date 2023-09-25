import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'action_icons_theme.dart';
import 'button_style.dart';
import 'debug.dart';
import 'icon_button.dart';
import 'icons.dart';
import 'material_localizations.dart';
import 'scaffold.dart';
import 'theme.dart';

abstract class _ActionButton extends StatelessWidget {
  const _ActionButton({
    super.key,
    this.color,
    required this.icon,
    required this.onPressed,
    this.style,
  });

  final Widget icon;

  final VoidCallback? onPressed;

  final Color? color;

  final ButtonStyle? style;

  String _getTooltip(BuildContext context);

  void _onPressedCallback(BuildContext context);

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMaterialLocalizations(context));
    return IconButton(
      icon: icon,
      style: style,
      color: color,
      tooltip: _getTooltip(context),
      onPressed: () {
        if (onPressed != null) {
          onPressed!();
        } else {
          _onPressedCallback(context);
        }
      },
    );
  }
}

typedef _ActionIconBuilderCallback = WidgetBuilder? Function(ActionIconThemeData? actionIconTheme);
typedef _ActionIconDataCallback = IconData Function(BuildContext context);
typedef _AndroidSemanticsLabelCallback = String Function(MaterialLocalizations materialLocalization);

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({
    required this.iconBuilderCallback,
    required this.getIcon,
    required this.getAndroidSemanticsLabel,
  });

  final _ActionIconBuilderCallback iconBuilderCallback;
  final _ActionIconDataCallback getIcon;
  final _AndroidSemanticsLabelCallback getAndroidSemanticsLabel;

  @override
  Widget build(BuildContext context) {
    final ActionIconThemeData? actionIconTheme = ActionIconTheme.of(context);
    final WidgetBuilder? iconBuilder = iconBuilderCallback(actionIconTheme);
    if (iconBuilder != null) {
      return iconBuilder(context);
    }

    final IconData data = getIcon(context);
    final String? semanticsLabel;
    // This can't use the platform from Theme because it is the Android OS that
    // expects the duplicated tooltip and label.
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        semanticsLabel = getAndroidSemanticsLabel(MaterialLocalizations.of(context));
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        semanticsLabel = null;
    }

    return Icon(data, semanticLabel: semanticsLabel);
  }
}

class BackButtonIcon extends StatelessWidget {
  const BackButtonIcon({ super.key });

  @override
  Widget build(BuildContext context) {
    return _ActionIcon(
      iconBuilderCallback: (ActionIconThemeData? actionIconTheme) {
        return actionIconTheme?.backButtonIconBuilder;
      },
      getIcon: (BuildContext context) {
        if (kIsWeb) {
          // Always use 'Icons.arrow_back' as a back_button icon in web.
          return Icons.arrow_back;
        }
        switch (Theme.of(context).platform) {
          case TargetPlatform.android:
          case TargetPlatform.fuchsia:
          case TargetPlatform.linux:
          case TargetPlatform.windows:
            return Icons.arrow_back;
          case TargetPlatform.iOS:
          case TargetPlatform.macOS:
            return Icons.arrow_back_ios;
        }
      },
      getAndroidSemanticsLabel: (MaterialLocalizations materialLocalization) {
        return materialLocalization.backButtonTooltip;
      },
    );
  }
}

class BackButton extends _ActionButton {
  const BackButton({
    super.key,
    super.color,
    super.style,
    super.onPressed,
  }) : super(icon: const BackButtonIcon());

  @override
  void _onPressedCallback(BuildContext context) => Navigator.maybePop(context);

  @override
  String _getTooltip(BuildContext context) {
    return MaterialLocalizations.of(context).backButtonTooltip;
  }
}

class CloseButtonIcon extends StatelessWidget {
  const CloseButtonIcon({ super.key });

  @override
  Widget build(BuildContext context) {
    return _ActionIcon(
      iconBuilderCallback: (ActionIconThemeData? actionIconTheme) {
        return actionIconTheme?.closeButtonIconBuilder;
      },
      getIcon: (BuildContext context) => Icons.close,
      getAndroidSemanticsLabel: (MaterialLocalizations materialLocalization) {
        return materialLocalization.closeButtonTooltip;
      },
    );
  }
}

class CloseButton extends _ActionButton {
  const CloseButton({ super.key, super.color, super.onPressed, super.style })
      : super(icon: const CloseButtonIcon());

  @override
  void _onPressedCallback(BuildContext context) => Navigator.maybePop(context);

  @override
  String _getTooltip(BuildContext context) {
    return MaterialLocalizations.of(context).closeButtonTooltip;
  }
}

class DrawerButtonIcon extends StatelessWidget {
  const DrawerButtonIcon({ super.key });

  @override
  Widget build(BuildContext context) {
    return _ActionIcon(
      iconBuilderCallback: (ActionIconThemeData? actionIconTheme) {
        return actionIconTheme?.drawerButtonIconBuilder;
      },
      getIcon: (BuildContext context) => Icons.menu,
      getAndroidSemanticsLabel: (MaterialLocalizations materialLocalization) {
        return materialLocalization.openAppDrawerTooltip;
      },
    );
  }
}

class DrawerButton extends _ActionButton {
  const DrawerButton({
    super.key,
    super.style,
    super.onPressed,
  }) : super(icon: const DrawerButtonIcon());

  @override
  void _onPressedCallback(BuildContext context) => Scaffold.of(context).openDrawer();

  @override
  String _getTooltip(BuildContext context) {
    return MaterialLocalizations.of(context).openAppDrawerTooltip;
  }
}

class EndDrawerButtonIcon extends StatelessWidget {
  const EndDrawerButtonIcon({ super.key });

  @override
  Widget build(BuildContext context) {
    return _ActionIcon(
      iconBuilderCallback: (ActionIconThemeData? actionIconTheme) {
        return actionIconTheme?.endDrawerButtonIconBuilder;
      },
      getIcon: (BuildContext context) => Icons.menu,
      getAndroidSemanticsLabel: (MaterialLocalizations materialLocalization) {
        return materialLocalization.openAppDrawerTooltip;
      },
    );
  }
}

class EndDrawerButton extends _ActionButton {
  const EndDrawerButton({
    super.key,
    super.style,
    super.onPressed,
  }) : super(icon: const EndDrawerButtonIcon());

  @override
  void _onPressedCallback(BuildContext context) => Scaffold.of(context).openEndDrawer();

  @override
  String _getTooltip(BuildContext context) {
    return MaterialLocalizations.of(context).openAppDrawerTooltip;
  }
}