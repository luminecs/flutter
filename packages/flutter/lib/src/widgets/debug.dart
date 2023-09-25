import 'dart:collection';
import 'dart:developer' show Timeline; // to disambiguate reference in dartdocs below

import 'package:flutter/foundation.dart';

import 'basic.dart';
import 'framework.dart';
import 'localizations.dart';
import 'lookup_boundary.dart';
import 'media_query.dart';
import 'overlay.dart';
import 'table.dart';

// Examples can assume:
// late BuildContext context;
// List<Widget> children = <Widget>[];
// List<Widget> items = <Widget>[];

// Any changes to this file should be reflected in the debugAssertAllWidgetVarsUnset()
// function below.

bool debugPrintRebuildDirtyWidgets = false;

typedef RebuildDirtyWidgetCallback = void Function(Element e, bool builtOnce);

RebuildDirtyWidgetCallback? debugOnRebuildDirtyWidget;

bool debugPrintBuildScope = false;

bool debugPrintScheduleBuildForStacks = false;

bool debugPrintGlobalKeyedWidgetLifecycle = false;

bool debugProfileBuildsEnabled = false;

bool debugProfileBuildsEnabledUserWidgets = false;

bool debugEnhanceBuildTimelineArguments = false;

bool debugHighlightDeprecatedWidgets = false;

Key? _firstNonUniqueKey(Iterable<Widget> widgets) {
  final Set<Key> keySet = HashSet<Key>();
  for (final Widget widget in widgets) {
    if (widget.key == null) {
      continue;
    }
    if (!keySet.add(widget.key!)) {
      return widget.key;
    }
  }
  return null;
}

bool debugChildrenHaveDuplicateKeys(Widget parent, Iterable<Widget> children, { String? message }) {
  assert(() {
    final Key? nonUniqueKey = _firstNonUniqueKey(children);
    if (nonUniqueKey != null) {
      throw FlutterError(
        "${message ?? 'Duplicate keys found.\n'
                      'If multiple keyed widgets exist as children of another widget, they must have unique keys.'}"
        '\n$parent has multiple children with key $nonUniqueKey.',
      );
    }
    return true;
  }());
  return false;
}

bool debugItemsHaveDuplicateKeys(Iterable<Widget> items) {
  assert(() {
    final Key? nonUniqueKey = _firstNonUniqueKey(items);
    if (nonUniqueKey != null) {
      throw FlutterError('Duplicate key found: $nonUniqueKey.');
    }
    return true;
  }());
  return false;
}

bool debugCheckHasTable(BuildContext context) {
  assert(() {
    if (context.widget is! Table && context.findAncestorWidgetOfExactType<Table>() == null) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('No Table widget found.'),
        ErrorDescription('${context.widget.runtimeType} widgets require a Table widget ancestor.'),
        context.describeWidget('The specific widget that could not find a Table ancestor was'),
        context.describeOwnershipChain('The ownership chain for the affected widget is'),
      ]);
    }
    return true;
  }());
  return true;
}

bool debugCheckHasMediaQuery(BuildContext context) {
  assert(() {
    if (context.widget is! MediaQuery && context.getElementForInheritedWidgetOfExactType<MediaQuery>() == null) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('No MediaQuery widget ancestor found.'),
        ErrorDescription('${context.widget.runtimeType} widgets require a MediaQuery widget ancestor.'),
        context.describeWidget('The specific widget that could not find a MediaQuery ancestor was'),
        context.describeOwnershipChain('The ownership chain for the affected widget is'),
        ErrorHint(
          'No MediaQuery ancestor could be found starting from the context '
          'that was passed to MediaQuery.of(). This can happen because the '
          'context used is not a descendant of a View widget, which introduces '
          'a MediaQuery.'
        ),
      ]);
    }
    return true;
  }());
  return true;
}

