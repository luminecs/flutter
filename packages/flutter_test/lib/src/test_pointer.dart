import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';

import 'test_async_utils.dart';

export 'dart:ui' show Offset;

class TestPointer {
  TestPointer([
    this.pointer = 1,
    this.kind = PointerDeviceKind.touch,
    int? device,
    int buttons = kPrimaryButton,
  ]) : _buttons = buttons {
    switch (kind) {
      case PointerDeviceKind.mouse:
        _device = device ?? 1;
      case PointerDeviceKind.stylus:
      case PointerDeviceKind.invertedStylus:
      case PointerDeviceKind.touch:
      case PointerDeviceKind.trackpad:
      case PointerDeviceKind.unknown:
        _device = device ?? 0;
    }
  }

  int get device => _device;
  late int _device;

  final int pointer;

  final PointerDeviceKind kind;

  int get buttons => _buttons;
  int _buttons;

  bool get isDown => _isDown;
  bool _isDown = false;

  bool get isPanZoomActive => _isPanZoomActive;
  bool _isPanZoomActive = false;

  Offset? get location => _location;
  Offset? _location;


  Offset? get pan => _pan;
  Offset? _pan;

  bool setDownInfo(
    PointerEvent event,
    Offset newLocation, {
    int? buttons,
  }) {
    _location = newLocation;
    if (buttons != null) {
      _buttons = buttons;
    }
    switch (event.runtimeType) {
      case const (PointerDownEvent):
        assert(!isDown);
        _isDown = true;
      case const (PointerUpEvent):
      case const (PointerCancelEvent):
        assert(isDown);
        _isDown = false;
      default:
        break;
    }
    return isDown;
  }

  PointerDownEvent down(
    Offset newLocation, {
    Duration timeStamp = Duration.zero,
    int? buttons,
  }) {
    assert(!isDown);
    assert(!isPanZoomActive);
    _isDown = true;
    _location = newLocation;
    if (buttons != null) {
      _buttons = buttons;
    }
    return PointerDownEvent(
      timeStamp: timeStamp,
      kind: kind,
      device: _device,
      pointer: pointer,
      position: location!,
      buttons: _buttons,
    );
  }

  PointerMoveEvent move(
    Offset newLocation, {
    Duration timeStamp = Duration.zero,
    int? buttons,
  }) {
    assert(
        isDown,
        'Move events can only be generated when the pointer is down. To '
        'create a movement event simulating a pointer move when the pointer is '
        'up, use hover() instead.');
    assert(!isPanZoomActive);
    final Offset delta = newLocation - location!;
    _location = newLocation;
    if (buttons != null) {
      _buttons = buttons;
    }
    return PointerMoveEvent(
      timeStamp: timeStamp,
      kind: kind,
      device: _device,
      pointer: pointer,
      position: newLocation,
      delta: delta,
      buttons: _buttons,
    );
  }

  PointerUpEvent up({ Duration timeStamp = Duration.zero }) {
    assert(!isPanZoomActive);
    assert(isDown);
    _isDown = false;
    return PointerUpEvent(
      timeStamp: timeStamp,
      kind: kind,
      device: _device,
      pointer: pointer,
      position: location!,
    );
  }

  PointerCancelEvent cancel({ Duration timeStamp = Duration.zero }) {
    assert(isDown);
    _isDown = false;
    return PointerCancelEvent(
      timeStamp: timeStamp,
      kind: kind,
      device: _device,
      pointer: pointer,
      position: location!,
    );
  }

  PointerAddedEvent addPointer({
    Duration timeStamp = Duration.zero,
    Offset? location,
  }) {
    _location = location ?? _location;
    return PointerAddedEvent(
      timeStamp: timeStamp,
      kind: kind,
      device: _device,
      position: _location ?? Offset.zero,
    );
  }

  PointerRemovedEvent removePointer({
    Duration timeStamp = Duration.zero,
    Offset? location,
  }) {
    _location = location ?? _location;
    return PointerRemovedEvent(
      timeStamp: timeStamp,
      kind: kind,
      device: _device,
      pointer: pointer,
      position: _location ?? Offset.zero,
    );
  }

