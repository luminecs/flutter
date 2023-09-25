import 'dart:convert';

import 'package:meta/meta.dart';

import 'deserialization_factory.dart';
import 'error.dart';
import 'message.dart';

const List<Type> _supportedKeyValueTypes = <Type>[String, int];

DriverError _createInvalidKeyValueTypeError(String invalidType) {
  return DriverError('Unsupported key value type $invalidType. Flutter Driver only supports ${_supportedKeyValueTypes.join(", ")}');
}

abstract class CommandWithTarget extends Command {
  CommandWithTarget(this.finder, {super.timeout});

  CommandWithTarget.deserialize(super.json, DeserializeFinderFactory finderFactory)
    : finder = finderFactory.deserializeFinder(json),
      super.deserialize();

  final SerializableFinder finder;

  @override
  Map<String, String> serialize() =>
      super.serialize()..addAll(finder.serialize());
}

class WaitFor extends CommandWithTarget {
  WaitFor(super.finder, {super.timeout});

  WaitFor.deserialize(super.json, super.finderFactory) : super.deserialize();

  @override
  String get kind => 'waitFor';
}

class WaitForAbsent extends CommandWithTarget {
  WaitForAbsent(super.finder, {super.timeout});

  WaitForAbsent.deserialize(super.json, super.finderFactory) : super.deserialize();

  @override
  String get kind => 'waitForAbsent';
}

class WaitForTappable extends CommandWithTarget {
  WaitForTappable(super.finder, {super.timeout});

  WaitForTappable.deserialize(
      super.json, super.finderFactory)
      : super.deserialize();

  @override
  String get kind => 'waitForTappable';
}

abstract class SerializableFinder {

  const SerializableFinder();

  String get finderType;

  @mustCallSuper
  Map<String, String> serialize() => <String, String>{
    'finderType': finderType,
  };
}

class ByTooltipMessage extends SerializableFinder {
  const ByTooltipMessage(this.text);

  final String text;

  @override
  String get finderType => 'ByTooltipMessage';

  @override
  Map<String, String> serialize() => super.serialize()..addAll(<String, String>{
    'text': text,
  });

  static ByTooltipMessage deserialize(Map<String, String> json) {
    return ByTooltipMessage(json['text']!);
  }
}

class BySemanticsLabel extends SerializableFinder {
  const BySemanticsLabel(this.label);

  final Pattern label;

  @override
  String get finderType => 'BySemanticsLabel';

  @override
  Map<String, String> serialize() {
    if (label is RegExp) {
      final RegExp regExp = label as RegExp;
      return super.serialize()..addAll(<String, String>{
        'label': regExp.pattern,
        'isRegExp': 'true',
      });
    } else {
      return super.serialize()..addAll(<String, String>{
        'label': label as String,
      });
    }
  }

  static BySemanticsLabel deserialize(Map<String, String> json) {
    final bool isRegExp = json['isRegExp'] == 'true';
    return BySemanticsLabel(isRegExp ? RegExp(json['label']!) : json['label']!);
  }
}

class ByText extends SerializableFinder {
  const ByText(this.text);

  final String text;

  @override
  String get finderType => 'ByText';

  @override
  Map<String, String> serialize() => super.serialize()..addAll(<String, String>{
    'text': text,
  });

  static ByText deserialize(Map<String, String> json) {
    return ByText(json['text']!);
  }
}

class ByValueKey extends SerializableFinder {
  ByValueKey(this.keyValue)
      : keyValueString = '$keyValue',
        keyValueType = '${keyValue.runtimeType}' {
    if (!_supportedKeyValueTypes.contains(keyValue.runtimeType)) {
      throw _createInvalidKeyValueTypeError('$keyValue.runtimeType');
    }
  }

  final dynamic keyValue;

  final String keyValueString;

  final String keyValueType;

  @override
  String get finderType => 'ByValueKey';

  @override
  Map<String, String> serialize() => super.serialize()..addAll(<String, String>{
    'keyValueString': keyValueString,
    'keyValueType': keyValueType,
  });

