import 'package:flutter/foundation.dart';

@immutable
class KeyboardInsertedContent {
  const KeyboardInsertedContent({required this.mimeType, required this.uri, this.data});

  KeyboardInsertedContent.fromJson(Map<String, dynamic> metadata):
      mimeType = metadata['mimeType'] as String,
      uri = metadata['uri'] as String,
      data = metadata['data'] != null
          ? Uint8List.fromList(List<int>.from(metadata['data'] as Iterable<dynamic>))
          : null;

  final String mimeType;

  final String uri;

  final Uint8List? data;

  bool get hasData => data?.isNotEmpty ?? false;

  @override
  String toString() => '${objectRuntimeType(this, 'KeyboardInsertedContent')}($mimeType, $uri, $data)';

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is KeyboardInsertedContent
        && other.mimeType == mimeType
        && other.uri == uri
        && other.data == data;
  }

  @override
  int get hashCode => Object.hash(mimeType, uri, data);
}