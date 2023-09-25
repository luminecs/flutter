import 'dart:ui';

import 'package:flutter/material.dart' show Tooltip;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import 'binding.dart';
import 'tree_traversal.dart';

typedef WidgetPredicate = bool Function(Widget widget);

typedef ElementPredicate = bool Function(Element element);

typedef SemanticsNodePredicate = bool Function(SemanticsNode node);

typedef DescribeMatchCallback = String Function(Plurality plurality);

const CommonFinders find = CommonFinders._();

// Examples can assume:
// typedef Button = Placeholder;
// late WidgetTester tester;
// late String filePath;
// late Key backKey;

class CommonFinders {
  const CommonFinders._();

  CommonSemanticsFinders get semantics => const CommonSemanticsFinders._();

  Finder text(
    String text, {
    bool findRichText = false,
    bool skipOffstage = true,
  }) {
    return _TextWidgetFinder(
      text,
      findRichText: findRichText,
      skipOffstage: skipOffstage,
    );
  }

  Finder textContaining(
    Pattern pattern, {
    bool findRichText = false,
    bool skipOffstage = true,
  }) {
    return _TextContainingWidgetFinder(
      pattern,
      findRichText: findRichText,
      skipOffstage: skipOffstage
    );
  }

  Finder widgetWithText(Type widgetType, String text, { bool skipOffstage = true }) {
    return find.ancestor(
      of: find.text(text, skipOffstage: skipOffstage),
      matching: find.byType(widgetType, skipOffstage: skipOffstage),
    );
  }

  Finder image(ImageProvider image, { bool skipOffstage = true }) => _ImageWidgetFinder(image, skipOffstage: skipOffstage);

  Finder byKey(Key key, { bool skipOffstage = true }) => _KeyWidgetFinder(key, skipOffstage: skipOffstage);

  Finder bySubtype<T extends Widget>({ bool skipOffstage = true }) => _SubtypeWidgetFinder<T>(skipOffstage: skipOffstage);

  Finder byType(Type type, { bool skipOffstage = true }) => _TypeWidgetFinder(type, skipOffstage: skipOffstage);

  Finder byIcon(IconData icon, { bool skipOffstage = true }) => _IconWidgetFinder(icon, skipOffstage: skipOffstage);

  Finder widgetWithIcon(Type widgetType, IconData icon, { bool skipOffstage = true }) {
    return find.ancestor(
      of: find.byIcon(icon),
      matching: find.byType(widgetType),
    );
  }

  Finder widgetWithImage(Type widgetType, ImageProvider image, { bool skipOffstage = true }) {
    return find.ancestor(
      of: find.image(image),
      matching: find.byType(widgetType),
    );
  }

  Finder byElementType(Type type, { bool skipOffstage = true }) => _ElementTypeWidgetFinder(type, skipOffstage: skipOffstage);

  Finder byWidget(Widget widget, { bool skipOffstage = true }) => _ExactWidgetFinder(widget, skipOffstage: skipOffstage);

  Finder byWidgetPredicate(WidgetPredicate predicate, { String? description, bool skipOffstage = true }) {
    return _WidgetPredicateWidgetFinder(predicate, description: description, skipOffstage: skipOffstage);
  }

  Finder byTooltip(String message, { bool skipOffstage = true }) {
    return byWidgetPredicate(
      (Widget widget) => widget is Tooltip && widget.message == message,
      skipOffstage: skipOffstage,
    );
  }

  Finder byElementPredicate(ElementPredicate predicate, { String? description, bool skipOffstage = true }) {
    return _ElementPredicateWidgetFinder(predicate, description: description, skipOffstage: skipOffstage);
  }

  Finder descendant({
    required FinderBase<Element> of,
    required FinderBase<Element> matching,
    bool matchRoot = false,
    bool skipOffstage = true,
  }) {
    return _DescendantWidgetFinder(of, matching, matchRoot: matchRoot, skipOffstage: skipOffstage);
  }

  Finder ancestor({
    required FinderBase<Element> of,
    required FinderBase<Element> matching,
    bool matchRoot = false,
  }) {
    return _AncestorWidgetFinder(of, matching, matchLeaves: matchRoot);
  }

