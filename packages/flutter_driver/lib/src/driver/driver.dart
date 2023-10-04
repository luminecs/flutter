import 'dart:io';

import 'package:meta/meta.dart';
import 'package:vm_service/vm_service.dart' as vms;
import 'package:webdriver/async_io.dart' as async_io;

import '../common/diagnostics_tree.dart';
import '../common/error.dart';
import '../common/find.dart';
import '../common/frame_sync.dart';
import '../common/geometry.dart';
import '../common/gesture.dart';
import '../common/health.dart';
import '../common/layer_tree.dart';
import '../common/message.dart';
import '../common/render_tree.dart';
import '../common/request_data.dart';
import '../common/semantics.dart';
import '../common/text.dart';
import '../common/text_input_action.dart';
import '../common/wait.dart';
import 'timeline.dart';
import 'vmservice_driver.dart';
import 'web_driver.dart';

export 'vmservice_driver.dart';
export 'web_driver.dart';

enum TimelineStream {
  all,

  api,

  compiler,

  compilerVerbose,

  dart,

  debugger,

  embedder,

  gc,

  isolate,

  vm,
}

@internal
const Duration kUnusuallyLongTimeout = Duration(seconds: 5);

const CommonFinders find = CommonFinders._();

typedef EvaluatorFunction = dynamic Function();

// Examples can assume:
// import 'package:flutter_driver/flutter_driver.dart';
// import 'package:test/test.dart';
// late FlutterDriver driver;

abstract class FlutterDriver {
  @visibleForTesting
  FlutterDriver();

  @visibleForTesting
  factory FlutterDriver.connectedTo({
    FlutterWebConnection? webConnection,
    vms.VmService? serviceClient,
    vms.Isolate? appIsolate,
  }) {
    if (webConnection != null) {
      return WebFlutterDriver.connectedTo(webConnection);
    }
    return VMServiceFlutterDriver.connectedTo(serviceClient!, appIsolate!);
  }

  static Future<FlutterDriver> connect({
    String? dartVmServiceUrl,
    bool printCommunication = false,
    bool logCommunicationToFile = true,
    int? isolateNumber,
    Pattern? fuchsiaModuleTarget,
    Duration? timeout,
    Map<String, dynamic>? headers,
  }) async {
    if (Platform.environment['FLUTTER_WEB_TEST'] != null) {
      return WebFlutterDriver.connectWeb(
        hostUrl: dartVmServiceUrl,
        timeout: timeout,
        printCommunication: printCommunication,
        logCommunicationToFile: logCommunicationToFile,
      );
    }
    return VMServiceFlutterDriver.connect(
      dartVmServiceUrl: dartVmServiceUrl,
      printCommunication: printCommunication,
      logCommunicationToFile: logCommunicationToFile,
      isolateNumber: isolateNumber,
      fuchsiaModuleTarget: fuchsiaModuleTarget,
      headers: headers,
    );
  }

  vms.Isolate get appIsolate => throw UnimplementedError();

  vms.VmService get serviceClient => throw UnimplementedError();

  async_io.WebDriver get webDriver => throw UnimplementedError();

  @Deprecated('Call setSemantics(true) instead. '
      'This feature was deprecated after v2.3.0-12.1.pre.')
  Future<void> enableAccessibility() async {
    await setSemantics(true);
  }

  Future<Map<String, dynamic>> sendCommand(Command command) async =>
      throw UnimplementedError();

  Future<Health> checkHealth({Duration? timeout}) async {
    return Health.fromJson(await sendCommand(GetHealth(timeout: timeout)));
  }

  Future<RenderTree> getRenderTree({Duration? timeout}) async {
    return RenderTree.fromJson(
        await sendCommand(GetRenderTree(timeout: timeout)));
  }

  Future<LayerTree> getLayerTree({Duration? timeout}) async {
    return LayerTree.fromJson(
        await sendCommand(GetLayerTree(timeout: timeout)));
  }

  Future<void> tap(SerializableFinder finder, {Duration? timeout}) async {
    await sendCommand(Tap(finder, timeout: timeout));
  }

  Future<void> waitFor(SerializableFinder finder, {Duration? timeout}) async {
    await sendCommand(WaitFor(finder, timeout: timeout));
  }

  Future<void> waitForAbsent(SerializableFinder finder,
      {Duration? timeout}) async {
    await sendCommand(WaitForAbsent(finder, timeout: timeout));
  }

