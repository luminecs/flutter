import '../../globals.dart' as globals;

String generateFlutterJsFile(String fileGeneratorsPath) {
  final String flutterJsPath = globals.localFileSystem.path.join(
    fileGeneratorsPath,
    'js',
    'flutter.js',
  );
  return globals.localFileSystem.file(flutterJsPath).readAsStringSync();
}
