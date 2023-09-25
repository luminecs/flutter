import 'dart:async';

import 'package:meta/meta.dart';
import 'package:multicast_dns/multicast_dns.dart';

import 'base/common.dart';
import 'base/context.dart';
import 'base/io.dart';
import 'base/logger.dart';
import 'build_info.dart';
import 'convert.dart';
import 'device.dart';
import 'reporting/reporting.dart';

class MDnsVmServiceDiscovery {
  MDnsVmServiceDiscovery({
    MDnsClient? mdnsClient,
    MDnsClient? preliminaryMDnsClient,
    required Logger logger,
    required Usage flutterUsage,
  })  : _client = mdnsClient ?? MDnsClient(),
        _preliminaryClient = preliminaryMDnsClient,
        _logger = logger,
        _flutterUsage = flutterUsage;

  final MDnsClient _client;

  // Used when discovering VM services with `queryForAttach` to do a preliminary
  // check for already running services so that results are not cached in _client.
  final MDnsClient? _preliminaryClient;

  final Logger _logger;
  final Usage _flutterUsage;

  @visibleForTesting
  static const String dartVmServiceName = '_dartVmService._tcp.local';

  static MDnsVmServiceDiscovery? get instance => context.get<MDnsVmServiceDiscovery>();

  @visibleForTesting
  Future<MDnsVmServiceDiscoveryResult?> queryForAttach({
    String? applicationId,
    int? deviceVmservicePort,
    bool ipv6 = false,
    bool useDeviceIPAsHost = false,
    Duration timeout = const Duration(minutes: 10),
  }) async {
    // Poll for 5 seconds to see if there are already services running.
    // Use a new instance of MDnsClient so results don't get cached in _client.
    // If no results are found, poll for a longer duration to wait for connections.
    // If more than 1 result is found, throw an error since it can't be determined which to pick.
    // If only one is found, return it.
    final List<MDnsVmServiceDiscoveryResult> results = await _pollingVmService(
      _preliminaryClient ?? MDnsClient(),
      applicationId: applicationId,
      deviceVmservicePort: deviceVmservicePort,
      ipv6: ipv6,
      useDeviceIPAsHost: useDeviceIPAsHost,
      timeout: const Duration(seconds: 5),
    );
    if (results.isEmpty) {
      return firstMatchingVmService(
        _client,
        applicationId: applicationId,
        deviceVmservicePort: deviceVmservicePort,
        ipv6: ipv6,
        useDeviceIPAsHost: useDeviceIPAsHost,
        timeout: timeout,
      );
    } else if (results.length > 1) {
      final StringBuffer buffer = StringBuffer();
      buffer.writeln('There are multiple Dart VM Services available.');
      buffer.writeln('Rerun this command with one of the following passed in as the app-id and device-vmservice-port:');
      buffer.writeln();
      for (final MDnsVmServiceDiscoveryResult result in results) {
        buffer.writeln(
            '  flutter attach --app-id "${result.domainName.replaceAll('.$dartVmServiceName', '')}" --device-vmservice-port ${result.port}');
      }
      throwToolExit(buffer.toString());
    }
    return results.first;
  }

  @visibleForTesting
  Future<MDnsVmServiceDiscoveryResult?> queryForLaunch({
    required String applicationId,
    int? deviceVmservicePort,
    String? deviceName,
    bool ipv6 = false,
    bool useDeviceIPAsHost = false,
    Duration timeout = const Duration(minutes: 10),
  }) async {
    // Either the device port or the device name must be provided.
    assert(deviceVmservicePort != null || deviceName != null);

    // Query for a specific application matching on either device port or device name.
    return firstMatchingVmService(
      _client,
      applicationId: applicationId,
      deviceVmservicePort: deviceVmservicePort,
      deviceName: deviceName,
      ipv6: ipv6,
      useDeviceIPAsHost: useDeviceIPAsHost,
      timeout: timeout,
    );
  }

  @visibleForTesting
  Future<MDnsVmServiceDiscoveryResult?> firstMatchingVmService(
    MDnsClient client, {
    String? applicationId,
    int? deviceVmservicePort,
    String? deviceName,
    bool ipv6 = false,
    bool useDeviceIPAsHost = false,
    Duration timeout = const Duration(minutes: 10),
  }) async {
    final List<MDnsVmServiceDiscoveryResult> results = await _pollingVmService(
      client,
      applicationId: applicationId,
      deviceVmservicePort: deviceVmservicePort,
      deviceName: deviceName,
      ipv6: ipv6,
      useDeviceIPAsHost: useDeviceIPAsHost,
      timeout: timeout,
      quitOnFind: true,
    );
    if (results.isEmpty) {
      return null;
    }
    return results.first;
  }