  Finder bySemanticsLabel(Pattern label, { bool skipOffstage = true }) {
    if (!SemanticsBinding.instance.semanticsEnabled) {
      throw StateError('Semantics are not enabled. '
                       'Make sure to call tester.ensureSemantics() before using '
                       'this finder, and call dispose on its return value after.');
    }
    return byElementPredicate(
      (Element element) {
        // Multiple elements can have the same renderObject - we want the "owner"
        // of the renderObject, i.e. the RenderObjectElement.
        if (element is! RenderObjectElement) {
          return false;
        }
        final String? semanticsLabel = element.renderObject.debugSemantics?.label;
        if (semanticsLabel == null) {
          return false;
        }
        return label is RegExp
            ? label.hasMatch(semanticsLabel)
            : label == semanticsLabel;
      },
      skipOffstage: skipOffstage,
    );
  }
}


class CommonSemanticsFinders {
  const CommonSemanticsFinders._();

  FinderBase<SemanticsNode> ancestor({
    required FinderBase<SemanticsNode> of,
    required FinderBase<SemanticsNode> matching,
    bool matchRoot = false,
  }) {
    return _AncestorSemanticsFinder(of, matching, matchRoot);
  }

  FinderBase<SemanticsNode> descendant({
    required FinderBase<SemanticsNode> of,
    required FinderBase<SemanticsNode> matching,
    bool matchRoot = false,
  }) {
    return _DescendantSemanticsFinder(of, matching, matchRoot: matchRoot);
  }

  SemanticsFinder byPredicate(
    SemanticsNodePredicate predicate, {
    DescribeMatchCallback? describeMatch,
    FlutterView? view,
  }) {
    return _PredicateSemanticsFinder(
      predicate,
      describeMatch,
      _rootFromView(view),
    );
  }

  SemanticsFinder byLabel(Pattern label, {FlutterView? view}) {
    return byPredicate(
      (SemanticsNode node) => _matchesPattern(node.label, label),
      describeMatch: (Plurality plurality) => '${switch (plurality) {
        Plurality.one => 'SemanticsNode',
        Plurality.zero || Plurality.many => 'SemanticsNodes',
      }} with label "$label"',
      view: view,
    );
  }

  SemanticsFinder byValue(Pattern value, {FlutterView? view}) {
    return byPredicate(
      (SemanticsNode node) => _matchesPattern(node.value, value),
      describeMatch: (Plurality plurality) => '${switch (plurality) {
        Plurality.one => 'SemanticsNode',
        Plurality.zero || Plurality.many => 'SemanticsNodes',
      }} with value "$value"',
      view: view,
    );
  }

  SemanticsFinder byHint(Pattern hint, {FlutterView? view}) {
    return byPredicate(
      (SemanticsNode node) => _matchesPattern(node.hint, hint),
      describeMatch: (Plurality plurality) => '${switch (plurality) {
        Plurality.one => 'SemanticsNode',
        Plurality.zero || Plurality.many => 'SemanticsNodes',
      }} with hint "$hint"',
      view: view,
    );
  }

  SemanticsFinder byAction(SemanticsAction action, {FlutterView? view}) {
    return byPredicate(
      (SemanticsNode node) => node.getSemanticsData().hasAction(action),
      describeMatch: (Plurality plurality) => '${switch (plurality) {
        Plurality.one => 'SemanticsNode',
        Plurality.zero || Plurality.many => 'SemanticsNodes',
      }} with action "$action"',
      view: view,
    );
  }

  SemanticsFinder byAnyAction(List<SemanticsAction> actions, {FlutterView? view}) {
    final int actionsInt = actions.fold(0, (int value, SemanticsAction action) => value | action.index);
    return byPredicate(
      (SemanticsNode node) => node.getSemanticsData().actions & actionsInt != 0,
      describeMatch: (Plurality plurality) => '${switch (plurality) {
        Plurality.one => 'SemanticsNode',
        Plurality.zero || Plurality.many => 'SemanticsNodes',
      }} with any of the following actions: $actions',
      view: view,
    );
  }

  SemanticsFinder byFlag(SemanticsFlag flag, {FlutterView? view}) {
    return byPredicate(
      (SemanticsNode node) => node.hasFlag(flag),
      describeMatch: (Plurality plurality) => '${switch (plurality) {
        Plurality.one => 'SemanticsNode',
        Plurality.zero || Plurality.many => 'SemanticsNodes',
      }} with flag "$flag"',
      view: view,
    );
  }

  SemanticsFinder byAnyFlag(List<SemanticsFlag> flags, {FlutterView? view}) {
    final int flagsInt = flags.fold(0, (int value, SemanticsFlag flag) => value | flag.index);
    return byPredicate(
      (SemanticsNode node) => node.getSemanticsData().flags & flagsInt != 0,
      describeMatch: (Plurality plurality) => '${switch (plurality) {
        Plurality.one => 'SemanticsNode',
        Plurality.zero || Plurality.many => 'SemanticsNodes',
      }} with any of the following flags: $flags',
      view: view,
    );
  }

  bool _matchesPattern(String target, Pattern pattern) {
    if (pattern is RegExp) {
      return pattern.hasMatch(target);
    } else {
      return pattern == target;
    }
  }

  SemanticsNode _rootFromView(FlutterView? view) {
    view ??= TestWidgetsFlutterBinding.instance.platformDispatcher.implicitView;
    assert(view != null, 'The given view was not available. Ensure WidgetTester.view is available or pass in a specific view using WidgetTester.viewOf.');
    final RenderView renderView = TestWidgetsFlutterBinding.instance.renderViews
      .firstWhere((RenderView r) => r.flutterView == view);

    return renderView.owner!.semanticsOwner!.rootSemanticsNode!;
  }
}

