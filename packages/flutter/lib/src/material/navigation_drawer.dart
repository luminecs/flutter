import 'package:flutter/widgets.dart';

import 'color_scheme.dart';
import 'colors.dart';
import 'drawer.dart';
import 'ink_well.dart';
import 'material.dart';
import 'material_localizations.dart';
import 'material_state.dart';
import 'navigation_bar.dart';
import 'navigation_drawer_theme.dart';
import 'text_theme.dart';
import 'theme.dart';

class NavigationDrawer extends StatelessWidget {
  const NavigationDrawer({
    super.key,
    required this.children,
    this.backgroundColor,
    this.shadowColor,
    this.surfaceTintColor,
    this.elevation,
    this.indicatorColor,
    this.indicatorShape,
    this.onDestinationSelected,
    this.selectedIndex = 0,
    this.tilePadding = const EdgeInsets.symmetric(horizontal: 12.0),
  });

  final Color? backgroundColor;

  final Color? shadowColor;

  final Color? surfaceTintColor;

  final double? elevation;

  final Color? indicatorColor;

  final ShapeBorder? indicatorShape;

  final List<Widget> children;

  final int? selectedIndex;

  final ValueChanged<int>? onDestinationSelected;

  final EdgeInsetsGeometry tilePadding;

  @override
  Widget build(BuildContext context) {
    final int totalNumberOfDestinations =
        children.whereType<NavigationDrawerDestination>().toList().length;

    int destinationIndex = 0;
    final List<Widget> wrappedChildren = <Widget>[];
    Widget wrapChild(Widget child, int index) => _SelectableAnimatedBuilder(
        duration: const Duration(milliseconds: 500),
        isSelected: index == selectedIndex,
        builder: (BuildContext context, Animation<double> animation) {
          return _NavigationDrawerDestinationInfo(
            index: index,
            totalNumberOfDestinations: totalNumberOfDestinations,
            selectedAnimation: animation,
            indicatorColor: indicatorColor,
            indicatorShape: indicatorShape,
            tilePadding: tilePadding,
            onTap: () {
              if (onDestinationSelected != null) {
                onDestinationSelected!(index);
              }
            },
            child: child,
          );
        });

    for (int i = 0; i < children.length; i++) {
      if (children[i] is! NavigationDrawerDestination) {
        wrappedChildren.add(children[i]);
      } else {
        wrappedChildren.add(wrapChild(children[i], destinationIndex));
        destinationIndex += 1;
      }
    }
    final NavigationDrawerThemeData navigationDrawerTheme = NavigationDrawerTheme.of(context);

    return Drawer(
      backgroundColor: backgroundColor ?? navigationDrawerTheme.backgroundColor,
      shadowColor: shadowColor ?? navigationDrawerTheme.shadowColor,
      surfaceTintColor: surfaceTintColor ?? navigationDrawerTheme.surfaceTintColor,
      elevation: elevation ?? navigationDrawerTheme.elevation,
      child: SafeArea(
        bottom: false,
        child: ListView(
          children: wrappedChildren,
        ),
      ),
    );
  }
}

class NavigationDrawerDestination extends StatelessWidget {
  const NavigationDrawerDestination({
    super.key,
    this.backgroundColor,
    required this.icon,
    this.selectedIcon,
    required this.label,
    this.enabled = true,
  });

  final Color? backgroundColor;

  final Widget icon;

  final Widget? selectedIcon;

  final Widget label;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    const Set<MaterialState> selectedState = <MaterialState>{
      MaterialState.selected
    };
    const Set<MaterialState> unselectedState = <MaterialState>{};
    const Set<MaterialState> disabledState = <MaterialState>{
      MaterialState.disabled
    };

    final NavigationDrawerThemeData navigationDrawerTheme =
        NavigationDrawerTheme.of(context);
    final NavigationDrawerThemeData defaults =
        _NavigationDrawerDefaultsM3(context);

    final Animation<double> animation =
        _NavigationDrawerDestinationInfo.of(context).selectedAnimation;

