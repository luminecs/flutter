import 'template.dart';

class DividerTemplate extends TokenTemplate {
  const DividerTemplate(super.blockName, super.fileName, super.tokens);

  @override
  String generate() => '''
class _${blockName}DefaultsM3 extends DividerThemeData {
  const _${blockName}DefaultsM3(this.context) : super(
    space: 16,
    thickness: ${getToken("md.comp.divider.thickness")},
    indent: 0,
    endIndent: 0,
  );

  final BuildContext context;

  @override Color? get color => ${componentColor("md.comp.divider")};
}
''';
}
