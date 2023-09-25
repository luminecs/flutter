// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import '_bitfield_io.dart'
  if (dart.library.js_util) '_bitfield_web.dart' as bitfield;

const int kMaxUnsignedSMI = bitfield.kMaxUnsignedSMI;

abstract class BitField<T extends dynamic> {
  factory BitField(int length) = bitfield.BitField<T>;

  factory BitField.filled(int length, bool value) = bitfield.BitField<T>.filled;

  bool operator [](T index);

  void operator []=(T index, bool value);

  void reset([ bool value = false ]);
}