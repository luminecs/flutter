
// ignore_for_file: prefer_const_constructors_in_immutables
// ignore_for_file: avoid_unused_constructor_parameters

import 'framework.dart';
import 'platform_view.dart';

extension HtmlElementViewImpl on HtmlElementView {
  static HtmlElementView createFromTagName({
    Key? key,
    required String tagName,
    bool isVisible = true,
    ElementCreatedCallback? onElementCreated,
  }) {
    throw UnimplementedError('HtmlElementView is only available on Flutter Web');
  }

  Widget buildImpl(BuildContext context) {
    throw UnimplementedError('HtmlElementView is only available on Flutter Web');
  }
}