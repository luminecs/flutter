
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';

import 'framework.dart';

abstract class SlottedMultiChildRenderObjectWidget<SlotType, ChildType extends RenderObject> extends RenderObjectWidget with SlottedMultiChildRenderObjectWidgetMixin<SlotType, ChildType> {
  const SlottedMultiChildRenderObjectWidget({ super.key });
}

@Deprecated(
  'Extend SlottedMultiChildRenderObjectWidget instead of mixing in SlottedMultiChildRenderObjectWidgetMixin. '
  'This feature was deprecated after v3.10.0-1.5.pre.'
)
mixin SlottedMultiChildRenderObjectWidgetMixin<SlotType, ChildType extends RenderObject> on RenderObjectWidget {
  @protected
  Iterable<SlotType> get slots;

  @protected
  Widget? childForSlot(SlotType slot);

  @override
  SlottedContainerRenderObjectMixin<SlotType, ChildType> createRenderObject(BuildContext context);

  @override
  void updateRenderObject(BuildContext context, SlottedContainerRenderObjectMixin<SlotType, ChildType> renderObject);

  @override
  SlottedRenderObjectElement<SlotType, ChildType> createElement() => SlottedRenderObjectElement<SlotType, ChildType>(this);
}

mixin SlottedContainerRenderObjectMixin<SlotType, ChildType extends RenderObject> on RenderObject {
  @protected
  ChildType? childForSlot(SlotType slot) => _slotToChild[slot];

  @protected
  Iterable<ChildType> get children => _slotToChild.values;

  @protected
  String debugNameForSlot(SlotType slot) {
    if (slot is Enum) {
      return slot.name;
    }
    return slot.toString();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    for (final ChildType child in children) {
      child.attach(owner);
    }
  }

  @override
  void detach() {
    super.detach();
    for (final ChildType child in children) {
      child.detach();
    }
  }

  @override
  void redepthChildren() {
    children.forEach(redepthChild);
  }

  @override
  void visitChildren(RenderObjectVisitor visitor) {
    children.forEach(visitor);
  }

  @override
  List<DiagnosticsNode> debugDescribeChildren() {
    final List<DiagnosticsNode> value = <DiagnosticsNode>[];
    final Map<ChildType, SlotType> childToSlot = Map<ChildType, SlotType>.fromIterables(
      _slotToChild.values,
      _slotToChild.keys,
    );
    for (final ChildType child in children) {
      _addDiagnostics(child, value, debugNameForSlot(childToSlot[child] as SlotType));
    }
    return value;
  }

  void _addDiagnostics(ChildType child, List<DiagnosticsNode> value, String name) {
    value.add(child.toDiagnosticsNode(name: name));
  }

  final Map<SlotType, ChildType> _slotToChild = <SlotType, ChildType>{};

  void _setChild(ChildType? child, SlotType slot) {
    final ChildType? oldChild = _slotToChild[slot];
    if (oldChild != null) {
      dropChild(oldChild);
      _slotToChild.remove(slot);
    }
    if (child != null) {
      _slotToChild[slot] = child;
      adoptChild(child);
    }
  }

  void _moveChild(ChildType child, SlotType slot, SlotType oldSlot) {
    assert(slot != oldSlot);
    final ChildType? oldChild = _slotToChild[oldSlot];
    if (oldChild == child) {
      _setChild(null, oldSlot);
    }
    _setChild(child, slot);
  }
}

class SlottedRenderObjectElement<SlotType, ChildType extends RenderObject> extends RenderObjectElement {
  SlottedRenderObjectElement(SlottedMultiChildRenderObjectWidgetMixin<SlotType, ChildType> super.widget);

  Map<SlotType, Element> _slotToChild = <SlotType, Element>{};
  Map<Key, Element> _keyedChildren = <Key, Element>{};

  @override
  SlottedContainerRenderObjectMixin<SlotType, ChildType> get renderObject => super.renderObject as SlottedContainerRenderObjectMixin<SlotType, ChildType>;

  @override
  void visitChildren(ElementVisitor visitor) {
    _slotToChild.values.forEach(visitor);
  }

  @override
  void forgetChild(Element child) {
    assert(_slotToChild.containsValue(child));
    assert(child.slot is SlotType);
    assert(_slotToChild.containsKey(child.slot));
    _slotToChild.remove(child.slot);
    super.forgetChild(child);
  }

  @override
  void mount(Element? parent, Object? newSlot) {
    super.mount(parent, newSlot);
    _updateChildren();
  }

