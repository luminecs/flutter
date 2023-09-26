import 'package:flutter/rendering.dart';

import 'basic.dart';
import 'framework.dart';
import 'image.dart';

class DecoratedSliver extends SingleChildRenderObjectWidget {
  const DecoratedSliver({
    super.key,
    required this.decoration,
    this.position = DecorationPosition.background,
    Widget? sliver,
  }) : super(child: sliver);

  final Decoration decoration;

  final DecorationPosition position;

  @override
  RenderDecoratedSliver createRenderObject(BuildContext context) {
    return RenderDecoratedSliver(
      decoration: decoration,
      position: position,
      configuration: createLocalImageConfiguration(context),
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderDecoratedSliver renderObject) {
    renderObject
      ..decoration = decoration
      ..position = position
      ..configuration = createLocalImageConfiguration(context);
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    final String label;
    switch (position) {
      case DecorationPosition.background:
        label = 'bg';
      case DecorationPosition.foreground:
        label = 'fg';
    }
    properties.add(EnumProperty<DecorationPosition>('position', position,
        level: DiagnosticLevel.hidden));
    properties.add(DiagnosticsProperty<Decoration>(label, decoration));
  }
}