  Future<List<MDnsVmServiceDiscoveryResult>> _pollingVmService(
    MDnsClient client, {
    String? applicationId,
    int? deviceVmservicePort,
    String? deviceName,
    bool ipv6 = false,
    bool useDeviceIPAsHost = false,
    required Duration timeout,
    bool quitOnFind = false,
  }) async {
    _logger.printTrace('Checking for advertised Dart VM Services...');
    try {
      await client.start();

      final List<MDnsVmServiceDiscoveryResult> results =
          <MDnsVmServiceDiscoveryResult>[];

      // uniqueDomainNames is used to track all domain names of Dart VM services
      // It is later used in this function to determine whether or not to throw an error.
      // We do not want to throw the error if it was unable to find any domain
      // names because that indicates it may be a problem with mDNS, which has
      // a separate error message in _checkForIPv4LinkLocal.
      final Set<String> uniqueDomainNames = <String>{};
      // uniqueDomainNamesInResults is used to filter out duplicates with exactly
      // the same domain name from the results.
      final Set<String> uniqueDomainNamesInResults = <String>{};

      // Listen for mDNS connections until timeout.
      final Stream<PtrResourceRecord> ptrResourceStream = client.lookup<PtrResourceRecord>(
        ResourceRecordQuery.serverPointer(dartVmServiceName),
        timeout: timeout
      );
      await for (final PtrResourceRecord ptr in ptrResourceStream) {
        uniqueDomainNames.add(ptr.domainName);

        String? domainName;
        if (applicationId != null) {
          // If applicationId is set, only use records that match it
          if (ptr.domainName.toLowerCase().startsWith(applicationId.toLowerCase())) {
            domainName = ptr.domainName;
          } else {
            continue;
          }
        } else {
          domainName = ptr.domainName;
        }

        // Result with same domain name was already found, skip it.
        if (uniqueDomainNamesInResults.contains(domainName)) {
          continue;
        }

        _logger.printTrace('Checking for available port on $domainName');
        final List<SrvResourceRecord> srvRecords = await client
          .lookup<SrvResourceRecord>(
            ResourceRecordQuery.service(domainName),
          )
          .toList();
        if (srvRecords.isEmpty) {
          continue;
        }

        // If more than one SrvResourceRecord found, it should just be a duplicate.
        final SrvResourceRecord srvRecord = srvRecords.first;
        if (srvRecords.length > 1) {
          _logger.printWarning(
              'Unexpectedly found more than one Dart VM Service report for $domainName '
              '- using first one (${srvRecord.port}).');
        }

        // If deviceVmservicePort is set, only use records that match it
        if (deviceVmservicePort != null && srvRecord.port != deviceVmservicePort) {
          continue;
        }

        // If deviceName is set, only use records that match it
        if (deviceName != null && !deviceNameMatchesTargetName(deviceName, srvRecord.target)) {
          continue;
        }

        // Get the IP address of the device if using the IP as the host.
        InternetAddress? ipAddress;
        if (useDeviceIPAsHost) {
          List<IPAddressResourceRecord> ipAddresses = await client
            .lookup<IPAddressResourceRecord>(
              ipv6
                  ? ResourceRecordQuery.addressIPv6(srvRecord.target)
                  : ResourceRecordQuery.addressIPv4(srvRecord.target),
            )
            .toList();
          if (ipAddresses.isEmpty) {
            throwToolExit('Did not find IP for service ${srvRecord.target}.');
          }

          // Filter out link-local addresses.
          if (ipAddresses.length > 1) {
            ipAddresses = ipAddresses.where((IPAddressResourceRecord element) => !element.address.isLinkLocal).toList();
          }

          ipAddress = ipAddresses.first.address;
          if (ipAddresses.length > 1) {
            _logger.printWarning(
                'Unexpectedly found more than one IP for Dart VM Service ${srvRecord.target} '
                '- using first one ($ipAddress).');
          }
        }

        _logger.printTrace('Checking for authentication code for $domainName');
        final List<TxtResourceRecord> txt = await client
          .lookup<TxtResourceRecord>(
              ResourceRecordQuery.text(domainName),
          )
          .toList();

        String authCode = '';
        if (txt.isNotEmpty) {
          authCode = _getAuthCode(txt.first.text);
        }
        results.add(MDnsVmServiceDiscoveryResult(
          domainName,
          srvRecord.port,
          authCode,
          ipAddress: ipAddress
        ));
        uniqueDomainNamesInResults.add(domainName);
        if (quitOnFind) {
          return results;
        }
      }

      // If applicationId is set and quitOnFind is true and no results matching
      // the applicationId were found but other results were found, throw an error.
      if (applicationId != null &&
          quitOnFind &&
          results.isEmpty &&
          uniqueDomainNames.isNotEmpty) {
        String message = 'Did not find a Dart VM Service advertised for $applicationId';
        if (deviceVmservicePort != null) {
          message += ' on port $deviceVmservicePort';
        }
        throwToolExit('$message.');
      }

      return results;
    } finally {
      client.stop();
    }
  }

