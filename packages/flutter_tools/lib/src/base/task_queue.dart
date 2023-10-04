import 'dart:async';
import 'dart:collection';

import '../globals.dart' as globals;

typedef TaskQueueClosure<T> = Future<T> Function();

class TaskQueue<T> {
  TaskQueue({int? maxJobs})
      : maxJobs = maxJobs ?? globals.platform.numberOfProcessors;

  final int maxJobs;

  final Queue<_TaskQueueItem<T>> _pendingTasks = Queue<_TaskQueueItem<T>>();
  final Set<_TaskQueueItem<T>> _activeTasks = <_TaskQueueItem<T>>{};
  final Set<Completer<void>> _completeListeners = <Completer<void>>{};

  Future<void> get tasksComplete {
    // In case this is called when there are no tasks, we want it to
    // signal complete immediately.
    if (_activeTasks.isEmpty && _pendingTasks.isEmpty) {
      return Future<void>.value();
    }
    final Completer<void> completer = Completer<void>();
    _completeListeners.add(completer);
    return completer.future;
  }

  Future<T> add(TaskQueueClosure<T> task) {
    final Completer<T> completer = Completer<T>();
    _pendingTasks.add(_TaskQueueItem<T>(task, completer));
    if (_activeTasks.length < maxJobs) {
      _processTask();
    }
    return completer.future;
  }

  // Process a single task.
  void _processTask() {
    if (_pendingTasks.isNotEmpty && _activeTasks.length <= maxJobs) {
      final _TaskQueueItem<T> item = _pendingTasks.removeFirst();
      _activeTasks.add(item);
      item.onComplete = () {
        _activeTasks.remove(item);
        _processTask();
      };
      item.run();
    } else {
      _checkForCompletion();
    }
  }

  void _checkForCompletion() {
    if (_activeTasks.isEmpty && _pendingTasks.isEmpty) {
      for (final Completer<void> completer in _completeListeners) {
        if (!completer.isCompleted) {
          completer.complete();
        }
      }
      _completeListeners.clear();
    }
  }
}

class _TaskQueueItem<T> {
  _TaskQueueItem(this._closure, this._completer, {this.onComplete});

  final TaskQueueClosure<T> _closure;
  final Completer<T> _completer;
  void Function()? onComplete;

  Future<void> run() async {
    try {
      _completer.complete(await _closure());
    } catch (e) {
      // ignore: avoid_catches_without_on_clauses, forwards to Future
      _completer.completeError(e);
    } finally {
      onComplete?.call();
    }
  }
}
