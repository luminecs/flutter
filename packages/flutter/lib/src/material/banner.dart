
import 'package:flutter/widgets.dart';

import 'banner_theme.dart';
import 'color_scheme.dart';
import 'divider.dart';
import 'material.dart';
import 'scaffold.dart';
import 'text_theme.dart';
import 'theme.dart';

// Examples can assume:
// late BuildContext context;

const Duration _materialBannerTransitionDuration = Duration(milliseconds: 250);
const Curve _materialBannerHeightCurve = Curves.fastOutSlowIn;

enum MaterialBannerClosedReason {
  dismiss,

  swipe,

  hide,

  remove,
}

class MaterialBanner extends StatefulWidget {
  const MaterialBanner({
    super.key,
    required this.content,
    this.contentTextStyle,
    required this.actions,
    this.elevation,
    this.leading,
    this.backgroundColor,
    this.surfaceTintColor,
    this.shadowColor,
    this.dividerColor,
    this.padding,
    this.margin,
    this.leadingPadding,
    this.forceActionsBelow = false,
    this.overflowAlignment = OverflowBarAlignment.end,
    this.animation,
    this.onVisible,
  }) : assert(elevation == null || elevation >= 0.0);

  final Widget content;

  final TextStyle? contentTextStyle;

  final List<Widget> actions;

  final double? elevation;

  final Widget? leading;

  final Color? backgroundColor;

  final Color? surfaceTintColor;

  final Color? shadowColor;

  final Color? dividerColor;

  final EdgeInsetsGeometry? padding;

  final EdgeInsetsGeometry? margin;

  final EdgeInsetsGeometry? leadingPadding;

  final bool forceActionsBelow;

  final OverflowBarAlignment overflowAlignment;

  final Animation<double>? animation;

  final VoidCallback? onVisible;

  // API for ScaffoldMessengerState.showMaterialBanner():

  static AnimationController createAnimationController({ required TickerProvider vsync }) {
    return AnimationController(
      duration: _materialBannerTransitionDuration,
      debugLabel: 'MaterialBanner',
      vsync: vsync,
    );
  }

  MaterialBanner withAnimation(Animation<double> newAnimation, { Key? fallbackKey }) {
    return MaterialBanner(
      key: key ?? fallbackKey,
      content: content,
      contentTextStyle: contentTextStyle,
      actions: actions,
      elevation: elevation,
      leading: leading,
      backgroundColor: backgroundColor,
      surfaceTintColor: surfaceTintColor,
      shadowColor: shadowColor,
      dividerColor: dividerColor,
      padding: padding,
      margin: margin,
      leadingPadding: leadingPadding,
      forceActionsBelow: forceActionsBelow,
      overflowAlignment: overflowAlignment,
      animation: newAnimation,
      onVisible: onVisible,
    );
  }

  @override
  State<MaterialBanner> createState() => _MaterialBannerState();
}

class _MaterialBannerState extends State<MaterialBanner> {
  bool _wasVisible = false;

  @override
  void initState() {
    super.initState();
    widget.animation?.addStatusListener(_onAnimationStatusChanged);
  }