  @visibleForTesting
  bool deviceNameMatchesTargetName(String deviceName, String targetName) {
    // Remove `.local` from the name along with any non-word, non-digit characters.
    final RegExp cleanedNameRegex = RegExp(r'\.local|\W');
    final String cleanedDeviceName = deviceName.trim().toLowerCase().replaceAll(cleanedNameRegex, '');
    final String cleanedTargetName = targetName.toLowerCase().replaceAll(cleanedNameRegex, '');
    return cleanedDeviceName == cleanedTargetName;
  }

  String _getAuthCode(String txtRecord) {
    const String authCodePrefix = 'authCode=';
    final Iterable<String> matchingRecords =
        LineSplitter.split(txtRecord).where((String record) => record.startsWith(authCodePrefix));
    if (matchingRecords.isEmpty) {
      return '';
    }
    String authCode = matchingRecords.first.substring(authCodePrefix.length);
    // The Dart VM Service currently expects a trailing '/' as part of the
    // URI, otherwise an invalid authentication code response is given.
    if (!authCode.endsWith('/')) {
      authCode += '/';
    }
    return authCode;
  }

  Future<Uri?> getVMServiceUriForAttach(
    String? applicationId,
    Device device, {
    bool usesIpv6 = false,
    int? hostVmservicePort,
    int? deviceVmservicePort,
    bool useDeviceIPAsHost = false,
    Duration timeout = const Duration(minutes: 10),
  }) async {
    final MDnsVmServiceDiscoveryResult? result = await queryForAttach(
      applicationId: applicationId,
      deviceVmservicePort: deviceVmservicePort,
      ipv6: usesIpv6,
      useDeviceIPAsHost: useDeviceIPAsHost,
      timeout: timeout,
    );
    return _handleResult(
      result,
      device,
      applicationId: applicationId,
      deviceVmservicePort: deviceVmservicePort,
      hostVmservicePort: hostVmservicePort,
      usesIpv6: usesIpv6,
      useDeviceIPAsHost: useDeviceIPAsHost
    );
  }

  Future<Uri?> getVMServiceUriForLaunch(
    String applicationId,
    Device device, {
    bool usesIpv6 = false,
    int? hostVmservicePort,
    int? deviceVmservicePort,
    bool useDeviceIPAsHost = false,
    Duration timeout = const Duration(minutes: 10),
  }) async {
    final MDnsVmServiceDiscoveryResult? result = await queryForLaunch(
      applicationId: applicationId,
      deviceVmservicePort: deviceVmservicePort,
      deviceName: deviceVmservicePort == null ? device.name : null,
      ipv6: usesIpv6,
      useDeviceIPAsHost: useDeviceIPAsHost,
      timeout: timeout,
    );
    return _handleResult(
      result,
      device,
      applicationId: applicationId,
      deviceVmservicePort: deviceVmservicePort,
      hostVmservicePort: hostVmservicePort,
      usesIpv6: usesIpv6,
      useDeviceIPAsHost: useDeviceIPAsHost
    );
  }

