// Copyright 2014 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

import 'message_codecs.dart';
import 'system_channels.dart';

export 'dart:typed_data' show Uint8List;

typedef _BucketVisitor = void Function(RestorationBucket bucket);

class RestorationManager extends ChangeNotifier {
  RestorationManager() {
    if (kFlutterMemoryAllocationsEnabled) {
      ChangeNotifier.maybeDispatchObjectCreation(this);
    }
    initChannels();
  }

  @protected
  void initChannels() {
    SystemChannels.restoration.setMethodCallHandler(_methodHandler);
  }

  Future<RestorationBucket?> get rootBucket {
    if (_rootBucketIsValid) {
      return SynchronousFuture<RestorationBucket?>(_rootBucket);
    }
    if (_pendingRootBucket == null) {
      _pendingRootBucket = Completer<RestorationBucket?>();
      _getRootBucketFromEngine();
    }
    return _pendingRootBucket!.future;
  }
  RestorationBucket? _rootBucket; // May be null to indicate that restoration is turned off.
  Completer<RestorationBucket?>? _pendingRootBucket;
  bool _rootBucketIsValid = false;

  bool get isReplacing => _isReplacing;
  bool _isReplacing = false;

  Future<void> _getRootBucketFromEngine() async {
    final Map<Object?, Object?>? config = await SystemChannels.restoration.invokeMethod<Map<Object?, Object?>>('get');
    if (_pendingRootBucket == null) {
      // The restoration data was obtained via other means (e.g. by calling
      // [handleRestorationDataUpdate] while the request to the engine was
      // outstanding. Ignore the engine's response.
      return;
    }
    assert(_rootBucket == null);
    _parseAndHandleRestorationUpdateFromEngine(config);
  }

  void _parseAndHandleRestorationUpdateFromEngine(Map<Object?, Object?>? update) {
    handleRestorationUpdateFromEngine(
      enabled: update != null && update['enabled']! as bool,
      data: update == null ? null : update['data'] as Uint8List?,
    );
  }

  @protected
  void handleRestorationUpdateFromEngine({required bool enabled, required Uint8List? data}) {
    assert(enabled || data == null);

    _isReplacing = _rootBucketIsValid && enabled;
    if (_isReplacing) {
      SchedulerBinding.instance.addPostFrameCallback((Duration _) {
        _isReplacing = false;
      });
    }

    final RestorationBucket? oldRoot = _rootBucket;
    _rootBucket = enabled
        ? RestorationBucket.root(manager: this, rawData: _decodeRestorationData(data))
        : null;
    _rootBucketIsValid = true;
    assert(_pendingRootBucket == null || !_pendingRootBucket!.isCompleted);
    _pendingRootBucket?.complete(_rootBucket);
    _pendingRootBucket = null;

    if (_rootBucket != oldRoot) {
      notifyListeners();
      oldRoot?.dispose();
    }
  }

  @protected
  Future<void> sendToEngine(Uint8List encodedData) {
    return SystemChannels.restoration.invokeMethod<void>(
      'put',
      encodedData,
    );
  }

  Future<void> _methodHandler(MethodCall call) async {
    switch (call.method) {
      case 'push':
        _parseAndHandleRestorationUpdateFromEngine(call.arguments as Map<Object?, Object?>);
      default:
        throw UnimplementedError("${call.method} was invoked but isn't implemented by $runtimeType");
    }
  }

  Map<Object?, Object?>? _decodeRestorationData(Uint8List? data) {
    if (data == null) {
      return null;
    }
    final ByteData encoded = data.buffer.asByteData(data.offsetInBytes, data.lengthInBytes);
    return const StandardMessageCodec().decodeMessage(encoded) as Map<Object?, Object?>?;
  }

  Uint8List _encodeRestorationData(Map<Object?, Object?> data) {
    final ByteData encoded = const StandardMessageCodec().encodeMessage(data)!;
    return encoded.buffer.asUint8List(encoded.offsetInBytes, encoded.lengthInBytes);
  }

  bool _debugDoingUpdate = false;
  bool _serializationScheduled = false;

  final Set<RestorationBucket> _bucketsNeedingSerialization = <RestorationBucket>{};