  Future<void> waitForTappable(SerializableFinder finder,
      {Duration? timeout}) async {
    await sendCommand(WaitForTappable(finder, timeout: timeout));
  }

  Future<void> waitForCondition(SerializableWaitCondition waitCondition,
      {Duration? timeout}) async {
    await sendCommand(WaitForCondition(waitCondition, timeout: timeout));
  }

  Future<void> waitUntilNoTransientCallbacks({Duration? timeout}) async {
    await sendCommand(
        WaitForCondition(const NoTransientCallbacks(), timeout: timeout));
  }

  Future<void> waitUntilFirstFrameRasterized() async {
    await sendCommand(const WaitForCondition(FirstFrameRasterized()));
  }

  Future<DriverOffset> _getOffset(SerializableFinder finder, OffsetType type,
      {Duration? timeout}) async {
    final GetOffset command = GetOffset(finder, type, timeout: timeout);
    final GetOffsetResult result =
        GetOffsetResult.fromJson(await sendCommand(command));
    return DriverOffset(result.dx, result.dy);
  }

  Future<DriverOffset> getTopLeft(SerializableFinder finder,
      {Duration? timeout}) async {
    return _getOffset(finder, OffsetType.topLeft, timeout: timeout);
  }

  Future<DriverOffset> getTopRight(SerializableFinder finder,
      {Duration? timeout}) async {
    return _getOffset(finder, OffsetType.topRight, timeout: timeout);
  }

  Future<DriverOffset> getBottomLeft(SerializableFinder finder,
      {Duration? timeout}) async {
    return _getOffset(finder, OffsetType.bottomLeft, timeout: timeout);
  }

  Future<DriverOffset> getBottomRight(SerializableFinder finder,
      {Duration? timeout}) async {
    return _getOffset(finder, OffsetType.bottomRight, timeout: timeout);
  }

  Future<DriverOffset> getCenter(SerializableFinder finder,
      {Duration? timeout}) async {
    return _getOffset(finder, OffsetType.center, timeout: timeout);
  }

  Future<Map<String, Object?>> getRenderObjectDiagnostics(
    SerializableFinder finder, {
    int subtreeDepth = 0,
    bool includeProperties = true,
    Duration? timeout,
  }) async {
    return sendCommand(GetDiagnosticsTree(
      finder,
      DiagnosticsType.renderObject,
      subtreeDepth: subtreeDepth,
      includeProperties: includeProperties,
      timeout: timeout,
    ));
  }

  Future<Map<String, Object?>> getWidgetDiagnostics(
    SerializableFinder finder, {
    int subtreeDepth = 0,
    bool includeProperties = true,
    Duration? timeout,
  }) async {
    return sendCommand(GetDiagnosticsTree(
      finder,
      DiagnosticsType.widget,
      subtreeDepth: subtreeDepth,
      includeProperties: includeProperties,
      timeout: timeout,
    ));
  }

  Future<void> scroll(
      SerializableFinder finder, double dx, double dy, Duration duration,
      {int frequency = 60, Duration? timeout}) async {
    await sendCommand(
        Scroll(finder, dx, dy, duration, frequency, timeout: timeout));
  }

  Future<void> scrollIntoView(SerializableFinder finder,
      {double alignment = 0.0, Duration? timeout}) async {
    await sendCommand(
        ScrollIntoView(finder, alignment: alignment, timeout: timeout));
  }

