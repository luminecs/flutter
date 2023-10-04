import 'binding.dart';

// ignore: avoid_classes_with_only_static_members
class BackgroundIsolateBinaryMessenger {
  static BinaryMessenger get instance {
    throw UnsupportedError('Isolates not supported on web.');
  }
}
