import 'bench_paths_recording.dart' as recording;
import 'recorder.dart';

class BenchPathRecording extends RawRecorder {
  BenchPathRecording() : super(name: benchmarkName);

  static const String benchmarkName = 'bench_path_recording';

  @override
  Future<void> setUpAll() async {
  }

  @override
  void body(Profile profile) {
    profile.record('recordPathConstruction', () {
      for (int i = 1; i <= 10; i++) {
        recording.createPaths();
      }
    }, reported: true);
  }
}