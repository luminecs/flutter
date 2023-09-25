// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:process/process.dart';

import 'common/logging.dart';
import 'common/network.dart';
import 'dart/dart_vm.dart';
import 'runners/ssh_command_runner.dart';

final String _ipv4Loopback = InternetAddress.loopbackIPv4.address;

final String _ipv6Loopback = InternetAddress.loopbackIPv6.address;

const ProcessManager _processManager = LocalProcessManager();

const Duration _kIsolateFindTimeout = Duration(minutes: 1);

const Duration _kDartVmConnectionTimeout = Duration(seconds: 9);

const Duration _kVmPollInterval = Duration(milliseconds: 1500);

final Logger _log = Logger('FuchsiaRemoteConnection');

typedef PortForwardingFunction = Future<PortForwarder> Function(
  String address,
  int remotePort, [
  String? interface,
  String? configFile,
]);

PortForwardingFunction fuchsiaPortForwardingFunction = _SshPortForwarder.start;

void restoreFuchsiaPortForwardingFunction() {
  fuchsiaPortForwardingFunction = _SshPortForwarder.start;
}

class FuchsiaRemoteConnectionError extends Error {
  FuchsiaRemoteConnectionError(this.message);

  final String message;

  @override
  String toString() {
    return '$FuchsiaRemoteConnectionError: $message';
  }
}

enum DartVmEventType {
  started,

  stopped,
}

class DartVmEvent {
  DartVmEvent._({required this.eventType, required this.servicePort, required this.uri});

  final Uri uri;

  final DartVmEventType eventType;

  final int servicePort;
}

class FuchsiaRemoteConnection {
  FuchsiaRemoteConnection._(this._useIpV6, this._sshCommandRunner)
    : _pollDartVms = false;

  bool _pollDartVms;
  final List<PortForwarder> _forwardedVmServicePorts = <PortForwarder>[];
  final SshCommandRunner _sshCommandRunner;
  final bool _useIpV6;

  final Map<int, PortForwarder> _dartVmPortMap = <int, PortForwarder>{};

  final Set<int> _stalePorts = <int>{};

  Stream<DartVmEvent> get onDartVmEvent => _onDartVmEvent;
  late Stream<DartVmEvent> _onDartVmEvent;
  final StreamController<DartVmEvent> _dartVmEventController =
      StreamController<DartVmEvent>();

  final Map<Uri, DartVm?> _dartVmCache = <Uri, DartVm?>{};

  static Future<FuchsiaRemoteConnection> connectWithSshCommandRunner(SshCommandRunner commandRunner) async {
    final FuchsiaRemoteConnection connection = FuchsiaRemoteConnection._(
        isIpV6Address(commandRunner.address), commandRunner);
    await connection._forwardOpenPortsToDeviceServicePorts();

    Stream<DartVmEvent> dartVmStream() {
      Future<void> listen() async {
        while (connection._pollDartVms) {
          await connection._pollVms();
          await Future<void>.delayed(_kVmPollInterval);
        }
        connection._dartVmEventController.close();
      }

      connection._dartVmEventController.onListen = listen;
      return connection._dartVmEventController.stream.asBroadcastStream();
    }

    connection._onDartVmEvent = dartVmStream();
    return connection;
  }

  static Future<FuchsiaRemoteConnection> connect([
    String? address,
    String interface = '',
    String? sshConfigPath,
  ]) async {
    address ??= Platform.environment['FUCHSIA_DEVICE_URL'];
    sshConfigPath ??= Platform.environment['FUCHSIA_SSH_CONFIG'];
    if (address == null) {
      throw FuchsiaRemoteConnectionError(
          r'No address supplied, and $FUCHSIA_DEVICE_URL not found.');
    }
    const String interfaceDelimiter = '%';
    if (address.contains(interfaceDelimiter)) {
      final List<String> addressAndInterface =
          address.split(interfaceDelimiter);
      address = addressAndInterface[0];
      interface = addressAndInterface[1];
    }

    return FuchsiaRemoteConnection.connectWithSshCommandRunner(
      SshCommandRunner(
        address: address,
        interface: interface,
        sshConfigPath: sshConfigPath,
      ),
    );
  }

