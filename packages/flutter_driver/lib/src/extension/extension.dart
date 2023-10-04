import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RendererBinding;
import 'package:flutter/scheduler.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../common/deserialization_factory.dart';
import '../common/error.dart';
import '../common/find.dart';
import '../common/handler_factory.dart';
import '../common/message.dart';
import '_extension_io.dart' if (dart.library.html) '_extension_web.dart';

const String _extensionMethodName = 'driver';

typedef DataHandler = Future<String> Function(String? message);

class _DriverBinding extends BindingBase
    with
        SchedulerBinding,
        ServicesBinding,
        GestureBinding,
        PaintingBinding,
        SemanticsBinding,
        RendererBinding,
        WidgetsBinding,
        TestDefaultBinaryMessengerBinding {
  _DriverBinding(this._handler, this._silenceErrors,
      this._enableTextEntryEmulation, this.finders, this.commands);

  final DataHandler? _handler;
  final bool _silenceErrors;
  final bool _enableTextEntryEmulation;
  final List<FinderExtension>? finders;
  final List<CommandExtension>? commands;

  // Because you can't really control which zone a driver test uses,
  // we override the test for zones here.
  @override
  bool debugCheckZone(String entryPoint) {
    return true;
  }

  @override
  void initServiceExtensions() {
    super.initServiceExtensions();
    final FlutterDriverExtension extension = FlutterDriverExtension(
        _handler, _silenceErrors, _enableTextEntryEmulation,
        finders: finders ?? const <FinderExtension>[],
        commands: commands ?? const <CommandExtension>[]);
    registerServiceExtension(
      name: _extensionMethodName,
      callback: extension.call,
    );
    if (kIsWeb) {
      registerWebServiceExtension(extension.call);
    }
  }
}

// Examples can assume:
// import 'package:flutter_driver/flutter_driver.dart';
// import 'package:flutter/widgets.dart';
// import 'package:flutter_driver/driver_extension.dart';
// import 'package:flutter_test/flutter_test.dart' hide find;
// import 'package:flutter_test/flutter_test.dart' as flutter_test;
// typedef MyHomeWidget = Placeholder;
// abstract class SomeWidget extends StatelessWidget { const SomeWidget({super.key, required this.title}); final String title; }
// late FlutterDriver driver;
// abstract class StubNestedCommand { int get times; SerializableFinder get finder; }
// class StubCommandResult extends Result { const StubCommandResult(this.arg); final String arg; @override Map<String, dynamic> toJson() => <String, dynamic>{}; }
// abstract class StubProberCommand { int get times; SerializableFinder get finder; }

void enableFlutterDriverExtension(
    {DataHandler? handler,
    bool silenceErrors = false,
    bool enableTextEntryEmulation = true,
    List<FinderExtension>? finders,
    List<CommandExtension>? commands}) {
  _DriverBinding(handler, silenceErrors, enableTextEntryEmulation,
      finders ?? <FinderExtension>[], commands ?? <CommandExtension>[]);
  assert(WidgetsBinding.instance is _DriverBinding);
}

typedef CommandHandlerCallback = Future<Result?> Function(Command c);

typedef CommandDeserializerCallback = Command Function(
    Map<String, String> params);

abstract class FinderExtension {
  String get finderType;

  SerializableFinder deserialize(
      Map<String, String> params, DeserializeFinderFactory finderFactory);

  Finder createFinder(
      SerializableFinder finder, CreateFinderFactory finderFactory);
}

abstract class CommandExtension {
  String get commandKind;

  Command deserialize(
      Map<String, String> params,
      DeserializeFinderFactory finderFactory,
      DeserializeCommandFactory commandFactory);

  Future<Result> call(Command command, WidgetController prober,
      CreateFinderFactory finderFactory, CommandHandlerFactory handlerFactory);
}

@visibleForTesting
class FlutterDriverExtension
    with
        DeserializeFinderFactory,
        CreateFinderFactory,
        DeserializeCommandFactory,
        CommandHandlerFactory {
  FlutterDriverExtension(
    this._requestDataHandler,
    this._silenceErrors,
    this._enableTextEntryEmulation, {
    List<FinderExtension> finders = const <FinderExtension>[],
    List<CommandExtension> commands = const <CommandExtension>[],
  }) {
    if (_enableTextEntryEmulation) {
      registerTextInput();
    }

    for (final FinderExtension finder in finders) {
      _finderExtensions[finder.finderType] = finder;
    }

    for (final CommandExtension command in commands) {
      _commandExtensions[command.commandKind] = command;
    }
  }

  final WidgetController _prober =
      LiveWidgetController(WidgetsBinding.instance);

  final DataHandler? _requestDataHandler;

  final bool _silenceErrors;

  final bool _enableTextEntryEmulation;

  void _log(String message) {
    driverLog('FlutterDriverExtension', message);
  }

  final Map<String, FinderExtension> _finderExtensions =
      <String, FinderExtension>{};
  final Map<String, CommandExtension> _commandExtensions =
      <String, CommandExtension>{};

  @visibleForTesting
  Future<Map<String, dynamic>> call(Map<String, String> params) async {
    final String commandKind = params['command']!;
    try {
      final Command command = deserializeCommand(params, this);
      assert(
          WidgetsBinding.instance.isRootWidgetAttached ||
              !command.requiresRootWidgetAttached,
          'No root widget is attached; have you remembered to call runApp()?');
      Future<Result> responseFuture = handleCommand(command, _prober, this);
      if (command.timeout != null) {
        responseFuture = responseFuture.timeout(command.timeout!);
      }
      final Result response = await responseFuture;
      return _makeResponse(response.toJson());
    } on TimeoutException catch (error, stackTrace) {
      final String message =
          'Timeout while executing $commandKind: $error\n$stackTrace';
      _log(message);
      return _makeResponse(message, isError: true);
    } catch (error, stackTrace) {
      final String message =
          'Uncaught extension error while executing $commandKind: $error\n$stackTrace';
      if (!_silenceErrors) {
        _log(message);
      }
      return _makeResponse(message, isError: true);
    }
  }

  Map<String, dynamic> _makeResponse(dynamic response, {bool isError = false}) {
    return <String, dynamic>{
      'isError': isError,
      'response': response,
    };
  }

  @override
  SerializableFinder deserializeFinder(Map<String, String> json) {
    final String? finderType = json['finderType'];
    if (_finderExtensions.containsKey(finderType)) {
      return _finderExtensions[finderType]!.deserialize(json, this);
    }

    return super.deserializeFinder(json);
  }

  @override
  Finder createFinder(SerializableFinder finder) {
    final String finderType = finder.finderType;
    if (_finderExtensions.containsKey(finderType)) {
      return _finderExtensions[finderType]!.createFinder(finder, this);
    }

    return super.createFinder(finder);
  }

  @override
  Command deserializeCommand(
      Map<String, String> params, DeserializeFinderFactory finderFactory) {
    final String? kind = params['command'];
    if (_commandExtensions.containsKey(kind)) {
      return _commandExtensions[kind]!.deserialize(params, finderFactory, this);
    }

    return super.deserializeCommand(params, finderFactory);
  }

  @override
  @protected
  DataHandler? getDataHandler() {
    return _requestDataHandler;
  }

  @override
  Future<Result> handleCommand(Command command, WidgetController prober,
      CreateFinderFactory finderFactory) {
    final String kind = command.kind;
    if (_commandExtensions.containsKey(kind)) {
      return _commandExtensions[kind]!
          .call(command, prober, finderFactory, this);
    }

    return super.handleCommand(command, prober, finderFactory);
  }
}
