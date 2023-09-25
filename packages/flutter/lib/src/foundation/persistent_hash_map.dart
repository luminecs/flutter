// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

class PersistentHashMap<K extends Object, V> {
  const PersistentHashMap.empty() : this._(null);

  const PersistentHashMap._(this._root);

  final _TrieNode? _root;

  PersistentHashMap<K, V> put(K key, V value) {
    final _TrieNode newRoot =
        (_root ?? _CompressedNode.empty).put(0, key, key.hashCode, value);
    if (newRoot == _root) {
      return this;
    }
    return PersistentHashMap<K, V>._(newRoot);
  }

  @pragma('dart2js:as:trust')
  V? operator[](K key) {
    if (_root == null) {
      return null;
    }

    // Unfortunately can not use unsafeCast<V?>(...) here because it leads
    // to worse code generation on VM.
    return _root.get(0, key, key.hashCode) as V?;
  }
}

abstract class _TrieNode {
  static const int hashBitsPerLevel = 5;
  static const int hashBitsPerLevelMask = (1 << hashBitsPerLevel) - 1;

  @pragma('vm:prefer-inline')
  static int trieIndex(int hash, int bitIndex) {
    return (hash >>> bitIndex) & hashBitsPerLevelMask;
  }

  _TrieNode put(int bitIndex, Object key, int keyHash, Object? value);

  Object? get(int bitIndex, Object key, int keyHash);
}

class _FullNode extends _TrieNode {
  _FullNode(this.descendants);

  static const int numElements = 1 << _TrieNode.hashBitsPerLevel;

  // Caveat: this array is actually List<_TrieNode?> but typing it like that
  // will introduce a type check when copying this array. For performance
  // reasons we instead omit the type and use (implicit) casts when accessing
  // it instead.
  final List<Object?> descendants;

  @override
  _TrieNode put(int bitIndex, Object key, int keyHash, Object? value) {
    final int index = _TrieNode.trieIndex(keyHash, bitIndex);
    final _TrieNode node = _unsafeCast<_TrieNode?>(descendants[index]) ?? _CompressedNode.empty;
    final _TrieNode newNode = node.put(bitIndex + _TrieNode.hashBitsPerLevel, key, keyHash, value);
    return identical(newNode, node)
        ? this
        : _FullNode(_copy(descendants)..[index] = newNode);
  }

  @override
  Object? get(int bitIndex, Object key, int keyHash) {
    final int index = _TrieNode.trieIndex(keyHash, bitIndex);

    final _TrieNode? node = _unsafeCast<_TrieNode?>(descendants[index]);
    return node?.get(bitIndex + _TrieNode.hashBitsPerLevel, key, keyHash);
  }
}

class _CompressedNode extends _TrieNode {
  _CompressedNode(this.occupiedIndices, this.keyValuePairs);
  _CompressedNode._empty() : this(0, _emptyArray);

  factory _CompressedNode.single(int bitIndex, int keyHash, _TrieNode node) {
    final int bit = 1 << _TrieNode.trieIndex(keyHash, bitIndex);
    // A single (null, node) pair.
    final List<Object?> keyValuePairs = _makeArray(2)
      ..[1] = node;
    return _CompressedNode(bit, keyValuePairs);
  }

  static final _CompressedNode empty = _CompressedNode._empty();

  // Caveat: do not replace with <Object?>[] or const <Object?>[] this will
  // introduce polymorphism in the keyValuePairs field and significantly
  // degrade performance on the VM because it will no longer be able to
  // devirtualize method calls on keyValuePairs.
  static final List<Object?> _emptyArray = _makeArray(0);

  // This bitmap only uses 32bits due to [_TrieNode.hashBitsPerLevel] being `5`.
  final int occupiedIndices;
  final List<Object?> keyValuePairs;