enum Plurality {
  zero,
  one,
  many;

  static Plurality _fromNum(num source) {
    assert(source >= 0, 'A Plurality can only be created with a positive number.');
    return switch (source) {
      0 => Plurality.zero,
      1 => Plurality.one,
      _ => Plurality.many,
    };
  }
}

abstract class FinderBase<CandidateType> {
  bool _cached = false;

  FinderResult<CandidateType> get found {
    assert(
      _found != null,
      'No results have been found yet. '
      'Either `evaluate` or `tryEvaluate` must be called before accessing `found`',
    );
    return _found!;
  }
  FinderResult<CandidateType>? _found;

  bool get hasFound => _found != null;

  String describeMatch(Plurality plurality);

  @protected
  Iterable<CandidateType> get allCandidates;

  FinderBase<CandidateType> get first => _FirstFinder<CandidateType>(this);

  FinderBase<CandidateType> get last => _LastFinder<CandidateType>(this);

  FinderBase<CandidateType> at(int index) => _IndexFinder<CandidateType>(this, index);

  @protected
  Iterable<CandidateType> findInCandidates(Iterable<CandidateType> candidates);

  FinderResult<CandidateType> evaluate() {
    if (!_cached || _found == null) {
      _found = FinderResult<CandidateType>(describeMatch, findInCandidates(allCandidates));
    }
    return found;
  }

  bool tryEvaluate() {
    evaluate();
    return found.isNotEmpty;
  }

  void runCached(VoidCallback run) {
    reset();
    _cached = true;
    try {
      run();
    } finally {
      reset();
      _cached = false;
    }
  }

  void reset() {
    _found = null;
  }

  @override
  String toString({bool describeSelf = false}) {
    if (describeSelf) {
      return 'A finder that searches for ${describeMatch(Plurality.many)}.';
    } else {
      if (!hasFound) {
        evaluate();
      }
      return found.toString();
    }
  }
}

class FinderResult<CandidateType> extends Iterable<CandidateType> {
  FinderResult(DescribeMatchCallback describeMatch, Iterable<CandidateType> values)
    : _describeMatch = describeMatch, _values = values;

  final DescribeMatchCallback _describeMatch;
  final Iterable<CandidateType> _values;

  @override
  Iterator<CandidateType> get iterator => _values.iterator;

  @override
  String toString() {
    final List<CandidateType> valuesList = _values.toList();
    // This will put each value on its own line with a comma and indentation
    final String valuesString = valuesList.fold(
      '',
      (String current, CandidateType candidate) => '$current\n  $candidate,',
    );
    return 'Found ${valuesList.length} ${_describeMatch(Plurality._fromNum(valuesList.length))}: ['
      '${valuesString.isNotEmpty ? '$valuesString\n' : ''}'
      ']';
  }
}

