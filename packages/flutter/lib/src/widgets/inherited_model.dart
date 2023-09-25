
import 'dart:collection';

import 'framework.dart';

abstract class InheritedModel<T> extends InheritedWidget {
  const InheritedModel({ super.key, required super.child });

  @override
  InheritedModelElement<T> createElement() => InheritedModelElement<T>(this);

  @protected
  bool updateShouldNotifyDependent(covariant InheritedModel<T> oldWidget, Set<T> dependencies);

  @protected
  bool isSupportedAspect(Object aspect) => true;

  // The [result] will be a list of all of context's type T ancestors concluding
  // with the one that supports the specified model [aspect].
  static void _findModels<T extends InheritedModel<Object>>(BuildContext context, Object aspect, List<InheritedElement> results) {
    final InheritedElement? model = context.getElementForInheritedWidgetOfExactType<T>();
    if (model == null) {
      return;
    }

    results.add(model);

    assert(model.widget is T);
    final T modelWidget = model.widget as T;
    if (modelWidget.isSupportedAspect(aspect)) {
      return;
    }

    Element? modelParent;
    model.visitAncestorElements((Element ancestor) {
      modelParent = ancestor;
      return false;
    });
    if (modelParent == null) {
      return;
    }

    _findModels<T>(modelParent!, aspect, results);
  }

  static T? inheritFrom<T extends InheritedModel<Object>>(BuildContext context, { Object? aspect }) {
    if (aspect == null) {
      return context.dependOnInheritedWidgetOfExactType<T>();
    }

    // Create a dependency on all of the type T ancestor models up until
    // a model is found for which isSupportedAspect(aspect) is true.
    final List<InheritedElement> models = <InheritedElement>[];
    _findModels<T>(context, aspect, models);
    if (models.isEmpty) {
      return null;
    }

    final InheritedElement lastModel = models.last;
    for (final InheritedElement model in models) {
      final T value = context.dependOnInheritedElement(model, aspect: aspect) as T;
      if (model == lastModel) {
        return value;
      }
    }

    assert(false);
    return null;
  }
}

class InheritedModelElement<T> extends InheritedElement {
  InheritedModelElement(InheritedModel<T> super.widget);

  @override
  void updateDependencies(Element dependent, Object? aspect) {
    final Set<T>? dependencies = getDependencies(dependent) as Set<T>?;
    if (dependencies != null && dependencies.isEmpty) {
      return;
    }

    if (aspect == null) {
      setDependencies(dependent, HashSet<T>());
    } else {
      assert(aspect is T);
      setDependencies(dependent, (dependencies ?? HashSet<T>())..add(aspect as T));
    }
  }

  @override
  void notifyDependent(InheritedModel<T> oldWidget, Element dependent) {
    final Set<T>? dependencies = getDependencies(dependent) as Set<T>?;
    if (dependencies == null) {
      return;
    }
    if (dependencies.isEmpty || (widget as InheritedModel<T>).updateShouldNotifyDependent(oldWidget, dependencies)) {
      dependent.didChangeDependencies();
    }
  }
}