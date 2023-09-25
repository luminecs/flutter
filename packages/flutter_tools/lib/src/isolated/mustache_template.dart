
import 'package:mustache_template/mustache_template.dart';

import '../base/template.dart';

class MustacheTemplateRenderer extends TemplateRenderer {
  const MustacheTemplateRenderer();

  @override
  String renderString(String template, dynamic context, {bool htmlEscapeValues = false}) {
    return Template(template, htmlEscapeValues: htmlEscapeValues).renderString(context);
  }
}