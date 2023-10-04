import 'package:flutter/widgets.dart';

void main() {
  // Changes made in https://github.com/flutter/flutter/pull/44189
  const Element element = Element(myWidget);
  element.inheritFromElement(ancestor);
  element.inheritFromWidgetOfExactType(targetType);
  element.ancestorInheritedElementForWidgetOfExactType(targetType);
  element.ancestorWidgetOfExactType(targetType);
  element.ancestorStateOfType(TypeMatcher<targetType>());
  element.rootAncestorStateOfType(TypeMatcher<targetType>());
  element.ancestorRenderObjectOfType(TypeMatcher<targetType>());
}
