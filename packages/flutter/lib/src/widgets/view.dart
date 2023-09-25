// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:collection';
import 'dart:ui' show FlutterView, SemanticsUpdate;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'framework.dart';
import 'lookup_boundary.dart';
import 'media_query.dart';

class View extends StatelessWidget {
  View({
    super.key,
    required this.view,
    @Deprecated(
      'Do not use. '
      'This parameter only exists to implement the deprecated RendererBinding.pipelineOwner property until it is removed. '
      'This feature was deprecated after v3.10.0-12.0.pre.'
    )
    PipelineOwner? deprecatedDoNotUseWillBeRemovedWithoutNoticePipelineOwner,
    @Deprecated(
      'Do not use. '
      'This parameter only exists to implement the deprecated RendererBinding.renderView property until it is removed. '
      'This feature was deprecated after v3.10.0-12.0.pre.'
    )
    RenderView? deprecatedDoNotUseWillBeRemovedWithoutNoticeRenderView,
    required this.child,
  }) : _deprecatedPipelineOwner = deprecatedDoNotUseWillBeRemovedWithoutNoticePipelineOwner,
       _deprecatedRenderView = deprecatedDoNotUseWillBeRemovedWithoutNoticeRenderView,
       assert((deprecatedDoNotUseWillBeRemovedWithoutNoticePipelineOwner == null) == (deprecatedDoNotUseWillBeRemovedWithoutNoticeRenderView == null)),
       assert(deprecatedDoNotUseWillBeRemovedWithoutNoticeRenderView == null || deprecatedDoNotUseWillBeRemovedWithoutNoticeRenderView.flutterView == view);

  final FlutterView view;

  final Widget child;

  final PipelineOwner? _deprecatedPipelineOwner;
  final RenderView? _deprecatedRenderView;

  static FlutterView? maybeOf(BuildContext context) {
    return LookupBoundary.dependOnInheritedWidgetOfExactType<_ViewScope>(context)?.view;
  }

  static FlutterView of(BuildContext context) {
    final FlutterView? result = maybeOf(context);
    assert(() {
      if (result == null) {
        final bool hiddenByBoundary = LookupBoundary.debugIsHidingAncestorWidgetOfExactType<_ViewScope>(context);
        final List<DiagnosticsNode> information = <DiagnosticsNode>[
          if (hiddenByBoundary) ...<DiagnosticsNode>[
            ErrorSummary('View.of() was called with a context that does not have access to a View widget.'),
            ErrorDescription('The context provided to View.of() does have a View widget ancestor, but it is hidden by a LookupBoundary.'),
          ] else ...<DiagnosticsNode>[
            ErrorSummary('View.of() was called with a context that does not contain a View widget.'),
            ErrorDescription('No View widget ancestor could be found starting from the context that was passed to View.of().'),
          ],
          ErrorDescription(
            'The context used was:\n'
            '  $context',
          ),
          ErrorHint('This usually means that the provided context is not associated with a View.'),
        ];
        throw FlutterError.fromParts(information);
      }
      return true;
    }());
    return result!;
  }

  static PipelineOwner pipelineOwnerOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<_PipelineOwnerScope>()?.pipelineOwner
        ?? RendererBinding.instance.rootPipelineOwner;
  }

  @override
  Widget build(BuildContext context) {
    return _RawView(
      view: view,
      deprecatedPipelineOwner: _deprecatedPipelineOwner,
      deprecatedRenderView: _deprecatedRenderView,
      builder: (BuildContext context, PipelineOwner owner) {
        return _ViewScope(
          view: view,
          child: _PipelineOwnerScope(
            pipelineOwner: owner,
            child: MediaQuery.fromView(
              view: view,
              child: child,
            ),
          ),
        );
      }
    );
  }
}

typedef _RawViewContentBuilder = Widget Function(BuildContext context, PipelineOwner owner);

class _RawView extends RenderObjectWidget {
  _RawView({
    required this.view,
    required PipelineOwner? deprecatedPipelineOwner,
    required RenderView? deprecatedRenderView,
    required this.builder,
  }) : _deprecatedPipelineOwner = deprecatedPipelineOwner,
       _deprecatedRenderView = deprecatedRenderView,
       assert(deprecatedRenderView == null || deprecatedRenderView.flutterView == view),
       // TODO(goderbauer): Replace this with GlobalObjectKey(view) when the deprecated properties are removed.
       super(key: _DeprecatedRawViewKey(view, deprecatedPipelineOwner, deprecatedRenderView));

