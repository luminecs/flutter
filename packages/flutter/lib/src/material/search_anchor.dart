
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/widgets.dart';

import 'button_style.dart';
import 'color_scheme.dart';
import 'colors.dart';
import 'constants.dart';
import 'divider.dart';
import 'divider_theme.dart';
import 'icon_button.dart';
import 'icons.dart';
import 'ink_well.dart';
import 'input_border.dart';
import 'input_decorator.dart';
import 'material.dart';
import 'material_state.dart';
import 'search_bar_theme.dart';
import 'search_view_theme.dart';
import 'text_field.dart';
import 'text_theme.dart';
import 'theme.dart';
import 'theme_data.dart';

const int _kOpenViewMilliseconds = 600;
const Duration _kOpenViewDuration = Duration(milliseconds: _kOpenViewMilliseconds);
const Duration _kAnchorFadeDuration = Duration(milliseconds: 150);
const Curve _kViewFadeOnInterval = Interval(0.0, 1/2);
const Curve _kViewIconsFadeOnInterval = Interval(1/6, 2/6);
const Curve _kViewDividerFadeOnInterval = Interval(0.0, 1/6);
const Curve _kViewListFadeOnInterval = Interval(133 / _kOpenViewMilliseconds, 233 / _kOpenViewMilliseconds);

typedef SearchAnchorChildBuilder = Widget Function(BuildContext context, SearchController controller);

typedef SuggestionsBuilder = FutureOr<Iterable<Widget>> Function(BuildContext context, SearchController controller);

typedef ViewBuilder = Widget Function(Iterable<Widget> suggestions);

class SearchAnchor extends StatefulWidget {
  const SearchAnchor({
    super.key,
    this.isFullScreen,
    this.searchController,
    this.viewBuilder,
    this.viewLeading,
    this.viewTrailing,
    this.viewHintText,
    this.viewBackgroundColor,
    this.viewElevation,
    this.viewSurfaceTintColor,
    this.viewSide,
    this.viewShape,
    this.headerTextStyle,
    this.headerHintStyle,
    this.dividerColor,
    this.viewConstraints,
    this.textCapitalization,
    required this.builder,
    required this.suggestionsBuilder,
  });

  factory SearchAnchor.bar({
    Widget? barLeading,
    Iterable<Widget>? barTrailing,
    String? barHintText,
    GestureTapCallback? onTap,
    MaterialStateProperty<double?>? barElevation,
    MaterialStateProperty<Color?>? barBackgroundColor,
    MaterialStateProperty<Color?>? barOverlayColor,
    MaterialStateProperty<BorderSide?>? barSide,
    MaterialStateProperty<OutlinedBorder?>? barShape,
    MaterialStateProperty<EdgeInsetsGeometry?>? barPadding,
    MaterialStateProperty<TextStyle?>? barTextStyle,
    MaterialStateProperty<TextStyle?>? barHintStyle,
    Widget? viewLeading,
    Iterable<Widget>? viewTrailing,
    String? viewHintText,
    Color? viewBackgroundColor,
    double? viewElevation,
    BorderSide? viewSide,
    OutlinedBorder? viewShape,
    TextStyle? viewHeaderTextStyle,
    TextStyle? viewHeaderHintStyle,
    Color? dividerColor,
    BoxConstraints? constraints,
    BoxConstraints? viewConstraints,
    bool? isFullScreen,
    SearchController searchController,
    TextCapitalization textCapitalization,
    required SuggestionsBuilder suggestionsBuilder
  }) = _SearchAnchorWithSearchBar;

  final bool? isFullScreen;

  final SearchController? searchController;

  final ViewBuilder? viewBuilder;

  final Widget? viewLeading;

  final Iterable<Widget>? viewTrailing;

  final String? viewHintText;

  final Color? viewBackgroundColor;

  final double? viewElevation;

  final Color? viewSurfaceTintColor;

  final BorderSide? viewSide;

  final OutlinedBorder? viewShape;

  final TextStyle? headerTextStyle;

  final TextStyle? headerHintStyle;

  final Color? dividerColor;

  final BoxConstraints? viewConstraints;

  final TextCapitalization? textCapitalization;

  final SearchAnchorChildBuilder builder;

  final SuggestionsBuilder suggestionsBuilder;

  @override
  State<SearchAnchor> createState() => _SearchAnchorState();
}