  @protected
  @visibleForTesting
  void scheduleSerializationFor(RestorationBucket bucket) {
    assert(bucket._manager == this);
    assert(!_debugDoingUpdate);
    _bucketsNeedingSerialization.add(bucket);
    if (!_serializationScheduled) {
      _serializationScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((Duration _) => _doSerialization());
    }
  }

  @protected
  @visibleForTesting
  void unscheduleSerializationFor(RestorationBucket bucket) {
    assert(bucket._manager == this);
    assert(!_debugDoingUpdate);
    _bucketsNeedingSerialization.remove(bucket);
  }

  void _doSerialization() {
    if (!_serializationScheduled) {
      return;
    }
    assert(() {
      _debugDoingUpdate = true;
      return true;
    }());
    _serializationScheduled = false;

    for (final RestorationBucket bucket in _bucketsNeedingSerialization) {
      bucket.finalize();
    }
    _bucketsNeedingSerialization.clear();
    sendToEngine(_encodeRestorationData(_rootBucket!._rawData));

    assert(() {
      _debugDoingUpdate = false;
      return true;
    }());
  }

  void flushData() {
    assert(!_debugDoingUpdate);
    if (SchedulerBinding.instance.hasScheduledFrame) {
      return;
    }
    _doSerialization();
    assert(!_serializationScheduled);
  }
}

class RestorationBucket {
  RestorationBucket.empty({
    required String restorationId,
    required Object? debugOwner,
  }) : _restorationId = restorationId,
       _rawData = <String, Object?>{} {
    assert(() {
      _debugOwner = debugOwner;
      return true;
    }());
  }

  RestorationBucket.root({
    required RestorationManager manager,
    required Map<Object?, Object?>? rawData,
  }) : _manager = manager,
       _rawData = rawData ?? <Object?, Object?>{},
       _restorationId = 'root' {
    assert(() {
      _debugOwner = manager;
      return true;
    }());
  }

  RestorationBucket.child({
    required String restorationId,
    required RestorationBucket parent,
    required Object? debugOwner,
  }) : assert(parent._rawChildren[restorationId] != null),
       _manager = parent._manager,
       _parent = parent,
       _rawData = parent._rawChildren[restorationId]! as Map<Object?, Object?>,
       _restorationId = restorationId {
    assert(() {
      _debugOwner = debugOwner;
      return true;
    }());
  }

  static const String _childrenMapKey = 'c';
  static const String _valuesMapKey = 'v';

  final Map<Object?, Object?> _rawData;

  Object? get debugOwner {
    assert(_debugAssertNotDisposed());
    return _debugOwner;
  }
  Object? _debugOwner;

  RestorationManager? _manager;
  RestorationBucket? _parent;

  bool get isReplacing => _manager?.isReplacing ?? false;

  String get restorationId {
    assert(_debugAssertNotDisposed());
    return _restorationId;
  }
  String _restorationId;

  // Maps a restoration ID to the raw map representation of a child bucket.
  Map<Object?, Object?> get _rawChildren => _rawData.putIfAbsent(_childrenMapKey, () => <Object?, Object?>{})! as Map<Object?, Object?>;
  // Maps a restoration ID to a value that is stored in this bucket.
  Map<Object?, Object?> get _rawValues => _rawData.putIfAbsent(_valuesMapKey, () => <Object?, Object?>{})! as Map<Object?, Object?>;

  // Get and store values.

  P? read<P>(String restorationId) {
    assert(_debugAssertNotDisposed());
    return _rawValues[restorationId] as P?;
  }

  void write<P>(String restorationId, P value) {
    assert(_debugAssertNotDisposed());
    assert(debugIsSerializableForRestoration(value));
    if (_rawValues[restorationId] != value || !_rawValues.containsKey(restorationId)) {
      _rawValues[restorationId] = value;
      _markNeedsSerialization();
    }
  }

  P? remove<P>(String restorationId) {
    assert(_debugAssertNotDisposed());
    final bool needsUpdate = _rawValues.containsKey(restorationId);
    final P? result = _rawValues.remove(restorationId) as P?;
    if (_rawValues.isEmpty) {
      _rawData.remove(_valuesMapKey);
    }
    if (needsUpdate) {
      _markNeedsSerialization();
    }
    return result;
  }