  final FlutterView view;

  final _RawViewContentBuilder builder;

  final PipelineOwner? _deprecatedPipelineOwner;
  final RenderView? _deprecatedRenderView;

  @override
  RenderObjectElement createElement() => _RawViewElement(this);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _deprecatedRenderView ?? RenderView(
      view: view,
    );
  }

  // No need to implement updateRenderObject: RawView uses the view as a
  // GlobalKey, so we never need to update the RenderObject with a new view.
}

class _RawViewElement extends RenderTreeRootElement {
  _RawViewElement(super.widget);

  late final PipelineOwner _pipelineOwner = PipelineOwner(
    onSemanticsOwnerCreated: _handleSemanticsOwnerCreated,
    onSemanticsUpdate: _handleSemanticsUpdate,
    onSemanticsOwnerDisposed: _handleSemanticsOwnerDisposed,
  );

  PipelineOwner get _effectivePipelineOwner => (widget as _RawView)._deprecatedPipelineOwner ?? _pipelineOwner;

  void _handleSemanticsOwnerCreated() {
    (_effectivePipelineOwner.rootNode as RenderView?)?.scheduleInitialSemantics();
  }

  void _handleSemanticsOwnerDisposed() {
    (_effectivePipelineOwner.rootNode as RenderView?)?.clearSemantics();
  }

  void _handleSemanticsUpdate(SemanticsUpdate update) {
    (widget as _RawView).view.updateSemantics(update);
  }

  @override
  RenderView get renderObject => super.renderObject as RenderView;

  Element? _child;

  void _updateChild() {
    try {
      final Widget child = (widget as _RawView).builder(this, _effectivePipelineOwner);
      _child = updateChild(_child, child, null);
    } catch (e, stack) {
      final FlutterErrorDetails details = FlutterErrorDetails(
        exception: e,
        stack: stack,
        library: 'widgets library',
        context: ErrorDescription('building $this'),
        informationCollector: !kDebugMode ? null : () => <DiagnosticsNode>[
          DiagnosticsDebugCreator(DebugCreator(this)),
        ],
      );
      FlutterError.reportError(details);
      final Widget error = ErrorWidget.builder(details);
      _child = updateChild(null, error, slot);
    }
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    assert(_effectivePipelineOwner.rootNode == null);
    _effectivePipelineOwner.rootNode = renderObject;
    _attachView();
    _updateChild();
    renderObject.prepareInitialFrame();
    if (_effectivePipelineOwner.semanticsOwner != null) {
      renderObject.scheduleInitialSemantics();
    }
  }

  PipelineOwner? _parentPipelineOwner; // Is null if view is currently not attached.

  void _attachView([PipelineOwner? parentPipelineOwner]) {
    assert(_parentPipelineOwner == null);
    parentPipelineOwner ??= View.pipelineOwnerOf(this);
    parentPipelineOwner.adoptChild(_effectivePipelineOwner);
    RendererBinding.instance.addRenderView(renderObject);
    _parentPipelineOwner = parentPipelineOwner;
  }

  void _detachView() {
    final PipelineOwner? parentPipelineOwner = _parentPipelineOwner;
    if (parentPipelineOwner != null) {
      RendererBinding.instance.removeRenderView(renderObject);
      parentPipelineOwner.dropChild(_effectivePipelineOwner);
      _parentPipelineOwner = null;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_parentPipelineOwner == null) {
      return;
    }
    final PipelineOwner newParentPipelineOwner = View.pipelineOwnerOf(this);
    if (newParentPipelineOwner != _parentPipelineOwner) {
      _detachView();
      _attachView(newParentPipelineOwner);
    }
  }

  @override
  void performRebuild() {
    super.performRebuild();
    _updateChild();
  }

  @override
  void activate() {
    super.activate();
    assert(_effectivePipelineOwner.rootNode == null);
    _effectivePipelineOwner.rootNode = renderObject;
    _attachView();
  }