    return _NavigationDestinationBuilder(
      buildIcon: (BuildContext context) {
        final Widget selectedIconWidget = IconTheme.merge(
          data: navigationDrawerTheme.iconTheme?.resolve(enabled ? selectedState : disabledState) ??
              defaults.iconTheme!.resolve(enabled ? selectedState : disabledState)!,
          child: selectedIcon ?? icon,
        );
        final Widget unselectedIconWidget = IconTheme.merge(
          data: navigationDrawerTheme.iconTheme?.resolve(enabled ? unselectedState : disabledState) ??
              defaults.iconTheme!.resolve(enabled ? unselectedState : disabledState)!,
          child: icon,
        );

        return _isForwardOrCompleted(animation)
            ? selectedIconWidget
            : unselectedIconWidget;
      },
      buildLabel: (BuildContext context) {
        final TextStyle? effectiveSelectedLabelTextStyle =
            navigationDrawerTheme.labelTextStyle?.resolve(enabled ? selectedState : disabledState) ??
            defaults.labelTextStyle!.resolve(enabled ? selectedState : disabledState);
        final TextStyle? effectiveUnselectedLabelTextStyle =
            navigationDrawerTheme.labelTextStyle?.resolve(enabled ? unselectedState : disabledState) ??
            defaults.labelTextStyle!.resolve(enabled ? unselectedState : disabledState);

        return DefaultTextStyle(
          style: _isForwardOrCompleted(animation)
            ? effectiveSelectedLabelTextStyle!
            : effectiveUnselectedLabelTextStyle!,
          child: label,
        );
      },
      enabled: enabled,
    );
  }
}

class _NavigationDestinationBuilder extends StatelessWidget {
  const _NavigationDestinationBuilder({
    required this.buildIcon,
    required this.buildLabel,
    this.enabled = true,
  });

  final WidgetBuilder buildIcon;

  final WidgetBuilder buildLabel;

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final _NavigationDrawerDestinationInfo info = _NavigationDrawerDestinationInfo.of(context);
    final NavigationDrawerThemeData navigationDrawerTheme = NavigationDrawerTheme.of(context);
    final NavigationDrawerThemeData defaults = _NavigationDrawerDefaultsM3(context);

    final Row destinationBody = Row(
      children: <Widget>[
        const SizedBox(width: 16),
        buildIcon(context),
        const SizedBox(width: 12),
        buildLabel(context),
      ],
    );

