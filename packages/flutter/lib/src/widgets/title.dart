import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'basic.dart';
import 'framework.dart';

class Title extends StatelessWidget {
  Title({
    super.key,
    this.title = '',
    required this.color,
    required this.child,
  }) : assert(color.alpha == 0xFF);

  final String title;

  final Color color;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    SystemChrome.setApplicationSwitcherDescription(
      ApplicationSwitcherDescription(
        label: title,
        primaryColor: color.value,
      ),
    );
    return child;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(StringProperty('title', title, defaultValue: ''));
    properties.add(ColorProperty('color', color, defaultValue: null));
  }
}