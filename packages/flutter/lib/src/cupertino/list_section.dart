
import 'package:flutter/widgets.dart';

import 'colors.dart';
import 'theme.dart';

// Margin on top of the list section. This was eyeballed from iOS 14.4 Simulator
// and should be always present on top of the edge-to-edge variant.
const double _kMarginTop = 22.0;

// Standard header margin, determined from SwiftUI's Forms in iOS 14.2 SDK.
const EdgeInsetsDirectional _kDefaultHeaderMargin = EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 6.0);

// Header margin for inset grouped variant, determined from iOS 14.4 Simulator.
const EdgeInsetsDirectional _kInsetGroupedDefaultHeaderMargin = EdgeInsetsDirectional.fromSTEB(20.0, 16.0, 20.0, 6.0);

// Standard footer margin, determined from SwiftUI's Forms in iOS 14.2 SDK.
const EdgeInsetsDirectional _kDefaultFooterMargin = EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 0.0);

// Footer margin for inset grouped variant, determined from iOS 14.4 Simulator.
const EdgeInsetsDirectional _kInsetGroupedDefaultFooterMargin = EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 10.0);

// Margin around children in edge-to-edge variant, determined from iOS 14.4
// Simulator.
const EdgeInsets _kDefaultRowsMargin = EdgeInsets.only(bottom: 8.0);

// Used for iOS "Inset Grouped" margin, determined from SwiftUI's Forms in
// iOS 14.2 SDK.
const EdgeInsetsDirectional _kDefaultInsetGroupedRowsMargin = EdgeInsetsDirectional.fromSTEB(20.0, 20.0, 20.0, 10.0);

// Used for iOS "Inset Grouped" margin, determined from SwiftUI's Forms in
// iOS 14.2 SDK.
const EdgeInsetsDirectional _kDefaultInsetGroupedRowsMarginWithHeader = EdgeInsetsDirectional.fromSTEB(20.0, 0.0, 20.0, 10.0);

// Used for iOS "Inset Grouped" border radius, estimated from SwiftUI's Forms in
// iOS 14.2 SDK.
// TODO(edrisian): This should be a rounded rectangle once that shape is added.
const BorderRadius _kDefaultInsetGroupedBorderRadius = BorderRadius.all(Radius.circular(10.0));

// The margin of divider used in base list section. Estimated from iOS 14.4 SDK
// Settings app.
const double _kBaseDividerMargin = 20.0;

// Additional margin of divider used in base list section with list tiles with
// leading widgets. Estimated from iOS 14.4 SDK Settings app.
const double _kBaseAdditionalDividerMargin = 44.0;

// The margin of divider used in inset grouped version of list section.
// Estimated from iOS 14.4 SDK Reminders app.
const double _kInsetDividerMargin = 14.0;

// Additional margin of divider used in inset grouped version of list section.
// Estimated from iOS 14.4 SDK Reminders app.
const double _kInsetAdditionalDividerMargin = 42.0;

// Additional margin of divider used in inset grouped version of list section
// when there is no leading widgets. Estimated from iOS 14.4 SDK Notes app.
const double _kInsetAdditionalDividerMarginWithoutLeading = 14.0;

// Color of header and footer text in edge-to-edge variant.
const Color _kHeaderFooterColor = CupertinoDynamicColor(
  color: Color.fromRGBO(108, 108, 108, 1.0),
  darkColor: Color.fromRGBO(142, 142, 146, 1.0),
  highContrastColor: Color.fromRGBO(74, 74, 77, 1.0),
  darkHighContrastColor: Color.fromRGBO(176, 176, 183, 1.0),
  elevatedColor: Color.fromRGBO(108, 108, 108, 1.0),
  darkElevatedColor: Color.fromRGBO(142, 142, 146, 1.0),
  highContrastElevatedColor: Color.fromRGBO(108, 108, 108, 1.0),
  darkHighContrastElevatedColor: Color.fromRGBO(142, 142, 146, 1.0),
);

enum CupertinoListSectionType {
  base,

  insetGrouped,
}

class CupertinoListSection extends StatelessWidget {
  const CupertinoListSection({
    super.key,
    this.children,
    this.header,
    this.footer,
    this.margin = _kDefaultRowsMargin,
    this.backgroundColor = CupertinoColors.systemGroupedBackground,
    this.decoration,
    this.clipBehavior = Clip.none,
    this.dividerMargin = _kBaseDividerMargin,
    double? additionalDividerMargin,
    this.topMargin = _kMarginTop,
    bool hasLeading = true,
    this.separatorColor,
  }) : assert((children != null && children.length > 0) || header != null),
       type = CupertinoListSectionType.base,
       additionalDividerMargin = additionalDividerMargin ??
           (hasLeading ? _kBaseAdditionalDividerMargin : 0.0);

