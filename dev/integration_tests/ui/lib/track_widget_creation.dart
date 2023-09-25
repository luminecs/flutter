import 'dart:developer';
import 'package:flutter/widgets.dart';

void main() {
  final Set<Widget> widgets = <Widget>{};
  widgets.add(const Text('same'));
  widgets.add(const Text('same'));

  // If track-widget-creation is enabled, the set will have 2 members.
  // Otherwise is will only have one.
  registerExtension('ext.devicelab.test', (String method, Map<String, Object> params) async {
    return ServiceExtensionResponse.result('{"result":${widgets.length}}');
  });
}