  bool contains(String restorationId) {
    assert(_debugAssertNotDisposed());
    return _rawValues.containsKey(restorationId);
  }

  // Child management.

  // The restoration IDs and associated buckets of children that have been
  // claimed via [claimChild].
  final Map<String, RestorationBucket> _claimedChildren = <String, RestorationBucket>{};
  // Newly created child buckets whose restoration ID is still in use, see
  // comment in [claimChild] for details.
  final Map<String, List<RestorationBucket>> _childrenToAdd = <String, List<RestorationBucket>>{};

  RestorationBucket claimChild(String restorationId, {required Object? debugOwner}) {
    assert(_debugAssertNotDisposed());
    // There are three cases to consider:
    // 1. Claiming an ID that has already been claimed.
    // 2. Claiming an ID that doesn't yet exist in [_rawChildren].
    // 3. Claiming an ID that does exist in [_rawChildren] and hasn't been
    //    claimed yet.
    // If an ID has already been claimed (case 1) the current owner may give up
    // that ID later this frame and it can be re-used. In anticipation of the
    // previous owner's surrender of the id, we return an empty bucket for this
    // new claim and check in [_debugAssertIntegrity] that at the end of the
    // frame the old owner actually did surrendered the id.
    // Case 2 also requires the creation of a new empty bucket.
    // In Case 3 we create a new bucket wrapping the existing data in
    // [_rawChildren].

    // Case 1+2: Adopt and return an empty bucket.
    if (_claimedChildren.containsKey(restorationId) || !_rawChildren.containsKey(restorationId)) {
      final RestorationBucket child = RestorationBucket.empty(
        debugOwner: debugOwner,
        restorationId: restorationId,
      );
      adoptChild(child);
      return child;
    }

    // Case 3: Return bucket wrapping the existing data.
    assert(_rawChildren[restorationId] != null);
    final RestorationBucket child = RestorationBucket.child(
      restorationId: restorationId,
      parent: this,
      debugOwner: debugOwner,
    );
    _claimedChildren[restorationId] = child;
    return child;
  }

  void adoptChild(RestorationBucket child) {
    assert(_debugAssertNotDisposed());
    if (child._parent != this) {
      child._parent?._removeChildData(child);
      child._parent = this;
      _addChildData(child);
      if (child._manager != _manager) {
        _recursivelyUpdateManager(child);
      }
    }
    assert(child._parent == this);
    assert(child._manager == _manager);
  }

  void _dropChild(RestorationBucket child) {
    assert(child._parent == this);
    _removeChildData(child);
    child._parent = null;
    if (child._manager != null) {
      child._updateManager(null);
      child._visitChildren(_recursivelyUpdateManager);
    }
  }

  bool _needsSerialization = false;
  void _markNeedsSerialization() {
    if (!_needsSerialization) {
      _needsSerialization = true;
      _manager?.scheduleSerializationFor(this);
    }
  }

  @visibleForTesting
  void finalize() {
    assert(_debugAssertNotDisposed());
    assert(_needsSerialization);
    _needsSerialization = false;
    assert(_debugAssertIntegrity());
  }

  void _recursivelyUpdateManager(RestorationBucket bucket) {
    bucket._updateManager(_manager);
    bucket._visitChildren(_recursivelyUpdateManager);
  }

  void _updateManager(RestorationManager? newManager) {
    if (_manager == newManager) {
      return;
    }
    if (_needsSerialization) {
      _manager?.unscheduleSerializationFor(this);
    }
    _manager = newManager;
    if (_needsSerialization && _manager != null) {
      _needsSerialization = false;
      _markNeedsSerialization();
    }
  }

