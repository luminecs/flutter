// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';

import '_background_isolate_binary_messenger_io.dart'
  if (dart.library.js_util) '_background_isolate_binary_messenger_web.dart';

import 'binary_messenger.dart';
import 'binding.dart';
import 'message_codec.dart';
import 'message_codecs.dart';

export '_background_isolate_binary_messenger_io.dart'
  if (dart.library.js_util) '_background_isolate_binary_messenger_web.dart';

export 'binary_messenger.dart' show BinaryMessenger;
export 'binding.dart' show RootIsolateToken;
export 'message_codec.dart' show MessageCodec, MethodCall, MethodCodec;

const bool kProfilePlatformChannels = false;

bool _profilePlatformChannelsIsRunning = false;
const Duration _profilePlatformChannelsRate = Duration(seconds: 1);
final Expando<BinaryMessenger> _profiledBinaryMessengers = Expando<BinaryMessenger>();

class _ProfiledBinaryMessenger implements BinaryMessenger {
  const _ProfiledBinaryMessenger(this.proxy, this.channelTypeName, this.codecTypeName);
  final BinaryMessenger proxy;
  final String channelTypeName;
  final String codecTypeName;

  @override
  Future<void> handlePlatformMessage(String channel, ByteData? data, PlatformMessageResponseCallback? callback) {
    return proxy.handlePlatformMessage(channel, data, callback);
  }

  Future<ByteData?>? sendWithPostfix(String channel, String postfix, ByteData? message) async {
    _debugRecordUpStream(channelTypeName, '$channel$postfix', codecTypeName, message);
    final TimelineTask timelineTask = TimelineTask()..start('Platform Channel send $channel$postfix');
    final ByteData? result;
    try {
      result = await proxy.send(channel, message);
    } finally {
      timelineTask.finish();
    }
    _debugRecordDownStream(channelTypeName, '$channel$postfix', codecTypeName, result);
    return result;
  }

  @override
  Future<ByteData?>? send(String channel, ByteData? message) =>
    sendWithPostfix(channel, '', message);

  @override
  void setMessageHandler(String channel, MessageHandler? handler) {
    proxy.setMessageHandler(channel, handler);
  }
}

class _PlatformChannelStats {
  _PlatformChannelStats(this.channel, this.codec, this.type);

  final String channel;
  final String codec;
  final String type;

  int _upCount = 0;
  int _upBytes = 0;
  int get upBytes => _upBytes;
  void addUpStream(int bytes) {
    _upCount += 1;
    _upBytes += bytes;
  }

  int _downCount = 0;
  int _downBytes = 0;
  int get downBytes => _downBytes;
  void addDownStream(int bytes) {
    _downCount += 1;
    _downBytes += bytes;
  }

  double get averageUpPayload => _upBytes / _upCount;
  double get averageDownPayload => _downBytes / _downCount;
}

final Map<String, _PlatformChannelStats> _profilePlatformChannelsStats = <String, _PlatformChannelStats>{};

Future<void> _debugLaunchProfilePlatformChannels() async {
  if (!_profilePlatformChannelsIsRunning) {
    _profilePlatformChannelsIsRunning = true;
    await Future<dynamic>.delayed(_profilePlatformChannelsRate);
    _profilePlatformChannelsIsRunning = false;
    final StringBuffer log = StringBuffer();
    log.writeln('Platform Channel Stats:');
    final List<_PlatformChannelStats> allStats =
        _profilePlatformChannelsStats.values.toList();
    // Sort highest combined bandwidth first.
    allStats.sort((_PlatformChannelStats x, _PlatformChannelStats y) =>
        (y.upBytes + y.downBytes) - (x.upBytes + x.downBytes));
    for (final _PlatformChannelStats stats in allStats) {
      log.writeln(
          '  (name:"${stats.channel}" type:"${stats.type}" codec:"${stats.codec}" upBytes:${stats.upBytes} upBytes_avg:${stats.averageUpPayload.toStringAsFixed(1)} downBytes:${stats.downBytes} downBytes_avg:${stats.averageDownPayload.toStringAsFixed(1)})');
    }
    debugPrint(log.toString());
    _profilePlatformChannelsStats.clear();
  }
}