  @override
  void deactivate() {
    _detachView();
    assert(_effectivePipelineOwner.rootNode == renderObject);
    _effectivePipelineOwner.rootNode = null; // To satisfy the assert in the super class.
    super.deactivate();
  }

  @override
  void update(_RawView newWidget) {
    super.update(newWidget);
    _updateChild();
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    if (_child != null) {
      visitor(_child!);
    }
  }

  @override
  void forgetChild(Element child) {
    assert(child == _child);
    _child = null;
    super.forgetChild(child);
  }

  @override
  void insertRenderObjectChild(RenderBox child, Object? slot) {
    assert(slot == null);
    assert(renderObject.debugValidateChild(child));
    renderObject.child = child;
  }

  @override
  void moveRenderObjectChild(RenderObject child, Object? oldSlot, Object? newSlot) {
    assert(false);
  }

  @override
  void removeRenderObjectChild(RenderObject child, Object? slot) {
    assert(slot == null);
    assert(renderObject.child == child);
    renderObject.child = null;
  }

  @override
  void unmount() {
    if (_effectivePipelineOwner != (widget as _RawView)._deprecatedPipelineOwner) {
      _effectivePipelineOwner.dispose();
    }
    super.unmount();
  }
}

class _ViewScope extends InheritedWidget {
  const _ViewScope({required this.view, required super.child});

  final FlutterView? view;

  @override
  bool updateShouldNotify(_ViewScope oldWidget) => view != oldWidget.view;
}

class _PipelineOwnerScope extends InheritedWidget {
  const _PipelineOwnerScope({
    required this.pipelineOwner,
    required super.child,
  });

  final PipelineOwner pipelineOwner;

  @override
  bool updateShouldNotify(_PipelineOwnerScope oldWidget) => pipelineOwner != oldWidget.pipelineOwner;
}

class _MultiChildComponentWidget extends Widget {
  const _MultiChildComponentWidget({
    super.key,
    List<Widget> views = const <Widget>[],
    Widget? child,
  }) : _views = views, _child = child;

  // It is up to the subclasses to make the relevant properties public.
  final List<Widget> _views;
  final Widget? _child;

  @override
  Element createElement() => _MultiChildComponentElement(this);
}

class ViewCollection extends _MultiChildComponentWidget {
  const ViewCollection({super.key, required super.views}) : assert(views.length > 0);

  List<Widget> get views => _views;
}

class ViewAnchor extends StatelessWidget {
  const ViewAnchor({
    super.key,
    this.view,
    required this.child,
  });

  final Widget? view;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _MultiChildComponentWidget(
      views: <Widget>[
        if (view != null)
          _ViewScope(
            view: null,
            child: view!,
          ),
      ],
      child: child,
    );
  }
}

class _MultiChildComponentElement extends Element {
  _MultiChildComponentElement(super.widget);

  List<Element> _viewElements = <Element>[];
  final Set<Element> _forgottenViewElements = HashSet<Element>();
  Element? _childElement;

  bool _debugAssertChildren() {
    final _MultiChildComponentWidget typedWidget = widget as _MultiChildComponentWidget;
    // Each view widget must have a corresponding element.
    assert(_viewElements.length == typedWidget._views.length);
    // Iff there is a child widget, it must have a corresponding element.
    assert((_childElement == null) == (typedWidget._child == null));
    // The child element is not also a view element.
    assert(!_viewElements.contains(_childElement));
    return true;
  }

  @override
  void attachRenderObject(Object? newSlot) {
    super.attachRenderObject(newSlot);
    assert(_debugCheckMustAttachRenderObject(newSlot));
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    assert(_debugCheckMustAttachRenderObject(newSlot));
    assert(_viewElements.isEmpty);
    assert(_childElement == null);
    rebuild();
    assert(_debugAssertChildren());
  }

  @override
  void updateSlot(Object? newSlot) {
    super.updateSlot(newSlot);
    assert(_debugCheckMustAttachRenderObject(newSlot));
  }