  PointerHoverEvent hover(
    Offset newLocation, {
    Duration timeStamp = Duration.zero,
  }) {
    assert(
        !isDown,
        'Hover events can only be generated when the pointer is up. To '
        'simulate movement when the pointer is down, use move() instead.');
    final Offset delta = location != null ? newLocation - location! : Offset.zero;
    _location = newLocation;
    return PointerHoverEvent(
      timeStamp: timeStamp,
      kind: kind,
      device: _device,
      pointer: pointer,
      position: newLocation,
      delta: delta,
    );
  }

  PointerScrollEvent scroll(
    Offset scrollDelta, {
    Duration timeStamp = Duration.zero,
  }) {
    assert(kind != PointerDeviceKind.touch, "Touch pointers can't generate pointer signal events");
    assert(location != null);
    return PointerScrollEvent(
      timeStamp: timeStamp,
      kind: kind,
      device: _device,
      position: location!,
      scrollDelta: scrollDelta,
    );
  }

  PointerScrollInertiaCancelEvent scrollInertiaCancel({
    Duration timeStamp = Duration.zero,
  }) {
    assert(kind != PointerDeviceKind.touch, "Touch pointers can't generate pointer signal events");
    assert(location != null);
    return PointerScrollInertiaCancelEvent(
      timeStamp: timeStamp,
      kind: kind,
      device: _device,
      position: location!
    );
  }

  PointerScaleEvent scale(
    double scale, {
    Duration timeStamp = Duration.zero,
  }) {
    assert(kind != PointerDeviceKind.touch, "Touch pointers can't generate pointer signal events");
    assert(location != null);
    return PointerScaleEvent(
      timeStamp: timeStamp,
      kind: kind,
      device: _device,
      position: location!,
      scale: scale,
    );
  }

  PointerPanZoomStartEvent panZoomStart(
    Offset location, {
    Duration timeStamp = Duration.zero
  }) {
    assert(!isPanZoomActive);
    assert(kind == PointerDeviceKind.trackpad);
    _location = location;
    _pan = Offset.zero;
    _isPanZoomActive = true;
    return PointerPanZoomStartEvent(
      timeStamp: timeStamp,
      device: _device,
      pointer: pointer,
      position: location,
    );
  }

  PointerPanZoomUpdateEvent panZoomUpdate(
    Offset location, {
    Offset pan = Offset.zero,
    double scale = 1,
    double rotation = 0,
    Duration timeStamp = Duration.zero,
  }) {
    assert(isPanZoomActive);
    assert(kind == PointerDeviceKind.trackpad);
    _location = location;
    final Offset panDelta = pan - _pan!;
    _pan = pan;
    return PointerPanZoomUpdateEvent(
      timeStamp: timeStamp,
      device: _device,
      pointer: pointer,
      position: location,
      pan: pan,
      panDelta: panDelta,
      scale: scale,
      rotation: rotation,
    );
  }

  PointerPanZoomEndEvent panZoomEnd({
    Duration timeStamp = Duration.zero
  }) {
    assert(isPanZoomActive);
    assert(kind == PointerDeviceKind.trackpad);
    _isPanZoomActive = false;
    _pan = null;
    return PointerPanZoomEndEvent(
      timeStamp: timeStamp,
      device: _device,
      pointer: pointer,
      position: location!,
    );
  }
}

typedef EventDispatcher = Future<void> Function(PointerEvent event);

typedef HitTester = HitTestResult Function(Offset location);

class TestGesture {
  TestGesture({
    required EventDispatcher dispatcher,
    int pointer = 1,
    PointerDeviceKind kind = PointerDeviceKind.touch,
    int? device,
    int buttons = kPrimaryButton,
  }) : _dispatcher = dispatcher,
       _pointer = TestPointer(pointer, kind, device, buttons);

  Future<void> down(Offset downLocation, { Duration timeStamp = Duration.zero }) async {
    assert(_pointer.kind != PointerDeviceKind.trackpad, 'Trackpads are expected to send panZoomStart events, not down events.');
    return TestAsyncUtils.guard<void>(() async {
      return _dispatcher(_pointer.down(downLocation, timeStamp: timeStamp));
    });
  }

  Future<void> downWithCustomEvent(Offset downLocation, PointerDownEvent event) async {
    assert(_pointer.kind != PointerDeviceKind.trackpad, 'Trackpads are expected to send panZoomStart events, not down events');
    _pointer.setDownInfo(event, downLocation);
    return TestAsyncUtils.guard<void>(() async {
      return _dispatcher(event);
    });
  }