class _SearchAnchorState extends State<SearchAnchor> {
  Size? _screenSize;
  bool _anchorIsVisible = true;
  final GlobalKey _anchorKey = GlobalKey();
  bool get _viewIsOpen => !_anchorIsVisible;
  late SearchController? _internalSearchController;
  SearchController get _searchController => widget.searchController ?? _internalSearchController!;

  @override
  void initState() {
    super.initState();
    if (widget.searchController == null) {
      _internalSearchController = SearchController();
    }
    _searchController._attach(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Size updatedScreenSize = MediaQuery.of(context).size;
    if (_screenSize != null && _screenSize != updatedScreenSize) {
      if (_searchController.isOpen && !getShowFullScreenView()) {
        _closeView(null);
      }
    }
    _screenSize = updatedScreenSize;
  }

  @override
  void dispose() {
    super.dispose();
    _searchController._detach(this);
    _internalSearchController = null;
  }

  void _openView() {
    Navigator.of(context).push(_SearchViewRoute(
      viewLeading: widget.viewLeading,
      viewTrailing: widget.viewTrailing,
      viewHintText: widget.viewHintText,
      viewBackgroundColor: widget.viewBackgroundColor,
      viewElevation: widget.viewElevation,
      viewSurfaceTintColor: widget.viewSurfaceTintColor,
      viewSide: widget.viewSide,
      viewShape: widget.viewShape,
      viewHeaderTextStyle: widget.headerTextStyle,
      viewHeaderHintStyle: widget.headerHintStyle,
      dividerColor: widget.dividerColor,
      viewConstraints: widget.viewConstraints,
      showFullScreenView: getShowFullScreenView(),
      toggleVisibility: toggleVisibility,
      textDirection: Directionality.of(context),
      viewBuilder: widget.viewBuilder,
      anchorKey: _anchorKey,
      searchController: _searchController,
      suggestionsBuilder: widget.suggestionsBuilder,
      textCapitalization: widget.textCapitalization,
    ));
  }

  void _closeView(String? selectedText) {
    if (selectedText != null) {
      _searchController.text = selectedText;
    }
    Navigator.of(context).pop();
  }

  bool toggleVisibility() {
    setState(() {
      _anchorIsVisible = !_anchorIsVisible;
    });
    return _anchorIsVisible;
  }

  bool getShowFullScreenView() {
    if (widget.isFullScreen != null) {
      return widget.isFullScreen!;
    }

    switch (Theme.of(context).platform) {
      case TargetPlatform.iOS:
      case TargetPlatform.android:
      case TargetPlatform.fuchsia:
        return true;
      case TargetPlatform.macOS:
      case TargetPlatform.linux:
      case TargetPlatform.windows:
        return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      key: _anchorKey,
      opacity: _anchorIsVisible ? 1.0 : 0.0,
      duration: _kAnchorFadeDuration,
      child: GestureDetector(
        onTap: _openView,
        child: widget.builder(context, _searchController),
      ),
    );
  }
}

class _SearchViewRoute extends PopupRoute<_SearchViewRoute> {
  _SearchViewRoute({
    this.toggleVisibility,
    this.textDirection,
    this.viewBuilder,
    this.viewLeading,
    this.viewTrailing,
    this.viewHintText,
    this.viewBackgroundColor,
    this.viewElevation,
    this.viewSurfaceTintColor,
    this.viewSide,
    this.viewShape,
    this.viewHeaderTextStyle,
    this.viewHeaderHintStyle,
    this.dividerColor,
    this.viewConstraints,
    this.textCapitalization,
    required this.showFullScreenView,
    required this.anchorKey,
    required this.searchController,
    required this.suggestionsBuilder,
  });

  final ValueGetter<bool>? toggleVisibility;
  final TextDirection? textDirection;
  final ViewBuilder? viewBuilder;
  final Widget? viewLeading;
  final Iterable<Widget>? viewTrailing;
  final String? viewHintText;
  final Color? viewBackgroundColor;
  final double? viewElevation;
  final Color? viewSurfaceTintColor;
  final BorderSide? viewSide;
  final OutlinedBorder? viewShape;
  final TextStyle? viewHeaderTextStyle;
  final TextStyle? viewHeaderHintStyle;
  final Color? dividerColor;
  final BoxConstraints? viewConstraints;
  final TextCapitalization? textCapitalization;
  final bool showFullScreenView;
  final GlobalKey anchorKey;
  final SearchController searchController;
  final SuggestionsBuilder suggestionsBuilder;

  @override
  Color? get barrierColor => Colors.transparent;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Dismiss';

  late final SearchViewThemeData viewDefaults;
  late final SearchViewThemeData viewTheme;
  late final DividerThemeData dividerTheme;
  final RectTween _rectTween = RectTween();