  Future<void> stop() async {
    for (final PortForwarder pf in _forwardedVmServicePorts) {
      // Closes VM service first to ensure that the connection is closed cleanly
      // on the target before shutting down the forwarding itself.
      final Uri uri = _getDartVmUri(pf);
      final DartVm? vmService = _dartVmCache[uri];
      _dartVmCache[uri] = null;
      await vmService?.stop();
      await pf.stop();
    }
    for (final PortForwarder pf in _dartVmPortMap.values) {
      final Uri uri = _getDartVmUri(pf);
      final DartVm? vmService = _dartVmCache[uri];
      _dartVmCache[uri] = null;
      await vmService?.stop();
      await pf.stop();
    }
    _dartVmCache.clear();
    _forwardedVmServicePorts.clear();
    _dartVmPortMap.clear();
    _pollDartVms = false;
  }

  Future<List<IsolateRef>> _waitForMainIsolatesByPattern([
    Pattern? pattern,
    Duration timeout = _kIsolateFindTimeout,
    Duration vmConnectionTimeout = _kDartVmConnectionTimeout,
  ]) async {
    final Completer<List<IsolateRef>> completer = Completer<List<IsolateRef>>();
    _onDartVmEvent.listen(
      (DartVmEvent event) async {
        if (event.eventType == DartVmEventType.started) {
          _log.fine('New VM found on port: ${event.servicePort}. Searching '
              'for Isolate: $pattern');
          final DartVm? vmService = await _getDartVm(event.uri);
          // If the VM service is null, set the result to the empty list.
          final List<IsolateRef> result = await vmService?.getMainIsolatesByPattern(pattern!) ?? <IsolateRef>[];
          if (result.isNotEmpty) {
            if (!completer.isCompleted) {
              completer.complete(result);
            } else {
              _log.warning('Found more than one Dart VM containing Isolates '
                  'that match the pattern "$pattern".');
            }
          }
        }
      },
      onDone: () {
        if (!completer.isCompleted) {
          _log.warning('Terminating isolate search for "$pattern"'
              ' before timeout reached.');
        }
      },
    );
    return completer.future.timeout(timeout);
  }

  Future<List<IsolateRef>> getMainIsolatesByPattern(
    Pattern pattern, {
    Duration timeout = _kIsolateFindTimeout,
    Duration vmConnectionTimeout = _kDartVmConnectionTimeout,
  }) async {
    // If for some reason there are no Dart VM's that are alive, wait for one to
    // start with the Isolate in question.
    if (_dartVmPortMap.isEmpty) {
      _log.fine('No live Dart VMs found. Awaiting new VM startup');
      return _waitForMainIsolatesByPattern(
          pattern, timeout, vmConnectionTimeout);
    }
    // Accumulate a list of eventual IsolateRef lists so that they can be loaded
    // simultaneously via Future.wait.
    final List<Future<List<IsolateRef>>> isolates =
        <Future<List<IsolateRef>>>[];
    for (final PortForwarder fp in _dartVmPortMap.values) {
      final DartVm? vmService =
      await _getDartVm(_getDartVmUri(fp), timeout: vmConnectionTimeout);
      if (vmService == null) {
        continue;
      }
      isolates.add(vmService.getMainIsolatesByPattern(pattern));
    }
    final List<IsolateRef> result =
      await Future.wait<List<IsolateRef>>(isolates)
        .timeout(timeout)
        .then<List<IsolateRef>>((List<List<IsolateRef>> listOfLists) {
          final List<List<IsolateRef>> mutableListOfLists =
            List<List<IsolateRef>>.from(listOfLists)
              ..retainWhere((List<IsolateRef> list) => list.isNotEmpty);
          // Folds the list of lists into one flat list.
          return mutableListOfLists.fold<List<IsolateRef>>(
            <IsolateRef>[],
            (List<IsolateRef> accumulator, List<IsolateRef> element) {
              accumulator.addAll(element);
              return accumulator;
            },
          );
        });

    // If no VM instance anywhere has this, it's possible it hasn't spun up
    // anywhere.
    //
    // For the time being one Flutter Isolate runs at a time in each VM, so for
    // now this will wait until the timer runs out or a new Dart VM starts that
    // contains the Isolate in question.
    //
    // TODO(awdavies): Set this up to handle multiple Isolates per Dart VM.
    if (result.isEmpty) {
      _log.fine('No instance of the Isolate found. Awaiting new VM startup');
      return _waitForMainIsolatesByPattern(
          pattern, timeout, vmConnectionTimeout);
    }
    return result;
  }

