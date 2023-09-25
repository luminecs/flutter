// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/rendering.dart';

import 'framework.dart';

class SelectionContainer extends StatefulWidget {
  const SelectionContainer({
    super.key,
    this.registrar,
    required SelectionContainerDelegate this.delegate,
    required this.child,
  });

  const SelectionContainer.disabled({
    super.key,
    required this.child,
  }) : registrar = null,
       delegate = null;

  final SelectionRegistrar? registrar;

  final Widget child;

  final SelectionContainerDelegate? delegate;

  static SelectionRegistrar? maybeOf(BuildContext context) {
    final SelectionRegistrarScope? scope = context.dependOnInheritedWidgetOfExactType<SelectionRegistrarScope>();
    return scope?.registrar;
  }

  bool get _disabled => delegate == null;

  @override
  State<SelectionContainer> createState() => _SelectionContainerState();
}

class _SelectionContainerState extends State<SelectionContainer> with Selectable, SelectionRegistrant {
  final Set<VoidCallback> _listeners = <VoidCallback>{};

  static const SelectionGeometry _disabledGeometry = SelectionGeometry(
    status: SelectionStatus.none,
    hasContent: true,
  );

  @override
  void initState() {
    super.initState();
    if (!widget._disabled) {
      widget.delegate!._selectionContainerContext = context;
      if (widget.registrar != null) {
        registrar = widget.registrar;
      }
    }
  }

  @override
  void didUpdateWidget(SelectionContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.delegate != widget.delegate) {
      if (!oldWidget._disabled) {
        oldWidget.delegate!._selectionContainerContext = null;
        _listeners.forEach(oldWidget.delegate!.removeListener);
      }
      if (!widget._disabled) {
        widget.delegate!._selectionContainerContext = context;
        _listeners.forEach(widget.delegate!.addListener);
      }
      if (oldWidget.delegate?.value != widget.delegate?.value) {
        // Avoid concurrent modification.
        for (final VoidCallback listener in _listeners.toList(growable: false)) {
          listener();
        }
      }
    }
    if (widget._disabled) {
      registrar = null;
    } else if (widget.registrar != null) {
      registrar = widget.registrar;
    }
    assert(!widget._disabled || registrar == null);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.registrar == null && !widget._disabled) {
      registrar = SelectionContainer.maybeOf(context);
    }
    assert(!widget._disabled || registrar == null);
  }

  @override
  void addListener(VoidCallback listener) {
    assert(!widget._disabled);
    widget.delegate!.addListener(listener);
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    widget.delegate?.removeListener(listener);
    _listeners.remove(listener);
  }

  @override
  void pushHandleLayers(LayerLink? startHandle, LayerLink? endHandle) {
    assert(!widget._disabled);
    widget.delegate!.pushHandleLayers(startHandle, endHandle);
  }

  @override
  SelectedContent? getSelectedContent() {
    assert(!widget._disabled);
    return widget.delegate!.getSelectedContent();
  }

  @override
  SelectionResult dispatchSelectionEvent(SelectionEvent event) {
    assert(!widget._disabled);
    return widget.delegate!.dispatchSelectionEvent(event);
  }

  @override
  SelectionGeometry get value {
    if (widget._disabled) {
      return _disabledGeometry;
    }
    return widget.delegate!.value;
  }

  @override
  Matrix4 getTransformTo(RenderObject? ancestor) {
    assert(!widget._disabled);
    return context.findRenderObject()!.getTransformTo(ancestor);
  }

  @override
  Size get size => (context.findRenderObject()! as RenderBox).size;

  @override
  void dispose() {
    if (!widget._disabled) {
      widget.delegate!._selectionContainerContext = null;
      _listeners.forEach(widget.delegate!.removeListener);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget._disabled) {
      return SelectionRegistrarScope._disabled(child: widget.child);
    }
    return SelectionRegistrarScope(
      registrar: widget.delegate!,
      child: widget.child,
    );
  }
}

class SelectionRegistrarScope extends InheritedWidget {
  const SelectionRegistrarScope({
    super.key,
    required SelectionRegistrar this.registrar,
    required super.child,
  });

  const SelectionRegistrarScope._disabled({
    required super.child,
  }) : registrar = null;

  final SelectionRegistrar? registrar;

  @override
  bool updateShouldNotify(SelectionRegistrarScope oldWidget) {
    return oldWidget.registrar != registrar;
  }
}

abstract class SelectionContainerDelegate implements SelectionHandler, SelectionRegistrar {
  BuildContext? _selectionContainerContext;

  Matrix4 getTransformFrom(Selectable child) {
    assert(
      _selectionContainerContext?.findRenderObject() != null,
      'getTransformFrom cannot be called before SelectionContainer is laid out.',
    );
    return child.getTransformTo(_selectionContainerContext!.findRenderObject()! as RenderBox);
  }

  Matrix4 getTransformTo(RenderObject? ancestor) {
    assert(
      _selectionContainerContext?.findRenderObject() != null,
      'getTransformTo cannot be called before SelectionContainer is laid out.',
    );
    final RenderBox box = _selectionContainerContext!.findRenderObject()! as RenderBox;
    return box.getTransformTo(ancestor);
  }

  bool get hasSize {
    assert(
    _selectionContainerContext?.findRenderObject() != null,
    'The _selectionContainerContext must have a renderObject, such as after the first build has completed.',
    );
    final RenderBox box = _selectionContainerContext!.findRenderObject()! as RenderBox;
    return box.hasSize;
  }

  Size get containerSize {
    assert(
      hasSize,
      'containerSize cannot be called before SelectionContainer is laid out.',
    );
    final RenderBox box = _selectionContainerContext!.findRenderObject()! as RenderBox;
    return box.size;
  }
}