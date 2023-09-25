
import 'drag_details.dart';

export 'drag_details.dart' show DragEndDetails, DragUpdateDetails;

abstract class Drag {
  void update(DragUpdateDetails details) { }

  void end(DragEndDetails details) { }

  void cancel() { }
}