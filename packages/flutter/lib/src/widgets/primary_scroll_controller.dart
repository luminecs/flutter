
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'framework.dart';
import 'scroll_configuration.dart';
import 'scroll_controller.dart';

const Set<TargetPlatform> _kMobilePlatforms = <TargetPlatform>{
  TargetPlatform.android,
  TargetPlatform.iOS,
  TargetPlatform.fuchsia,
};

class PrimaryScrollController extends InheritedWidget {
  const PrimaryScrollController({
    super.key,
    required ScrollController this.controller,
    this.automaticallyInheritForPlatforms = _kMobilePlatforms,
    this.scrollDirection = Axis.vertical,
    required super.child,
  });

  const PrimaryScrollController.none({
    super.key,
    required super.child,
  }) : automaticallyInheritForPlatforms = const <TargetPlatform>{},
       scrollDirection = null,
       controller = null;

  final ScrollController? controller;

  final Axis? scrollDirection;

  final Set<TargetPlatform> automaticallyInheritForPlatforms;

  static bool shouldInherit(BuildContext context, Axis scrollDirection) {
    final PrimaryScrollController? result = context.findAncestorWidgetOfExactType<PrimaryScrollController>();
    if (result == null) {
      return false;
    }

    final TargetPlatform platform = ScrollConfiguration.of(context).getPlatform(context);
    if (result.automaticallyInheritForPlatforms.contains(platform)) {
      return result.scrollDirection == scrollDirection;
    }
    return false;
  }

  static ScrollController? maybeOf(BuildContext context) {
    final PrimaryScrollController? result = context.dependOnInheritedWidgetOfExactType<PrimaryScrollController>();
    return result?.controller;
  }

  static ScrollController of(BuildContext context) {
    final ScrollController? controller = maybeOf(context);
    assert(() {
      if (controller == null) {
        throw FlutterError(
          'PrimaryScrollController.of() was called with a context that does not contain a '
          'PrimaryScrollController widget.\n'
          'No PrimaryScrollController widget ancestor could be found starting from the '
          'context that was passed to PrimaryScrollController.of(). This can happen '
          'because you are using a widget that looks for a PrimaryScrollController '
          'ancestor, but no such ancestor exists.\n'
          'The context used was:\n'
          '  $context',
        );
      }
      return true;
    }());
    return controller!;
  }

  @override
  bool updateShouldNotify(PrimaryScrollController oldWidget) => controller != oldWidget.controller;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DiagnosticsProperty<ScrollController>('controller', controller, ifNull: 'no controller', showName: false));
  }
}