    return Padding(
      padding: info.tilePadding,
      child: _NavigationDestinationSemantics(
        child: SizedBox(
          height: navigationDrawerTheme.tileHeight ?? defaults.tileHeight,
          child: InkWell(
            highlightColor: Colors.transparent,
            onTap: enabled ? info.onTap : null,
            customBorder: info.indicatorShape ?? navigationDrawerTheme.indicatorShape ?? defaults.indicatorShape!,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                NavigationIndicator(
                  animation: info.selectedAnimation,
                  color: info.indicatorColor ?? navigationDrawerTheme.indicatorColor ?? defaults.indicatorColor!,
                  shape: info.indicatorShape ?? navigationDrawerTheme.indicatorShape ?? defaults.indicatorShape!,
                  width: (navigationDrawerTheme.indicatorSize ?? defaults.indicatorSize!).width,
                  height: (navigationDrawerTheme.indicatorSize ?? defaults.indicatorSize!).height,
                ),
                destinationBody
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationDestinationSemantics extends StatelessWidget {
  const _NavigationDestinationSemantics({
    required this.child,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final MaterialLocalizations localizations = MaterialLocalizations.of(context);
    final _NavigationDrawerDestinationInfo destinationInfo = _NavigationDrawerDestinationInfo.of(context);
    // The AnimationStatusBuilder will make sure that the semantics update to
    // "selected" when the animation status changes.
    return _StatusTransitionWidgetBuilder(
      animation: destinationInfo.selectedAnimation,
      builder: (BuildContext context, Widget? child) {
        return Semantics(
          selected: _isForwardOrCompleted(destinationInfo.selectedAnimation),
          container: true,
          child: child,
        );
      },
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          child,
          Semantics(
            label: localizations.tabLabel(
              tabIndex: destinationInfo.index + 1,
              tabCount: destinationInfo.totalNumberOfDestinations,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusTransitionWidgetBuilder extends StatusTransitionWidget {
  const _StatusTransitionWidgetBuilder({
    required super.animation,
    required this.builder,
    this.child,
  });

  final TransitionBuilder builder;

  final Widget? child;

  @override
  Widget build(BuildContext context) => builder(context, child);
}

class _NavigationDrawerDestinationInfo extends InheritedWidget {
  const _NavigationDrawerDestinationInfo({
    required this.index,
    required this.totalNumberOfDestinations,
    required this.selectedAnimation,
    required this.indicatorColor,
    required this.indicatorShape,
    required this.onTap,
    required super.child,
    required this.tilePadding,
  });

  final int index;

  final int totalNumberOfDestinations;

  final Animation<double> selectedAnimation;

  final Color? indicatorColor;

  final ShapeBorder? indicatorShape;

  final VoidCallback onTap;

  final EdgeInsetsGeometry tilePadding;

  static _NavigationDrawerDestinationInfo of(BuildContext context) {
    final _NavigationDrawerDestinationInfo? result = context.dependOnInheritedWidgetOfExactType<_NavigationDrawerDestinationInfo>();
    assert(
      result != null,
      'Navigation destinations need a _NavigationDrawerDestinationInfo parent, '
      'which is usually provided by NavigationDrawer.',
    );
    return result!;
  }

  @override
  bool updateShouldNotify(_NavigationDrawerDestinationInfo oldWidget) {
    return index != oldWidget.index
        || totalNumberOfDestinations != oldWidget.totalNumberOfDestinations
        || selectedAnimation != oldWidget.selectedAnimation
        || onTap != oldWidget.onTap;
  }
}

// Builder widget for widgets that need to be animated from 0 (unselected) to
// 1.0 (selected).
//
// This widget creates and manages an [AnimationController] that it passes down
// to the child through the [builder] function.
//
// When [isSelected] is `true`, the animation controller will animate from
// 0 to 1 (for [duration] time).
//
// When [isSelected] is `false`, the animation controller will animate from
// 1 to 0 (for [duration] time).
//
// If [isSelected] is updated while the widget is animating, the animation will
// be reversed until it is either 0 or 1 again.
//
// Usage:
// ```dart
// _SelectableAnimatedBuilder(
//   isSelected: _isDrawerOpen,
//   builder: (context, animation) {
//     return AnimatedIcon(
//       icon: AnimatedIcons.menu_arrow,
//       progress: animation,
//       semanticLabel: 'Show menu',
//     );
//   }
// )
// ```
class _SelectableAnimatedBuilder extends StatefulWidget {
  const _SelectableAnimatedBuilder({
    required this.isSelected,
    this.duration = const Duration(milliseconds: 200),
    required this.builder,
  });

  final bool isSelected;

  final Duration duration;

  final Widget Function(BuildContext, Animation<double>) builder;

  @override
  _SelectableAnimatedBuilderState createState() => _SelectableAnimatedBuilderState();
}

class _SelectableAnimatedBuilderState extends State<_SelectableAnimatedBuilder>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _controller.duration = widget.duration;
    _controller.value = widget.isSelected ? 1.0 : 0.0;
  }

  @override
  void didUpdateWidget(_SelectableAnimatedBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.isSelected != widget.isSelected) {
      if (widget.isSelected) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      _controller,
    );
  }
}

bool _isForwardOrCompleted(Animation<double> animation) {
  return animation.status == AnimationStatus.forward || animation.status == AnimationStatus.completed;
}

// BEGIN GENERATED TOKEN PROPERTIES - NavigationDrawer

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

class _NavigationDrawerDefaultsM3 extends NavigationDrawerThemeData {
  _NavigationDrawerDefaultsM3(this.context)
    : super(
        elevation: 1.0,
        tileHeight: 56.0,
        indicatorShape: const StadiumBorder(),
        indicatorSize: const Size(336.0, 56.0),
      );

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;
  late final TextTheme _textTheme = Theme.of(context).textTheme;

  @override
  Color? get backgroundColor => _colors.surface;

  @override
  Color? get surfaceTintColor => _colors.surfaceTint;

  @override
  Color? get shadowColor => Colors.transparent;

  @override
  Color? get indicatorColor => _colors.secondaryContainer;

  @override
  MaterialStateProperty<IconThemeData?>? get iconTheme {
    return MaterialStateProperty.resolveWith((Set<MaterialState> states) {
      return IconThemeData(
        size: 24.0,
        color: states.contains(MaterialState.disabled)
          ? _colors.onSurfaceVariant.withOpacity(0.38)
          : states.contains(MaterialState.selected)
            ? _colors.onSecondaryContainer
            : _colors.onSurfaceVariant,
      );
    });
  }

  @override
  MaterialStateProperty<TextStyle?>? get labelTextStyle {
    return MaterialStateProperty.resolveWith((Set<MaterialState> states) {
      final TextStyle style = _textTheme.labelLarge!;
      return style.apply(
        color: states.contains(MaterialState.disabled)
          ? _colors.onSurfaceVariant.withOpacity(0.38)
          : states.contains(MaterialState.selected)
            ? _colors.onSecondaryContainer
            : _colors.onSurfaceVariant,
      );
    });
  }
}

// END GENERATED TOKEN PROPERTIES - NavigationDrawer