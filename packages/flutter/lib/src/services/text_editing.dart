import 'dart:ui' show TextAffinity, TextPosition, TextRange;

import 'package:flutter/foundation.dart';

export 'dart:ui' show TextAffinity, TextPosition;

@immutable
class TextSelection extends TextRange {
  const TextSelection({
    required this.baseOffset,
    required this.extentOffset,
    this.affinity = TextAffinity.downstream,
    this.isDirectional = false,
  }) : super(
         start: baseOffset < extentOffset ? baseOffset : extentOffset,
         end: baseOffset < extentOffset ? extentOffset : baseOffset,
       );

  const TextSelection.collapsed({
    required int offset,
    this.affinity = TextAffinity.downstream,
  }) : baseOffset = offset,
       extentOffset = offset,
       isDirectional = false,
       super.collapsed(offset);

  TextSelection.fromPosition(TextPosition position)
    : baseOffset = position.offset,
      extentOffset = position.offset,
      affinity = position.affinity,
      isDirectional = false,
      super.collapsed(position.offset);

  final int baseOffset;

  final int extentOffset;

  final TextAffinity affinity;

  final bool isDirectional;

  TextPosition get base {
    final TextAffinity affinity;
    if (!isValid || baseOffset == extentOffset) {
      affinity = this.affinity;
    } else if (baseOffset < extentOffset) {
      affinity = TextAffinity.downstream;
    } else {
      affinity = TextAffinity.upstream;
    }
    return TextPosition(offset: baseOffset, affinity: affinity);
  }

  TextPosition get extent {
    final TextAffinity affinity;
    if (!isValid || baseOffset == extentOffset) {
      affinity = this.affinity;
    } else if (baseOffset < extentOffset) {
      affinity = TextAffinity.upstream;
    } else {
      affinity = TextAffinity.downstream;
    }
    return TextPosition(offset: extentOffset, affinity: affinity);
  }

  @override
  String toString() {
    final String typeName = objectRuntimeType(this, 'TextSelection');
    if (!isValid) {
      return '$typeName.invalid';
    }
    return isCollapsed
      ? '$typeName.collapsed(offset: $baseOffset, affinity: $affinity, isDirectional: $isDirectional)'
      : '$typeName(baseOffset: $baseOffset, extentOffset: $extentOffset, isDirectional: $isDirectional)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    if (other is! TextSelection) {
      return false;
    }
    if (!isValid) {
      return !other.isValid;
    }
    return other.baseOffset == baseOffset
        && other.extentOffset == extentOffset
        && (!isCollapsed || other.affinity == affinity)
        && other.isDirectional == isDirectional;
  }

  @override
  int get hashCode {
    if (!isValid) {
      return Object.hash(-1.hashCode, -1.hashCode, TextAffinity.downstream.hashCode);
    }

    final int affinityHash = isCollapsed ? affinity.hashCode : TextAffinity.downstream.hashCode;
    return Object.hash(baseOffset.hashCode, extentOffset.hashCode, affinityHash, isDirectional.hashCode);
  }


  TextSelection copyWith({
    int? baseOffset,
    int? extentOffset,
    TextAffinity? affinity,
    bool? isDirectional,
  }) {
    return TextSelection(
      baseOffset: baseOffset ?? this.baseOffset,
      extentOffset: extentOffset ?? this.extentOffset,
      affinity: affinity ?? this.affinity,
      isDirectional: isDirectional ?? this.isDirectional,
    );
  }

  TextSelection expandTo(TextPosition position, [bool extentAtIndex = false]) {
    // If position is already within in the selection, there's nothing to do.
    if (position.offset >= start && position.offset <= end) {
      return this;
    }

    final bool normalized = baseOffset <= extentOffset;
    if (position.offset <= start) {
      // Here the position is somewhere before the selection: ..|..[...]....
      if (extentAtIndex) {
        return copyWith(
          baseOffset: end,
          extentOffset: position.offset,
          affinity: position.affinity,
        );
      }
      return copyWith(
        baseOffset: normalized ? position.offset : baseOffset,
        extentOffset: normalized ? extentOffset : position.offset,
      );
    }
    // Here the position is somewhere after the selection: ....[...]..|..
    if (extentAtIndex) {
      return copyWith(
        baseOffset: start,
        extentOffset: position.offset,
        affinity: position.affinity,
      );
    }
    return copyWith(
      baseOffset: normalized ? baseOffset : position.offset,
      extentOffset: normalized ? position.offset : extentOffset,
    );
  }

  TextSelection extendTo(TextPosition position) {
    // If the selection's extent is at the position already, then nothing
    // happens.
    if (extent == position) {
      return this;
    }

    return copyWith(
      extentOffset: position.offset,
      affinity: position.affinity,
    );
  }
}