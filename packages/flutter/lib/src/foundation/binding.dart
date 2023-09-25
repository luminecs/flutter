import 'dart:async';
import 'dart:convert' show json;
import 'dart:developer' as developer;
import 'dart:io' show exit;
import 'dart:ui' as ui show Brightness, PlatformDispatcher, SingletonFlutterWindow, window; // ignore: deprecated_member_use

// Before adding any more dart:ui imports, please read the README.

import 'package:meta/meta.dart';

import 'assertions.dart';
import 'basic_types.dart';
import 'constants.dart';
import 'debug.dart';
import 'object.dart';
import 'platform.dart';
import 'print.dart';
import 'service_extensions.dart';
import 'timeline.dart';

export 'dart:ui' show PlatformDispatcher, SingletonFlutterWindow, clampDouble; // ignore: deprecated_member_use

export 'basic_types.dart' show AsyncCallback, AsyncValueGetter, AsyncValueSetter;

// Examples can assume:
// mixin BarBinding on BindingBase { }

typedef ServiceExtensionCallback = Future<Map<String, dynamic>> Function(Map<String, String> parameters);

abstract class BindingBase {
  BindingBase() {
    if (!kReleaseMode) {
      FlutterTimeline.startSync('Framework initialization');
    }
    assert(() {
      _debugConstructed = true;
      return true;
    }());

    assert(_debugInitializedType == null, 'Binding is already initialized to $_debugInitializedType');
    initInstances();
    assert(_debugInitializedType != null);

    assert(!_debugServiceExtensionsRegistered);
    initServiceExtensions();
    assert(_debugServiceExtensionsRegistered);

    if (!kReleaseMode) {
      developer.postEvent('Flutter.FrameworkInitialization', <String, String>{});
      FlutterTimeline.finishSync();
    }
  }

  bool _debugConstructed = false;
  static Type? _debugInitializedType;
  static bool _debugServiceExtensionsRegistered = false;

  @Deprecated(
    'Look up the current FlutterView from the context via View.of(context) or consult the PlatformDispatcher directly instead. '
    'Deprecated to prepare for the upcoming multi-window support. '
    'This feature was deprecated after v3.7.0-32.0.pre.'
  )
  ui.SingletonFlutterWindow get window => ui.window;

  ui.PlatformDispatcher get platformDispatcher => ui.PlatformDispatcher.instance;

  @protected
  @mustCallSuper
  void initInstances() {
    assert(_debugInitializedType == null);
    assert(() {
      _debugInitializedType = runtimeType;
      _debugBindingZone = Zone.current;
      return true;
    }());
  }

