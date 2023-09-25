// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'message.dart';

class RequestData extends Command {
  const RequestData(this.message, { super.timeout });

  RequestData.deserialize(super.json)
    : message = json['message'],
      super.deserialize();

  final String? message;

  @override
  String get kind => 'request_data';

  @override
  bool get requiresRootWidgetAttached => false;

  @override
  Map<String, String> serialize() => super.serialize()..addAll(<String, String>{
    if (message != null)
      'message': message!,
  });
}

class RequestDataResult extends Result {
  const RequestDataResult(this.message);

  final String message;

  static RequestDataResult fromJson(Map<String, dynamic> json) {
    return RequestDataResult(json['message'] as String);
  }

  @override
  Map<String, dynamic> toJson() => <String, String>{
    'message': message,
  };
}