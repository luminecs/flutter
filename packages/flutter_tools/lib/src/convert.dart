// Hide the original utf8 [Codec] so that we can export our own implementation
// which adds additional error handling.
import 'dart:convert' hide utf8;
import 'dart:convert' as cnv show Utf8Decoder, utf8;

import 'package:meta/meta.dart';

import 'base/common.dart';
export 'dart:convert' hide Utf8Codec, Utf8Decoder, utf8;

@visibleForTesting
const Encoding utf8ForTesting = cnv.utf8;

class Utf8Codec extends Encoding {
  const Utf8Codec({this.reportErrors = true});

  final bool reportErrors;

  @override
  Converter<List<int>, String> get decoder => reportErrors
    ? const Utf8Decoder()
    : const Utf8Decoder(reportErrors: false);

  @override
  Converter<String, List<int>> get encoder => cnv.utf8.encoder;

  @override
  String get name => cnv.utf8.name;
}

const Encoding utf8 = Utf8Codec();

class Utf8Decoder extends Converter<List<int>, String> {
  const Utf8Decoder({this.reportErrors = true});

  static const cnv.Utf8Decoder _systemDecoder =
      cnv.Utf8Decoder(allowMalformed: true);

  final bool reportErrors;

  @override
  String convert(List<int> input, [int start = 0, int? end]) {
    final String result = _systemDecoder.convert(input, start, end);
    // Finding a Unicode replacement character indicates that the input
    // was malformed.
    if (reportErrors && result.contains('\u{FFFD}')) {
      throwToolExit(
        'Bad UTF-8 encoding (U+FFFD; REPLACEMENT CHARACTER) found while decoding string: $result. '
        'The Flutter team would greatly appreciate if you could file a bug explaining '
        'exactly what you were doing when this happened:\n'
        'https://github.com/flutter/flutter/issues/new/choose\n'
        'The source bytes were:\n$input\n\n');
    }
    return result;
  }

  @override
  ByteConversionSink startChunkedConversion(Sink<String> sink) =>
      _systemDecoder.startChunkedConversion(sink);

  @override
  Stream<String> bind(Stream<List<int>> stream) => _systemDecoder.bind(stream);

  @override
  Converter<List<int>, T> fuse<T>(Converter<String, T> other) =>
      _systemDecoder.fuse(other);
}