void _debugRecordUpStream(String channelTypeName, String name,
    String codecTypeName, ByteData? bytes) {
  final _PlatformChannelStats stats =
      _profilePlatformChannelsStats[name] ??=
          _PlatformChannelStats(name, codecTypeName, channelTypeName);
  stats.addUpStream(bytes?.lengthInBytes ?? 0);
  _debugLaunchProfilePlatformChannels();
}

void _debugRecordDownStream(String channelTypeName, String name,
    String codecTypeName, ByteData? bytes) {
  final _PlatformChannelStats stats =
      _profilePlatformChannelsStats[name] ??=
          _PlatformChannelStats(name, codecTypeName, channelTypeName);
  stats.addDownStream(bytes?.lengthInBytes ?? 0);
  _debugLaunchProfilePlatformChannels();
}

BinaryMessenger _findBinaryMessenger() {
  return !kIsWeb && ServicesBinding.rootIsolateToken == null
      ? BackgroundIsolateBinaryMessenger.instance
      : ServicesBinding.instance.defaultBinaryMessenger;
}

class BasicMessageChannel<T> {
  const BasicMessageChannel(this.name, this.codec, { BinaryMessenger? binaryMessenger })
      : _binaryMessenger = binaryMessenger;

  final String name;

  final MessageCodec<T> codec;

  BinaryMessenger get binaryMessenger {
    final BinaryMessenger result = _binaryMessenger ?? _findBinaryMessenger();
    return kProfilePlatformChannels
        ? _profiledBinaryMessengers[this] ??= _ProfiledBinaryMessenger(
            // ignore: no_runtimetype_tostring
            result, runtimeType.toString(), codec.runtimeType.toString())
        : result;
  }
  final BinaryMessenger? _binaryMessenger;

  Future<T?> send(T message) async {
    return codec.decodeMessage(await binaryMessenger.send(name, codec.encodeMessage(message)));
  }

  void setMessageHandler(Future<T> Function(T? message)? handler) {
    if (handler == null) {
      binaryMessenger.setMessageHandler(name, null);
    } else {
      binaryMessenger.setMessageHandler(name, (ByteData? message) async {
        return codec.encodeMessage(await handler(codec.decodeMessage(message)));
      });
    }
  }

  // Looking for setMockMessageHandler?
  // See this shim package: packages/flutter_test/lib/src/deprecated.dart
}

@pragma('vm:keep-name')
class MethodChannel {
  const MethodChannel(this.name, [this.codec = const StandardMethodCodec(), BinaryMessenger? binaryMessenger ])
      : _binaryMessenger = binaryMessenger;

  final String name;

  final MethodCodec codec;

  BinaryMessenger get binaryMessenger {
    final BinaryMessenger result = _binaryMessenger ?? _findBinaryMessenger();
    return kProfilePlatformChannels
        ? _profiledBinaryMessengers[this] ??= _ProfiledBinaryMessenger(
            // ignore: no_runtimetype_tostring
            result, runtimeType.toString(), codec.runtimeType.toString())
        : result;
  }
  final BinaryMessenger? _binaryMessenger;

  @optionalTypeArgs
  Future<T?> _invokeMethod<T>(String method, { required bool missingOk, dynamic arguments }) async {
    final ByteData input = codec.encodeMethodCall(MethodCall(method, arguments));
    final ByteData? result =
      kProfilePlatformChannels ?
        await (binaryMessenger as _ProfiledBinaryMessenger).sendWithPostfix(name, '#$method', input) :
        await binaryMessenger.send(name, input);
    if (result == null) {
      if (missingOk) {
        return null;
      }
      throw MissingPluginException('No implementation found for method $method on channel $name');
    }
    return codec.decodeEnvelope(result) as T?;
  }