mixin _LegacyFinderMixin on FinderBase<Element> {
  Iterable<Element>? _precacheResults;

  @Deprecated(
    'Use FinderBase.describeMatch instead. '
    'FinderBase.describeMatch allows for more readable descriptions and removes ambiguity about pluralization. '
    'This feature was deprecated after v3.13.0-0.2.pre.'
  )
  String get description;

  @Deprecated(
    'Override FinderBase.findInCandidates instead. '
    'Using the FinderBase API allows for more consistent caching behavior and cleaner options for interacting with the widget tree. '
    'This feature was deprecated after v3.13.0-0.2.pre.'
  )
  Iterable<Element> apply(Iterable<Element> candidates) {
    return findInCandidates(candidates);
  }

  @Deprecated(
    'Use FinderBase.tryFind or FinderBase.runCached instead. '
    'Using the FinderBase API allows for more consistent caching behavior and cleaner options for interacting with the widget tree. '
    'This feature was deprecated after v3.13.0-0.2.pre.'
  )
  bool precache() {
    assert(_precacheResults == null);
    if (tryEvaluate()) {
      return true;
    }
    _precacheResults = null;
    return false;
  }

  @override
  Iterable<Element> findInCandidates(Iterable<Element> candidates) {
    return apply(candidates);
  }
}

abstract class Finder extends FinderBase<Element> with _LegacyFinderMixin {
  Finder({this.skipOffstage = true});

  final bool skipOffstage;

  @override
  Finder get first => _FirstWidgetFinder(this);

  @override
  Finder get last => _LastWidgetFinder(this);

  @override
  Finder at(int index) => _IndexWidgetFinder(this, index);

  @override
  Iterable<Element> get allCandidates {
    return collectAllElementsFrom(
      WidgetsBinding.instance.rootElement!,
      skipOffstage: skipOffstage,
    );
  }

  @override
  String describeMatch(Plurality plurality) {
    return switch (plurality) {
      Plurality.zero ||Plurality.many => 'widgets with $description',
      Plurality.one => 'widget with $description',
    };
  }

  Finder hitTestable({ Alignment at = Alignment.center }) => _HitTestableWidgetFinder(this, at);
}

abstract class SemanticsFinder extends FinderBase<SemanticsNode> {
  SemanticsFinder(this.root);

  final SemanticsNode root;

  @override
  Iterable<SemanticsNode> get allCandidates {
    return collectAllSemanticsNodesFrom(root);
  }
}

 mixin ChainedFinderMixin<CandidateType> on FinderBase<CandidateType> {

  FinderBase<CandidateType> get parent;

  Iterable<CandidateType> filter(Iterable<CandidateType> parentCandidates);

  @override
  Iterable<CandidateType> findInCandidates(Iterable<CandidateType> candidates) {
    return filter(parent.findInCandidates(candidates));
  }

  @override
  Iterable<CandidateType> get allCandidates => parent.allCandidates;
}

abstract class ChainedFinder extends Finder with ChainedFinderMixin<Element> {
  ChainedFinder(this.parent);

  @override
  final FinderBase<Element> parent;
}

mixin _FirstFinderMixin<CandidateType> on ChainedFinderMixin<CandidateType>{
  @override
  String describeMatch(Plurality plurality) {
    return '${parent.describeMatch(plurality)} (ignoring all but first)';
  }

  @override
  Iterable<CandidateType> filter(Iterable<CandidateType> parentCandidates) sync* {
    yield parentCandidates.first;
  }
}

class _FirstFinder<CandidateType> extends FinderBase<CandidateType>
  with ChainedFinderMixin<CandidateType>, _FirstFinderMixin<CandidateType> {
  _FirstFinder(this.parent);

  @override
  final FinderBase<CandidateType> parent;
}

class _FirstWidgetFinder extends ChainedFinder with _FirstFinderMixin<Element> {
  _FirstWidgetFinder(super.parent);

  @override
  String get description => describeMatch(Plurality.many);
}

mixin _LastFinderMixin<CandidateType> on ChainedFinderMixin<CandidateType> {
  @override
  String describeMatch(Plurality plurality) {
    return '${parent.describeMatch(plurality)} (ignoring all but first)';
  }

  @override
  Iterable<CandidateType> filter(Iterable<CandidateType> parentCandidates) sync* {
    yield parentCandidates.last;
  }
}

class _LastFinder<CandidateType> extends FinderBase<CandidateType>
  with ChainedFinderMixin<CandidateType>, _LastFinderMixin<CandidateType>{
  _LastFinder(this.parent);

  @override
  final FinderBase<CandidateType> parent;
}

class _LastWidgetFinder extends ChainedFinder with _LastFinderMixin<Element> {
  _LastWidgetFinder(super.parent);

