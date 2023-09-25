
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';

import 'framework.dart';
import 'notification_listener.dart';
import 'scroll_metrics.dart';

mixin ViewportNotificationMixin on Notification {
  int get depth => _depth;
  int _depth = 0;

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('depth: $depth (${ depth == 0 ? "local" : "remote"})');
  }
}

mixin ViewportElementMixin  on NotifiableElementMixin {
  @override
  bool onNotification(Notification notification) {
    if (notification is ViewportNotificationMixin) {
      notification._depth += 1;
    }
    return false;
  }
}

abstract class ScrollNotification extends LayoutChangedNotification with ViewportNotificationMixin {
  ScrollNotification({
    required this.metrics,
    required this.context,
  });

  final ScrollMetrics metrics;

  final BuildContext? context;

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('$metrics');
  }
}

class ScrollStartNotification extends ScrollNotification {
  ScrollStartNotification({
    required super.metrics,
    required super.context,
    this.dragDetails,
  });

  final DragStartDetails? dragDetails;

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    if (dragDetails != null) {
      description.add('$dragDetails');
    }
  }
}

class ScrollUpdateNotification extends ScrollNotification {
  ScrollUpdateNotification({
    required super.metrics,
    required BuildContext super.context,
    this.dragDetails,
    this.scrollDelta,
    int? depth,
  }) {
    if (depth != null) {
      _depth = depth;
    }
  }

  final DragUpdateDetails? dragDetails;

  final double? scrollDelta;

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('scrollDelta: $scrollDelta');
    if (dragDetails != null) {
      description.add('$dragDetails');
    }
  }
}

class OverscrollNotification extends ScrollNotification {
  OverscrollNotification({
    required super.metrics,
    required BuildContext super.context,
    this.dragDetails,
    required this.overscroll,
    this.velocity = 0.0,
  }) : assert(overscroll.isFinite),
       assert(overscroll != 0.0);

  final DragUpdateDetails? dragDetails;

  final double overscroll;

  final double velocity;

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('overscroll: ${overscroll.toStringAsFixed(1)}');
    description.add('velocity: ${velocity.toStringAsFixed(1)}');
    if (dragDetails != null) {
      description.add('$dragDetails');
    }
  }
}

class ScrollEndNotification extends ScrollNotification {
  ScrollEndNotification({
    required super.metrics,
    required BuildContext super.context,
    this.dragDetails,
  });

  final DragEndDetails? dragDetails;

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    if (dragDetails != null) {
      description.add('$dragDetails');
    }
  }
}

class UserScrollNotification extends ScrollNotification {
  UserScrollNotification({
    required super.metrics,
    required BuildContext super.context,
    required this.direction,
  });

  final ScrollDirection direction;

  @override
  void debugFillDescription(List<String> description) {
    super.debugFillDescription(description);
    description.add('direction: $direction');
  }
}

typedef ScrollNotificationPredicate = bool Function(ScrollNotification notification);

bool defaultScrollNotificationPredicate(ScrollNotification notification) {
  return notification.depth == 0;
}