  Future<List<FlutterView>> getFlutterViews() async {
    if (_dartVmPortMap.isEmpty) {
      return <FlutterView>[];
    }
    final List<List<FlutterView>> flutterViewLists =
        await _invokeForAllVms<List<FlutterView>>((DartVm vmService) async {
      return vmService.getAllFlutterViews();
    });
    final List<FlutterView> results = flutterViewLists.fold<List<FlutterView>>(
        <FlutterView>[], (List<FlutterView> acc, List<FlutterView> element) {
      acc.addAll(element);
      return acc;
    });
    return List<FlutterView>.unmodifiable(results);
  }

  // Calls all Dart VM's, returning a list of results.
  //
  // A side effect of this function is that internally tracked port forwarding
  // will be updated in the event that ports are found to be broken/stale: they
  // will be shut down and removed from tracking.
  Future<List<E>> _invokeForAllVms<E>(
    Future<E> Function(DartVm vmService) vmFunction, [
    bool queueEvents = true,
  ]) async {
    final List<E> result = <E>[];

    // Helper function loop.
    Future<void> shutDownPortForwarder(PortForwarder pf) async {
      await pf.stop();
      _stalePorts.add(pf.remotePort);
      if (queueEvents) {
        _dartVmEventController.add(DartVmEvent._(
          eventType: DartVmEventType.stopped,
          servicePort: pf.remotePort,
          uri: _getDartVmUri(pf),
        ));
      }
    }

    for (final PortForwarder pf in _dartVmPortMap.values) {
      final DartVm? service = await _getDartVm(_getDartVmUri(pf));
      if (service == null) {
        await shutDownPortForwarder(pf);
      } else {
        result.add(await vmFunction(service));
      }
    }
    _stalePorts.forEach(_dartVmPortMap.remove);
    return result;
  }

  Uri _getDartVmUri(PortForwarder pf) {
    String? addr;
    if (pf.openPortAddress == null) {
      addr = _useIpV6 ? '[$_ipv6Loopback]' : _ipv4Loopback;
    } else {
      addr = isIpV6Address(pf.openPortAddress!)
        ? '[${pf.openPortAddress}]'
        : pf.openPortAddress;
    }
    final Uri uri = Uri.http('$addr:${pf.port}', '/');
    return uri;
  }

  Future<DartVm?> _getDartVm(
    Uri uri, {
    Duration timeout = _kDartVmConnectionTimeout,
  }) async {
    if (!_dartVmCache.containsKey(uri)) {
      // When raising an HttpException this means that there is no instance of
      // the Dart VM to communicate with. The TimeoutException is raised when
      // the Dart VM instance is shut down in the middle of communicating.
      try {
        final DartVm dartVm = await DartVm.connect(uri, timeout: timeout);
        _dartVmCache[uri] = dartVm;
      } on HttpException {
        _log.warning('HTTP Exception encountered connecting to new VM');
        return null;
      } on TimeoutException {
        _log.warning('TimeoutException encountered connecting to new VM');
        return null;
      }
    }
    return _dartVmCache[uri];
  }

