// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'message.dart';

class SetFrameSync extends Command {
  const SetFrameSync(this.enabled, { super.timeout });

  SetFrameSync.deserialize(super.json)
    : enabled = json['enabled']!.toLowerCase() == 'true',
      super.deserialize();

  final bool enabled;

  @override
  String get kind => 'set_frame_sync';

  @override
  Map<String, String> serialize() => super.serialize()..addAll(<String, String>{
    'enabled': '$enabled',
  });
}