  bool _debugCheckMustAttachRenderObject(Object? slot) {
    // Check only applies in the ViewCollection configuration.
    if (!kDebugMode || (widget as _MultiChildComponentWidget)._child != null) {
      return true;
    }
    bool hasAncestorRenderObjectElement = false;
    bool ancestorWantsRenderObject = true;
    visitAncestorElements((Element ancestor) {
      if (!ancestor.debugExpectsRenderObjectForSlot(slot)) {
        ancestorWantsRenderObject = false;
        return false;
      }
      if (ancestor is RenderObjectElement) {
        hasAncestorRenderObjectElement = true;
        return false;
      }
      return true;
    });
    if (hasAncestorRenderObjectElement && ancestorWantsRenderObject) {
      FlutterError.reportError(
        FlutterErrorDetails(exception: FlutterError.fromParts(
          <DiagnosticsNode>[
            ErrorSummary(
              'The Element for ${toStringShort()} cannot be inserted into slot "$slot" of its ancestor. ',
            ),
            ErrorDescription(
              'The ownership chain for the Element in question was:\n  ${debugGetCreatorChain(10)}',
            ),
            ErrorDescription(
              'This Element allows the creation of multiple independent render trees, which cannot '
              'be attached to an ancestor in an existing render tree. However, an ancestor RenderObject '
              'is expecting that a child will be attached.'
            ),
            ErrorHint(
              'Try moving the subtree that contains the ${toStringShort()} widget into the '
              'view property of a ViewAnchor widget or to the root of the widget tree, where '
              'it is not expected to attach its RenderObject to its ancestor.',
            ),
          ],
        )),
      );
    }
    return true;
  }

  @override
  void update(_MultiChildComponentWidget newWidget) {
    // Cannot switch from ViewAnchor config to ViewCollection config.
    assert((newWidget._child == null) == ((widget as _MultiChildComponentWidget)._child == null));
    super.update(newWidget);
    rebuild(force: true);
    assert(_debugAssertChildren());
  }

  static const Object _viewSlot = Object();

  @override
  bool debugExpectsRenderObjectForSlot(Object? slot) => slot != _viewSlot;

  @override
  void performRebuild() {
    final _MultiChildComponentWidget typedWidget = widget as _MultiChildComponentWidget;

    _childElement = updateChild(_childElement, typedWidget._child, slot);

    final List<Widget> views = typedWidget._views;
    _viewElements = updateChildren(
      _viewElements,
      views,
      forgottenChildren: _forgottenViewElements,
      slots: List<Object>.generate(views.length, (_) => _viewSlot),
    );
    _forgottenViewElements.clear();

    super.performRebuild(); // clears the dirty flag
    assert(_debugAssertChildren());
  }

  @override
  void forgetChild(Element child) {
    if (child == _childElement) {
      _childElement = null;
    } else {
      assert(_viewElements.contains(child));
      assert(!_forgottenViewElements.contains(child));
      _forgottenViewElements.add(child);
    }
    super.forgetChild(child);
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    if (_childElement != null) {
      visitor(_childElement!);
    }
    for (final Element child in _viewElements) {
      if (!_forgottenViewElements.contains(child)) {
        visitor(child);
      }
    }
  }

  @override
  bool get debugDoingBuild => false; // This element does not have a concept of "building".

  @override
  Element? get renderObjectAttachingChild => _childElement;

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    final List<DiagnosticsNode> children = <DiagnosticsNode>[];
    if (_childElement != null) {
      children.add(_childElement!.toDiagnosticsNode());
    }
    for (int i = 0; i < _viewElements.length; i++) {
      children.add(_viewElements[i].toDiagnosticsNode(
        name: 'view ${i + 1}',
        style: DiagnosticsTreeStyle.offstage,
      ));
    }
    return children;
  }
}

// A special [GlobalKey] to support passing the deprecated
// [RendererBinding.renderView] and [RendererBinding.pipelineOwner] to the
// [_RawView]. Will be removed when those deprecated properties are removed.
@optionalTypeArgs
class _DeprecatedRawViewKey<T extends State<StatefulWidget>> extends GlobalKey<T> {
  const _DeprecatedRawViewKey(this.view, this.owner, this.renderView) : super.constructor();

  final FlutterView view;
  final PipelineOwner? owner;
  final RenderView? renderView;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is _DeprecatedRawViewKey<T>
        && identical(other.view, view)
        && identical(other.owner, owner)
        && identical(other.renderView, renderView);
  }

  @override
  int get hashCode => Object.hash(view, owner, renderView);

  @override
  String toString() => '[_DeprecatedRawViewKey ${describeIdentity(view)}]';
}