  @override
  void update(SlottedMultiChildRenderObjectWidgetMixin<SlotType, ChildType> newWidget) {
    super.update(newWidget);
    assert(widget == newWidget);
    _updateChildren();
  }

  List<SlotType>? _debugPreviousSlots;

  void _updateChildren() {
    final SlottedMultiChildRenderObjectWidgetMixin<SlotType, ChildType> slottedMultiChildRenderObjectWidgetMixin = widget as SlottedMultiChildRenderObjectWidgetMixin<SlotType, ChildType>;
    assert(() {
      _debugPreviousSlots ??= slottedMultiChildRenderObjectWidgetMixin.slots.toList();
      return listEquals(_debugPreviousSlots, slottedMultiChildRenderObjectWidgetMixin.slots.toList());
    }(), '${widget.runtimeType}.slots must not change.');
    assert(slottedMultiChildRenderObjectWidgetMixin.slots.toSet().length == slottedMultiChildRenderObjectWidgetMixin.slots.length, 'slots must be unique');

    final Map<Key, Element> oldKeyedElements = _keyedChildren;
    _keyedChildren = <Key, Element>{};
    final Map<SlotType, Element> oldSlotToChild = _slotToChild;
    _slotToChild = <SlotType, Element>{};

    Map<Key, List<Element>>? debugDuplicateKeys;

    for (final SlotType slot in slottedMultiChildRenderObjectWidgetMixin.slots) {
      final Widget? widget = slottedMultiChildRenderObjectWidgetMixin.childForSlot(slot);
      final Key? newWidgetKey = widget?.key;

      final Element? oldSlotChild = oldSlotToChild[slot];
      final Element? oldKeyChild = oldKeyedElements[newWidgetKey];

      // Try to find the slot for the correct Element that `widget` should update.
      // If key matching fails, resort to `oldSlotChild` from the same slot.
      final Element? fromElement;
      if (oldKeyChild != null) {
        fromElement = oldSlotToChild.remove(oldKeyChild.slot as SlotType);
      } else if (oldSlotChild?.widget.key == null) {
        fromElement = oldSlotToChild.remove(slot);
      } else {
        // The only case we can't use `oldSlotChild` is when its widget has a key.
        assert(oldSlotChild!.widget.key != newWidgetKey);
        fromElement = null;
      }
      final Element? newChild = updateChild(fromElement, widget, slot);

      if (newChild != null) {
        _slotToChild[slot] = newChild;

        if (newWidgetKey != null) {
          assert(() {
            final Element? existingElement = _keyedChildren[newWidgetKey];
            if (existingElement != null) {
              (debugDuplicateKeys ??= <Key, List<Element>>{})
                .putIfAbsent(newWidgetKey, () => <Element>[existingElement])
                .add(newChild);
            }
            return true;
          }());
          _keyedChildren[newWidgetKey] = newChild;
        }
      }
    }
    oldSlotToChild.values.forEach(deactivateChild);
    assert(_debugDuplicateKeys(debugDuplicateKeys));
    assert(_keyedChildren.values.every(_slotToChild.values.contains), '_keyedChildren ${_keyedChildren.values} should be a subset of ${_slotToChild.values}');
  }

  bool _debugDuplicateKeys(Map<Key, List<Element>>? debugDuplicateKeys) {
    if (debugDuplicateKeys == null) {
      return true;
    }
    for (final MapEntry<Key, List<Element>> duplicateKey in debugDuplicateKeys.entries) {
      throw FlutterError.fromParts(<DiagnosticsNode>[
        ErrorSummary('Multiple widgets used the same key in ${widget.runtimeType}.'),
        ErrorDescription(
          'The key ${duplicateKey.key} was used by multiple widgets. The offending widgets were:\n'
        ),
        for (final Element element in duplicateKey.value) ErrorDescription('  - $element\n'),
        ErrorDescription(
          'A key can only be specified on one widget at a time in the same parent widget.',
        ),
      ]);
    }
    return true;
  }

  @override
  void insertRenderObjectChild(ChildType child, SlotType slot) {
    renderObject._setChild(child, slot);
    assert(renderObject._slotToChild[slot] == child);
  }

  @override
  void removeRenderObjectChild(ChildType child, SlotType slot) {
    if (renderObject._slotToChild[slot] == child) {
      renderObject._setChild(null, slot);
      assert(renderObject._slotToChild[slot] == null);
    }
  }

  @override
  void moveRenderObjectChild(ChildType child, SlotType oldSlot, SlotType newSlot) {
    renderObject._moveChild(child, newSlot, oldSlot);
  }
}