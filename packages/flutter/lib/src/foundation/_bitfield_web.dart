// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'bitfield.dart' as bitfield;

const int kMaxUnsignedSMI = -1;

class BitField<T extends dynamic> implements bitfield.BitField<T> {
  // Can remove when we have metaclasses.
  // ignore: avoid_unused_constructor_parameters
  BitField(int length);

  // Can remove when we have metaclasses.
  // ignore: avoid_unused_constructor_parameters
  BitField.filled(int length, bool value);

  @override
  bool operator [](T index) {
    throw UnsupportedError('Not supported when compiling to JavaScript');
  }

  @override
  void operator []=(T index, bool value) {
    throw UnsupportedError('Not supported when compiling to JavaScript');
  }

  @override
  void reset([ bool value = false ]) {
    throw UnsupportedError('Not supported when compiling to JavaScript');
  }
}