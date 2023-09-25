
import 'package:archive/archive.dart';

import '../base/file_system.dart';
import '../base/version.dart';
import '../convert.dart';
import '../doctor_validator.dart';

class IntelliJPlugins {
  IntelliJPlugins(this.pluginsPath, {
    required FileSystem fileSystem
  }) : _fileSystem = fileSystem;

  final FileSystem _fileSystem;
  final String pluginsPath;

  static final Version kMinFlutterPluginVersion = Version(16, 0, 0);
  static const String kIntellijDartPluginUrl = 'https://plugins.jetbrains.com/plugin/6351-dart';
  static const String kIntellijFlutterPluginUrl = 'https://plugins.jetbrains.com/plugin/9212-flutter';

  void validatePackage(
    List<ValidationMessage> messages,
    List<String> packageNames,
    String title,
    String url, {
    Version? minVersion,
  }) {
    for (final String packageName in packageNames) {
      if (!_hasPackage(packageName)) {
        continue;
      }

      final String? versionText = _readPackageVersion(packageName);
      final Version? version = Version.parse(versionText);
      if (version != null && minVersion != null && version < minVersion) {
        messages.add(ValidationMessage.error(
          '$title plugin version $versionText - the recommended minimum version is $minVersion'),
        );
      } else {
        messages.add(ValidationMessage(
          '$title plugin ${version != null ? "version $version" : "installed"}'),
        );
      }
      return;
    }
    messages.add(ValidationMessage(
      '$title plugin can be installed from:',
      contextUrl: url,
    ));
  }

  bool _hasPackage(String packageName) {
    final String packagePath = _fileSystem.path.join(pluginsPath, packageName);
    if (packageName.endsWith('.jar')) {
      return _fileSystem.isFileSync(packagePath);
    }
    return _fileSystem.isDirectorySync(packagePath);
  }

  ArchiveFile? _findPluginXml(String packageName) {
    final List<File> mainJarFileList = <File>[];
    if (packageName.endsWith('.jar')) {
      // package exists (checked in _hasPackage)
      mainJarFileList.add(_fileSystem.file(_fileSystem.path.join(pluginsPath, packageName)));
    } else {
      final String packageLibPath =
          _fileSystem.path.join(pluginsPath, packageName, 'lib');
      if (!_fileSystem.isDirectorySync(packageLibPath)) {
        return null;
      }
      // Collect the files with a file suffix of .jar/.zip that contains the plugin.xml file
      final List<File> pluginJarFiles = _fileSystem
          .directory(_fileSystem.path.join(pluginsPath, packageName, 'lib'))
          .listSync()
          .whereType<File>()
          .where((File file) {
            final String fileExt= _fileSystem.path.extension(file.path);
            return fileExt == '.jar' || fileExt == '.zip';
          })
          .toList();

      if (pluginJarFiles.isEmpty) {
        return null;
      }
      // Prefer file with the same suffix as the package name
      pluginJarFiles.sort((File a, File b) {
        final bool aStartWithPackageName =
            a.basename.toLowerCase().startsWith(packageName.toLowerCase());
        final bool bStartWithPackageName =
            b.basename.toLowerCase().startsWith(packageName.toLowerCase());
        if (bStartWithPackageName != aStartWithPackageName) {
          return bStartWithPackageName ? 1 : -1;
        }
        return a.basename.length - b.basename.length;
      });
      mainJarFileList.addAll(pluginJarFiles);
    }

    for (final File file in mainJarFileList) {
      final Archive archive = ZipDecoder().decodeBytes(file.readAsBytesSync());
      final ArchiveFile? archiveFile = archive.findFile('META-INF/plugin.xml');
      if (archiveFile != null) {
        return archiveFile;
      }
    }
    return null;
  }

  String? _readPackageVersion(String packageName) {
    try {
      final ArchiveFile? archiveFile = _findPluginXml(packageName);
      if (archiveFile == null) {
        return null;
      }
      final String content = utf8.decode(archiveFile.content as List<int>);
      const String versionStartTag = '<version>';
      final int start = content.indexOf(versionStartTag);
      final int end = content.indexOf('</version>', start);
      return content.substring(start + versionStartTag.length, end);
    } on ArchiveException {
      return null;
    }
  }
}