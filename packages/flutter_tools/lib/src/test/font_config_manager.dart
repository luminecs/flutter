import 'dart:async';

import '../base/file_system.dart';
import '../globals.dart' as globals;

class FontConfigManager {
  Directory? _fontsDirectory;

  late final File fontConfigFile = () {
    final StringBuffer sb = StringBuffer();
    sb.writeln('<fontconfig>');
    sb.writeln('  <dir>${globals.cache.getCacheArtifacts().path}</dir>');
    sb.writeln('  <cachedir>/var/cache/fontconfig</cachedir>');
    sb.writeln('</fontconfig>');

    if (_fontsDirectory == null) {
      _fontsDirectory =
          globals.fs.systemTempDirectory.createTempSync('flutter_test_fonts.');
      globals.printTrace(
          'Using this directory for fonts configuration: ${_fontsDirectory!.path}');
    }

    final File cachedFontConfig =
        globals.fs.file('${_fontsDirectory!.path}/fonts.conf');
    cachedFontConfig.createSync();
    cachedFontConfig.writeAsStringSync(sb.toString());
    return cachedFontConfig;
  }();

  Future<void> dispose() async {
    if (_fontsDirectory != null) {
      globals.printTrace('Deleting ${_fontsDirectory!.path}...');
      await _fontsDirectory!.delete(recursive: true);
      _fontsDirectory = null;
    }
  }
}