  final EventDispatcher _dispatcher;
  final TestPointer _pointer;

  @visibleForTesting
  Future<void> updateWithCustomEvent(PointerEvent event, { Duration timeStamp = Duration.zero }) {
    _pointer.setDownInfo(event, event.position);
    return TestAsyncUtils.guard<void>(() {
      return _dispatcher(event);
    });
  }

  Future<void> addPointer({ Duration timeStamp = Duration.zero, Offset? location }) {
    return TestAsyncUtils.guard<void>(() {
      return _dispatcher(_pointer.addPointer(timeStamp: timeStamp, location: location ?? _pointer.location));
    });
  }

  Future<void> removePointer({ Duration timeStamp = Duration.zero, Offset? location }) {
    return TestAsyncUtils.guard<void>(() {
      return _dispatcher(_pointer.removePointer(timeStamp: timeStamp, location: location ?? _pointer.location));
    });
  }

  Future<void> moveBy(Offset offset, { Duration timeStamp = Duration.zero }) {
    assert(_pointer.location != null);
    if (_pointer.isPanZoomActive) {
      return panZoomUpdate(
        _pointer.location!,
        pan: (_pointer.pan ?? Offset.zero) + offset,
        timeStamp: timeStamp
      );
    } else {
      return moveTo(_pointer.location! + offset, timeStamp: timeStamp);
    }
  }

  Future<void> moveTo(Offset location, { Duration timeStamp = Duration.zero }) {
    assert(_pointer.kind != PointerDeviceKind.trackpad);
    return TestAsyncUtils.guard<void>(() {
      if (_pointer._isDown) {
        return _dispatcher(_pointer.move(location, timeStamp: timeStamp));
      } else {
        return _dispatcher(_pointer.hover(location, timeStamp: timeStamp));
      }
    });
  }

  Future<void> up({ Duration timeStamp = Duration.zero }) {
    return TestAsyncUtils.guard<void>(() async {
      if (_pointer.kind == PointerDeviceKind.trackpad) {
        assert(_pointer._isPanZoomActive);
        await _dispatcher(_pointer.panZoomEnd(timeStamp: timeStamp));
        assert(!_pointer._isPanZoomActive);
      } else {
        assert(_pointer._isDown);
        await _dispatcher(_pointer.up(timeStamp: timeStamp));
        assert(!_pointer._isDown);
      }
    });
  }

  Future<void> cancel({ Duration timeStamp = Duration.zero }) {
    assert(_pointer.kind != PointerDeviceKind.trackpad, 'Trackpads do not send cancel events.');
    return TestAsyncUtils.guard<void>(() async {
      assert(_pointer._isDown);
      await _dispatcher(_pointer.cancel(timeStamp: timeStamp));
      assert(!_pointer._isDown);
    });
  }

  Future<void> panZoomStart(Offset location, { Duration timeStamp = Duration.zero }) async {
    assert(_pointer.kind == PointerDeviceKind.trackpad, 'Only trackpads can send PointerPanZoom events.');
    return TestAsyncUtils.guard<void>(() async {
      return _dispatcher(_pointer.panZoomStart(location, timeStamp: timeStamp));
    });
  }

  Future<void> panZoomUpdate(Offset location, {
    Offset pan = Offset.zero,
    double scale = 1,
    double rotation = 0,
    Duration timeStamp = Duration.zero
  }) async {
    assert(_pointer.kind == PointerDeviceKind.trackpad, 'Only trackpads can send PointerPanZoom events.');
    return TestAsyncUtils.guard<void>(() async {
      return _dispatcher(_pointer.panZoomUpdate(location,
        pan: pan,
        scale: scale,
        rotation: rotation,
        timeStamp: timeStamp
      ));
    });
  }

  Future<void> panZoomEnd({
    Duration timeStamp = Duration.zero
  }) async {
    assert(_pointer.kind == PointerDeviceKind.trackpad, 'Only trackpads can send PointerPanZoom events.');
    return TestAsyncUtils.guard<void>(() async {
      return _dispatcher(_pointer.panZoomEnd(
        timeStamp: timeStamp
      ));
    });
  }
}

class PointerEventRecord {
  PointerEventRecord(this.timeDelay, this.events);

  final Duration timeDelay;

  final List<PointerEvent> events;
}