  bool _debugAssertIntegrity() {
    assert(() {
      if (_childrenToAdd.isEmpty) {
        return true;
      }
      final List<DiagnosticsNode> error = <DiagnosticsNode>[
        ErrorSummary('Multiple owners claimed child RestorationBuckets with the same IDs.'),
        ErrorDescription('The following IDs were claimed multiple times from the parent $this:'),
      ];
      for (final MapEntry<String, List<RestorationBucket>> child in _childrenToAdd.entries) {
        final String id = child.key;
        final List<RestorationBucket> buckets = child.value;
        assert(buckets.isNotEmpty);
        assert(_claimedChildren.containsKey(id));
        error.addAll(<DiagnosticsNode>[
          ErrorDescription(' * "$id" was claimed by:'),
          ...buckets.map((RestorationBucket bucket) => ErrorDescription('   * ${bucket.debugOwner}')),
          ErrorDescription('   * ${_claimedChildren[id]!.debugOwner} (current owner)'),
        ]);
      }
      throw FlutterError.fromParts(error);
    }());
    return true;
  }

  void _removeChildData(RestorationBucket child) {
    assert(child._parent == this);
    if (_claimedChildren.remove(child.restorationId) == child) {
      _rawChildren.remove(child.restorationId);
      final List<RestorationBucket>? pendingChildren = _childrenToAdd[child.restorationId];
      if (pendingChildren != null) {
        final RestorationBucket toAdd = pendingChildren.removeLast();
        _finalizeAddChildData(toAdd);
        if (pendingChildren.isEmpty) {
          _childrenToAdd.remove(child.restorationId);
        }
      }
      if (_rawChildren.isEmpty) {
        _rawData.remove(_childrenMapKey);
      }
      _markNeedsSerialization();
      return;
    }
    _childrenToAdd[child.restorationId]?.remove(child);
    if (_childrenToAdd[child.restorationId]?.isEmpty ?? false) {
      _childrenToAdd.remove(child.restorationId);
    }
  }

  void _addChildData(RestorationBucket child) {
    assert(child._parent == this);
    if (_claimedChildren.containsKey(child.restorationId)) {
      // Delay addition until the end of the frame in the hopes that the current
      // owner of the child with the same ID will have given up that child by
      // then.
      _childrenToAdd.putIfAbsent(child.restorationId, () => <RestorationBucket>[]).add(child);
      _markNeedsSerialization();
      return;
    }
    _finalizeAddChildData(child);
    _markNeedsSerialization();
  }

  void _finalizeAddChildData(RestorationBucket child) {
    assert(_claimedChildren[child.restorationId] == null);
    assert(_rawChildren[child.restorationId] == null);
    _claimedChildren[child.restorationId] = child;
    _rawChildren[child.restorationId] = child._rawData;
  }

  void _visitChildren(_BucketVisitor visitor, {bool concurrentModification = false}) {
    Iterable<RestorationBucket> children = _claimedChildren.values
        .followedBy(_childrenToAdd.values.expand((List<RestorationBucket> buckets) => buckets));
    if (concurrentModification) {
      children = children.toList(growable: false);
    }
    children.forEach(visitor);
  }

  // Bucket management

  void rename(String newRestorationId) {
    assert(_debugAssertNotDisposed());
    if (newRestorationId == restorationId) {
      return;
    }
    _parent?._removeChildData(this);
    _restorationId = newRestorationId;
    _parent?._addChildData(this);
  }

  void dispose() {
    assert(_debugAssertNotDisposed());
    _visitChildren(_dropChild, concurrentModification: true);
    _claimedChildren.clear();
    _childrenToAdd.clear();
    _parent?._removeChildData(this);
    _parent = null;
    _updateManager(null);
    _debugDisposed = true;
  }

  @override
  String toString() => '${objectRuntimeType(this, 'RestorationBucket')}(restorationId: $restorationId, owner: $debugOwner)';

  bool _debugDisposed = false;
  bool _debugAssertNotDisposed() {
    assert(() {
      if (_debugDisposed) {
        throw FlutterError(
            'A $runtimeType was used after being disposed.\n'
            'Once you have called dispose() on a $runtimeType, it can no longer be used.',
        );
      }
      return true;
    }());
    return true;
  }
}

bool debugIsSerializableForRestoration(Object? object) {
  bool result = false;

  assert(() {
    try {
      const StandardMessageCodec().encodeMessage(object);
      result = true;
    } catch (error) {
      // This is only used in asserts, so reporting the exception isn't
      // particularly useful, since the assert itself will likely fail.
      result = false;
    }
    return true;
  }());

  return result;
}