
import '../base/process.dart';

import 'fuchsia_device.dart';
import 'fuchsia_pm.dart';

class FuchsiaPkgctl {
  Future<bool> addRepo(
      FuchsiaDevice device, FuchsiaPackageServer server) async {
    final String localIp = await device.hostAddress;
    final String configUrl = 'http://[$localIp]:${server.port}/config.json';
    final RunResult result =
        await device.shell('pkgctl repo add url -n ${server.name} $configUrl');
    return result.exitCode == 0;
  }

  Future<bool> rmRepo(FuchsiaDevice device, FuchsiaPackageServer server) async {
    final RunResult result = await device.shell(
      'pkgctl repo rm fuchsia-pkg://${server.name}',
    );
    return result.exitCode == 0;
  }

  Future<bool> resolve(
    FuchsiaDevice device,
    String serverName,
    String packageName,
  ) async {
    final String packageUrl = 'fuchsia-pkg://$serverName/$packageName';
    final RunResult result = await device.shell('pkgctl resolve $packageUrl');
    return result.exitCode == 0;
  }
}