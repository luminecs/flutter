import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

import 'focus_manager.dart';
import 'focus_scope.dart';
import 'framework.dart';
import 'notification_listener.dart';
import 'primary_scroll_controller.dart';
import 'scroll_controller.dart';
import 'scroll_delegate.dart';
import 'scroll_notification.dart';
import 'scroll_physics.dart';
import 'scroll_view.dart';
import 'scrollable.dart';
import 'scrollable_helpers.dart';
import 'two_dimensional_viewport.dart';

abstract class TwoDimensionalScrollView extends StatelessWidget {
  const TwoDimensionalScrollView({
    super.key,
    this.primary,
    this.mainAxis = Axis.vertical,
    this.verticalDetails = const ScrollableDetails.vertical(),
    this.horizontalDetails = const ScrollableDetails.horizontal(),
    required this.delegate,
    this.cacheExtent,
    this.diagonalDragBehavior = DiagonalDragBehavior.none,
    this.dragStartBehavior = DragStartBehavior.start,
    this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.manual,
    this.clipBehavior = Clip.hardEdge,
  });

  final TwoDimensionalChildDelegate delegate;

  final double? cacheExtent;

  final DiagonalDragBehavior diagonalDragBehavior;

  final bool? primary;

  final Axis mainAxis;

  final ScrollableDetails verticalDetails;

  final ScrollableDetails horizontalDetails;

  final DragStartBehavior dragStartBehavior;

  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  final Clip clipBehavior;

  Widget buildViewport(
    BuildContext context,
    ViewportOffset verticalOffset,
    ViewportOffset horizontalOffset,
  );

  @override
  Widget build(BuildContext context) {
    assert(
      axisDirectionToAxis(verticalDetails.direction) == Axis.vertical,
      'TwoDimensionalScrollView.verticalDetails are not Axis.vertical.'
    );
    assert(
      axisDirectionToAxis(horizontalDetails.direction) == Axis.horizontal,
      'TwoDimensionalScrollView.horizontalDetails are not Axis.horizontal.'
    );

    ScrollableDetails mainAxisDetails = switch (mainAxis) {
      Axis.vertical => verticalDetails,
      Axis.horizontal => horizontalDetails,
    };

    final bool effectivePrimary = primary
      ?? mainAxisDetails.controller == null && PrimaryScrollController.shouldInherit(
        context,
        mainAxis,
      );

    if (effectivePrimary) {
      // Using PrimaryScrollController for mainAxis.
      assert(
        mainAxisDetails.controller == null,
        'TwoDimensionalScrollView.primary was explicitly set to true, but a '
        'ScrollController was provided in the ScrollableDetails of the '
        'TwoDimensionalScrollView.mainAxis.'
      );
      mainAxisDetails = mainAxisDetails.copyWith(
        controller: PrimaryScrollController.of(context),
      );
    }

    final TwoDimensionalScrollable scrollable = TwoDimensionalScrollable(
      horizontalDetails : switch (mainAxis) {
        Axis.horizontal => mainAxisDetails,
        Axis.vertical => horizontalDetails,
      },
      verticalDetails: switch (mainAxis) {
        Axis.vertical => mainAxisDetails,
        Axis.horizontal => verticalDetails,
      },
      diagonalDragBehavior: diagonalDragBehavior,
      viewportBuilder: buildViewport,
      dragStartBehavior: dragStartBehavior,
    );

    final Widget scrollableResult = effectivePrimary
      // Further descendant ScrollViews will not inherit the same PrimaryScrollController
      ? PrimaryScrollController.none(child: scrollable)
      : scrollable;

    if (keyboardDismissBehavior == ScrollViewKeyboardDismissBehavior.onDrag) {
      return NotificationListener<ScrollUpdateNotification>(
        child: scrollableResult,
        onNotification: (ScrollUpdateNotification notification) {
          final FocusScopeNode focusScope = FocusScope.of(context);
          if (notification.dragDetails != null && focusScope.hasFocus) {
            focusScope.unfocus();
          }
          return false;
        },
      );
    }
    return scrollableResult;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<Axis>('mainAxis', mainAxis));
    properties.add(EnumProperty<DiagonalDragBehavior>('diagonalDragBehavior', diagonalDragBehavior));
    properties.add(FlagProperty('primary', value: primary, ifTrue: 'using primary controller', showName: true));
    properties.add(DiagnosticsProperty<ScrollableDetails>('verticalDetails', verticalDetails, showName: false));
    properties.add(DiagnosticsProperty<ScrollableDetails>('horizontalDetails', horizontalDetails, showName: false));
  }
}