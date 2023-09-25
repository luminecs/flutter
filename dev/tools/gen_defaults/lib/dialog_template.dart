
import 'template.dart';

class DialogTemplate extends TokenTemplate {
  const DialogTemplate(super.blockName, super.fileName, super.tokens, {
    super.colorSchemePrefix = '_colors.',
    super.textThemePrefix = '_textTheme.'
  });

  @override
  String generate() => '''
class _${blockName}DefaultsM3 extends DialogTheme {
  _${blockName}DefaultsM3(this.context)
    : super(
        alignment: Alignment.center,
        elevation: ${elevation("md.comp.dialog.container")},
        shape: ${shape("md.comp.dialog.container")},
      );

  final BuildContext context;
  late final ColorScheme _colors = Theme.of(context).colorScheme;
  late final TextTheme _textTheme = Theme.of(context).textTheme;

  @override
  Color? get iconColor => _colors.secondary;

  @override
  Color? get backgroundColor => ${componentColor("md.comp.dialog.container")};

  @override
  Color? get shadowColor => ${colorOrTransparent("md.comp.dialog.container.shadow-color")};

  @override
  Color? get surfaceTintColor => ${colorOrTransparent("md.comp.dialog.container.surface-tint-layer.color")};

  @override
  TextStyle? get titleTextStyle => ${textStyle("md.comp.dialog.headline")};

  @override
  TextStyle? get contentTextStyle => ${textStyle("md.comp.dialog.supporting-text")};

  @override
  EdgeInsetsGeometry? get actionsPadding => const EdgeInsets.only(left: 24.0, right: 24.0, bottom: 24.0);
}
''';
}

class DialogFullscreenTemplate extends TokenTemplate {
  const DialogFullscreenTemplate(super.blockName, super.fileName, super.tokens);

  @override
  String generate() => '''
class _${blockName}DefaultsM3 extends DialogTheme {
  const _${blockName}DefaultsM3(this.context);

  final BuildContext context;

  @override
  Color? get backgroundColor => ${componentColor("md.comp.full-screen-dialog.container")};
}
''';
}