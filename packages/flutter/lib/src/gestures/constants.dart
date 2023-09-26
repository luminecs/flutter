// Modeled after Android's ViewConfiguration:
// https://github.com/android/platform_frameworks_base/blob/master/core/java/android/view/ViewConfiguration.java

const Duration kPressTimeout = Duration(milliseconds: 100);

// TODO(ianh): Remove this, or implement a hover-tap gesture recognizer which
// uses this.
const Duration kHoverTapTimeout = Duration(milliseconds: 150);

// TODO(ianh): Remove this or implement it correctly.
const double kHoverTapSlop = 20.0; // Logical pixels

const Duration kLongPressTimeout = Duration(milliseconds: 500);

// In Android, this is actually the time from the first's up event
// to the second's down event, according to the ViewConfiguration docs.
const Duration kDoubleTapTimeout = Duration(milliseconds: 300);

const Duration kDoubleTapMinTime = Duration(milliseconds: 40);

const double kDoubleTapTouchSlop = kTouchSlop; // Logical pixels

const double kDoubleTapSlop = 100.0; // Logical pixels

const Duration kZoomControlsTimeout = Duration(milliseconds: 3000);

// This value was empirically derived. We started at 8.0 and increased it to
// 18.0 after getting complaints that it was too difficult to hit targets.
const double kTouchSlop = 18.0; // Logical pixels

// TODO(ianh): Create variants of HorizontalDragGestureRecognizer et al for
// paging, which use this constant.
const double kPagingTouchSlop = kTouchSlop * 2.0; // Logical pixels

const double kPanSlop = kTouchSlop * 2.0; // Logical pixels

const double kScaleSlop = kTouchSlop; // Logical pixels

// TODO(ianh): Make ModalBarrier support this.
const double kWindowTouchSlop = 16.0; // Logical pixels

// TODO(ianh): Make sure nobody has their own version of this.
const double kMinFlingVelocity = 50.0; // Logical pixels / second
// const Velocity kMinFlingVelocity = const Velocity(pixelsPerSecond: 50.0);

// TODO(ianh): Make sure nobody has their own version of this.
const double kMaxFlingVelocity = 8000.0; // Logical pixels / second

// TODO(ianh): Implement jump-tap gestures.
const Duration kJumpTapTimeout = Duration(milliseconds: 500);

const double kPrecisePointerHitSlop = 1.0; // Logical pixels;

const double kPrecisePointerPanSlop =
    kPrecisePointerHitSlop * 2.0; // Logical pixels

const double kPrecisePointerScaleSlop =
    kPrecisePointerHitSlop; // Logical pixels
