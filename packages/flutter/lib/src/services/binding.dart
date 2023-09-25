import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'asset_bundle.dart';
import 'binary_messenger.dart';
import 'hardware_keyboard.dart';
import 'message_codec.dart';
import 'restoration.dart';
import 'service_extensions.dart';
import 'system_channels.dart';
import 'text_input.dart';

export 'dart:ui' show ChannelBuffers, RootIsolateToken;

export 'binary_messenger.dart' show BinaryMessenger;
export 'hardware_keyboard.dart' show HardwareKeyboard, KeyEventManager;
export 'restoration.dart' show RestorationManager;

mixin ServicesBinding on BindingBase, SchedulerBinding {
  @override
  void initInstances() {
    super.initInstances();
    _instance = this;
    _defaultBinaryMessenger = createBinaryMessenger();
    _restorationManager = createRestorationManager();
    _initKeyboard();
    initLicenses();
    SystemChannels.system.setMessageHandler((dynamic message) => handleSystemMessage(message as Object));
    SystemChannels.lifecycle.setMessageHandler(_handleLifecycleMessage);
    SystemChannels.platform.setMethodCallHandler(_handlePlatformMessage);
    TextInput.ensureInitialized();
    readInitialLifecycleStateFromNativeWindow();
    initializationComplete();
  }

  static ServicesBinding get instance => BindingBase.checkInstance(_instance);
  static ServicesBinding? _instance;

  HardwareKeyboard get keyboard => _keyboard;
  late final HardwareKeyboard _keyboard;

  KeyEventManager get keyEventManager => _keyEventManager;
  late final KeyEventManager _keyEventManager;

  void _initKeyboard() {
    _keyboard = HardwareKeyboard();
    _keyEventManager = KeyEventManager(_keyboard, RawKeyboard.instance);
    _keyboard.syncKeyboardState().then((_) {
      platformDispatcher.onKeyData = _keyEventManager.handleKeyData;
      SystemChannels.keyEvent.setMessageHandler(_keyEventManager.handleRawKeyMessage);
    });
  }

  BinaryMessenger get defaultBinaryMessenger => _defaultBinaryMessenger;
  late final BinaryMessenger _defaultBinaryMessenger;

  static ui.RootIsolateToken? get rootIsolateToken => ui.RootIsolateToken.instance;

  ui.ChannelBuffers get channelBuffers => ui.channelBuffers;

  @protected
  BinaryMessenger createBinaryMessenger() {
    return const _DefaultBinaryMessenger._();
  }

  @protected
  @mustCallSuper
  void handleMemoryPressure() {
    rootBundle.clear();
  }

  @protected
  @mustCallSuper
  Future<void> handleSystemMessage(Object systemMessage) async {
    final Map<String, dynamic> message = systemMessage as Map<String, dynamic>;
    final String type = message['type'] as String;
    switch (type) {
      case 'memoryPressure':
        handleMemoryPressure();
    }
    return;
  }

  @protected
  @mustCallSuper
  void initLicenses() {
    LicenseRegistry.addLicense(_addLicenses);
  }

  Stream<LicenseEntry> _addLicenses() {
    late final StreamController<LicenseEntry> controller;
    controller = StreamController<LicenseEntry>(
      onListen: () async {
        late final String rawLicenses;
        if (kIsWeb) {
          // NOTICES for web isn't compressed since we don't have access to
          // dart:io on the client side and it's already compressed between
          // the server and client.
          rawLicenses = await rootBundle.loadString('NOTICES', cache: false);
        } else {
          // The compressed version doesn't have a more common .gz extension
          // because gradle for Android non-transparently manipulates .gz files.
          final ByteData licenseBytes = await rootBundle.load('NOTICES.Z');
          final List<int> unzippedBytes = await compute<List<int>, List<int>>(gzip.decode, licenseBytes.buffer.asUint8List(), debugLabel: 'decompressLicenses');
          rawLicenses = await compute<List<int>, String>(utf8.decode, unzippedBytes, debugLabel: 'utf8DecodeLicenses');
        }
        final List<LicenseEntry> licenses = await compute<String, List<LicenseEntry>>(_parseLicenses, rawLicenses, debugLabel: 'parseLicenses');
        licenses.forEach(controller.add);
        await controller.close();
      },
    );
    return controller.stream;
  }

  // This is run in another isolate created by _addLicenses above.
  static List<LicenseEntry> _parseLicenses(String rawLicenses) {
    final String licenseSeparator = '\n${'-' * 80}\n';
    final List<LicenseEntry> result = <LicenseEntry>[];
    final List<String> licenses = rawLicenses.split(licenseSeparator);
    for (final String license in licenses) {
      final int split = license.indexOf('\n\n');
      if (split >= 0) {
        result.add(LicenseEntryWithLineBreaks(
          license.substring(0, split).split('\n'),
          license.substring(split + 2),
        ));
      } else {
        result.add(LicenseEntryWithLineBreaks(const <String>[], license));
      }
    }
    return result;
  }

  @override
  void initServiceExtensions() {
    super.initServiceExtensions();

    assert(() {
      registerStringServiceExtension(
        name: ServicesServiceExtensions.evict.name,
        getter: () async => '',
        setter: (String value) async {
          evict(value);
        },
      );
      return true;
    }());
  }

  @protected
  @mustCallSuper
  void evict(String asset) {
    rootBundle.evict(asset);
  }

  // App life cycle

  @protected
  void readInitialLifecycleStateFromNativeWindow() {
    if (lifecycleState != null || platformDispatcher.initialLifecycleState.isEmpty) {
      return;
    }
    _handleLifecycleMessage(platformDispatcher.initialLifecycleState);
  }

  Future<String?> _handleLifecycleMessage(String? message) async {
    final AppLifecycleState? state = _parseAppLifecycleMessage(message!);
    final List<AppLifecycleState> generated = _generateStateTransitions(lifecycleState, state!);
    generated.forEach(handleAppLifecycleStateChanged);
    return null;
  }

  List<AppLifecycleState> _generateStateTransitions(AppLifecycleState? previousState, AppLifecycleState state) {
    if (previousState == state) {
      return const <AppLifecycleState>[];
    }
    if (previousState == AppLifecycleState.paused && state == AppLifecycleState.detached) {
      // Handle the wrap-around from paused to detached
      return const <AppLifecycleState>[
        AppLifecycleState.detached,
      ];
    }
    final List<AppLifecycleState> stateChanges = <AppLifecycleState>[];
    if (previousState == null) {
      // If there was no previous state, just jump directly to the new state.
      stateChanges.add(state);
    } else {
      final int previousStateIndex = AppLifecycleState.values.indexOf(previousState);
      final int stateIndex = AppLifecycleState.values.indexOf(state);
      assert(previousStateIndex != -1, 'State $previousState missing in stateOrder array');
      assert(stateIndex != -1, 'State $state missing in stateOrder array');
      if (previousStateIndex > stateIndex) {
        for (int i = stateIndex; i < previousStateIndex; ++i) {
          stateChanges.insert(0, AppLifecycleState.values[i]);
        }
      } else {
        for (int i = previousStateIndex + 1; i <= stateIndex; ++i) {
          stateChanges.add(AppLifecycleState.values[i]);
        }
      }
    }
    assert((){
      AppLifecycleState? starting = previousState;
      for (final AppLifecycleState ending in stateChanges) {
        if (!_debugVerifyLifecycleChange(starting, ending)) {
          return false;
        }
        starting = ending;
      }
      return true;
    }(), 'Invalid lifecycle state transition generated from $previousState to $state (generated $stateChanges)');
    return stateChanges;
  }

  static bool _debugVerifyLifecycleChange(AppLifecycleState? starting, AppLifecycleState ending) {
    if (starting == null) {
      // Any transition from null is fine, since it is initializing the state.
      return true;
    }
    if (starting == ending) {
      // Any transition to itself shouldn't happen.
      return false;
    }
    switch (starting) {
      case AppLifecycleState.detached:
        if (ending == AppLifecycleState.resumed || ending == AppLifecycleState.paused) {
          return true;
        }
      case AppLifecycleState.resumed:
        // Can't go from resumed to detached directly (must go through paused).
        if (ending == AppLifecycleState.inactive) {
          return true;
        }
      case AppLifecycleState.inactive:
        if (ending == AppLifecycleState.resumed || ending == AppLifecycleState.hidden) {
          return true;
        }
      case AppLifecycleState.hidden:
        if (ending == AppLifecycleState.inactive || ending == AppLifecycleState.paused) {
          return true;
        }
      case AppLifecycleState.paused:
        if (ending == AppLifecycleState.hidden || ending == AppLifecycleState.detached) {
          return true;
        }
    }
    return false;
  }

  Future<dynamic> _handlePlatformMessage(MethodCall methodCall) async {
    final String method = methodCall.method;
    assert(method == 'SystemChrome.systemUIChange' || method == 'System.requestAppExit');
    switch (method) {
      case 'SystemChrome.systemUIChange':
        final List<dynamic> args = methodCall.arguments as List<dynamic>;
        if (_systemUiChangeCallback != null) {
          await _systemUiChangeCallback!(args[0] as bool);
        }
      case 'System.requestAppExit':
        return <String, dynamic>{'response': (await handleRequestAppExit()).name};
    }
  }

  static AppLifecycleState? _parseAppLifecycleMessage(String message) {
    switch (message) {
      case 'AppLifecycleState.resumed':
        return AppLifecycleState.resumed;
      case 'AppLifecycleState.inactive':
        return AppLifecycleState.inactive;
      case 'AppLifecycleState.hidden':
        return AppLifecycleState.hidden;
      case 'AppLifecycleState.paused':
        return AppLifecycleState.paused;
      case 'AppLifecycleState.detached':
        return AppLifecycleState.detached;
    }
    return null;
  }

  Future<ui.AppExitResponse> handleRequestAppExit() async {
    return ui.AppExitResponse.exit;
  }

  Future<ui.AppExitResponse> exitApplication(ui.AppExitType exitType, [int exitCode = 0]) async {
    final Map<String, Object?>? result = await SystemChannels.platform.invokeMethod<Map<String, Object?>>(
      'System.exitApplication',
      <String, Object?>{'type': exitType.name, 'exitCode': exitCode},
    );
    if (result == null ) {
      return ui.AppExitResponse.cancel;
    }
    switch (result['response']) {
      case 'cancel':
        return ui.AppExitResponse.cancel;
      case 'exit':
      default:
        // In practice, this will never get returned, because the application
        // will have exited before it returns.
        return ui.AppExitResponse.exit;
    }
  }

  RestorationManager get restorationManager => _restorationManager;
  late RestorationManager _restorationManager;

  @protected
  RestorationManager createRestorationManager() {
    return RestorationManager();
  }

  SystemUiChangeCallback? _systemUiChangeCallback;

  // ignore: use_setters_to_change_properties, (API predates enforcing the lint)
  void setSystemUiChangeCallback(SystemUiChangeCallback? callback) {
    _systemUiChangeCallback = callback;
  }

  @protected
  Future<void> initializationComplete() async {
    await SystemChannels.platform.invokeMethod('System.initializationComplete');
  }
}