  const CupertinoListSection.insetGrouped({
    super.key,
    this.children,
    this.header,
    this.footer,
    EdgeInsetsGeometry? margin,
    this.backgroundColor = CupertinoColors.systemGroupedBackground,
    this.decoration,
    this.clipBehavior = Clip.hardEdge,
    this.dividerMargin = _kInsetDividerMargin,
    double? additionalDividerMargin,
    this.topMargin,
    bool hasLeading = true,
    this.separatorColor,
  }) : assert((children != null && children.length > 0) || header != null),
       type = CupertinoListSectionType.insetGrouped,
       additionalDividerMargin = additionalDividerMargin ??
           (hasLeading
               ? _kInsetAdditionalDividerMargin
               : _kInsetAdditionalDividerMarginWithoutLeading),
       margin = margin ?? (header == null ? _kDefaultInsetGroupedRowsMargin : _kDefaultInsetGroupedRowsMarginWithHeader);

  @visibleForTesting
  final CupertinoListSectionType type;

  final Widget? header;

  final Widget? footer;

  final EdgeInsetsGeometry margin;

  final List<Widget>? children;

  final BoxDecoration? decoration;

  final Color backgroundColor;

  final Clip clipBehavior;

  final double dividerMargin;

  final double additionalDividerMargin;

  final double? topMargin;

  final Color? separatorColor;

  @override
  Widget build(BuildContext context) {
    final Color dividerColor = separatorColor ?? CupertinoColors.separator.resolveFrom(context);
    final double dividerHeight = 1.0 / MediaQuery.devicePixelRatioOf(context);

    // Long divider is used for wrapping the top and bottom of rows.
    // Only used in CupertinoListSectionType.base mode.
    final Widget longDivider = Container(
      color: dividerColor,
      height: dividerHeight,
    );

    // Short divider is used between rows.
    final Widget shortDivider = Container(
      margin: EdgeInsetsDirectional.only(
          start: dividerMargin + additionalDividerMargin),
      color: dividerColor,
      height: dividerHeight,
    );

    Widget? headerWidget;
    if (header != null) {
      headerWidget = DefaultTextStyle(
        style: CupertinoTheme.of(context).textTheme.textStyle.merge(
              type == CupertinoListSectionType.base
                  ? TextStyle(
                      fontSize: 13.0,
                      color: CupertinoDynamicColor.resolve(
                          _kHeaderFooterColor, context))
                  : const TextStyle(
                      fontSize: 20.0, fontWeight: FontWeight.bold),
            ),
        child: header!,
      );
    }

    Widget? footerWidget;
    if (footer != null) {
      footerWidget = DefaultTextStyle(
        style: type == CupertinoListSectionType.base
            ? CupertinoTheme.of(context).textTheme.textStyle.merge(TextStyle(
                  fontSize: 13.0,
                  color: CupertinoDynamicColor.resolve(
                      _kHeaderFooterColor, context),
                ))
            : CupertinoTheme.of(context).textTheme.textStyle,
        child: footer!,
      );
    }

    Widget? decoratedChildrenGroup;
    if (children != null && children!.isNotEmpty) {
      // We construct childrenWithDividers as follows:
      // Insert a short divider between all rows.
      // If it is a `CupertinoListSectionType.base` type, add a long divider
      // to the top and bottom of the rows.
      final List<Widget> childrenWithDividers = <Widget>[];

      if (type == CupertinoListSectionType.base) {
        childrenWithDividers.add(longDivider);
      }

      children!.sublist(0, children!.length - 1).forEach((Widget widget) {
        childrenWithDividers.add(widget);
        childrenWithDividers.add(shortDivider);
      });

      childrenWithDividers.add(children!.last);
      if (type == CupertinoListSectionType.base) {
        childrenWithDividers.add(longDivider);
      }

      final BorderRadius childrenGroupBorderRadius = switch (type) {
        CupertinoListSectionType.insetGrouped => _kDefaultInsetGroupedBorderRadius,
        CupertinoListSectionType.base => BorderRadius.zero,
      };

      decoratedChildrenGroup = DecoratedBox(
        decoration: decoration ??
            BoxDecoration(
              color: CupertinoDynamicColor.resolve(
                  decoration?.color ??
                      CupertinoColors.secondarySystemGroupedBackground,
                  context),
              borderRadius: childrenGroupBorderRadius,
            ),
        child: Column(children: childrenWithDividers),
      );

      decoratedChildrenGroup = Padding(
        padding: margin,
        child: clipBehavior == Clip.none
            ? decoratedChildrenGroup
            : ClipRRect(
                borderRadius: childrenGroupBorderRadius,
                clipBehavior: clipBehavior,
                child: decoratedChildrenGroup,
              ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
          color: CupertinoDynamicColor.resolve(backgroundColor, context)),
      child: Column(
        children: <Widget>[
          if (type == CupertinoListSectionType.base)
            SizedBox(height: topMargin),
          if (headerWidget != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: type == CupertinoListSectionType.base
                    ? _kDefaultHeaderMargin
                    : _kInsetGroupedDefaultHeaderMargin,
                child: headerWidget,
              ),
            ),
          if (decoratedChildrenGroup != null)
            decoratedChildrenGroup,
          if (footerWidget != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: type == CupertinoListSectionType.base
                    ? _kDefaultFooterMargin
                    : _kInsetGroupedDefaultFooterMargin,
                child: footerWidget,
              ),
            ),
        ],
      ),
    );
  }
}