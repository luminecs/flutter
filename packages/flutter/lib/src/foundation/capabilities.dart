
import '_capabilities_io.dart'
  if (dart.library.js_util) '_capabilities_web.dart' as capabilities;

bool get isCanvasKit => capabilities.isCanvasKit;