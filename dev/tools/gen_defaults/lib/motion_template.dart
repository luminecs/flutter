
import 'template.dart';
import 'token_logger.dart';

class MotionTemplate extends TokenTemplate {
  MotionTemplate(String blockName, String fileName, this.tokens, this.tokensLogger) : super(blockName, fileName, tokens);
  Map<String, dynamic> tokens;
  TokenLogger tokensLogger;

  // List of duration tokens.
  late List<MapEntry<String, dynamic>> durationTokens = tokens.entries.where(
    (MapEntry<String, dynamic> entry) => entry.key.contains('.duration.')
  ).toList()
  ..sort(
    (MapEntry<String, dynamic> a, MapEntry<String, dynamic> b) => (a.value as double).compareTo(b.value as double)
  );

  // List of easing curve tokens.
  late List<MapEntry<String, dynamic>> easingCurveTokens = tokens.entries.where(
    (MapEntry<String, dynamic> entry) => entry.key.contains('.easing.')
  ).toList()
  ..sort(
    // Sort the legacy curves at the end of the list.
    (MapEntry<String, dynamic> a, MapEntry<String, dynamic> b) => a.key.contains('legacy') ? 1 : a.key.compareTo(b.key)
  );

  String durationTokenString(String token, dynamic tokenValue) {
    tokensLogger.log(token);
    final String tokenName = token.split('.').last.replaceAll('-', '').replaceFirst('Ms', '');
    final int milliseconds = (tokenValue as double).toInt();
    return
'''
  static const Duration $tokenName = Duration(milliseconds: $milliseconds);
''';
  }

  String easingCurveTokenString(String token, dynamic tokenValue) {
    tokensLogger.log(token);
    final String tokenName = token
      .replaceFirst('md.sys.motion.easing.', '')
      .replaceAllMapped(RegExp(r'[-\.](\w)'), (Match match) {
        return match.group(1)!.toUpperCase();
      });
    return '''
  static const Curve $tokenName = $tokenValue;
''';
  }

  @override
  String generate() => '''
abstract final class Durations {
${durationTokens.map((MapEntry<String, dynamic> entry) => durationTokenString(entry.key, entry.value)).join('\n')}}


// TODO(guidezpl): Improve with description and assets, b/289870605

abstract final class Easing {
${easingCurveTokens.map((MapEntry<String, dynamic> entry) => easingCurveTokenString(entry.key, entry.value)).join('\n')}}
''';
}