  @override
  String get description => describeMatch(Plurality.many);
}

mixin _IndexFinderMixin<CandidateType> on ChainedFinderMixin<CandidateType> {
  int get index;

  @override
  String describeMatch(Plurality plurality) {
    return '${parent.describeMatch(plurality)} (ignoring all but index $index)';
  }

  @override
  Iterable<CandidateType> filter(Iterable<CandidateType> parentCandidates) sync* {
    yield parentCandidates.elementAt(index);
  }
}

class _IndexFinder<CandidateType> extends FinderBase<CandidateType>
    with ChainedFinderMixin<CandidateType>, _IndexFinderMixin<CandidateType> {
  _IndexFinder(this.parent, this.index);

  @override
  final int index;

  @override
  final FinderBase<CandidateType> parent;
}

class _IndexWidgetFinder extends ChainedFinder with _IndexFinderMixin<Element> {
  _IndexWidgetFinder(super.parent, this.index);

  @override
  final int index;

  @override
  String get description => describeMatch(Plurality.many);
}

class _HitTestableWidgetFinder extends ChainedFinder {
  _HitTestableWidgetFinder(super.parent, this.alignment);

  final Alignment alignment;

  @override
  String describeMatch(Plurality plurality) {
    return '${parent.describeMatch(plurality)} (considering only hit-testable ones)';
  }

  @override
  String get description => describeMatch(Plurality.many);

  @override
  Iterable<Element> filter(Iterable<Element> parentCandidates) sync* {
    for (final Element candidate in parentCandidates) {
      final int viewId = candidate.findAncestorWidgetOfExactType<View>()!.view.viewId;
      final RenderBox box = candidate.renderObject! as RenderBox;
      final Offset absoluteOffset = box.localToGlobal(alignment.alongSize(box.size));
      final HitTestResult hitResult = HitTestResult();
      WidgetsBinding.instance.hitTestInView(hitResult, absoluteOffset, viewId);
      for (final HitTestEntry entry in hitResult.path) {
        if (entry.target == candidate.renderObject) {
          yield candidate;
          break;
        }
      }
    }
  }
}

mixin MatchFinderMixin<CandidateType> on FinderBase<CandidateType> {
  bool matches(CandidateType candidate);

  @override
  Iterable<CandidateType> findInCandidates(Iterable<CandidateType> candidates) {
    return candidates.where(matches);
  }
}

abstract class MatchFinder extends Finder with MatchFinderMixin<Element> {
  MatchFinder({ super.skipOffstage });
}

abstract class _MatchTextFinder extends MatchFinder {
  _MatchTextFinder({
    this.findRichText = false,
    super.skipOffstage,
  });

  final bool findRichText;

  bool matchesText(String textToMatch);

  @override
  bool matches(Element candidate) {
    final Widget widget = candidate.widget;
    if (widget is EditableText) {
      return _matchesEditableText(widget);
    }

    if (!findRichText) {
      return _matchesNonRichText(widget);
    }
    // It would be sufficient to always use _matchesRichText if we wanted to
    // match both standalone RichText widgets as well as Text widgets. However,
    // the find.text() finder used to always ignore standalone RichText widgets,
    // which is why we need the _matchesNonRichText method in order to not be
    // backwards-compatible and not break existing tests.
    return _matchesRichText(widget);
  }

  bool _matchesRichText(Widget widget) {
    if (widget is RichText) {
      return matchesText(widget.text.toPlainText());
    }
    return false;
  }

  bool _matchesNonRichText(Widget widget) {
    if (widget is Text) {
      if (widget.data != null) {
        return matchesText(widget.data!);
      }
      assert(widget.textSpan != null);
      return matchesText(widget.textSpan!.toPlainText());
    }
    return false;
  }

  bool _matchesEditableText(EditableText widget) {
    return matchesText(widget.controller.text);
  }
}

class _TextWidgetFinder extends _MatchTextFinder {
  _TextWidgetFinder(
    this.text, {
    super.findRichText,
    super.skipOffstage,
  });

  final String text;

  @override
  String get description => 'text "$text"';

  @override
  bool matchesText(String textToMatch) {
    return textToMatch == text;
  }
}

class _TextContainingWidgetFinder extends _MatchTextFinder {
  _TextContainingWidgetFinder(
    this.pattern, {
    super.findRichText,
    super.skipOffstage,
  });

