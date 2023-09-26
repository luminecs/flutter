import 'test_device.dart';

abstract class TestWatcher {
  void handleStartedDevice(Uri? vmServiceUri) {}

  Future<void> handleFinishedTest(TestDevice testDevice);

  Future<void> handleTestCrashed(TestDevice testDevice);

  Future<void> handleTestTimedOut(TestDevice testDevice);
}