  Rect? getRect() {
    final BuildContext? context = anchorKey.currentContext;
    if (context != null) {
      final RenderBox searchBarBox = context.findRenderObject()! as RenderBox;
      final Size boxSize = searchBarBox.size;
      final NavigatorState navigator = Navigator.of(context);
      final Offset boxLocation = searchBarBox.localToGlobal(Offset.zero, ancestor: navigator.context.findRenderObject());
      return boxLocation & boxSize;
    }
    return null;
  }

  @override
  TickerFuture didPush() {
    assert(anchorKey.currentContext != null);
    updateViewConfig(anchorKey.currentContext!);
    updateTweens(anchorKey.currentContext!);
    toggleVisibility?.call();
    return super.didPush();
  }

  @override
  bool didPop(_SearchViewRoute? result) {
    assert(anchorKey.currentContext != null);
    updateTweens(anchorKey.currentContext!);
    toggleVisibility?.call();
    return super.didPop(result);
  }

  void updateViewConfig(BuildContext context) {
    viewDefaults = _SearchViewDefaultsM3(context, isFullScreen: showFullScreenView);
    viewTheme = SearchViewTheme.of(context);
    dividerTheme = DividerTheme.of(context);
  }

  void updateTweens(BuildContext context) {
    final RenderBox navigator = Navigator.of(context).context.findRenderObject()! as RenderBox;
    final Size screenSize = navigator.size;
    final Rect anchorRect = getRect() ?? Rect.zero;

    final BoxConstraints effectiveConstraints = viewConstraints ?? viewTheme.constraints ?? viewDefaults.constraints!;
    _rectTween.begin = anchorRect;

    final double viewWidth = clampDouble(anchorRect.width, effectiveConstraints.minWidth, effectiveConstraints.maxWidth);
    final double viewHeight = clampDouble(screenSize.height * 2 / 3, effectiveConstraints.minHeight, effectiveConstraints.maxHeight);

    switch (textDirection ?? TextDirection.ltr) {
      case TextDirection.ltr:
        final double viewLeftToScreenRight = screenSize.width - anchorRect.left;
        final double viewTopToScreenBottom = screenSize.height - anchorRect.top;

        // Make sure the search view doesn't go off the screen. If the search view
        // doesn't fit, move the top-left corner of the view to fit the window.
        // If the window is smaller than the view, then we resize the view to fit the window.
        Offset topLeft = anchorRect.topLeft;
        if (viewLeftToScreenRight < viewWidth) {
          topLeft = Offset(screenSize.width - math.min(viewWidth, screenSize.width), topLeft.dy);
        }
        if (viewTopToScreenBottom < viewHeight) {
          topLeft = Offset(topLeft.dx, screenSize.height - math.min(viewHeight, screenSize.height));
        }
        final Size endSize = Size(viewWidth, viewHeight);
        _rectTween.end = showFullScreenView ? Offset.zero & screenSize : (topLeft & endSize);
        return;
      case TextDirection.rtl:
        final double viewRightToScreenLeft = anchorRect.right;
        final double viewTopToScreenBottom = screenSize.height - anchorRect.top;

        // Make sure the search view doesn't go off the screen.
        Offset topLeft = Offset(math.max(anchorRect.right - viewWidth, 0.0), anchorRect.top);
        if (viewRightToScreenLeft < viewWidth) {
          topLeft = Offset(0.0, topLeft.dy);
        }
        if (viewTopToScreenBottom < viewHeight) {
          topLeft = Offset(topLeft.dx, screenSize.height - math.min(viewHeight, screenSize.height));
        }
        final Size endSize = Size(viewWidth, viewHeight);
        _rectTween.end = showFullScreenView ? Offset.zero & screenSize : (topLeft & endSize);
    }
  }

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {

    return Directionality(
      textDirection: textDirection ?? TextDirection.ltr,
      child: AnimatedBuilder(
        animation: animation,
        builder: (BuildContext context, Widget? child) {
          final Animation<double> curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubicEmphasized,
            reverseCurve: Curves.easeInOutCubicEmphasized.flipped,
          );

          final Rect viewRect = _rectTween.evaluate(curvedAnimation)!;
          final double topPadding = showFullScreenView
            ? lerpDouble(0.0, MediaQuery.paddingOf(context).top, curvedAnimation.value)!
            : 0.0;

          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: _kViewFadeOnInterval,
              reverseCurve: _kViewFadeOnInterval.flipped,
            ),
            child: _ViewContent(
              viewLeading: viewLeading,
              viewTrailing: viewTrailing,
              viewHintText: viewHintText,
              viewBackgroundColor: viewBackgroundColor,
              viewElevation: viewElevation,
              viewSurfaceTintColor: viewSurfaceTintColor,
              viewSide: viewSide,
              viewShape: viewShape,
              viewHeaderTextStyle: viewHeaderTextStyle,
              viewHeaderHintStyle: viewHeaderHintStyle,
              dividerColor: dividerColor,
              showFullScreenView: showFullScreenView,
              animation: curvedAnimation,
              topPadding: topPadding,
              viewMaxWidth: _rectTween.end!.width,
              viewRect: viewRect,
              viewDefaults: viewDefaults,
              viewTheme: viewTheme,
              dividerTheme: dividerTheme,
              viewBuilder: viewBuilder,
              searchController: searchController,
              suggestionsBuilder: suggestionsBuilder,
              textCapitalization: textCapitalization,
            ),
          );
        }
      ),
    );
  }

  @override
  Duration get transitionDuration => _kOpenViewDuration;
}