  final Pattern pattern;

  @override
  String get description => 'text containing $pattern';

  @override
  bool matchesText(String textToMatch) {
    return textToMatch.contains(pattern);
  }
}

class _KeyWidgetFinder extends MatchFinder {
  _KeyWidgetFinder(this.key, { super.skipOffstage });

  final Key key;

  @override
  String get description => 'key $key';

  @override
  bool matches(Element candidate) {
    return candidate.widget.key == key;
  }
}

class _SubtypeWidgetFinder<T extends Widget> extends MatchFinder {
  _SubtypeWidgetFinder({ super.skipOffstage });

  @override
  String get description => 'is "$T"';

  @override
  bool matches(Element candidate) {
    return candidate.widget is T;
  }
}

class _TypeWidgetFinder extends MatchFinder {
  _TypeWidgetFinder(this.widgetType, { super.skipOffstage });

  final Type widgetType;

  @override
  String get description => 'type "$widgetType"';

  @override
  bool matches(Element candidate) {
    return candidate.widget.runtimeType == widgetType;
  }
}

class _ImageWidgetFinder extends MatchFinder {
  _ImageWidgetFinder(this.image, { super.skipOffstage });

  final ImageProvider image;

  @override
  String get description => 'image "$image"';

  @override
  bool matches(Element candidate) {
    final Widget widget = candidate.widget;
    if (widget is Image) {
      return widget.image == image;
    } else if (widget is FadeInImage) {
      return widget.image == image;
    }
    return false;
  }
}

class _IconWidgetFinder extends MatchFinder {
  _IconWidgetFinder(this.icon, { super.skipOffstage });

  final IconData icon;

  @override
  String get description => 'icon "$icon"';

  @override
  bool matches(Element candidate) {
    final Widget widget = candidate.widget;
    return widget is Icon && widget.icon == icon;
  }
}

class _ElementTypeWidgetFinder extends MatchFinder {
  _ElementTypeWidgetFinder(this.elementType, { super.skipOffstage });

  final Type elementType;

  @override
  String get description => 'type "$elementType"';

  @override
  bool matches(Element candidate) {
    return candidate.runtimeType == elementType;
  }
}

class _ExactWidgetFinder extends MatchFinder {
  _ExactWidgetFinder(this.widget, { super.skipOffstage });

  final Widget widget;

  @override
  String get description => 'the given widget ($widget)';

  @override
  bool matches(Element candidate) {
    return candidate.widget == widget;
  }
}

class _WidgetPredicateWidgetFinder extends MatchFinder {
  _WidgetPredicateWidgetFinder(this.predicate, { String? description, super.skipOffstage })
    : _description = description;

  final WidgetPredicate predicate;
  final String? _description;

  @override
  String get description => _description ?? 'widget matching predicate';

  @override
  bool matches(Element candidate) {
    return predicate(candidate.widget);
  }
}

class _ElementPredicateWidgetFinder extends MatchFinder {
  _ElementPredicateWidgetFinder(this.predicate, { String? description, super.skipOffstage })
    : _description = description;

  final ElementPredicate predicate;
  final String? _description;

  @override
  String get description => _description ?? 'element matching predicate';

  @override
  bool matches(Element candidate) {
    return predicate(candidate);
  }
}

class _PredicateSemanticsFinder extends SemanticsFinder
    with MatchFinderMixin<SemanticsNode> {
  _PredicateSemanticsFinder(this.predicate, DescribeMatchCallback? describeMatch, super.root)
    : _describeMatch = describeMatch;

  final SemanticsNodePredicate predicate;
  final DescribeMatchCallback? _describeMatch;

  @override
  String describeMatch(Plurality plurality) {
    return _describeMatch?.call(plurality) ??
      'matching semantics predicate';
  }

  @override
  bool matches(SemanticsNode candidate) {
    return predicate(candidate);
  }
}