  @optionalTypeArgs
  Future<T?> invokeMethod<T>(String method, [ dynamic arguments ]) {
    return _invokeMethod<T>(method, missingOk: false, arguments: arguments);
  }

  Future<List<T>?> invokeListMethod<T>(String method, [ dynamic arguments ]) async {
    final List<dynamic>? result = await invokeMethod<List<dynamic>>(method, arguments);
    return result?.cast<T>();
  }

  Future<Map<K, V>?> invokeMapMethod<K, V>(String method, [ dynamic arguments ]) async {
    final Map<dynamic, dynamic>? result = await invokeMethod<Map<dynamic, dynamic>>(method, arguments);
    return result?.cast<K, V>();
  }

  void setMethodCallHandler(Future<dynamic> Function(MethodCall call)? handler) {
    assert(
      _binaryMessenger != null || BindingBase.debugBindingType() != null,
      'Cannot set the method call handler before the binary messenger has been initialized. '
      'This happens when you call setMethodCallHandler() before the WidgetsFlutterBinding '
      'has been initialized. You can fix this by either calling WidgetsFlutterBinding.ensureInitialized() '
      'before this or by passing a custom BinaryMessenger instance to MethodChannel().',
    );
    binaryMessenger.setMessageHandler(
      name,
      handler == null
        ? null
        : (ByteData? message) => _handleAsMethodCall(message, handler),
    );
  }

  Future<ByteData?> _handleAsMethodCall(ByteData? message, Future<dynamic> Function(MethodCall call) handler) async {
    final MethodCall call = codec.decodeMethodCall(message);
    try {
      return codec.encodeSuccessEnvelope(await handler(call));
    } on PlatformException catch (e) {
      return codec.encodeErrorEnvelope(
        code: e.code,
        message: e.message,
        details: e.details,
      );
    } on MissingPluginException {
      return null;
    } catch (error) {
      return codec.encodeErrorEnvelope(code: 'error', message: error.toString());
    }
  }

  // Looking for setMockMethodCallHandler or checkMethodCallHandler?
  // See this shim package: packages/flutter_test/lib/src/deprecated.dart
}

class OptionalMethodChannel extends MethodChannel {
  const OptionalMethodChannel(super.name, [super.codec, super.binaryMessenger]);

  @override
  Future<T?> invokeMethod<T>(String method, [ dynamic arguments ]) async {
    return super._invokeMethod<T>(method, missingOk: true, arguments: arguments);
  }
}

class EventChannel {
  const EventChannel(this.name, [this.codec = const StandardMethodCodec(), BinaryMessenger? binaryMessenger])
      : _binaryMessenger = binaryMessenger;

  final String name;

  final MethodCodec codec;

  BinaryMessenger get binaryMessenger =>
      _binaryMessenger ?? _findBinaryMessenger();
  final BinaryMessenger? _binaryMessenger;

  Stream<dynamic> receiveBroadcastStream([ dynamic arguments ]) {
    final MethodChannel methodChannel = MethodChannel(name, codec);
    late StreamController<dynamic> controller;
    controller = StreamController<dynamic>.broadcast(onListen: () async {
      binaryMessenger.setMessageHandler(name, (ByteData? reply) async {
        if (reply == null) {
          controller.close();
        } else {
          try {
            controller.add(codec.decodeEnvelope(reply));
          } on PlatformException catch (e) {
            controller.addError(e);
          }
        }
        return null;
      });
      try {
        await methodChannel.invokeMethod<void>('listen', arguments);
      } catch (exception, stack) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'services library',
          context: ErrorDescription('while activating platform stream on channel $name'),
        ));
      }
    }, onCancel: () async {
      binaryMessenger.setMessageHandler(name, null);
      try {
        await methodChannel.invokeMethod<void>('cancel', arguments);
      } catch (exception, stack) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'services library',
          context: ErrorDescription('while de-activating platform stream on channel $name'),
        ));
      }
    });
    return controller.stream;
  }
}