  @override
  _TrieNode put(int bitIndex, Object key, int keyHash, Object? value) {
    final int bit = 1 << _TrieNode.trieIndex(keyHash, bitIndex);
    final int index = _compressedIndex(bit);

    if ((occupiedIndices & bit) != 0) {
      // Index is occupied.
      final Object? keyOrNull = keyValuePairs[2 * index];
      final Object? valueOrNode = keyValuePairs[2 * index + 1];

      // Is this a (null, trieNode) pair?
      if (identical(keyOrNull, null)) {
        final _TrieNode newNode = _unsafeCast<_TrieNode>(valueOrNode).put(
            bitIndex + _TrieNode.hashBitsPerLevel, key, keyHash, value);
        if (newNode == valueOrNode) {
          return this;
        }
        return _CompressedNode(
            occupiedIndices, _copy(keyValuePairs)..[2 * index + 1] = newNode);
      }

      if (key == keyOrNull) {
        // Found key/value pair with a matching key. If values match
        // then avoid doing anything otherwise copy and update.
        return identical(value, valueOrNode)
            ? this
            : _CompressedNode(
                occupiedIndices, _copy(keyValuePairs)..[2 * index + 1] = value);
      }

      // Two different keys at the same index, resolve collision.
      final _TrieNode newNode = _resolveCollision(
          bitIndex + _TrieNode.hashBitsPerLevel,
          keyOrNull,
          valueOrNode,
          key,
          keyHash,
          value);
      return _CompressedNode(
          occupiedIndices,
          _copy(keyValuePairs)
            ..[2 * index] = null
            ..[2 * index + 1] = newNode);
    } else {
      // Adding new key/value mapping.
      final int occupiedCount = _bitCount(occupiedIndices);
      if (occupiedCount >= 16) {
        // Too many occupied: inflate compressed node into full node and
        // update descendant at the corresponding index.
        return _inflate(bitIndex)
          ..descendants[_TrieNode.trieIndex(keyHash, bitIndex)] =
              _CompressedNode.empty.put(
                  bitIndex + _TrieNode.hashBitsPerLevel, key, keyHash, value);
      } else {
        // Grow keyValuePairs by inserting key/value pair at the given
        // index.
        final int prefixLength = 2 * index;
        final int totalLength = 2 * occupiedCount;
        final List<Object?> newKeyValuePairs = _makeArray(totalLength + 2);
        for (int srcIndex = 0; srcIndex < prefixLength; srcIndex++) {
          newKeyValuePairs[srcIndex] = keyValuePairs[srcIndex];
        }
        newKeyValuePairs[prefixLength] = key;
        newKeyValuePairs[prefixLength + 1] = value;
        for (int srcIndex = prefixLength, dstIndex = prefixLength + 2;
            srcIndex < totalLength;
            srcIndex++, dstIndex++) {
          newKeyValuePairs[dstIndex] = keyValuePairs[srcIndex];
        }
        return _CompressedNode(occupiedIndices | bit, newKeyValuePairs);
      }
    }
  }

  @override
  Object? get(int bitIndex, Object key, int keyHash) {
    final int bit = 1 << _TrieNode.trieIndex(keyHash, bitIndex);
    if ((occupiedIndices & bit) == 0) {
      return null;
    }
    final int index = _compressedIndex(bit);
    final Object? keyOrNull = keyValuePairs[2 * index];
    final Object? valueOrNode = keyValuePairs[2 * index + 1];
    if (keyOrNull == null) {
      final _TrieNode node = _unsafeCast<_TrieNode>(valueOrNode);
      return node.get(bitIndex + _TrieNode.hashBitsPerLevel, key, keyHash);
    }
    if (key == keyOrNull) {
      return valueOrNode;
    }
    return null;
  }

  _FullNode _inflate(int bitIndex) {
    final List<Object?> nodes = _makeArray(_FullNode.numElements);
    int srcIndex = 0;
    for (int dstIndex = 0; dstIndex < _FullNode.numElements; dstIndex++) {
      if (((occupiedIndices >>> dstIndex) & 1) != 0) {
        final Object? keyOrNull = keyValuePairs[srcIndex];
        if (keyOrNull == null) {
          nodes[dstIndex] = keyValuePairs[srcIndex + 1];
        } else {
          nodes[dstIndex] = _CompressedNode.empty.put(
              bitIndex + _TrieNode.hashBitsPerLevel,
              keyOrNull,
              keyValuePairs[srcIndex].hashCode,
              keyValuePairs[srcIndex + 1]);
        }
        srcIndex += 2;
      }
    }
    return _FullNode(nodes);
  }