mixin _DescendantFinderMixin<CandidateType> on FinderBase<CandidateType> {

  FinderBase<CandidateType> get ancestor;
  FinderBase<CandidateType> get descendant;
  bool get matchRoot;

  @override
  String describeMatch(Plurality plurality) {
    return '${descendant.describeMatch(plurality)} descending from '
      '${ancestor.describeMatch(plurality)}'
      '${matchRoot ? ' inclusive' : ''}';
  }

  @override
  Iterable<CandidateType> findInCandidates(Iterable<CandidateType> candidates) {
    final Iterable<CandidateType> descendants = descendant.evaluate();
    return candidates.where((CandidateType candidate) => descendants.contains(candidate));
  }

  @override
  Iterable<CandidateType> get allCandidates {
    final Iterable<CandidateType> ancestors = ancestor.evaluate();
    final List<CandidateType> candidates = ancestors.expand<CandidateType>(
      (CandidateType ancestor) => _collectDescendants(ancestor)
    ).toSet().toList();
    if (matchRoot) {
      candidates.insertAll(0, ancestors);
    }
    return candidates;
  }

  Iterable<CandidateType> _collectDescendants(CandidateType root);
}

class _DescendantWidgetFinder extends Finder
    with _DescendantFinderMixin<Element> {
  _DescendantWidgetFinder(
    this.ancestor,
    this.descendant, {
    this.matchRoot = false,
    super.skipOffstage,
  });

  @override
  final FinderBase<Element> ancestor;
  @override
  final FinderBase<Element> descendant;
  @override
  final bool matchRoot;

  @override
  String get description => describeMatch(Plurality.many);

  @override
  Iterable<Element> _collectDescendants(Element root) {
    return collectAllElementsFrom(root, skipOffstage: skipOffstage);
  }
}

class _DescendantSemanticsFinder extends FinderBase<SemanticsNode>
    with _DescendantFinderMixin<SemanticsNode> {
  _DescendantSemanticsFinder(this.ancestor, this.descendant, {this.matchRoot = false});

  @override
  final FinderBase<SemanticsNode> ancestor;

  @override
  final FinderBase<SemanticsNode> descendant;

  @override
  final bool matchRoot;

  @override
  Iterable<SemanticsNode> _collectDescendants(SemanticsNode root) {
    return collectAllSemanticsNodesFrom(root);
  }
}

mixin _AncestorFinderMixin<CandidateType> on FinderBase<CandidateType> {
  FinderBase<CandidateType> get ancestor;
  FinderBase<CandidateType> get descendant;
  bool get matchLeaves;

  @override
  String describeMatch(Plurality plurality) {
    return '${ancestor.describeMatch(plurality)} that are ancestors of '
    '${descendant.describeMatch(plurality)}'
    '${matchLeaves ? ' inclusive' : ''}';
  }

  @override
  Iterable<CandidateType> findInCandidates(Iterable<CandidateType> candidates) {
    final Iterable<CandidateType> ancestors = ancestor.evaluate();
    return candidates.where((CandidateType element) => ancestors.contains(element));
  }

  @override
  Iterable<CandidateType> get allCandidates {
    final List<CandidateType> candidates = <CandidateType>[];
    for (final CandidateType leaf in descendant.evaluate()) {
      if (matchLeaves) {
        candidates.add(leaf);
      }
      candidates.addAll(_collectAncestors(leaf));
    }
    return candidates;
  }

  Iterable<CandidateType> _collectAncestors(CandidateType child);
}

class _AncestorWidgetFinder extends Finder
    with _AncestorFinderMixin<Element> {
  _AncestorWidgetFinder(this.descendant, this.ancestor, { this.matchLeaves = false }) : super(skipOffstage: false);

  @override
  final FinderBase<Element> ancestor;
  @override
  final FinderBase<Element> descendant;
  @override
  final bool matchLeaves;

  @override
  String get description => describeMatch(Plurality.many);

  @override
  Iterable<Element> _collectAncestors(Element child) {
    final List<Element> ancestors = <Element>[];
    child.visitAncestorElements((Element element) {
      ancestors.add(element);
      return true;
    });
    return ancestors;
  }
}

class _AncestorSemanticsFinder extends FinderBase<SemanticsNode>
    with _AncestorFinderMixin<SemanticsNode> {
  _AncestorSemanticsFinder(this.descendant, this.ancestor, this.matchLeaves);

  @override
  final FinderBase<SemanticsNode> ancestor;

  @override
  final FinderBase<SemanticsNode> descendant;

  @override
  final bool matchLeaves;

  @override
  Iterable<SemanticsNode> _collectAncestors(SemanticsNode child) {
    final List<SemanticsNode> ancestors = <SemanticsNode>[];
    while (child.parent != null) {
      ancestors.add(child.parent!);
      child = child.parent!;
    }
    return ancestors;
  }
}