bool debugCheckHasDirectionality(BuildContext context, { String? why, String? hint, String? alternative }) {
  assert(() {
    if (context.widget is! Directionality && context.getElementForInheritedWidgetOfExactType<Directionality>() == null) {
      why = why == null ? '' : ' $why';
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('No Directionality widget found.'),
        ErrorDescription('${context.widget.runtimeType} widgets require a Directionality widget ancestor$why.\n'),
        if (hint != null)
          ErrorHint(hint),
        context.describeWidget('The specific widget that could not find a Directionality ancestor was'),
        context.describeOwnershipChain('The ownership chain for the affected widget is'),
        ErrorHint(
          'Typically, the Directionality widget is introduced by the MaterialApp '
          'or WidgetsApp widget at the top of your application widget tree. It '
          'determines the ambient reading direction and is used, for example, to '
          'determine how to lay out text, how to interpret "start" and "end" '
          'values, and to resolve EdgeInsetsDirectional, '
          'AlignmentDirectional, and other *Directional objects.',
        ),
        if (alternative != null)
          ErrorHint(alternative),
      ]);
    }
    return true;
  }());
  return true;
}

void debugWidgetBuilderValue(Widget widget, Widget? built) {
  assert(() {
    if (built == null) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('A build function returned null.'),
        DiagnosticsProperty<Widget>('The offending widget is', widget, style: DiagnosticsTreeStyle.errorProperty),
        ErrorDescription('Build functions must never return null.'),
        ErrorHint(
          'To return an empty space that causes the building widget to fill available room, return "Container()". '
          'To return an empty space that takes as little room as possible, return "Container(width: 0.0, height: 0.0)".',
        ),
      ]);
    }
    if (widget == built) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('A build function returned context.widget.'),
        DiagnosticsProperty<Widget>('The offending widget is', widget, style: DiagnosticsTreeStyle.errorProperty),
        ErrorDescription(
          'Build functions must never return their BuildContext parameter\'s widget or a child that contains "context.widget". '
          'Doing so introduces a loop in the widget tree that can cause the app to crash.',
        ),
      ]);
    }
    return true;
  }());
}

bool debugCheckHasWidgetsLocalizations(BuildContext context) {
  assert(() {
    if (Localizations.of<WidgetsLocalizations>(context, WidgetsLocalizations) == null) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('No WidgetsLocalizations found.'),
        ErrorDescription(
          '${context.widget.runtimeType} widgets require WidgetsLocalizations '
          'to be provided by a Localizations widget ancestor.',
        ),
        ErrorDescription(
          'The widgets library uses Localizations to generate messages, '
          'labels, and abbreviations.',
        ),
        ErrorHint(
          'To introduce a WidgetsLocalizations, either use a '
          'WidgetsApp at the root of your application to include them '
          'automatically, or add a Localization widget with a '
          'WidgetsLocalizations delegate.',
        ),
        ...context.describeMissingAncestor(expectedAncestorType: WidgetsLocalizations),
      ]);
    }
    return true;
  }());
  return true;
}

bool debugCheckHasOverlay(BuildContext context) {
  assert(() {
    if (LookupBoundary.findAncestorWidgetOfExactType<Overlay>(context) == null) {
      final bool hiddenByBoundary = LookupBoundary.debugIsHidingAncestorWidgetOfExactType<Overlay>(context);
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('No Overlay widget found${hiddenByBoundary ? ' within the closest LookupBoundary' : ''}.'),
        if (hiddenByBoundary)
          ErrorDescription(
              'There is an ancestor Overlay widget, but it is hidden by a LookupBoundary.'
          ),
        ErrorDescription(
          '${context.widget.runtimeType} widgets require an Overlay '
          'widget ancestor within the closest LookupBoundary.\n'
          'An overlay lets widgets float on top of other widget children.',
        ),
        ErrorHint(
          'To introduce an Overlay widget, you can either directly '
          'include one, or use a widget that contains an Overlay itself, '
          'such as a Navigator, WidgetApp, MaterialApp, or CupertinoApp.',
        ),
        ...context.describeMissingAncestor(expectedAncestorType: Overlay),
      ]);
    }
    return true;
  }());
  return true;
}

bool debugAssertAllWidgetVarsUnset(String reason) {
  assert(() {
    if (debugPrintRebuildDirtyWidgets ||
        debugPrintBuildScope ||
        debugPrintScheduleBuildForStacks ||
        debugPrintGlobalKeyedWidgetLifecycle ||
        debugProfileBuildsEnabled ||
        debugHighlightDeprecatedWidgets ||
        debugProfileBuildsEnabledUserWidgets) {
      throw FlutterError(reason);
    }
    return true;
  }());
  return true;
}