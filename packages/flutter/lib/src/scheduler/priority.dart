import 'package:flutter/foundation.dart';

@immutable
class Priority {
  const Priority._(this._value);

  int get value => _value;
  final int _value;

  static const Priority idle = Priority._(0);

  static const Priority animation = Priority._(100000);

  static const Priority touch = Priority._(200000);

  static const int kMaxOffset = 10000;

  Priority operator +(int offset) {
    if (offset.abs() > kMaxOffset) {
      // Clamp the input offset.
      offset = kMaxOffset * offset.sign;
    }
    return Priority._(_value + offset);
  }

  Priority operator -(int offset) => this + (-offset);
}
