
import 'system_channels.dart';

enum SystemSoundType {
  click,

  alert,

  // If you add new values here, you also need to update the `SoundType` Java
  // enum in `PlatformChannel.java`.
}

abstract final class SystemSound {
  static Future<void> play(SystemSoundType type) async {
    await SystemChannels.platform.invokeMethod<void>(
      'SystemSound.play',
      type.toString(),
    );
  }
}