  @protected
  static T checkInstance<T extends BindingBase>(T? instance) {
    assert(() {
      if (_debugInitializedType == null && instance == null) {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('Binding has not yet been initialized.'),
          ErrorDescription('The "instance" getter on the $T binding mixin is only available once that binding has been initialized.'),
          ErrorHint(
            'Typically, this is done by calling "WidgetsFlutterBinding.ensureInitialized()" or "runApp()" (the '
            'latter calls the former). Typically this call is done in the "void main()" method. The "ensureInitialized" method '
            'is idempotent; calling it multiple times is not harmful. After calling that method, the "instance" getter will '
            'return the binding.',
          ),
          ErrorHint(
            'In a test, one can call "TestWidgetsFlutterBinding.ensureInitialized()" as the first line in the test\'s "main()" method '
            'to initialize the binding.',
          ),
          ErrorHint(
            'If $T is a custom binding mixin, there must also be a custom binding class, like WidgetsFlutterBinding, '
            'but that mixes in the selected binding, and that is the class that must be constructed before using the "instance" getter.',
          ),
        ]);
      }
      if (instance == null) {
        assert(_debugInitializedType == null);
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('Binding mixin instance is null but bindings are already initialized.'),
          ErrorDescription(
            'The "instance" property of the $T binding mixin was accessed, but that binding was not initialized when '
            'the "initInstances()" method was called.',
          ),
          ErrorHint(
            'This probably indicates that the $T mixin was not mixed into the class that was used to initialize the binding. '
            'If this is a custom binding mixin, there must also be a custom binding class, like WidgetsFlutterBinding, '
            'but that mixes in the selected binding. If this is a test binding, check that the binding being initialized '
            'is the same as the one into which the test binding is mixed.',
          ),
          ErrorHint(
            'It is also possible that $T does not implement "initInstances()" to assign a value to "instance". See the '
            'documentation of the BindingBase class for more details.',
          ),
          ErrorHint(
            'The binding that was initialized was of the type "$_debugInitializedType". '
          ),
        ]);
      }
      try {
        if (instance._debugConstructed && _debugInitializedType == null) {
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary('Binding initialized without calling initInstances.'),
            ErrorDescription('An instance of $T is non-null, but BindingBase.initInstances() has not yet been called.'),
            ErrorHint(
              'This could happen because a binding mixin was somehow used outside of the normal binding mechanisms, or because '
              'the binding\'s initInstances() method did not call "super.initInstances()".',
            ),
            ErrorHint(
              'This could also happen if some code was invoked that used the binding while the binding was initializing, '
              'for example if the "initInstances" method invokes a callback. Bindings should not invoke callbacks before '
              '"initInstances" has completed.',
            ),
          ]);
        }
        if (!instance._debugConstructed) {
          // The state of _debugInitializedType doesn't matter in this failure mode.
          throw FlutterError.fromParts(<DiagnosticsNode>[
            ErrorSummary('Binding did not complete initialization.'),
            ErrorDescription('An instance of $T is non-null, but the BindingBase() constructor has not yet been called.'),
            ErrorHint(
              'This could also happen if some code was invoked that used the binding while the binding was initializing, '
              "for example if the binding's constructor itself invokes a callback. Bindings should not invoke callbacks "
              'before "initInstances" has completed.',
            ),
          ]);
        }
      } on NoSuchMethodError {
        throw FlutterError.fromParts(<DiagnosticsNode>[
          ErrorSummary('Binding does not extend BindingBase'),
          ErrorDescription('An instance of $T was created but the BindingBase constructor was not called.'),
          ErrorHint(
            'This could happen because the binding was implemented using "implements" rather than "extends" or "with". '
            'Concrete binding classes must extend or mix in BindingBase.',
          ),
        ]);
      }
      return true;
    }());
    return instance!;
  }

  static Type? debugBindingType() {
    return _debugInitializedType;
  }

  Zone? _debugBindingZone;

  static bool debugZoneErrorsAreFatal = false;

  bool debugCheckZone(String entryPoint) {
    assert(() {
      assert(_debugBindingZone != null, 'debugCheckZone can only be used after the binding is fully initialized.');
      if (Zone.current != _debugBindingZone) {
        final Error message = FlutterError(
          'Zone mismatch.\n'
          'The Flutter bindings were initialized in a different zone than is now being used. '
          'This will likely cause confusion and bugs as any zone-specific configuration will '
          'inconsistently use the configuration of the original binding initialization zone '
          'or this zone based on hard-to-predict factors such as which zone was active when '
          'a particular callback was set.\n'
          'It is important to use the same zone when calling `ensureInitialized` on the binding '
          'as when calling `$entryPoint` later.\n'
          'To make this ${ debugZoneErrorsAreFatal ? 'error non-fatal' : 'warning fatal' }, '
          'set BindingBase.debugZoneErrorsAreFatal to ${!debugZoneErrorsAreFatal} before the '
          'bindings are initialized (i.e. as the first statement in `void main() { }`).',
        );
        if (debugZoneErrorsAreFatal) {
          throw message;
        }
        FlutterError.reportError(FlutterErrorDetails(
          exception: message,
          stack: StackTrace.current,
          context: ErrorDescription('during $entryPoint'),
        ));
      }
      return true;
    }());
    return true;
  }

  @protected
  @mustCallSuper
  void initServiceExtensions() {
    assert(!_debugServiceExtensionsRegistered);

    assert(() {
      registerSignalServiceExtension(
        name: FoundationServiceExtensions.reassemble.name,
        callback: reassembleApplication,
      );
      return true;
    }());

    if (!kReleaseMode) {
      if (!kIsWeb) {
        registerSignalServiceExtension(
          name: FoundationServiceExtensions.exit.name,
          callback: _exitApplication,
        );
      }
      // These service extensions are used in profile mode applications.
      registerStringServiceExtension(
        name: FoundationServiceExtensions.connectedVmServiceUri.name,
        getter: () async => connectedVmServiceUri ?? '',
        setter: (String uri) async {
          connectedVmServiceUri = uri;
        },
      );
      registerStringServiceExtension(
        name: FoundationServiceExtensions.activeDevToolsServerAddress.name,
        getter: () async => activeDevToolsServerAddress ?? '',
        setter: (String serverAddress) async {
          activeDevToolsServerAddress = serverAddress;
        },
      );
    }

    assert(() {
      registerServiceExtension(
        name: FoundationServiceExtensions.platformOverride.name,
        callback: (Map<String, String> parameters) async {
          if (parameters.containsKey('value')) {
            final String value = parameters['value']!;
            debugDefaultTargetPlatformOverride = null;
            for (final TargetPlatform candidate in TargetPlatform.values) {
              if (candidate.name == value) {
                debugDefaultTargetPlatformOverride = candidate;
                break;
              }
            }
            _postExtensionStateChangedEvent(
              FoundationServiceExtensions.platformOverride.name,
              defaultTargetPlatform.name,
            );
            await reassembleApplication();
          }
          return <String, dynamic>{
            'value': defaultTargetPlatform.name,
          };
        },
      );

      registerServiceExtension(
        name: FoundationServiceExtensions.brightnessOverride.name,
        callback: (Map<String, String> parameters) async {
          if (parameters.containsKey('value')) {
            switch (parameters['value']) {
              case 'Brightness.light':
                debugBrightnessOverride = ui.Brightness.light;
              case 'Brightness.dark':
                debugBrightnessOverride = ui.Brightness.dark;
              default:
                debugBrightnessOverride = null;
            }
            _postExtensionStateChangedEvent(
              FoundationServiceExtensions.brightnessOverride.name,
              (debugBrightnessOverride ?? platformDispatcher.platformBrightness).toString(),
            );
            await reassembleApplication();
          }
          return <String, dynamic>{
            'value': (debugBrightnessOverride ?? platformDispatcher.platformBrightness).toString(),
          };
        },
      );
      return true;
    }());
    assert(() {
      _debugServiceExtensionsRegistered = true;
      return true;
    }());
  }

  @protected
  bool get locked => _lockCount > 0;
  int _lockCount = 0;

  @protected
  Future<void> lockEvents(Future<void> Function() callback) {
    developer.TimelineTask? debugTimelineTask;
    if (!kReleaseMode) {
      debugTimelineTask = developer.TimelineTask()..start('Lock events');
    }

    _lockCount += 1;
    final Future<void> future = callback();
    future.whenComplete(() {
      _lockCount -= 1;
      if (!locked) {
        if (!kReleaseMode) {
          debugTimelineTask!.finish();
        }
        try {
          unlocked();
        } catch (error, stack) {
          FlutterError.reportError(FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'foundation',
            context: ErrorDescription('while handling pending events'),
          ));
        }
      }
    });
    return future;
  }

  @protected
  @mustCallSuper
  void unlocked() {
    assert(!locked);
  }

  Future<void> reassembleApplication() {
    return lockEvents(performReassemble);
  }

  @mustCallSuper
  @protected
  Future<void> performReassemble() {
    FlutterError.resetErrorCount();
    return Future<void>.value();
  }

  @protected
  void registerSignalServiceExtension({
    required String name,
    required AsyncCallback callback,
  }) {
    registerServiceExtension(
      name: name,
      callback: (Map<String, String> parameters) async {
        await callback();
        return <String, dynamic>{};
      },
    );
  }

  @protected
  void registerBoolServiceExtension({
    required String name,
    required AsyncValueGetter<bool> getter,
    required AsyncValueSetter<bool> setter,
  }) {
    registerServiceExtension(
      name: name,
      callback: (Map<String, String> parameters) async {
        if (parameters.containsKey('enabled')) {
          await setter(parameters['enabled'] == 'true');
          _postExtensionStateChangedEvent(name, await getter() ? 'true' : 'false');
        }
        return <String, dynamic>{'enabled': await getter() ? 'true' : 'false'};
      },
    );
  }

  @protected
  void registerNumericServiceExtension({
    required String name,
    required AsyncValueGetter<double> getter,
    required AsyncValueSetter<double> setter,
  }) {
    registerServiceExtension(
      name: name,
      callback: (Map<String, String> parameters) async {
        if (parameters.containsKey(name)) {
          await setter(double.parse(parameters[name]!));
          _postExtensionStateChangedEvent(name, (await getter()).toString());
        }
        return <String, dynamic>{name: (await getter()).toString()};
      },
    );
  }

  void _postExtensionStateChangedEvent(String name, dynamic value) {
    postEvent(
      'Flutter.ServiceExtensionStateChanged',
      <String, dynamic>{
        'extension': 'ext.flutter.$name',
        'value': value,
      },
    );
  }

  @protected
  void postEvent(String eventKind, Map<String, dynamic> eventData) {
    developer.postEvent(eventKind, eventData);
  }

  @protected
  void registerStringServiceExtension({
    required String name,
    required AsyncValueGetter<String> getter,
    required AsyncValueSetter<String> setter,
  }) {
    registerServiceExtension(
      name: name,
      callback: (Map<String, String> parameters) async {
        if (parameters.containsKey('value')) {
          await setter(parameters['value']!);
          _postExtensionStateChangedEvent(name, await getter());
        }
        return <String, dynamic>{'value': await getter()};
      },
    );
  }

  @protected
  void registerServiceExtension({
    required String name,
    required ServiceExtensionCallback callback,
  }) {
    final String methodName = 'ext.flutter.$name';
    developer.registerExtension(methodName, (String method, Map<String, String> parameters) async {
      assert(method == methodName);
      assert(() {
        if (debugInstrumentationEnabled) {
          debugPrint('service extension method received: $method($parameters)');
        }
        return true;
      }());

      // VM service extensions are handled as "out of band" messages by the VM,
      // which means they are handled at various times, generally ASAP.
      // Notably, this includes being handled in the middle of microtask loops.
      // While this makes sense for some service extensions (e.g. "dump current
      // stack trace", which explicitly doesn't want to wait for a loop to
      // complete), Flutter extensions need not be handled with such high
      // priority. Further, handling them with such high priority exposes us to
      // the possibility that they're handled in the middle of a frame, which
      // breaks many assertions. As such, we ensure they we run the callbacks
      // on the outer event loop here.
      await debugInstrumentAction<void>('Wait for outer event loop', () {
        return Future<void>.delayed(Duration.zero);
      });

      late Map<String, dynamic> result;
      try {
        result = await callback(parameters);
      } catch (exception, stack) {
        FlutterError.reportError(FlutterErrorDetails(
          exception: exception,
          stack: stack,
          context: ErrorDescription('during a service extension callback for "$method"'),
        ));
        return developer.ServiceExtensionResponse.error(
          developer.ServiceExtensionResponse.extensionError,
          json.encode(<String, String>{
            'exception': exception.toString(),
            'stack': stack.toString(),
            'method': method,
          }),
        );
      }
      result['type'] = '_extensionType';
      result['method'] = method;
      return developer.ServiceExtensionResponse.result(json.encode(result));
    });
  }

  @override
  String toString() => '<${objectRuntimeType(this, 'BindingBase')}>';
}

Future<void> _exitApplication() async {
  exit(0);
}