  @pragma('vm:prefer-inline')
  int _compressedIndex(int bit) {
    return _bitCount(occupiedIndices & (bit - 1));
  }

  static _TrieNode _resolveCollision(int bitIndex, Object existingKey,
      Object? existingValue, Object key, int keyHash, Object? value) {
    final int existingKeyHash = existingKey.hashCode;
    // Check if this is a full hash collision and use _HashCollisionNode
    // in this case.
    return (existingKeyHash == keyHash)
        ? _HashCollisionNode.fromCollision(
            keyHash, existingKey, existingValue, key, value)
        : _CompressedNode.empty
            .put(bitIndex, existingKey, existingKeyHash, existingValue)
            .put(bitIndex, key, keyHash, value);
  }
}

class _HashCollisionNode extends _TrieNode {
  _HashCollisionNode(this.hash, this.keyValuePairs);

  factory _HashCollisionNode.fromCollision(
      int keyHash, Object keyA, Object? valueA, Object keyB, Object? valueB) {
    final List<Object?> list = _makeArray(4);
    list[0] = keyA;
    list[1] = valueA;
    list[2] = keyB;
    list[3] = valueB;
    return _HashCollisionNode(keyHash, list);
  }

  final int hash;
  final List<Object?> keyValuePairs;

  @override
  _TrieNode put(int bitIndex, Object key, int keyHash, Object? val) {
    // Is this another full hash collision?
    if (keyHash == hash) {
      final int index = _indexOf(key);
      if (index != -1) {
        return identical(keyValuePairs[index + 1], val)
            ? this
            : _HashCollisionNode(
                keyHash, _copy(keyValuePairs)..[index + 1] = val);
      }
      final int length = keyValuePairs.length;
      final List<Object?> newArray = _makeArray(length + 2);
      for (int i = 0; i < length; i++) {
        newArray[i] = keyValuePairs[i];
      }
      newArray[length] = key;
      newArray[length + 1] = val;
      return _HashCollisionNode(keyHash, newArray);
    }

    // Not a full hash collision, need to introduce a _CompressedNode which
    // uses previously unused bits.
    return _CompressedNode.single(bitIndex, hash, this)
        .put(bitIndex, key, keyHash, val);
  }

  @override
  Object? get(int bitIndex, Object key, int keyHash) {
    final int index = _indexOf(key);
    return index < 0 ? null : keyValuePairs[index + 1];
  }

  int _indexOf(Object key) {
    final int length = keyValuePairs.length;
    for (int i = 0; i < length; i += 2) {
      if (key == keyValuePairs[i]) {
        return i;
      }
    }
    return -1;
  }
}

@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
int _bitCount(int n) {
  assert((n & 0xFFFFFFFF) == n);
  n = n - ((n >> 1) & 0x55555555);
  n = (n & 0x33333333) + ((n >>> 2) & 0x33333333);
  n = (n + (n >> 4)) & 0x0F0F0F0F;
  n = n + (n >> 8);
  n = n + (n >> 16);
  return n & 0x0000003F;
}

@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
List<Object?> _copy(List<Object?> array) {
  final List<Object?> clone = _makeArray(array.length);
  for (int j = 0; j < array.length; j++) {
    clone[j] = array[j];
  }
  return clone;
}

@pragma('vm:prefer-inline')
@pragma('dart2js:tryInline')
List<Object?> _makeArray(int length) {
  return List<Object?>.filled(length, null);
}

@pragma('dart2js:tryInline')
@pragma('dart2js:as:trust')
@pragma('vm:prefer-inline')
T _unsafeCast<T>(Object? o) {
  return o as T;
}