import 'package:flutter/rendering.dart';

import 'basic.dart';
import 'framework.dart';

// (We ignore `avoid_implementing_value_types` here because the superclass
// doesn't really implement `operator ==`, it just overrides it to _prevent_ it
// from being implemented, which is the exact opposite of the spirit of the
// `avoid_implementing_value_types` lint.)
// ignore: avoid_implementing_value_types
abstract class PreferredSizeWidget implements Widget {
  Size get preferredSize;
}

class PreferredSize extends StatelessWidget implements PreferredSizeWidget {
  const PreferredSize({
    super.key,
    required this.preferredSize,
    required this.child,
  });

  final Widget child;

  @override
  final Size preferredSize;

  @override
  Widget build(BuildContext context) => child;
}
