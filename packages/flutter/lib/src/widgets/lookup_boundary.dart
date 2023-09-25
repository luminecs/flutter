
import 'framework.dart';

// Examples can assume:
// class MyWidget extends StatelessWidget { const MyWidget({super.key, required this.child}); final Widget child; @override Widget build(BuildContext context) => child; }

// TODO(goderbauer): Reference the View widget here once available.
class LookupBoundary extends InheritedWidget {
  const LookupBoundary({super.key, required super.child});

  static T? dependOnInheritedWidgetOfExactType<T extends InheritedWidget>(BuildContext context, { Object? aspect }) {
    // The following call makes sure that context depends on something so
    // Element.didChangeDependencies is called when context moves in the tree
    // even when requested dependency remains unfulfilled (i.e. null is
    // returned).
    context.dependOnInheritedWidgetOfExactType<LookupBoundary>();
    final InheritedElement? candidate = getElementForInheritedWidgetOfExactType<T>(context);
    if (candidate == null) {
      return null;
    }
    context.dependOnInheritedElement(candidate, aspect: aspect);
    return candidate.widget as T;
  }

  static InheritedElement? getElementForInheritedWidgetOfExactType<T extends InheritedWidget>(BuildContext context) {
    final InheritedElement? candidate = context.getElementForInheritedWidgetOfExactType<T>();
    if (candidate == null) {
      return null;
    }
    final Element? boundary = context.getElementForInheritedWidgetOfExactType<LookupBoundary>();
    if (boundary != null && boundary.depth > candidate.depth) {
      return null;
    }
    return candidate;
  }

  static T? findAncestorWidgetOfExactType<T extends Widget>(BuildContext context) {
    Element? target;
    context.visitAncestorElements((Element ancestor) {
      if (ancestor.widget.runtimeType == T) {
        target = ancestor;
        return false;
      }
      return ancestor.widget.runtimeType != LookupBoundary;
    });
    return target?.widget as T?;
  }

  static T? findAncestorStateOfType<T extends State>(BuildContext context) {
    StatefulElement? target;
    context.visitAncestorElements((Element ancestor) {
      if (ancestor is StatefulElement && ancestor.state is T) {
        target = ancestor;
        return false;
      }
      return ancestor.widget.runtimeType != LookupBoundary;
    });
    return target?.state as T?;
  }

  static T? findRootAncestorStateOfType<T extends State>(BuildContext context) {
    StatefulElement? target;
    context.visitAncestorElements((Element ancestor) {
      if (ancestor is StatefulElement && ancestor.state is T) {
        target = ancestor;
      }
      return ancestor.widget.runtimeType != LookupBoundary;
    });
    return target?.state as T?;
  }

  static T? findAncestorRenderObjectOfType<T extends RenderObject>(BuildContext context) {
    Element? target;
    context.visitAncestorElements((Element ancestor) {
      if (ancestor is RenderObjectElement && ancestor.renderObject is T) {
        target = ancestor;
        return false;
      }
      return ancestor.widget.runtimeType != LookupBoundary;
    });
    return target?.renderObject as T?;
  }

  static void visitAncestorElements(BuildContext context, ConditionalElementVisitor visitor) {
    context.visitAncestorElements((Element ancestor) {
      return visitor(ancestor) && ancestor.widget.runtimeType != LookupBoundary;
    });
  }

  static void visitChildElements(BuildContext context, ElementVisitor visitor) {
    context.visitChildElements((Element child) {
      if (child.widget.runtimeType != LookupBoundary) {
        visitor(child);
      }
    });
  }

  static bool debugIsHidingAncestorWidgetOfExactType<T extends Widget>(BuildContext context) {
    bool? result;
    assert(() {
      bool hiddenByBoundary = false;
      bool ancestorFound = false;
      context.visitAncestorElements((Element ancestor) {
        if (ancestor.widget.runtimeType == T) {
          ancestorFound = true;
          return false;
        }
        hiddenByBoundary = hiddenByBoundary || ancestor.widget.runtimeType == LookupBoundary;
        return true;
      });
      result = ancestorFound & hiddenByBoundary;
      return true;
    } ());
    return result!;
  }

  static bool debugIsHidingAncestorStateOfType<T extends State>(BuildContext context) {
    bool? result;
    assert(() {
      bool hiddenByBoundary = false;
      bool ancestorFound = false;
      context.visitAncestorElements((Element ancestor) {
        if (ancestor is StatefulElement && ancestor.state is T) {
          ancestorFound = true;
          return false;
        }
        hiddenByBoundary = hiddenByBoundary || ancestor.widget.runtimeType == LookupBoundary;
        return true;
      });
      result = ancestorFound & hiddenByBoundary;
      return true;
    } ());
    return result!;
  }

  static bool debugIsHidingAncestorRenderObjectOfType<T extends RenderObject>(BuildContext context) {
    bool? result;
    assert(() {
      bool hiddenByBoundary = false;
      bool ancestorFound = false;
      context.visitAncestorElements((Element ancestor) {
        if (ancestor is RenderObjectElement && ancestor.renderObject is T) {
          ancestorFound = true;
          return false;
        }
        hiddenByBoundary = hiddenByBoundary || ancestor.widget.runtimeType == LookupBoundary;
        return true;
      });
      result = ancestorFound & hiddenByBoundary;
      return true;
    } ());
    return result!;
  }

  @override
  bool updateShouldNotify(covariant InheritedWidget oldWidget) => false;
}