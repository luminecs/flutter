import 'package:convert/convert.dart';
import 'package:crypto/crypto.dart';

import '../convert.dart';
import '../persistent_tool_state.dart';

const String _kFlutterFirstRunMessage = '''
  ╔════════════════════════════════════════════════════════════════════════════╗
  ║                 Welcome to Flutter! - https://flutter.dev                  ║
  ║                                                                            ║
  ║ The Flutter tool uses Google Analytics to anonymously report feature usage ║
  ║ statistics and basic crash reports. This data is used to help improve      ║
  ║ Flutter tools over time.                                                   ║
  ║                                                                            ║
  ║ Flutter tool analytics are not sent on the very first run. To disable      ║
  ║ reporting, type 'flutter config --no-analytics'. To display the current    ║
  ║ setting, type 'flutter config'. If you opt out of analytics, an opt-out    ║
  ║ event will be sent, and then no further information will be sent by the    ║
  ║ Flutter tool.                                                              ║
  ║                                                                            ║
  ║ By downloading the Flutter SDK, you agree to the Google Terms of Service.  ║
  ║ The Google Privacy Policy describes how data is handled in this service.   ║
  ║                                                                            ║
  ║ Moreover, Flutter includes the Dart SDK, which may send usage metrics and  ║
  ║ crash reports to Google.                                                   ║
  ║                                                                            ║
  ║ Read about data we send with crash reports:                                ║
  ║ https://flutter.dev/docs/reference/crash-reporting                         ║
  ║                                                                            ║
  ║ See Google's privacy policy:                                               ║
  ║ https://policies.google.com/privacy                                        ║
  ║                                                                            ║
  ║ To disable animations in this tool, use 'flutter config --no-animations'.  ║
  ╚════════════════════════════════════════════════════════════════════════════╝
''';

class FirstRunMessenger {
  FirstRunMessenger({required PersistentToolState persistentToolState})
      : _persistentToolState = persistentToolState;

  final PersistentToolState _persistentToolState;

  bool shouldDisplayLicenseTerms() {
    if (_persistentToolState.shouldRedisplayWelcomeMessage == false) {
      return false;
    }
    final String? oldHash = _persistentToolState.lastActiveLicenseTermsHash;
    return oldHash != _currentHash;
  }

  void confirmLicenseTermsDisplayed() {
    _persistentToolState.setLastActiveLicenseTermsHash(_currentHash);
  }

  String get _currentHash =>
      hex.encode(md5.convert(utf8.encode(licenseTerms)).bytes);

  String get licenseTerms => _kFlutterFirstRunMessage;
}