  Future<void> _pollVms() async {
    await _checkPorts();
    final List<int> servicePorts = await getDeviceServicePorts();
    for (final int servicePort in servicePorts) {
      if (!_stalePorts.contains(servicePort) &&
          !_dartVmPortMap.containsKey(servicePort)) {
        _dartVmPortMap[servicePort] = await fuchsiaPortForwardingFunction(
            _sshCommandRunner.address,
            servicePort,
            _sshCommandRunner.interface,
            _sshCommandRunner.sshConfigPath);

        _dartVmEventController.add(DartVmEvent._(
          eventType: DartVmEventType.started,
          servicePort: servicePort,
          uri: _getDartVmUri(_dartVmPortMap[servicePort]!),
        ));
      }
    }
  }

  Future<void> _checkPorts([ bool queueEvents = true ]) async {
    // Filters out stale ports after connecting. Ignores results.
    await _invokeForAllVms<void>(
      (DartVm vmService) async {
        await vmService.ping();
      },
      queueEvents,
    );
  }

  Future<void> _forwardOpenPortsToDeviceServicePorts() async {
    await stop();
    final List<int> servicePorts = await getDeviceServicePorts();
    final List<PortForwarder?> forwardedVmServicePorts =
      await Future.wait<PortForwarder?>(
        servicePorts.map<Future<PortForwarder?>>((int deviceServicePort) {
          return fuchsiaPortForwardingFunction(
              _sshCommandRunner.address,
              deviceServicePort,
              _sshCommandRunner.interface,
              _sshCommandRunner.sshConfigPath);
        }));

    for (final PortForwarder? pf in forwardedVmServicePorts) {
      // TODO(awdavies): Handle duplicates.
      _dartVmPortMap[pf!.remotePort] = pf;
    }

    // Don't queue events, since this is the initial forwarding.
    await _checkPorts(false);

    _pollDartVms = true;
  }

  List<int> getVmServicePortFromInspectSnapshot(dynamic inspectSnapshot) {
    final List<Map<String, dynamic>> snapshot =
        List<Map<String, dynamic>>.from(inspectSnapshot as List<dynamic>);
    final List<int> ports = <int>[];

    for (final Map<String, dynamic> item in snapshot) {
      if (!item.containsKey('payload') || item['payload'] == null) {
        continue;
      }
      final Map<String, dynamic> payload =
          Map<String, dynamic>.from(item['payload'] as Map<String, dynamic>);

      if (!payload.containsKey('root') || payload['root'] == null) {
        continue;
      }
      final Map<String, dynamic> root =
          Map<String, dynamic>.from(payload['root'] as Map<String, dynamic>);

      if (!root.containsKey('vm_service_port') ||
          root['vm_service_port'] == null) {
        continue;
      }

      final int? port = int.tryParse(root['vm_service_port'] as String);
      if (port != null) {
        ports.add(port);
      }
    }
    return ports;
  }

  Future<List<int>> getDeviceServicePorts() async {
    final List<String> inspectResult = await _sshCommandRunner
        .run("iquery --format json show '**:root:vm_service_port'");
    final dynamic inspectOutputJson = jsonDecode(inspectResult.join('\n'));
    final List<int> ports =
        getVmServicePortFromInspectSnapshot(inspectOutputJson);

    if (ports.length > 1) {
      throw StateError('More than one Flutter observatory port found');
    }
    return ports;
  }
}

abstract class PortForwarder {
  int get port;

  String? get openPortAddress => null;

  int get remotePort;

  Future<void> stop();
}

class _SshPortForwarder implements PortForwarder {
  _SshPortForwarder._(
    this._remoteAddress,
    this._remotePort,
    this._localSocket,
    this._interface,
    this._sshConfigPath,
    this._ipV6,
  );

  final String _remoteAddress;
  final int _remotePort;
  final ServerSocket _localSocket;
  final String? _sshConfigPath;
  final String? _interface;
  final bool _ipV6;

