abstract class TemplateRenderer {
  const TemplateRenderer();

  String renderString(String template, dynamic context, {bool htmlEscapeValues = false});
}