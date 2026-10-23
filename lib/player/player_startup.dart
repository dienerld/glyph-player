import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// Opens a stream, retrying when it does not start, and tells the loading
/// overlay what to show. IPTV servers often refuse or stall a connection that
/// works a moment later.
///
/// An attempt fails when mpv cannot open the URL, the stream ends before the
/// first frame, or nothing plays within [attemptTimeout]. After [attempts]
/// failures the overlay shows an error with a retry button.
class PlayerStartup extends ChangeNotifier {
  PlayerStartup({
    required Stream<Duration> position,
    required Stream<bool> buffering,
    required Stream<bool> completed,
    required Stream<String> error,
    required Future<void> Function(String url) open,
    required Future<void> Function() stop,
  }) : _open = open,
       _stop = stop {
    _subs.addAll([
      position.listen((p) {
        if (p > Duration.zero && _armed) {
          _armed = false;
          _timer?.cancel();
          _started = true;
          notifyListeners();
        }
      }),
      buffering.listen((b) {
        if (b == _buffering) return;
        _buffering = b;
        notifyListeners();
      }),
      completed.listen((done) {
        if (done) _failAttempt();
      }),
      error.listen((text) {
        if (text.startsWith('Failed to open')) _failAttempt();
      }),
    ]);
  }

  factory PlayerStartup.of(Player player) => PlayerStartup(
    position: player.stream.position,
    buffering: player.stream.buffering,
    completed: player.stream.completed,
    error: player.stream.error,
    open: (url) => player.open(Media(url)),
    stop: player.stop,
  );

  static const attempts = 3;
  static const attemptTimeout = Duration(seconds: 15);
  static const retryDelay = Duration(seconds: 2);

  final Future<void> Function(String url) _open;
  final Future<void> Function() _stop;
  final _subs = <StreamSubscription<Object>>[];
  Timer? _timer;
  String? _url;

  /// True while an attempt is running and has not played yet. Events that
  /// arrive between attempts (an aborted open failing late) are ignored.
  bool _armed = false;
  bool _started = false;
  bool _failed = false;
  bool _buffering = false;
  int _attempt = 0;

  /// The attempt in progress, from 1 to [attempts].
  int get attempt => _attempt;

  /// Every attempt failed; the error stays until [retry] or a new [open].
  bool get failed => _failed;

  /// Show the spinner: still connecting, or playing but waiting for data.
  bool get loading => !_failed && (!_started || _buffering);

  /// Opens [url] from the first attempt. Completes when the first attempt has
  /// been handed to the player, not when it plays.
  Future<void> open(String url) {
    _url = url;
    _attempt = 0;
    return _next();
  }

  /// Starts over after every attempt failed.
  void retry() {
    final url = _url;
    if (url != null) open(url);
  }

  Future<void> _next() {
    _timer?.cancel();
    _attempt++;
    _armed = true;
    _started = false;
    _failed = false;
    notifyListeners();
    _timer = Timer(attemptTimeout, _failAttempt);
    return _open(_url!);
  }

  void _failAttempt() {
    if (!_armed) return;
    _armed = false;
    _timer?.cancel();
    unawaited(_stop());
    if (_attempt < attempts) {
      _timer = Timer(retryDelay, _next);
    } else {
      _failed = true;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
