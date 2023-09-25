
class SystemClock {
  const SystemClock();

  const factory SystemClock.fixed(DateTime time) = _FixedTimeClock;

  DateTime now() => DateTime.now();

  DateTime ago(Duration duration) {
    return now().subtract(duration);
  }
}

class _FixedTimeClock extends SystemClock {
  const _FixedTimeClock(this._fixedTime);

  final DateTime _fixedTime;

  @override
  DateTime now() => _fixedTime;
}

String formatDateTime(DateTime t) {
  final String sign = t.timeZoneOffset.isNegative ? '-' : '+';
  final Duration tzOffset = t.timeZoneOffset.abs();
  final int hoursOffset = tzOffset.inHours;
  final int minutesOffset =
      tzOffset.inMinutes - (Duration.minutesPerHour * hoursOffset);
  assert(hoursOffset < 24);
  assert(minutesOffset < 60);

  String twoDigits(int n) => (n >= 10) ? '$n' : '0$n';
  return '$t $sign${twoDigits(hoursOffset)}${twoDigits(minutesOffset)}';
}