  Future<void> scrollUntilVisible(
    SerializableFinder scrollable,
    SerializableFinder item, {
    double alignment = 0.0,
    double dxScroll = 0.0,
    double dyScroll = 0.0,
    Duration? timeout,
  }) async {
    assert(dxScroll != 0.0 || dyScroll != 0.0);

    // Kick off an (unawaited) waitFor that will complete when the item we're
    // looking for finally scrolls onscreen. We add an initial pause to give it
    // the chance to complete if the item is already onscreen; if not, scroll
    // repeatedly until we either find the item or time out.
    bool isVisible = false;
    waitFor(item, timeout: timeout).then<void>((_) {
      isVisible = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 500));
    while (!isVisible) {
      await scroll(
          scrollable, dxScroll, dyScroll, const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    return scrollIntoView(item, alignment: alignment);
  }

  Future<String> getText(SerializableFinder finder, {Duration? timeout}) async {
    return GetTextResult.fromJson(
            await sendCommand(GetText(finder, timeout: timeout)))
        .text;
  }

  Future<void> enterText(String text, {Duration? timeout}) async {
    await sendCommand(EnterText(text, timeout: timeout));
  }

  Future<void> setTextEntryEmulation(
      {required bool enabled, Duration? timeout}) async {
    await sendCommand(SetTextEntryEmulation(enabled, timeout: timeout));
  }

  Future<void> sendTextInputAction(TextInputAction action,
      {Duration? timeout}) async {
    await sendCommand(SendTextInputAction(action, timeout: timeout));
  }

  Future<String> requestData(String? message, {Duration? timeout}) async {
    return RequestDataResult.fromJson(
            await sendCommand(RequestData(message, timeout: timeout)))
        .message;
  }

  Future<bool> setSemantics(bool enabled, {Duration? timeout}) async {
    final SetSemanticsResult result = SetSemanticsResult.fromJson(
        await sendCommand(SetSemantics(enabled, timeout: timeout)));
    return result.changedState;
  }

  Future<int> getSemanticsId(SerializableFinder finder,
      {Duration? timeout}) async {
    final Map<String, dynamic> jsonResponse =
        await sendCommand(GetSemanticsId(finder, timeout: timeout));
    final GetSemanticsIdResult result =
        GetSemanticsIdResult.fromJson(jsonResponse);
    return result.id;
  }

  Future<List<int>> screenshot() async {
    throw UnimplementedError();
  }

  Future<List<Map<String, dynamic>>> getVmFlags() async {
    throw UnimplementedError();
  }

  Future<void> startTracing({
    List<TimelineStream> streams = const <TimelineStream>[TimelineStream.all],
    Duration timeout = kUnusuallyLongTimeout,
  }) async {
    throw UnimplementedError();
  }

  Future<Timeline> stopTracingAndDownloadTimeline({
    Duration timeout = kUnusuallyLongTimeout,
  }) async {
    throw UnimplementedError();
  }

  Future<Timeline> traceAction(
    Future<dynamic> Function() action, {
    List<TimelineStream> streams = const <TimelineStream>[TimelineStream.all],
    bool retainPriorEvents = false,
  }) async {
    throw UnimplementedError();
  }

  Future<void> clearTimeline({
    Duration timeout = kUnusuallyLongTimeout,
  }) async {
    throw UnimplementedError();
  }

  Future<T> runUnsynchronized<T>(Future<T> Function() action,
      {Duration? timeout}) async {
    await sendCommand(SetFrameSync(false, timeout: timeout));
    T result;
    try {
      result = await action();
    } finally {
      await sendCommand(SetFrameSync(true, timeout: timeout));
    }
    return result;
  }

  Future<void> forceGC() async {
    throw UnimplementedError();
  }

  Future<void> close() async {
    throw UnimplementedError();
  }
}

class CommonFinders {
  const CommonFinders._();

  SerializableFinder text(String text) => ByText(text);

  SerializableFinder byValueKey(dynamic key) => ByValueKey(key);

  SerializableFinder byTooltip(String message) => ByTooltipMessage(message);

  SerializableFinder bySemanticsLabel(Pattern label) => BySemanticsLabel(label);

  SerializableFinder byType(String type) => ByType(type);

  SerializableFinder pageBack() => const PageBack();

  SerializableFinder ancestor({
    required SerializableFinder of,
    required SerializableFinder matching,
    bool matchRoot = false,
    bool firstMatchOnly = false,
  }) =>
      Ancestor(
          of: of,
          matching: matching,
          matchRoot: matchRoot,
          firstMatchOnly: firstMatchOnly);

  SerializableFinder descendant({
    required SerializableFinder of,
    required SerializableFinder matching,
    bool matchRoot = false,
    bool firstMatchOnly = false,
  }) =>
      Descendant(
          of: of,
          matching: matching,
          matchRoot: matchRoot,
          firstMatchOnly: firstMatchOnly);
}

@immutable
class DriverOffset {
  const DriverOffset(this.dx, this.dy);

  final double dx;

  final double dy;

  @override
  String toString() =>
      '$runtimeType($dx, $dy)'; // ignore: no_runtimetype_tostring, can't access package:flutter here to use objectRuntimeType

  @override
  bool operator ==(Object other) {
    return other is DriverOffset && other.dx == dx && other.dy == dy;
  }

  @override
  int get hashCode => Object.hash(dx, dy);
}
