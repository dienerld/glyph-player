import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:media_kit/media_kit.dart';

/// Opens a stream, retrying when it does not start, reconnects a live stream
/// that drops, and tells the loading overlay what to show. IPTV servers often
/// refuse, stall or cut a connection that works a moment later.
///
/// An attempt fails when mpv cannot open the URL, the stream ends before the
/// first frame, or nothing plays within [attemptTimeout]. After [attempts]
/// failures the overlay shows an error with a retry button.
///
/// Once playing, a live stream (mpv reports no duration, so it never really
/// ends) reconnects when it ends or makes no progress for [stallTimeout]
/// while not paused: a frozen frame, a long wait for data, or the same stretch
/// replayed in a loop. Movies and finite videos are left alone.
class PlayerConnection extends ChangeNotifier {
  PlayerConnection({
    required Stream<Duration> position,
    required Stream<Duration> duration,
    required Stream<bool> playing,
    required Stream<bool> buffering,
    required Stream<bool> completed,
    required Stream<String> error,
    required Future<void> Function(String url) open,
    required Future<void> Function() stop,
  }) : _open = open,
       _stop = stop {
    _subs.addAll([
      position.listen(_onPosition),
      duration.listen((d) => _live = d <= Duration.zero),
      playing.listen((p) => _playing = p),
      buffering.listen((b) {
        if (b == _buffering) return;
        _buffering = b;
        notifyListeners();
      }),
      completed.listen((done) {
        if (!done) return;
        if (_armed) {
          _failAttempt();
        } else if (_started && _live) {
          _reconnect();
        }
      }),
      error.listen((text) {
        if (text.startsWith('Failed to open')) _failAttempt();
      }),
    ]);
  }

  factory PlayerConnection.of(Player player) => PlayerConnection(
    position: player.stream.position,
    duration: player.stream.duration,
    playing: player.stream.playing,
    buffering: player.stream.buffering,
    completed: player.stream.completed,
    error: player.stream.error,
    open: (url) => player.open(Media(url)),
    stop: player.stop,
  );

  static const attempts = 3;
  static const attemptTimeout = Duration(seconds: 15);
  static const retryDelay = Duration(seconds: 2);
  static const stallTimeout = Duration(seconds: 15);
  static const _tick = Duration(seconds: 1);

  final Future<void> Function(String url) _open;
  final Future<void> Function() _stop;
  final _subs = <StreamSubscription<Object>>[];
  Timer? _timer;
  Timer? _watch;
  String? _url;

  /// True while an attempt is running and has not played yet. Events that
  /// arrive between attempts (an aborted open failing late) are ignored.
  bool _armed = false;
  bool _started = false;
  bool _failed = false;
  bool _buffering = false;
  bool _reconnecting = false;
  bool _live = true;
  bool _playing = true;
  int _attempt = 0;
  int _run = 0;
  bool _disposed = false;

  /// Furthest position of the current connection, and seconds since it last
  /// moved forward.
  Duration _furthest = Duration.zero;
  int _stalled = 0;

  /// The attempt in progress, from 1 to [attempts].
  int get attempt => _attempt;

  /// The attempts are reconnecting a stream that was playing.
  bool get reconnecting => _reconnecting;

  /// Every attempt failed; the error stays until [retry] or a new [open].
  bool get failed => _failed;

  /// Show the spinner: still connecting, or playing but waiting for data.
  bool get loading => !_failed && (!_started || _buffering);

  /// Opens [url] from the first attempt. Completes when the first attempt has
  /// been handed to the player, not when it plays.
  Future<void> open(String url) {
    _url = url;
    _reconnecting = false;
    _attempt = 0;
    return _next();
  }

  /// Starts over after every attempt failed.
  void retry() {
    final url = _url;
    if (url != null) open(url);
  }

  void _reconnect() {
    _reconnecting = true;
    _attempt = 0;
    _next();
  }

  void _onPosition(Duration p) {
    if (!_armed && !_started || p <= _furthest) return;
    _furthest = p;
    _stalled = 0;
    if (_armed) {
      _armed = false;
      _timer?.cancel();
      _started = true;
      _watch = Timer.periodic(_tick, (_) => _checkProgress());
      notifyListeners();
    }
  }

  void _checkProgress() {
    if (!_live || !_playing) {
      _stalled = 0;
      return;
    }
    if (++_stalled * _tick.inSeconds >= stallTimeout.inSeconds) _reconnect();
  }

  /// Hands the next attempt to the player. It counts only once the player
  /// has opened it, so events of the stream being replaced (a channel still
  /// playing while zapping) are not taken for the new one.
  Future<void> _next() async {
    _timer?.cancel();
    _watch?.cancel();
    _attempt++;
    _armed = false;
    _started = false;
    _failed = false;
    notifyListeners();
    final run = ++_run;
    await _open(_url!);
    if (run != _run || _disposed) return;
    _furthest = Duration.zero;
    _stalled = 0;
    _armed = true;
    _timer = Timer(attemptTimeout, _failAttempt);
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
    _disposed = true;
    _timer?.cancel();
    _watch?.cancel();
    for (final s in _subs) {
      s.cancel();
    }
    super.dispose();
  }
}
