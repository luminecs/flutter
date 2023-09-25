import 'dart:io';

import 'token_logger.dart';

abstract class TokenTemplate {
  const TokenTemplate(this.blockName, this.fileName, this._tokens, {
    this.colorSchemePrefix = 'Theme.of(context).colorScheme.',
    this.textThemePrefix = 'Theme.of(context).textTheme.'
  });

  final String blockName;

  final String fileName;

  final Map<String, dynamic> _tokens;

  final String colorSchemePrefix;

  final String textThemePrefix;

  bool tokenAvailable(String tokenName) => _tokens.containsKey(tokenName);

  dynamic getToken(String tokenName) {
    tokenLogger.log(tokenName);
    return _tokens[tokenName];
  }

  static const String beginGeneratedComment = '''

// BEGIN GENERATED TOKEN PROPERTIES''';

  static const String headerComment = '''

// Do not edit by hand. The code between the "BEGIN GENERATED" and
// "END GENERATED" comments are generated from data in the Material
// Design token database by the script:
//   dev/tools/gen_defaults/bin/gen_defaults.dart.

''';

  static const String endGeneratedComment = '''

// END GENERATED TOKEN PROPERTIES''';

  Future<void> updateFile() async {
    final String contents = File(fileName).readAsStringSync();
    final String beginComment = '$beginGeneratedComment - $blockName\n';
    final String endComment = '$endGeneratedComment - $blockName\n';
    final int beginPreviousBlock = contents.indexOf(beginComment);
    final int endPreviousBlock = contents.indexOf(endComment);
    late String contentBeforeBlock;
    late String contentAfterBlock;
    if (beginPreviousBlock != -1) {
      if (endPreviousBlock < beginPreviousBlock) {
        print('Unable to find block named $blockName in $fileName, skipping code generation.');
        return;
      }
      // Found a valid block matching the name, so record the content before and after.
      contentBeforeBlock = contents.substring(0, beginPreviousBlock);
      contentAfterBlock = contents.substring(endPreviousBlock + endComment.length);
    } else {
      // Just append to the bottom.
      contentBeforeBlock = contents;
      contentAfterBlock = '';
    }

    final StringBuffer buffer = StringBuffer(contentBeforeBlock);
    buffer.write(beginComment);
    buffer.write(headerComment);
    buffer.write(generate());
    buffer.write(endComment);
    buffer.write(contentAfterBlock);
    File(fileName).writeAsStringSync(buffer.toString());
  }

  String generate();

  String color(String colorToken, [String defaultValue = 'null']) {
    return tokenAvailable(colorToken)
      ? '$colorSchemePrefix${getToken(colorToken)}'
      : defaultValue;
  }

  String? colorOrTransparent(String token) => color(token, 'Colors.transparent');

  String componentColor(String componentToken) {
    final String colorToken = '$componentToken.color';
    if (!tokenAvailable(colorToken)) {
      return 'null';
    }
    String value = color(colorToken);
    final String opacityToken = '$componentToken.opacity';
    if (tokenAvailable(opacityToken)) {
      value += '.withOpacity(${opacity(opacityToken)})';
    }
    return value;
  }

  String? opacity(String token) {
    tokenLogger.log(token);
    return _numToString(getToken(token));
  }

  String? _numToString(Object? value, [int? digits]) {
    if (value == null) {
      return null;
    }
    if (value is num) {
      if (value == double.infinity) {
        return 'double.infinity';
      }
      return digits == null ? value.toString() : value.toStringAsFixed(digits);
    }
    return getToken(value as String).toString();
  }

  String elevation(String componentToken) {
    return getToken(getToken('$componentToken.elevation')! as String)!.toString();
  }

  String size(String componentToken) {
    final String sizeToken = '$componentToken.size';
    if (!tokenAvailable(sizeToken)) {
      final String widthToken = '$componentToken.width';
      final String heightToken = '$componentToken.height';
      if (!tokenAvailable(widthToken) && !tokenAvailable(heightToken)) {
        throw Exception('Unable to find width, height, or size tokens for $componentToken');
      }
      final String? width = _numToString(tokenAvailable(widthToken) ? getToken(widthToken)! as num : double.infinity, 0);
      final String? height = _numToString(tokenAvailable(heightToken) ? getToken(heightToken)! as num : double.infinity, 0);
      return 'const Size($width, $height)';
    }
    return 'const Size.square(${_numToString(getToken(sizeToken))})';
  }

  String shape(String componentToken, [String prefix = 'const ']) {

    final Map<String, dynamic> shape = getToken(getToken('$componentToken.shape') as String) as Map<String, dynamic>;
    switch (shape['family']) {
      case 'SHAPE_FAMILY_ROUNDED_CORNERS':
        final double topLeft = shape['topLeft'] as double;
        final double topRight = shape['topRight'] as double;
        final double bottomLeft = shape['bottomLeft'] as double;
        final double bottomRight = shape['bottomRight'] as double;
        if (topLeft == topRight && topLeft == bottomLeft && topLeft == bottomRight) {
          if (topLeft == 0) {
            return '${prefix}RoundedRectangleBorder()';
          }
          return '${prefix}RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular($topLeft)))';
        }
        if (topLeft == topRight && bottomLeft == bottomRight) {
          return '${prefix}RoundedRectangleBorder(borderRadius: BorderRadius.vertical('
            '${topLeft > 0 ? 'top: Radius.circular($topLeft)':''}'
            '${topLeft > 0 && bottomLeft > 0 ? ',':''}'
            '${bottomLeft > 0 ? 'bottom: Radius.circular($bottomLeft)':''}'
            '))';
        }
        return '${prefix}RoundedRectangleBorder(borderRadius: '
          'BorderRadius.only('
          'topLeft: Radius.circular(${shape['topLeft']}), '
          'topRight: Radius.circular(${shape['topRight']}), '
          'bottomLeft: Radius.circular(${shape['bottomLeft']}), '
          'bottomRight: Radius.circular(${shape['bottomRight']})))';
    case 'SHAPE_FAMILY_CIRCULAR':
        return '${prefix}StadiumBorder()';
    }
    print('Unsupported shape family type: ${shape['family']} for $componentToken');
    return '';
  }

  String border(String componentToken) {

    if (!tokenAvailable('$componentToken.color')) {
      return 'null';
    }
    final String borderColor = componentColor(componentToken);
    final double width = (getToken('$componentToken.width') ?? getToken('$componentToken.height') ?? 1.0) as double;
    return 'BorderSide(color: $borderColor${width != 1.0 ? ", width: $width" : ""})';
  }

  String textStyle(String componentToken) {

    return '$textThemePrefix${getToken("$componentToken.text-style")}';
  }

  String textStyleWithColor(String componentToken) {

    if (!tokenAvailable('$componentToken.text-style')) {
      return 'null';
    }
    String style = textStyle(componentToken);
    if (tokenAvailable('$componentToken.color')) {
      style = '$style?.copyWith(color: ${componentColor(componentToken)})';
    }
    return style;
  }
}