  @override
  void didUpdateWidget(MaterialBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animation != oldWidget.animation) {
      oldWidget.animation?.removeStatusListener(_onAnimationStatusChanged);
      widget.animation?.addStatusListener(_onAnimationStatusChanged);
    }
  }

  @override
  void dispose() {
    widget.animation?.removeStatusListener(_onAnimationStatusChanged);
    super.dispose();
  }

  void _onAnimationStatusChanged(AnimationStatus animationStatus) {
    switch (animationStatus) {
      case AnimationStatus.dismissed:
      case AnimationStatus.forward:
      case AnimationStatus.reverse:
        break;
      case AnimationStatus.completed:
        if (widget.onVisible != null && !_wasVisible) {
          widget.onVisible!();
        }
        _wasVisible = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasMediaQuery(context));
    final bool accessibleNavigation = MediaQuery.accessibleNavigationOf(context);

    assert(widget.actions.isNotEmpty);

    final ThemeData theme = Theme.of(context);
    final MaterialBannerThemeData bannerTheme = MaterialBannerTheme.of(context);
    final MaterialBannerThemeData defaults = theme.useMaterial3 ? _BannerDefaultsM3(context) : _BannerDefaultsM2(context);

    final bool isSingleRow = widget.actions.length == 1 && !widget.forceActionsBelow;
    final EdgeInsetsGeometry padding = widget.padding ?? bannerTheme.padding ?? (isSingleRow
        ? const EdgeInsetsDirectional.only(start: 16.0, top: 2.0)
        : const EdgeInsetsDirectional.only(start: 16.0, top: 24.0, end: 16.0, bottom: 4.0));
    final EdgeInsetsGeometry leadingPadding = widget.leadingPadding
        ?? bannerTheme.leadingPadding
        ?? const EdgeInsetsDirectional.only(end: 16.0);

    final Widget buttonBar = Container(
      alignment: AlignmentDirectional.centerEnd,
      constraints: const BoxConstraints(minHeight: 52.0),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: OverflowBar(
        overflowAlignment: widget.overflowAlignment,
        spacing: 8,
        children: widget.actions,
      ),
    );

    final double elevation = widget.elevation ?? bannerTheme.elevation ?? 0.0;
    final EdgeInsetsGeometry margin = widget.margin ?? EdgeInsets.only(bottom: elevation > 0 ? 10.0 : 0.0);
    final Color backgroundColor = widget.backgroundColor
        ?? bannerTheme.backgroundColor
        ?? defaults.backgroundColor!;
    final Color? surfaceTintColor = widget.surfaceTintColor
        ?? bannerTheme.surfaceTintColor
        ?? defaults.surfaceTintColor;
    final Color? shadowColor = widget.shadowColor
        ?? bannerTheme.shadowColor;
    final Color? dividerColor = widget.dividerColor
        ?? bannerTheme.dividerColor
        ?? defaults.dividerColor;
    final TextStyle? textStyle = widget.contentTextStyle
        ?? bannerTheme.contentTextStyle
        ?? defaults.contentTextStyle;

    Widget materialBanner = Container(
      margin: margin,
      child: Material(
        elevation: elevation,
        color: backgroundColor,
        surfaceTintColor: surfaceTintColor,
        shadowColor: shadowColor,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Padding(
              padding: padding,
              child: Row(
                children: <Widget>[
                  if (widget.leading != null)
                    Padding(
                      padding: leadingPadding,
                      child: widget.leading,
                    ),
                  Expanded(
                    child: DefaultTextStyle(
                      style: textStyle!,
                      child: widget.content,
                    ),
                  ),
                  if (isSingleRow)
                    buttonBar,
                ],
              ),
            ),
            if (!isSingleRow)
              buttonBar,
            if (elevation == 0)
              Divider(height: 0, color: dividerColor),
          ],
        ),
      ),
    );

    // This provides a static banner for backwards compatibility.
    if (widget.animation == null) {
      return materialBanner;
    }

    materialBanner = SafeArea(
      child: materialBanner,
    );

    final CurvedAnimation heightAnimation = CurvedAnimation(parent: widget.animation!, curve: _materialBannerHeightCurve);
    final Animation<Offset> slideOutAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: widget.animation!,
      curve: const Threshold(0.0),
    ));

    materialBanner = Semantics(
      container: true,
      liveRegion: true,
      onDismiss: () {
        ScaffoldMessenger.of(context).removeCurrentMaterialBanner(reason: MaterialBannerClosedReason.dismiss);
      },
      child: accessibleNavigation
          ? materialBanner
          : SlideTransition(
        position: slideOutAnimation,
        child: materialBanner,
      ),
    );

    final Widget materialBannerTransition;
    if (accessibleNavigation) {
      materialBannerTransition = materialBanner;
    } else {
      materialBannerTransition = AnimatedBuilder(
        animation: heightAnimation,
        builder: (BuildContext context, Widget? child) {
          return Align(
            alignment: AlignmentDirectional.bottomStart,
            heightFactor: heightAnimation.value,
            child: child,
          );
        },
        child: materialBanner,
      );
    }

    return Hero(
      tag: '<MaterialBanner Hero tag - ${widget.content}>',
      child: ClipRect(child: materialBannerTransition),
    );
  }
}

class _BannerDefaultsM2 extends MaterialBannerThemeData {
  _BannerDefaultsM2(this.context)
    : _theme = Theme.of(context),
      super(elevation: 0.0);

  final BuildContext context;
  final ThemeData _theme;

  @override
  Color? get backgroundColor => _theme.colorScheme.surface;

  @override
  TextStyle? get contentTextStyle => _theme.textTheme.bodyMedium;
}

// BEGIN GENERATED TOKEN PROPERTIES - Banner

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

class _BannerDefaultsM3 extends MaterialBannerThemeData {
  _BannerDefaultsM3(this.context)
    : super(elevation: 1.0);

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;
  late final TextTheme _textTheme = Theme.of(context).textTheme;

  @override
  Color? get backgroundColor => _colors.surface;

  @override
  Color? get surfaceTintColor => _colors.surfaceTint;

  @override
  Color? get dividerColor => _colors.outlineVariant;

  @override
  TextStyle? get contentTextStyle => _textTheme.bodyMedium;
}

// END GENERATED TOKEN PROPERTIES - Banner