  Future<Uri?> _handleResult(
    MDnsVmServiceDiscoveryResult? result,
    Device device, {
    String? applicationId,
    int? deviceVmservicePort,
    int? hostVmservicePort,
    bool usesIpv6 = false,
    bool useDeviceIPAsHost = false,
  }) async {
    if (result == null) {
      await _checkForIPv4LinkLocal(device);
      return null;
    }
    final String host;

    final InternetAddress? ipAddress = result.ipAddress;
    if (useDeviceIPAsHost && ipAddress != null) {
      host = ipAddress.address;
    } else {
      host = usesIpv6
      ? InternetAddress.loopbackIPv6.address
      : InternetAddress.loopbackIPv4.address;
    }
    return buildVMServiceUri(
      device,
      host,
      result.port,
      hostVmservicePort,
      result.authCode,
      useDeviceIPAsHost,
    );
  }

  // If there's not an ipv4 link local address in `NetworkInterfaces.list`,
  // then request user interventions with a `printError()` if possible.
  Future<void> _checkForIPv4LinkLocal(Device device) async {
    _logger.printTrace(
      'mDNS query failed. Checking for an interface with a ipv4 link local address.'
    );
    final List<NetworkInterface> interfaces = await listNetworkInterfaces(
      includeLinkLocal: true,
      type: InternetAddressType.IPv4,
    );
    if (_logger.isVerbose) {
      _logInterfaces(interfaces);
    }
    final bool hasIPv4LinkLocal = interfaces.any(
      (NetworkInterface interface) => interface.addresses.any(
        (InternetAddress address) => address.isLinkLocal,
      ),
    );
    if (hasIPv4LinkLocal) {
      _logger.printTrace('An interface with an ipv4 link local address was found.');
      return;
    }
    final TargetPlatform targetPlatform = await device.targetPlatform;
    switch (targetPlatform) {
      case TargetPlatform.ios:
        UsageEvent('ios-mdns', 'no-ipv4-link-local', flutterUsage: _flutterUsage).send();
        _logger.printError(
          'The mDNS query for an attached iOS device failed. It may '
          'be necessary to disable the "Personal Hotspot" on the device, and '
          'to ensure that the "Disable unless needed" setting is unchecked '
          'under System Preferences > Network > iPhone USB. '
          'See https://github.com/flutter/flutter/issues/46698 for details.'
        );
      case TargetPlatform.android:
      case TargetPlatform.android_arm:
      case TargetPlatform.android_arm64:
      case TargetPlatform.android_x64:
      case TargetPlatform.android_x86:
      case TargetPlatform.darwin:
      case TargetPlatform.fuchsia_arm64:
      case TargetPlatform.fuchsia_x64:
      case TargetPlatform.linux_arm64:
      case TargetPlatform.linux_x64:
      case TargetPlatform.tester:
      case TargetPlatform.web_javascript:
      case TargetPlatform.windows_x64:
        _logger.printTrace('No interface with an ipv4 link local address was found.');
    }
  }

  void _logInterfaces(List<NetworkInterface> interfaces) {
    for (final NetworkInterface interface in interfaces) {
      if (_logger.isVerbose) {
        _logger.printTrace('Found interface "${interface.name}":');
        for (final InternetAddress address in interface.addresses) {
          final String linkLocal = address.isLinkLocal ? 'link local' : '';
          _logger.printTrace('\tBound address: "${address.address}" $linkLocal');
        }
      }
    }
  }
}

class MDnsVmServiceDiscoveryResult {
  MDnsVmServiceDiscoveryResult(
    this.domainName,
    this.port,
    this.authCode, {
    this.ipAddress
  });
  final String domainName;
  final int port;
  final String authCode;
  final InternetAddress? ipAddress;
}

Future<Uri> buildVMServiceUri(
  Device device,
  String host,
  int devicePort, [
  int? hostVmservicePort,
  String? authCode,
  bool useDeviceIPAsHost = false,
]) async {
  String path = '/';
  if (authCode != null) {
    path = authCode;
  }
  // Not having a trailing slash can cause problems in some situations.
  // Ensure that there's one present.
  if (!path.endsWith('/')) {
    path += '/';
  }
  hostVmservicePort ??= 0;

  final int? actualHostPort;
  if (useDeviceIPAsHost) {
    // When using the device's IP as the host, port forwarding is not required
    // so just use the device's port.
    actualHostPort = devicePort;
  } else {
    actualHostPort = hostVmservicePort == 0 ?
    await device.portForwarder?.forward(devicePort) :
    hostVmservicePort;
  }
  return Uri(scheme: 'http', host: host, port: actualHostPort, path: path);
}