import 'find.dart';

class Tap extends CommandWithTarget {
  Tap(super.finder, {super.timeout});

  Tap.deserialize(super.json, super.finderFactory) : super.deserialize();

  @override
  String get kind => 'tap';
}

class Scroll extends CommandWithTarget {
  Scroll(
    super.finder,
    this.dx,
    this.dy,
    this.duration,
    this.frequency, {
    super.timeout,
  });

  Scroll.deserialize(super.json, super.finderFactory)
      : dx = double.parse(json['dx']!),
        dy = double.parse(json['dy']!),
        duration = Duration(microseconds: int.parse(json['duration']!)),
        frequency = int.parse(json['frequency']!),
        super.deserialize();

  final double dx;

  final double dy;

  final Duration duration;

  final int frequency;

  @override
  String get kind => 'scroll';

  @override
  Map<String, String> serialize() => super.serialize()
    ..addAll(<String, String>{
      'dx': '$dx',
      'dy': '$dy',
      'duration': '${duration.inMicroseconds}',
      'frequency': '$frequency',
    });
}

class ScrollIntoView extends CommandWithTarget {
  ScrollIntoView(super.finder, {this.alignment = 0.0, super.timeout});

  ScrollIntoView.deserialize(super.json, super.finderFactory)
      : alignment = double.parse(json['alignment']!),
        super.deserialize();

  final double alignment;

  @override
  String get kind => 'scrollIntoView';

  @override
  Map<String, String> serialize() => super.serialize()
    ..addAll(<String, String>{
      'alignment': '$alignment',
    });
}
