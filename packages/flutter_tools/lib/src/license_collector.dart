
import 'package:package_config/package_config.dart';

import 'base/file_system.dart';

class LicenseCollector {
  LicenseCollector({
    required FileSystem fileSystem
  }) : _fileSystem = fileSystem;

  final FileSystem _fileSystem;

  static final String licenseSeparator = '\n${'-' * 80}\n';

  LicenseResult obtainLicenses(
    PackageConfig packageConfig,
    Map<String, List<File>> additionalLicenses,
  ) {
    final Map<String, Set<String>> packageLicenses = <String, Set<String>>{};
    final Set<String> allPackages = <String>{};
    final List<File> dependencies = <File>[];

    for (final Package package in packageConfig.packages) {
      final Uri packageUri = package.packageUriRoot;
      if (packageUri.scheme != 'file') {
        continue;
      }
      // First check for NOTICES, then fallback to LICENSE
      File file = _fileSystem.file(packageUri.resolve('../NOTICES'));
      if (!file.existsSync()) {
        file = _fileSystem.file(packageUri.resolve('../LICENSE'));
      }
      if (!file.existsSync()) {
        continue;
      }

      dependencies.add(file);
      final List<String> rawLicenses = file
        .readAsStringSync()
        .split(licenseSeparator);
      for (final String rawLicense in rawLicenses) {
        List<String> packageNames = <String>[];
        String? licenseText;
        if (rawLicenses.length > 1) {
          final int split = rawLicense.indexOf('\n\n');
          if (split >= 0) {
            packageNames = rawLicense.substring(0, split).split('\n');
            licenseText = rawLicense.substring(split + 2);
          }
        }
        if (licenseText == null) {
          packageNames = <String>[package.name];
          licenseText = rawLicense;
        }
        packageLicenses.putIfAbsent(licenseText, () => <String>{}).addAll(packageNames);
        allPackages.addAll(packageNames);
      }
    }

    final List<String> combinedLicensesList = packageLicenses.entries
      .map<String>((MapEntry<String, Set<String>> entry) {
        final List<String> packageNames = entry.value.toList()..sort();
        return '${packageNames.join('\n')}\n\n${entry.key}';
      }).toList();
    combinedLicensesList.sort();

    final List<String> additionalLicenseText = <String>[];
    final List<String> errorMessages = <String>[];
    for (final String package in additionalLicenses.keys) {
      for (final File license in additionalLicenses[package]!) {
        if (!license.existsSync()) {
          errorMessages.add(
            'package $package specified an additional license at ${license.path}, but this file '
            'does not exist.'
          );
          continue;
        }
        dependencies.add(license);
        try {
          additionalLicenseText.add(license.readAsStringSync());
        } on FormatException catch (err) {
          // File has an invalid encoding.
          errorMessages.add(
            'package $package specified an additional license at ${license.path}, but this file '
            'could not be read:\n$err'
          );
        } on FileSystemException catch (err) {
          // File cannot be parsed.
          errorMessages.add(
            'package $package specified an additional license at ${license.path}, but this file '
            'could not be read:\n$err'
          );
        }
      }
    }
    if (errorMessages.isNotEmpty) {
      return LicenseResult(
        combinedLicenses: '',
        dependencies: <File>[],
        errorMessages: errorMessages,
      );
    }

    final String combinedLicenses = combinedLicensesList
      .followedBy(additionalLicenseText)
      .join(licenseSeparator);

    return LicenseResult(
      combinedLicenses: combinedLicenses,
      dependencies: dependencies,
      errorMessages: errorMessages,
    );
  }
}

class LicenseResult {
  const LicenseResult({
    required this.combinedLicenses,
    required this.dependencies,
    required this.errorMessages,
  });

  final String combinedLicenses;

  final List<File> dependencies;

  final List<String> errorMessages;
}