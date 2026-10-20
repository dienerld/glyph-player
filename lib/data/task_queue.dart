import 'dart:async';
import 'dart:collection';

/// Runs async tasks first in, first out, at most [limit] at a time.
class TaskQueue {
  TaskQueue({this.limit = 4}) : assert(limit > 0);

  final int limit;
  int _running = 0;
  final _waiting = ListQueue<_Job>();

  /// Tasks running now.
  int get running => _running;

  /// Tasks waiting for a free slot.
  int get waiting => _waiting.length;

  /// Runs [task] once a slot is free. When [isCancelled] says true at that
  /// moment the task is dropped without running and the future completes
  /// with null. Errors of [task] reach the returned future.
  Future<T?> run<T>(Future<T> Function() task, {bool Function()? isCancelled}) {
    final done = Completer<T?>();
    _waiting.add(
      _Job(
        start: () async {
          try {
            done.complete(await task());
          } catch (e, s) {
            done.completeError(e, s);
          }
        },
        cancelled: isCancelled ?? () => false,
        drop: () => done.complete(null),
      ),
    );
    _pump();
    return done.future;
  }

  void _pump() {
    while (_running < limit && _waiting.isNotEmpty) {
      final job = _waiting.removeFirst();
      if (job.cancelled()) {
        job.drop();
        continue;
      }
      _running++;
      job.start().whenComplete(() {
        _running--;
        _pump();
      });
    }
  }
}

class _Job {
  const _Job({
    required this.start,
    required this.cancelled,
    required this.drop,
  });
  final Future<void> Function() start;
  final bool Function() cancelled;
  final void Function() drop;
}
