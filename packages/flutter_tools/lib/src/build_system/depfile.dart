
import '../base/error_handling_io.dart';
import '../base/file_system.dart';
import '../base/logger.dart';

class DepfileService {
  DepfileService({
    required Logger logger,
    required FileSystem fileSystem,
  }) : _logger = logger,
       _fileSystem = fileSystem;

  final Logger _logger;
  final FileSystem _fileSystem;
  static final RegExp _separatorExpr = RegExp(r'([^\\]) ');
  static final RegExp _escapeExpr = RegExp(r'\\(.)');

  void writeToFile(Depfile depfile, File output, {bool writeEmpty = false}) {
    if (depfile.inputs.isEmpty && depfile.outputs.isEmpty && !writeEmpty) {
      ErrorHandlingFileSystem.deleteIfExists(output);
      return;
    }
    final StringBuffer buffer = StringBuffer();
    _writeFilesToBuffer(depfile.outputs, buffer);
    buffer.write(': ');
    _writeFilesToBuffer(depfile.inputs, buffer);
    output.writeAsStringSync(buffer.toString());
  }

  Depfile parse(File file) {
    final String contents = file.readAsStringSync();
    final List<String> colonSeparated = contents.split(': ');
    if (colonSeparated.length != 2) {
      _logger.printError('Invalid depfile: ${file.path}');
      return const Depfile(<File>[], <File>[]);
    }
    final List<File> inputs = _processList(colonSeparated[1].trim());
    final List<File> outputs = _processList(colonSeparated[0].trim());
    return Depfile(inputs, outputs);
  }


  Depfile parseDart2js(File file, File output) {
    final List<File> inputs = <File>[];
    for (final String rawUri in file.readAsLinesSync()) {
      if (rawUri.trim().isEmpty) {
        continue;
      }
      final Uri? fileUri = Uri.tryParse(rawUri);
      if (fileUri == null) {
        continue;
      }
      if (fileUri.scheme != 'file') {
        continue;
      }
      inputs.add(_fileSystem.file(fileUri));
    }
    return Depfile(inputs, <File>[output]);
  }

  void _writeFilesToBuffer(List<File> files, StringBuffer buffer) {
    for (final File outputFile in files) {
      if (_fileSystem.path.style.separator == r'\') {
        // backslashes and spaces in a depfile have to be escaped if the
        // platform separator is a backslash.
        final String path = outputFile.path
          .replaceAll(r'\', r'\\')
          .replaceAll(r' ', r'\ ');
        buffer.write(' $path');
      } else {
        final String path = outputFile.path
          .replaceAll(r' ', r'\ ');
        buffer.write(' $path');
      }
    }
  }

  List<File> _processList(String rawText) {
    return rawText
    // Put every file on right-hand side on the separate line
        .replaceAllMapped(_separatorExpr, (Match match) => '${match.group(1)}\n')
        .split('\n')
    // Expand escape sequences, so that '\ ', for example,ß becomes ' '
        .map<String>((String path) => path.replaceAllMapped(_escapeExpr, (Match match) => match.group(1)!).trim())
        .where((String path) => path.isNotEmpty)
    // The tool doesn't write duplicates to these lists. This call is an attempt to
    // be resilient to the outputs of other tools which write or user edits to depfiles.
        .toSet()
        .map(_fileSystem.file)
        .toList();
  }
}

class Depfile {
  const Depfile(this.inputs, this.outputs);

  final List<File> inputs;

  final List<File> outputs;
}