class _ViewContent extends StatefulWidget {
  const _ViewContent({
    this.viewBuilder,
    this.viewLeading,
    this.viewTrailing,
    this.viewHintText,
    this.viewBackgroundColor,
    this.viewElevation,
    this.viewSurfaceTintColor,
    this.viewSide,
    this.viewShape,
    this.viewHeaderTextStyle,
    this.viewHeaderHintStyle,
    this.dividerColor,
    this.textCapitalization,
    required this.showFullScreenView,
    required this.topPadding,
    required this.animation,
    required this.viewMaxWidth,
    required this.viewRect,
    required this.viewDefaults,
    required this.viewTheme,
    required this.dividerTheme,
    required this.searchController,
    required this.suggestionsBuilder,
  });

  final ViewBuilder? viewBuilder;
  final Widget? viewLeading;
  final Iterable<Widget>? viewTrailing;
  final String? viewHintText;
  final Color? viewBackgroundColor;
  final double? viewElevation;
  final Color? viewSurfaceTintColor;
  final BorderSide? viewSide;
  final OutlinedBorder? viewShape;
  final TextStyle? viewHeaderTextStyle;
  final TextStyle? viewHeaderHintStyle;
  final Color? dividerColor;
  final TextCapitalization? textCapitalization;
  final bool showFullScreenView;
  final double topPadding;
  final Animation<double> animation;
  final double viewMaxWidth;
  final Rect viewRect;
  final SearchViewThemeData viewDefaults;
  final SearchViewThemeData viewTheme;
  final DividerThemeData dividerTheme;
  final SearchController searchController;
  final SuggestionsBuilder suggestionsBuilder;

  @override
  State<_ViewContent> createState() => _ViewContentState();
}

