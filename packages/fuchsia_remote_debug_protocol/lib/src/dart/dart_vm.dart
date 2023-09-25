import 'dart:async';
import 'dart:io';

import 'package:vm_service/vm_service.dart' as vms;

import '../common/logging.dart';

const Duration _kConnectTimeout = Duration(seconds: 3);
final Logger _log = Logger('DartVm');

typedef RpcPeerConnectionFunction = Future<vms.VmService> Function(
  Uri uri, {
  required Duration timeout,
});

RpcPeerConnectionFunction fuchsiaVmServiceConnectionFunction = _waitAndConnect;

Future<vms.VmService> _waitAndConnect(
  Uri uri, {
  Duration timeout = _kConnectTimeout,
}) async {
  int attempts = 0;
  late WebSocket socket;
  while (true) {
    try {
      socket = await WebSocket.connect(uri.toString());
      final StreamController<dynamic> controller = StreamController<dynamic>();
      final Completer<void> streamClosedCompleter = Completer<void>();
      socket.listen(
        (dynamic data) => controller.add(data),
        onDone: () => streamClosedCompleter.complete(),
      );
      final vms.VmService service = vms.VmService(
        controller.stream,
        socket.add,
        disposeHandler: () => socket.close(),
        streamClosed: streamClosedCompleter.future
      );
      // This call is to ensure we are able to establish a connection instead of
      // keeping on trucking and failing farther down the process.
      await service.getVersion();
      return service;
    } catch (e) {
      // We should not be catching all errors arbitrarily here, this might hide real errors.
      // TODO(ianh): Determine which exceptions to catch here.
      await socket.close();
      if (attempts > 5) {
        _log.warning('It is taking an unusually long time to connect to the VM...');
      }
      attempts += 1;
      await Future<void>.delayed(timeout);
    }
  }
}

void restoreVmServiceConnectionFunction() {
  fuchsiaVmServiceConnectionFunction = _waitAndConnect;
}

class RpcFormatError extends Error {
  RpcFormatError(this.message);

  final String message;

  @override
  String toString() {
    return '$RpcFormatError: $message\n${super.stackTrace}';
  }
}

class DartVm {
  DartVm._(this._vmService, this.uri);

  final vms.VmService _vmService;

  final Uri uri;

  static Future<DartVm> connect(
    Uri uri, {
    Duration timeout = _kConnectTimeout,
  }) async {
    if (uri.scheme == 'http') {
      uri = uri.replace(scheme: 'ws', path: '/ws');
    }

    final vms.VmService service = await fuchsiaVmServiceConnectionFunction(uri, timeout: timeout);
    return DartVm._(service, uri);
  }

  Future<List<IsolateRef>> getMainIsolatesByPattern(Pattern pattern) async {
    final vms.VM vmRef = await _vmService.getVM();
    final List<IsolateRef> result = <IsolateRef>[];
    for (final vms.IsolateRef isolateRef in vmRef.isolates!) {
      if (pattern.matchAsPrefix(isolateRef.name!) != null) {
        _log.fine('Found Isolate matching "$pattern": "${isolateRef.name}"');
        result.add(IsolateRef._fromJson(isolateRef.json!, this));
      }
    }
    return result;
  }


  Future<List<FlutterView>> getAllFlutterViews() async {
    final List<FlutterView> views = <FlutterView>[];
    final vms.Response rpcResponse = await _vmService.callMethod('_flutter.listViews');
    for (final Map<String, dynamic> jsonView in (rpcResponse.json!['views'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      views.add(FlutterView._fromJson(jsonView));
    }
    return views;
  }

  Future<void> ping() async {
    final vms.Version version = await _vmService.getVersion();
    _log.fine('DartVM($uri) version check result: $version');
  }

  Future<void> stop() async {
    await _vmService.dispose();
    await _vmService.onDone;
  }
}

class FlutterView {
  FlutterView._(this._name, this._id);

  factory FlutterView._fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? isolate = json['isolate'] as Map<String, dynamic>?;
    final String? id = json['id'] as String?;
    String? name;
    if (id == null) {
      throw RpcFormatError(
          'Unable to find view name for the following JSON structure "$json"');
    }
    if (isolate != null) {
      name = isolate['name'] as String?;
      if (name == null) {
        throw RpcFormatError('Unable to find name for isolate "$isolate"');
      }
    }
    return FlutterView._(name, id);
  }

  final String? _name;

  final String _id;

  String get id => _id;

  String? get name => _name;
}

class IsolateRef {
  IsolateRef._(this.name, this.number, this.dartVm);

  factory IsolateRef._fromJson(Map<String, dynamic> json, DartVm dartVm) {
    final String? number = json['number'] as String?;
    final String? name = json['name'] as String?;
    final String? type = json['type'] as String?;
    if (type == null) {
      throw RpcFormatError('Unable to find type within JSON "$json"');
    }
    if (type != '@Isolate') {
      throw RpcFormatError('Type "$type" does not match for IsolateRef');
    }
    if (number == null) {
      throw RpcFormatError(
          'Unable to find number for isolate ref within JSON "$json"');
    }
    if (name == null) {
      throw RpcFormatError(
          'Unable to find name for isolate ref within JSON "$json"');
    }
    return IsolateRef._(name, int.parse(number), dartVm);
  }

  final String name;

  final int number;

  final DartVm dartVm;
}