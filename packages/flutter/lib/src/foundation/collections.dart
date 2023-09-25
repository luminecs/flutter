// TODO(ianh): These should be on the Set and List classes themselves.

bool setEquals<T>(Set<T>? a, Set<T>? b) {
  if (a == null) {
    return b == null;
  }
  if (b == null || a.length != b.length) {
    return false;
  }
  if (identical(a, b)) {
    return true;
  }
  for (final T value in a) {
    if (!b.contains(value)) {
      return false;
    }
  }
  return true;
}

bool listEquals<T>(List<T>? a, List<T>? b) {
  if (a == null) {
    return b == null;
  }
  if (b == null || a.length != b.length) {
    return false;
  }
  if (identical(a, b)) {
    return true;
  }
  for (int index = 0; index < a.length; index += 1) {
    if (a[index] != b[index]) {
      return false;
    }
  }
  return true;
}

bool mapEquals<T, U>(Map<T, U>? a, Map<T, U>? b) {
  if (a == null) {
    return b == null;
  }
  if (b == null || a.length != b.length) {
    return false;
  }
  if (identical(a, b)) {
    return true;
  }
  for (final T key in a.keys) {
    if (!b.containsKey(key) || b[key] != a[key]) {
      return false;
    }
  }
  return true;
}

int binarySearch<T extends Comparable<Object>>(List<T> sortedList, T value) {
  int min = 0;
  int max = sortedList.length;
  while (min < max) {
    final int mid = min + ((max - min) >> 1);
    final T element = sortedList[mid];
    final int comp = element.compareTo(value);
    if (comp == 0) {
      return mid;
    }
    if (comp < 0) {
      min = mid + 1;
    } else {
      max = mid;
    }
  }
  return -1;
}

const int _kMergeSortLimit = 32;

void mergeSort<T>(
  List<T> list, {
  int start = 0,
  int? end,
  int Function(T, T)? compare,
}) {
  end ??= list.length;
  compare ??= _defaultCompare<T>();

  final int length = end - start;
  if (length < 2) {
    return;
  }
  if (length < _kMergeSortLimit) {
    _insertionSort<T>(list, compare: compare, start: start, end: end);
    return;
  }
  // Special case the first split instead of directly calling _mergeSort,
  // because the _mergeSort requires its target to be different from its source,
  // and it requires extra space of the same size as the list to sort. This
  // split allows us to have only half as much extra space, and it ends up in
  // the original place.
  final int middle = start + ((end - start) >> 1);
  final int firstLength = middle - start;
  final int secondLength = end - middle;
  // secondLength is always the same as firstLength, or one greater.
  final List<T> scratchSpace = List<T>.filled(secondLength, list[start]);
  _mergeSort<T>(list, compare, middle, end, scratchSpace, 0);
  final int firstTarget = end - firstLength;
  _mergeSort<T>(list, compare, start, middle, list, firstTarget);
  _merge<T>(compare, list, firstTarget, end, scratchSpace, 0, secondLength, list, start);
}

Comparator<T> _defaultCompare<T>() {
  // If we specify Comparable<T> here, it fails if the type is an int, because
  // int isn't a subtype of comparable. Leaving out the type implicitly converts
  // it to a num, which is a comparable.
  return (T value1, T value2) => (value1 as Comparable<dynamic>).compareTo(value2);
}

void _insertionSort<T>(
  List<T> list, {
  int Function(T, T)? compare,
  int start = 0,
  int? end,
}) {
  // If the same method could have both positional and named optional
  // parameters, this should be (list, [start, end], {compare}).
  compare ??= _defaultCompare<T>();
  end ??= list.length;

  for (int pos = start + 1; pos < end; pos++) {
    int min = start;
    int max = pos;
    final T element = list[pos];
    while (min < max) {
      final int mid = min + ((max - min) >> 1);
      final int comparison = compare(element, list[mid]);
      if (comparison < 0) {
        max = mid;
      } else {
        min = mid + 1;
      }
    }
    list.setRange(min + 1, pos + 1, list, min);
    list[min] = element;
  }
}

void _movingInsertionSort<T>(
  List<T> list,
  int Function(T, T) compare,
  int start,
  int end,
  List<T> target,
  int targetOffset,
) {
  final int length = end - start;
  if (length == 0) {
    return;
  }
  target[targetOffset] = list[start];
  for (int i = 1; i < length; i++) {
    final T element = list[start + i];
    int min = targetOffset;
    int max = targetOffset + i;
    while (min < max) {
      final int mid = min + ((max - min) >> 1);
      if (compare(element, target[mid]) < 0) {
        max = mid;
      } else {
        min = mid + 1;
      }
    }
    target.setRange(min + 1, targetOffset + i + 1, target, min);
    target[min] = element;
  }
}

void _mergeSort<T>(
  List<T> list,
  int Function(T, T) compare,
  int start,
  int end,
  List<T> target,
  int targetOffset,
) {
  final int length = end - start;
  if (length < _kMergeSortLimit) {
    _movingInsertionSort<T>(list, compare, start, end, target, targetOffset);
    return;
  }
  final int middle = start + (length >> 1);
  final int firstLength = middle - start;
  final int secondLength = end - middle;
  // Here secondLength >= firstLength (differs by at most one).
  final int targetMiddle = targetOffset + firstLength;
  // Sort the second half into the end of the target area.
  _mergeSort<T>(list, compare, middle, end, target, targetMiddle);
  // Sort the first half into the end of the source area.
  _mergeSort<T>(list, compare, start, middle, list, middle);
  // Merge the two parts into the target area.
  _merge<T>(
    compare,
    list,
    middle,
    middle + firstLength,
    target,
    targetMiddle,
    targetMiddle + secondLength,
    target,
    targetOffset,
  );
}

void _merge<T>(
  int Function(T, T) compare,
  List<T> firstList,
  int firstStart,
  int firstEnd,
  List<T> secondList,
  int secondStart,
  int secondEnd,
  List<T> target,
  int targetOffset,
) {
  // No empty lists reaches here.
  assert(firstStart < firstEnd);
  assert(secondStart < secondEnd);
  int cursor1 = firstStart;
  int cursor2 = secondStart;
  T firstElement = firstList[cursor1++];
  T secondElement = secondList[cursor2++];
  while (true) {
    if (compare(firstElement, secondElement) <= 0) {
      target[targetOffset++] = firstElement;
      if (cursor1 == firstEnd) {
        // Flushing second list after loop.
        break;
      }
      firstElement = firstList[cursor1++];
    } else {
      target[targetOffset++] = secondElement;
      if (cursor2 != secondEnd) {
        secondElement = secondList[cursor2++];
        continue;
      }
      // Second list empties first. Flushing first list here.
      target[targetOffset++] = firstElement;
      target.setRange(targetOffset, targetOffset + (firstEnd - cursor1), firstList, cursor1);
      return;
    }
  }
  // First list empties first. Reached by break above.
  target[targetOffset++] = secondElement;
  target.setRange(targetOffset, targetOffset + (secondEnd - cursor2), secondList, cursor2);
}