  @override
  int get port => _localSocket.port;

  @override
  String get openPortAddress => _ipV6 ? _ipv6Loopback : _ipv4Loopback;

  @override
  int get remotePort => _remotePort;

  static Future<_SshPortForwarder> start(
    String address,
    int remotePort, [
    String? interface,
    String? sshConfigPath,
  ]) async {
    final bool isIpV6 = isIpV6Address(address);
    final ServerSocket? localSocket = await _createLocalSocket();
    if (localSocket == null || localSocket.port == 0) {
      _log.warning('_SshPortForwarder failed to find a local port for '
          '$address:$remotePort');
      throw StateError('Unable to create a socket or no available ports.');
    }
    // TODO(awdavies): The square-bracket enclosure for using the IPv6 loopback
    // didn't appear to work, but when assigning to the IPv4 loopback device,
    // netstat shows that the local port is actually being used on the IPv6
    // loopback (::1). Therefore, while the IPv4 loopback can be used for
    // forwarding to the destination IPv6 interface, when connecting to the
    // websocket, the IPV6 loopback should be used.
    final String formattedForwardingUrl =
        '${localSocket.port}:$_ipv4Loopback:$remotePort';
    final String targetAddress =
        isIpV6 && interface!.isNotEmpty ? '$address%$interface' : address;
    const String dummyRemoteCommand = 'true';
    final List<String> command = <String>[
      'ssh',
      if (isIpV6) '-6',
      if (sshConfigPath != null)
        ...<String>['-F', sshConfigPath],
      '-nNT',
      '-f',
      '-L',
      formattedForwardingUrl,
      targetAddress,
      dummyRemoteCommand,
    ];
    _log.fine("_SshPortForwarder running '${command.join(' ')}'");
    // Must await for the port forwarding function to completer here, as
    // forwarding must be completed before surfacing VM events (as the user may
    // want to connect immediately after an event is surfaced).
    final ProcessResult processResult = await _processManager.run(command);
    _log.fine("'${command.join(' ')}' exited with exit code "
        '${processResult.exitCode}');
    if (processResult.exitCode != 0) {
      throw StateError('Unable to start port forwarding');
    }
    final _SshPortForwarder result = _SshPortForwarder._(
        address, remotePort, localSocket, interface, sshConfigPath, isIpV6);
    _log.fine('Set up forwarding from ${localSocket.port} '
        'to $address port $remotePort');
    return result;
  }

  @override
  Future<void> stop() async {
    // Cancel the forwarding request. See [start] for commentary about why this
    // uses the IPv4 loopback.
    final String formattedForwardingUrl =
        '${_localSocket.port}:$_ipv4Loopback:$_remotePort';
    final String targetAddress = _ipV6 && _interface!.isNotEmpty
        ? '$_remoteAddress%$_interface'
        : _remoteAddress;
    final String? sshConfigPath = _sshConfigPath;
    final List<String> command = <String>[
      'ssh',
      if (sshConfigPath != null)
        ...<String>['-F', sshConfigPath],
      '-O',
      'cancel',
      '-L',
      formattedForwardingUrl,
      targetAddress,
    ];
    _log.fine(
        'Shutting down SSH forwarding with command: ${command.join(' ')}');
    final ProcessResult result = await _processManager.run(command);
    if (result.exitCode != 0) {
      _log.warning('Command failed:\nstdout: ${result.stdout}'
          '\nstderr: ${result.stderr}');
    }
    _localSocket.close();
  }

  static Future<ServerSocket?> _createLocalSocket() async {
    try {
      return await ServerSocket.bind(_ipv4Loopback, 0);
    } catch (e) {
      // We should not be catching all errors arbitrarily here, this might hide real errors.
      // TODO(ianh): Determine which exceptions to catch here.
      _log.warning('_createLocalSocket failed: $e');
      return null;
    }
  }
}