typedef SystemUiChangeCallback = Future<void> Function(bool systemOverlaysAreVisible);

class _DefaultBinaryMessenger extends BinaryMessenger {
  const _DefaultBinaryMessenger._();

  @override
  Future<void> handlePlatformMessage(
    String channel,
    ByteData? message,
    ui.PlatformMessageResponseCallback? callback,
  ) async {
    ui.channelBuffers.push(channel, message, (ByteData? data) {
      if (callback != null) {
        callback(data);
      }
    });
  }

  @override
  Future<ByteData?> send(String channel, ByteData? message) {
    final Completer<ByteData?> completer = Completer<ByteData?>();
    // ui.PlatformDispatcher.instance is accessed directly instead of using
    // ServicesBinding.instance.platformDispatcher because this method might be
    // invoked before any binding is initialized. This issue was reported in
    // #27541. It is not ideal to statically access
    // ui.PlatformDispatcher.instance because the PlatformDispatcher may be
    // dependency injected elsewhere with a different instance. However, static
    // access at this location seems to be the least bad option.
    // TODO(ianh): Use ServicesBinding.instance once we have better diagnostics
    // on that getter.
    ui.PlatformDispatcher.instance.sendPlatformMessage(channel, message, (ByteData? reply) {
      try {
        completer.complete(reply);
      } catch (exception, stack) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: exception,
          stack: stack,
          library: 'services library',
          context: ErrorDescription('during a platform message response callback'),
        ));
      }
    });
    return completer.future;
  }

  @override
  void setMessageHandler(String channel, MessageHandler? handler) {
    if (handler == null) {
      ui.channelBuffers.clearListener(channel);
    } else {
      ui.channelBuffers.setListener(channel, (ByteData? data, ui.PlatformMessageResponseCallback callback) async {
        ByteData? response;
        try {
          response = await handler(data);
        } catch (exception, stack) {
          FlutterError.reportError(FlutterErrorDetails(
            exception: exception,
            stack: stack,
            library: 'services library',
            context: ErrorDescription('during a platform message callback'),
          ));
        } finally {
          callback(response);
        }
      });
    }
  }
}