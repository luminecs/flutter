// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;
import 'dart:typed_data';

export 'dart:typed_data' show ByteData, Endian, Float32List, Float64List, Int32List, Int64List, Uint8List;

class WriteBuffer {
  factory WriteBuffer({int startCapacity = 8}) {
    assert(startCapacity > 0);
    final ByteData eightBytes = ByteData(8);
    final Uint8List eightBytesAsList = eightBytes.buffer.asUint8List();
    return WriteBuffer._(Uint8List(startCapacity), eightBytes, eightBytesAsList);
  }

  WriteBuffer._(this._buffer, this._eightBytes, this._eightBytesAsList);

  Uint8List _buffer;
  int _currentSize = 0;
  bool _isDone = false;
  final ByteData _eightBytes;
  final Uint8List _eightBytesAsList;
  static final Uint8List _zeroBuffer = Uint8List(8);

  void _add(int byte) {
    if (_currentSize == _buffer.length) {
      _resize();
    }
    _buffer[_currentSize] = byte;
    _currentSize += 1;
  }

  void _append(Uint8List other) {
    final int newSize = _currentSize + other.length;
    if (newSize >= _buffer.length) {
      _resize(newSize);
    }
    _buffer.setRange(_currentSize, newSize, other);
    _currentSize += other.length;
  }

  void _addAll(Uint8List data, [int start = 0, int? end]) {
    final int newEnd = end ?? _eightBytesAsList.length;
    final int newSize = _currentSize + (newEnd - start);
    if (newSize >= _buffer.length) {
      _resize(newSize);
    }
    _buffer.setRange(_currentSize, newSize, data);
    _currentSize = newSize;
  }

  void _resize([int? requiredLength]) {
    final int doubleLength = _buffer.length * 2;
    final int newLength = math.max(requiredLength ?? 0, doubleLength);
    final Uint8List newBuffer = Uint8List(newLength);
    newBuffer.setRange(0, _buffer.length, _buffer);
    _buffer = newBuffer;
  }

  void putUint8(int byte) {
    assert(!_isDone);
    _add(byte);
  }

  void putUint16(int value, {Endian? endian}) {
    assert(!_isDone);
    _eightBytes.setUint16(0, value, endian ?? Endian.host);
    _addAll(_eightBytesAsList, 0, 2);
  }

  void putUint32(int value, {Endian? endian}) {
    assert(!_isDone);
    _eightBytes.setUint32(0, value, endian ?? Endian.host);
    _addAll(_eightBytesAsList, 0, 4);
  }

  void putInt32(int value, {Endian? endian}) {
    assert(!_isDone);
    _eightBytes.setInt32(0, value, endian ?? Endian.host);
    _addAll(_eightBytesAsList, 0, 4);
  }

  void putInt64(int value, {Endian? endian}) {
    assert(!_isDone);
    _eightBytes.setInt64(0, value, endian ?? Endian.host);
    _addAll(_eightBytesAsList, 0, 8);
  }

  void putFloat64(double value, {Endian? endian}) {
    assert(!_isDone);
    _alignTo(8);
    _eightBytes.setFloat64(0, value, endian ?? Endian.host);
    _addAll(_eightBytesAsList);
  }

  void putUint8List(Uint8List list) {
    assert(!_isDone);
    _append(list);
  }

  void putInt32List(Int32List list) {
    assert(!_isDone);
    _alignTo(4);
    _append(list.buffer.asUint8List(list.offsetInBytes, 4 * list.length));
  }

  void putInt64List(Int64List list) {
    assert(!_isDone);
    _alignTo(8);
    _append(list.buffer.asUint8List(list.offsetInBytes, 8 * list.length));
  }

  void putFloat32List(Float32List list) {
    assert(!_isDone);
    _alignTo(4);
    _append(list.buffer.asUint8List(list.offsetInBytes, 4 * list.length));
  }

  void putFloat64List(Float64List list) {
    assert(!_isDone);
    _alignTo(8);
    _append(list.buffer.asUint8List(list.offsetInBytes, 8 * list.length));
  }

  void _alignTo(int alignment) {
    assert(!_isDone);
    final int mod = _currentSize % alignment;
    if (mod != 0) {
      _addAll(_zeroBuffer, 0, alignment - mod);
    }
  }

  ByteData done() {
    if (_isDone) {
      throw StateError('done() must not be called more than once on the same $runtimeType.');
    }
    final ByteData result = _buffer.buffer.asByteData(0, _currentSize);
    _buffer = Uint8List(0);
    _isDone = true;
    return result;
  }
}

class ReadBuffer {
  ReadBuffer(this.data);

  final ByteData data;

  int _position = 0;

  bool get hasRemaining => _position < data.lengthInBytes;

  int getUint8() {
    return data.getUint8(_position++);
  }

  int getUint16({Endian? endian}) {
    final int value = data.getUint16(_position, endian ?? Endian.host);
    _position += 2;
    return value;
  }

  int getUint32({Endian? endian}) {
    final int value = data.getUint32(_position, endian ?? Endian.host);
    _position += 4;
    return value;
  }

  int getInt32({Endian? endian}) {
    final int value = data.getInt32(_position, endian ?? Endian.host);
    _position += 4;
    return value;
  }

  int getInt64({Endian? endian}) {
    final int value = data.getInt64(_position, endian ?? Endian.host);
    _position += 8;
    return value;
  }

  double getFloat64({Endian? endian}) {
    _alignTo(8);
    final double value = data.getFloat64(_position, endian ?? Endian.host);
    _position += 8;
    return value;
  }

  Uint8List getUint8List(int length) {
    final Uint8List list = data.buffer.asUint8List(data.offsetInBytes + _position, length);
    _position += length;
    return list;
  }

  Int32List getInt32List(int length) {
    _alignTo(4);
    final Int32List list = data.buffer.asInt32List(data.offsetInBytes + _position, length);
    _position += 4 * length;
    return list;
  }

  Int64List getInt64List(int length) {
    _alignTo(8);
    final Int64List list = data.buffer.asInt64List(data.offsetInBytes + _position, length);
    _position += 8 * length;
    return list;
  }

  Float32List getFloat32List(int length) {
    _alignTo(4);
    final Float32List list = data.buffer.asFloat32List(data.offsetInBytes + _position, length);
    _position += 4 * length;
    return list;
  }

  Float64List getFloat64List(int length) {
    _alignTo(8);
    final Float64List list = data.buffer.asFloat64List(data.offsetInBytes + _position, length);
    _position += 8 * length;
    return list;
  }

  void _alignTo(int alignment) {
    final int mod = _position % alignment;
    if (mod != 0) {
      _position += alignment - mod;
    }
  }
}