class _ViewContentState extends State<_ViewContent> {
  Size? _screenSize;
  late Rect _viewRect;
  late final SearchController _controller;
  Iterable<Widget> result = <Widget>[];
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _viewRect = widget.viewRect;
    _controller = widget.searchController;
    if (!_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }
  }

  @override
  void didUpdateWidget(covariant _ViewContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.viewRect != oldWidget.viewRect) {
      setState(() {
        _viewRect = widget.viewRect;
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final Size updatedScreenSize = MediaQuery.of(context).size;

    if (_screenSize != updatedScreenSize) {
      _screenSize = updatedScreenSize;
      if (widget.showFullScreenView) {
        _viewRect = Offset.zero & _screenSize!;
      }
    }
    unawaited(updateSuggestions());
  }

  Widget viewBuilder(Iterable<Widget> suggestions) {
    if (widget.viewBuilder == null) {
      return MediaQuery.removePadding(
        context: context,
        removeTop: true,
        child: ListView(
          children: suggestions.toList()
        ),
      );
    }
    return widget.viewBuilder!(suggestions);
  }

  Future<void> updateSuggestions() async {
    final Iterable<Widget> suggestions = await widget.suggestionsBuilder(context, _controller);
    if (mounted) {
      setState(() {
        result = suggestions;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget defaultLeading = IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () { Navigator.of(context).pop(); },
      style: const ButtonStyle(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
    );

    final List<Widget> defaultTrailing = <Widget>[
      IconButton(
        icon: const Icon(Icons.close),
        onPressed: () {
          _controller.clear();
          updateSuggestions();
        },
      ),
    ];

    final Color effectiveBackgroundColor = widget.viewBackgroundColor
      ?? widget.viewTheme.backgroundColor
      ?? widget.viewDefaults.backgroundColor!;
    final Color effectiveSurfaceTint = widget.viewSurfaceTintColor
      ?? widget.viewTheme.surfaceTintColor
      ?? widget.viewDefaults.surfaceTintColor!;
    final double effectiveElevation = widget.viewElevation
      ?? widget.viewTheme.elevation
      ?? widget.viewDefaults.elevation!;
    final BorderSide? effectiveSide = widget.viewSide
      ?? widget.viewTheme.side
      ?? widget.viewDefaults.side;
    OutlinedBorder effectiveShape = widget.viewShape
      ?? widget.viewTheme.shape
      ?? widget.viewDefaults.shape!;
    if (effectiveSide != null) {
      effectiveShape = effectiveShape.copyWith(side: effectiveSide);
    }
    final Color effectiveDividerColor = widget.dividerColor
      ?? widget.viewTheme.dividerColor
      ?? widget.dividerTheme.color
      ?? widget.viewDefaults.dividerColor!;
    final TextStyle? effectiveTextStyle = widget.viewHeaderTextStyle
      ?? widget.viewTheme.headerTextStyle
      ?? widget.viewDefaults.headerTextStyle;
    final TextStyle? effectiveHintStyle = widget.viewHeaderHintStyle
      ?? widget.viewTheme.headerHintStyle
      ?? widget.viewHeaderTextStyle
      ?? widget.viewTheme.headerTextStyle
      ?? widget.viewDefaults.headerHintStyle;

    final Widget viewDivider = DividerTheme(
      data: widget.dividerTheme.copyWith(color: effectiveDividerColor),
      child: const Divider(height: 1),
    );

    return Align(
      alignment: Alignment.topLeft,
      child: Transform.translate(
        offset: _viewRect.topLeft,
        child: SizedBox(
          width: _viewRect.width,
          height: _viewRect.height,
          child: Material(
            clipBehavior: Clip.antiAlias,
            shape: effectiveShape,
            color: effectiveBackgroundColor,
            surfaceTintColor: effectiveSurfaceTint,
            elevation: effectiveElevation,
            child: ClipRect(
              clipBehavior: Clip.antiAlias,
              child: OverflowBox(
                alignment: Alignment.topLeft,
                maxWidth: math.min(widget.viewMaxWidth, _screenSize!.width),
                minWidth: 0,
                child: FadeTransition(
                  opacity: CurvedAnimation(
                    parent: widget.animation,
                    curve: _kViewIconsFadeOnInterval,
                    reverseCurve: _kViewIconsFadeOnInterval.flipped,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Padding(
                        padding: EdgeInsets.only(top: widget.topPadding),
                        child: SafeArea(
                          top: false,
                          bottom: false,
                          child: SearchBar(
                            constraints: widget.showFullScreenView ? BoxConstraints(minHeight: _SearchViewDefaultsM3.fullScreenBarHeight) : null,
                            focusNode: _focusNode,
                            leading: widget.viewLeading ?? defaultLeading,
                            trailing: widget.viewTrailing ?? defaultTrailing,
                            hintText: widget.viewHintText,
                            backgroundColor: const MaterialStatePropertyAll<Color>(Colors.transparent),
                            overlayColor: const MaterialStatePropertyAll<Color>(Colors.transparent),
                            elevation: const MaterialStatePropertyAll<double>(0.0),
                            textStyle: MaterialStatePropertyAll<TextStyle?>(effectiveTextStyle),
                            hintStyle: MaterialStatePropertyAll<TextStyle?>(effectiveHintStyle),
                            controller: _controller,
                            onChanged: (_) {
                              updateSuggestions();
                            },
                            textCapitalization: widget.textCapitalization,
                          ),
                        ),
                      ),
                      FadeTransition(
                        opacity: CurvedAnimation(
                          parent: widget.animation,
                          curve: _kViewDividerFadeOnInterval,
                          reverseCurve: _kViewFadeOnInterval.flipped,
                        ),
                        child: viewDivider),
                      Expanded(
                        child: FadeTransition(
                          opacity: CurvedAnimation(
                            parent: widget.animation,
                            curve: _kViewListFadeOnInterval,
                            reverseCurve: _kViewListFadeOnInterval.flipped,
                          ),
                          child: viewBuilder(result),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SearchAnchorWithSearchBar extends SearchAnchor {
  _SearchAnchorWithSearchBar({
    Widget? barLeading,
    Iterable<Widget>? barTrailing,
    String? barHintText,
    GestureTapCallback? onTap,
    MaterialStateProperty<double?>? barElevation,
    MaterialStateProperty<Color?>? barBackgroundColor,
    MaterialStateProperty<Color?>? barOverlayColor,
    MaterialStateProperty<BorderSide?>? barSide,
    MaterialStateProperty<OutlinedBorder?>? barShape,
    MaterialStateProperty<EdgeInsetsGeometry?>? barPadding,
    MaterialStateProperty<TextStyle?>? barTextStyle,
    MaterialStateProperty<TextStyle?>? barHintStyle,
    super.viewLeading,
    super.viewTrailing,
    String? viewHintText,
    super.viewBackgroundColor,
    super.viewElevation,
    super.viewSide,
    super.viewShape,
    TextStyle? viewHeaderTextStyle,
    TextStyle? viewHeaderHintStyle,
    super.dividerColor,
    BoxConstraints? constraints,
    super.viewConstraints,
    super.isFullScreen,
    super.searchController,
    super.textCapitalization,
    required super.suggestionsBuilder
  }) : super(
    viewHintText: viewHintText ?? barHintText,
    headerTextStyle: viewHeaderTextStyle,
    headerHintStyle: viewHeaderHintStyle,
    builder: (BuildContext context, SearchController controller) {
      return SearchBar(
        constraints: constraints,
        controller: controller,
        onTap: () {
          controller.openView();
          onTap?.call();
        },
        onChanged: (_) {
          controller.openView();
        },
        hintText: barHintText,
        hintStyle: barHintStyle,
        textStyle: barTextStyle,
        elevation: barElevation,
        backgroundColor: barBackgroundColor,
        overlayColor: barOverlayColor,
        side: barSide,
        shape: barShape,
        padding: barPadding ?? const MaterialStatePropertyAll<EdgeInsets>(EdgeInsets.symmetric(horizontal: 16.0)),
        leading: barLeading ?? const Icon(Icons.search),
        trailing: barTrailing,
        textCapitalization: textCapitalization,
      );
    }
  );
}

class SearchController extends TextEditingController {
  // The anchor that this controller controls.
  //
  // This is set automatically when a [SearchController] is given to the anchor
  // it controls.
  _SearchAnchorState? _anchor;

  bool get isOpen {
    assert(_anchor != null);
    return _anchor!._viewIsOpen;
  }

  void openView() {
    assert(_anchor != null);
    _anchor!._openView();
  }

  void closeView(String? selectedText) {
    assert(_anchor != null);
    _anchor!._closeView(selectedText);
  }

  // ignore: use_setters_to_change_properties
  void _attach(_SearchAnchorState anchor) {
    _anchor = anchor;
  }

  void _detach(_SearchAnchorState anchor) {
    if (_anchor == anchor) {
      _anchor = null;
    }
  }
}

class SearchBar extends StatefulWidget {
  const SearchBar({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.leading,
    this.trailing,
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.constraints,
    this.elevation,
    this.backgroundColor,
    this.shadowColor,
    this.surfaceTintColor,
    this.overlayColor,
    this.side,
    this.shape,
    this.padding,
    this.textStyle,
    this.hintStyle,
    this.textCapitalization,
  });

  final TextEditingController? controller;

  final FocusNode? focusNode;

  final String? hintText;

  final Widget? leading;

  final Iterable<Widget>? trailing;

  final GestureTapCallback? onTap;

  final ValueChanged<String>? onChanged;

  final ValueChanged<String>? onSubmitted;

  final BoxConstraints? constraints;

  final MaterialStateProperty<double?>? elevation;

  final MaterialStateProperty<Color?>? backgroundColor;

  final MaterialStateProperty<Color?>? shadowColor;

  final MaterialStateProperty<Color?>? surfaceTintColor;

  final MaterialStateProperty<Color?>? overlayColor;

  final MaterialStateProperty<BorderSide?>? side;

  final MaterialStateProperty<OutlinedBorder?>? shape;

  final MaterialStateProperty<EdgeInsetsGeometry?>? padding;

  final MaterialStateProperty<TextStyle?>? textStyle;

  final MaterialStateProperty<TextStyle?>? hintStyle;

  final TextCapitalization? textCapitalization;

  @override
  State<SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  late final MaterialStatesController _internalStatesController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _internalStatesController = MaterialStatesController();
    _internalStatesController.addListener(() {
      setState(() {});
    });
    _focusNode = widget.focusNode ?? FocusNode();
  }

  @override
  void dispose() {
    _internalStatesController.dispose();
    if (widget.focusNode == null) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextDirection textDirection = Directionality.of(context);
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final IconThemeData iconTheme = IconTheme.of(context);
    final SearchBarThemeData searchBarTheme = SearchBarTheme.of(context);
    final SearchBarThemeData defaults = _SearchBarDefaultsM3(context);

    T? resolve<T>(
      MaterialStateProperty<T>? widgetValue,
      MaterialStateProperty<T>? themeValue,
      MaterialStateProperty<T>? defaultValue,
    ) {
      final Set<MaterialState> states = _internalStatesController.value;
      return widgetValue?.resolve(states) ?? themeValue?.resolve(states) ?? defaultValue?.resolve(states);
    }

    final TextStyle? effectiveTextStyle = resolve<TextStyle?>(widget.textStyle, searchBarTheme.textStyle, defaults.textStyle);
    final double? effectiveElevation = resolve<double?>(widget.elevation, searchBarTheme.elevation, defaults.elevation);
    final Color? effectiveShadowColor = resolve<Color?>(widget.shadowColor, searchBarTheme.shadowColor, defaults.shadowColor);
    final Color? effectiveBackgroundColor = resolve<Color?>(widget.backgroundColor, searchBarTheme.backgroundColor, defaults.backgroundColor);
    final Color? effectiveSurfaceTintColor = resolve<Color?>(widget.surfaceTintColor, searchBarTheme.surfaceTintColor, defaults.surfaceTintColor);
    final OutlinedBorder? effectiveShape = resolve<OutlinedBorder?>(widget.shape, searchBarTheme.shape, defaults.shape);
    final BorderSide? effectiveSide = resolve<BorderSide?>(widget.side, searchBarTheme.side, defaults.side);
    final EdgeInsetsGeometry? effectivePadding = resolve<EdgeInsetsGeometry?>(widget.padding, searchBarTheme.padding, defaults.padding);
    final MaterialStateProperty<Color?>? effectiveOverlayColor = widget.overlayColor ?? searchBarTheme.overlayColor ?? defaults.overlayColor;
    final TextCapitalization effectiveTextCapitalization = widget.textCapitalization ?? searchBarTheme.textCapitalization ?? defaults.textCapitalization!;

    final Set<MaterialState> states = _internalStatesController.value;
    final TextStyle? effectiveHintStyle = widget.hintStyle?.resolve(states)
      ?? searchBarTheme.hintStyle?.resolve(states)
      ?? widget.textStyle?.resolve(states)
      ?? searchBarTheme.textStyle?.resolve(states)
      ?? defaults.hintStyle?.resolve(states);

    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    bool isIconThemeColorDefault(Color? color) {
      if (isDark) {
        return color == kDefaultIconLightColor;
      }
      return color == kDefaultIconDarkColor;
    }

    Widget? leading;
    if (widget.leading != null) {
      leading = IconTheme.merge(
        data: isIconThemeColorDefault(iconTheme.color)
          ? IconThemeData(color: colorScheme.onSurface)
          : iconTheme,
        child: widget.leading!,
      );
    }

    List<Widget>? trailing;
    if (widget.trailing != null) {
      trailing = widget.trailing?.map((Widget trailing) => IconTheme.merge(
        data: isIconThemeColorDefault(iconTheme.color)
          ? IconThemeData(color: colorScheme.onSurfaceVariant)
          : iconTheme,
        child: trailing,
      )).toList();
    }

    return ConstrainedBox(
      constraints: widget.constraints ?? searchBarTheme.constraints ?? defaults.constraints!,
      child: Material(
        elevation: effectiveElevation!,
        shadowColor: effectiveShadowColor,
        color: effectiveBackgroundColor,
        surfaceTintColor: effectiveSurfaceTintColor,
        shape: effectiveShape?.copyWith(side: effectiveSide),
        child: InkWell(
          onTap: () {
            widget.onTap?.call();
            _focusNode.requestFocus();
          },
          overlayColor: effectiveOverlayColor,
          customBorder: effectiveShape?.copyWith(side: effectiveSide),
          statesController: _internalStatesController,
          child: Padding(
            padding: effectivePadding!,
            child: Row(
              textDirection: textDirection,
              children: <Widget>[
                if (leading != null) leading,
                Expanded(
                  child: IgnorePointer(
                    child: Padding(
                      padding: effectivePadding,
                      child: TextField(
                        focusNode: _focusNode,
                        onChanged: widget.onChanged,
                        onSubmitted: widget.onSubmitted,
                        controller: widget.controller,
                        style: effectiveTextStyle,
                        decoration: InputDecoration(
                          hintText: widget.hintText,
                        ).applyDefaults(InputDecorationTheme(
                          hintStyle: effectiveHintStyle,

                          // The configuration below is to make sure that the text field
                          // in `SearchBar` will not be overridden by the overall `InputDecorationTheme`
                          enabledBorder: InputBorder.none,
                          border: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                          // Setting `isDense` to true to allow the text field height to be
                          // smaller than 48.0
                          isDense: true,
                        )),
                        textCapitalization: effectiveTextCapitalization,
                      ),
                    ),
                  )
                ),
                if (trailing != null) ...trailing,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// BEGIN GENERATED TOKEN PROPERTIES - SearchBar

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

class _SearchBarDefaultsM3 extends SearchBarThemeData {
  _SearchBarDefaultsM3(this.context);

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;
  late final TextTheme _textTheme = Theme.of(context).textTheme;

  @override
  MaterialStateProperty<Color?>? get backgroundColor =>
    MaterialStatePropertyAll<Color>(_colors.surface);

  @override
  MaterialStateProperty<double>? get elevation =>
    const MaterialStatePropertyAll<double>(6.0);

  @override
  MaterialStateProperty<Color>? get shadowColor =>
    MaterialStatePropertyAll<Color>(_colors.shadow);

  @override
  MaterialStateProperty<Color>? get surfaceTintColor =>
    MaterialStatePropertyAll<Color>(_colors.surfaceTint);

  @override
  MaterialStateProperty<Color?>? get overlayColor =>
    MaterialStateProperty.resolveWith((Set<MaterialState> states) {
      if (states.contains(MaterialState.pressed)) {
        return _colors.onSurface.withOpacity(0.12);
      }
      if (states.contains(MaterialState.hovered)) {
        return _colors.onSurface.withOpacity(0.08);
      }
      if (states.contains(MaterialState.focused)) {
        return Colors.transparent;
      }
      return Colors.transparent;
    });

  // No default side

  @override
  MaterialStateProperty<OutlinedBorder>? get shape =>
    const MaterialStatePropertyAll<OutlinedBorder>(StadiumBorder());

  @override
  MaterialStateProperty<EdgeInsetsGeometry>? get padding =>
    const MaterialStatePropertyAll<EdgeInsetsGeometry>(EdgeInsets.symmetric(horizontal: 8.0));

  @override
  MaterialStateProperty<TextStyle?> get textStyle =>
    MaterialStatePropertyAll<TextStyle?>(_textTheme.bodyLarge?.copyWith(color: _colors.onSurface));

  @override
  MaterialStateProperty<TextStyle?> get hintStyle =>
    MaterialStatePropertyAll<TextStyle?>(_textTheme.bodyLarge?.copyWith(color: _colors.onSurfaceVariant));

  @override
  BoxConstraints get constraints =>
    const BoxConstraints(minWidth: 360.0, maxWidth: 800.0, minHeight: 56.0);

  @override
  TextCapitalization get textCapitalization => TextCapitalization.none;
}

// END GENERATED TOKEN PROPERTIES - SearchBar

// BEGIN GENERATED TOKEN PROPERTIES - SearchView

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

class _SearchViewDefaultsM3 extends SearchViewThemeData {
  _SearchViewDefaultsM3(this.context, {required this.isFullScreen});

  final BuildContext context;
  final bool isFullScreen;
  late final ColorScheme _colors = Theme.of(context).colorScheme;
  late final TextTheme _textTheme = Theme.of(context).textTheme;

  static double fullScreenBarHeight = 72.0;

  @override
  Color? get backgroundColor => _colors.surface;

  @override
  double? get elevation => 6.0;

  @override
  Color? get surfaceTintColor => _colors.surfaceTint;

  // No default side

  @override
  OutlinedBorder? get shape => isFullScreen
    ? const RoundedRectangleBorder()
    : const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(28.0)));

  @override
  TextStyle? get headerTextStyle => _textTheme.bodyLarge?.copyWith(color: _colors.onSurface);

  @override
  TextStyle? get headerHintStyle => _textTheme.bodyLarge?.copyWith(color: _colors.onSurfaceVariant);

  @override
  BoxConstraints get constraints => const BoxConstraints(minWidth: 360.0, minHeight: 240.0);

  @override
  Color? get dividerColor => _colors.outline;
}

// END GENERATED TOKEN PROPERTIES - SearchView