  static ByValueKey deserialize(Map<String, String> json) {
    final String keyValueString = json['keyValueString']!;
    final String keyValueType = json['keyValueType']!;
    switch (keyValueType) {
      case 'int':
        return ByValueKey(int.parse(keyValueString));
      case 'String':
        return ByValueKey(keyValueString);
      default:
        throw _createInvalidKeyValueTypeError(keyValueType);
    }
  }
}

class ByType extends SerializableFinder {
  const ByType(this.type);

  final String type;

  @override
  String get finderType => 'ByType';

  @override
  Map<String, String> serialize() => super.serialize()..addAll(<String, String>{
    'type': type,
  });

  static ByType deserialize(Map<String, String> json) {
    return ByType(json['type']!);
  }
}

class PageBack extends SerializableFinder {
  const PageBack();

  @override
  String get finderType => 'PageBack';
}

class Descendant extends SerializableFinder {
  const Descendant({
    required this.of,
    required this.matching,
    this.matchRoot = false,
    this.firstMatchOnly = false,
  });

  final SerializableFinder of;

  final SerializableFinder matching;

  final bool matchRoot;

  final bool firstMatchOnly;

  @override
  String get finderType => 'Descendant';

  @override
  Map<String, String> serialize() {
    return super.serialize()
        ..addAll(<String, String>{
          'of': jsonEncode(of.serialize()),
          'matching': jsonEncode(matching.serialize()),
          'matchRoot': matchRoot ? 'true' : 'false',
          'firstMatchOnly': firstMatchOnly ? 'true' : 'false',
        });
  }

  static Descendant deserialize(Map<String, String> json, DeserializeFinderFactory finderFactory) {
    final Map<String, String> jsonOfMatcher =
        Map<String, String>.from(jsonDecode(json['of']!) as Map<String, dynamic>);
    final Map<String, String> jsonMatchingMatcher =
        Map<String, String>.from(jsonDecode(json['matching']!) as Map<String, dynamic>);
    return Descendant(
      of: finderFactory.deserializeFinder(jsonOfMatcher),
      matching: finderFactory.deserializeFinder(jsonMatchingMatcher),
      matchRoot: json['matchRoot'] == 'true',
      firstMatchOnly: json['firstMatchOnly'] == 'true',
    );
  }
}

class Ancestor extends SerializableFinder {
  const Ancestor({
    required this.of,
    required this.matching,
    this.matchRoot = false,
    this.firstMatchOnly = false,
  });

  final SerializableFinder of;

  final SerializableFinder matching;

  final bool matchRoot;

  final bool firstMatchOnly;

  @override
  String get finderType => 'Ancestor';

  @override
  Map<String, String> serialize() {
    return super.serialize()
      ..addAll(<String, String>{
        'of': jsonEncode(of.serialize()),
        'matching': jsonEncode(matching.serialize()),
        'matchRoot': matchRoot ? 'true' : 'false',
        'firstMatchOnly': firstMatchOnly ? 'true' : 'false',
      });
  }

  static Ancestor deserialize(Map<String, String> json, DeserializeFinderFactory finderFactory) {
    final Map<String, String> jsonOfMatcher =
        Map<String, String>.from(jsonDecode(json['of']!) as Map<String, dynamic>);
    final Map<String, String> jsonMatchingMatcher =
        Map<String, String>.from(jsonDecode(json['matching']!) as Map<String, dynamic>);
    return Ancestor(
      of: finderFactory.deserializeFinder(jsonOfMatcher),
      matching: finderFactory.deserializeFinder(jsonMatchingMatcher),
      matchRoot: json['matchRoot'] == 'true',
      firstMatchOnly: json['firstMatchOnly'] == 'true',
    );
  }
}

class GetSemanticsId extends CommandWithTarget {

  GetSemanticsId(super.finder, {super.timeout});

  GetSemanticsId.deserialize(super.json, super.finderFactory)
    : super.deserialize();

  @override
  String get kind => 'get_semantics_id';
}

class GetSemanticsIdResult extends Result {

  const GetSemanticsIdResult(this.id);

  final int id;

  static GetSemanticsIdResult fromJson(Map<String, dynamic> json) {
    return GetSemanticsIdResult(json['id'] as int);
  }

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{'id': id};
}