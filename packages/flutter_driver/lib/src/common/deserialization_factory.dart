import 'diagnostics_tree.dart';
import 'error.dart';
import 'find.dart';
import 'frame_sync.dart';
import 'geometry.dart';
import 'gesture.dart';
import 'health.dart';
import 'layer_tree.dart';
import 'message.dart';
import 'render_tree.dart';
import 'request_data.dart';
import 'semantics.dart';
import 'text.dart';
import 'wait.dart';

mixin DeserializeFinderFactory {
  SerializableFinder deserializeFinder(Map<String, String> json) {
    final String? finderType = json['finderType'];
    switch (finderType) {
      case 'ByType': return ByType.deserialize(json);
      case 'ByValueKey': return ByValueKey.deserialize(json);
      case 'ByTooltipMessage': return ByTooltipMessage.deserialize(json);
      case 'BySemanticsLabel': return BySemanticsLabel.deserialize(json);
      case 'ByText': return ByText.deserialize(json);
      case 'PageBack': return const PageBack();
      case 'Descendant': return Descendant.deserialize(json, this);
      case 'Ancestor': return Ancestor.deserialize(json, this);
    }
    throw DriverError('Unsupported search specification type $finderType');
  }
}

mixin DeserializeCommandFactory {
  Command deserializeCommand(Map<String, String> params, DeserializeFinderFactory finderFactory) {
    final String? kind = params['command'];
    switch (kind) {
      case 'get_health': return GetHealth.deserialize(params);
      case 'get_layer_tree': return GetLayerTree.deserialize(params);
      case 'get_render_tree': return GetRenderTree.deserialize(params);
      case 'enter_text': return EnterText.deserialize(params);
      case 'get_text': return GetText.deserialize(params, finderFactory);
      case 'request_data': return RequestData.deserialize(params);
      case 'scroll': return Scroll.deserialize(params, finderFactory);
      case 'scrollIntoView': return ScrollIntoView.deserialize(params, finderFactory);
      case 'set_frame_sync': return SetFrameSync.deserialize(params);
      case 'set_semantics': return SetSemantics.deserialize(params);
      case 'set_text_entry_emulation': return SetTextEntryEmulation.deserialize(params);
      case 'tap': return Tap.deserialize(params, finderFactory);
      case 'waitFor': return WaitFor.deserialize(params, finderFactory);
      case 'waitForAbsent': return WaitForAbsent.deserialize(params, finderFactory);
      case 'waitForTappable': return WaitForTappable.deserialize(params, finderFactory);
      case 'waitForCondition': return WaitForCondition.deserialize(params);
      case 'waitUntilNoTransientCallbacks': return WaitForCondition.deserialize(params);
      case 'waitUntilNoPendingFrame': return WaitForCondition.deserialize(params);
      case 'waitUntilFirstFrameRasterized': return WaitForCondition.deserialize(params);
      case 'get_semantics_id': return GetSemanticsId.deserialize(params, finderFactory);
      case 'get_offset': return GetOffset.deserialize(params, finderFactory);
      case 'get_diagnostics_tree': return GetDiagnosticsTree.deserialize(params, finderFactory);
    }

    throw DriverError('Unsupported command kind $kind');
  }
}