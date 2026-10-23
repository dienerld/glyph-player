import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/player/player_connection.dart';

/// Stands in for the player: records opens and stops, emits its streams.
class _Fake {
  final position = StreamController<Duration>.broadcast(sync: true);
  final duration = StreamController<Duration>.broadcast(sync: true);
  final playing = StreamController<bool>.broadcast(sync: true);
  final buffering = StreamController<bool>.broadcast(sync: true);
  final completed = StreamController<bool>.broadcast(sync: true);
  final error = StreamController<String>.broadcast(sync: true);
  final opened = <String>[];
  var stops = 0;

  late final connection = PlayerConnection(
    position: position.stream,
    duration: duration.stream,
    playing: playing.stream,
    buffering: buffering.stream,
    completed: completed.stream,
    error: error.stream,
    open: (url) async => opened.add(url),
    stop: () async => stops++,
  );

  /// Plays from [from] for [seconds], one position a second.
  Future<void> play(WidgetTester t, int from, int seconds) async {
    for (var s = from; s < from + seconds; s++) {
      position.add(Duration(seconds: s + 1));
      await t.pump(const Duration(seconds: 1));
    }
  }
}

void main() {
  final wait = PlayerConnection.attemptTimeout + PlayerConnection.retryDelay;

  Future<_Fake> opened(WidgetTester t, [String url = 'a']) async {
    final f = _Fake();
    f.connection.open(url);
    await t.pump(); // the player finishes opening
    return f;
  }

  testWidgets('loads until the first frame, then hides', (t) async {
    final f = await opened(t);
    expect(f.connection.loading, isTrue);
    expect(f.connection.attempt, 1);
    await f.play(t, 0, 40);
    expect(f.connection.loading, isFalse);
    expect(f.opened, ['a']); // a stream that keeps playing is never reopened
    f.connection.dispose();
  });

  testWidgets('retries a stalled open, then fails after 3 attempts', (t) async {
    final f = await opened(t);
    await t.pump(wait);
    expect(f.connection.attempt, 2);
    expect(f.opened, ['a', 'a']);
    await t.pump(wait);
    expect(f.connection.attempt, 3);
    await t.pump(PlayerConnection.attemptTimeout);
    expect(f.connection.failed, isTrue);
    expect(f.connection.reconnecting, isFalse);
    expect(f.connection.loading, isFalse);
    expect(f.opened, hasLength(3));
    expect(f.stops, 3);
    await t.pump(wait * 2);
    expect(f.opened, hasLength(3)); // stays on the error

    f.connection.retry();
    await t.pump();
    expect(f.connection.failed, isFalse);
    expect(f.connection.attempt, 1);
    expect(f.opened, hasLength(4));
    f.connection.dispose();
  });

  testWidgets('a refused connection fails the attempt without waiting', (
    t,
  ) async {
    final f = await opened(t);
    f.error.add('Failed to open http://host/x.ts.');
    await t.pump(PlayerConnection.retryDelay);
    await t.pump();
    expect(f.connection.attempt, 2);
    f.error.add('h264: error while decoding MB'); // not an open failure
    f.completed.add(true); // ended before the first frame
    await t.pump(PlayerConnection.retryDelay);
    expect(f.connection.attempt, 3);
    f.connection.dispose();
  });

  testWidgets('events of the stream being replaced are ignored', (t) async {
    final f = _Fake();
    f.connection.open('a');
    f.position.add(const Duration(minutes: 5)); // old channel, before opening
    await t.pump();
    expect(f.connection.loading, isTrue);
    f.error.add('Failed to open a');
    f.error.add('Failed to open a'); // the aborted open failing again
    await t.pump(PlayerConnection.retryDelay);
    await t.pump();
    expect(f.connection.attempt, 2);
    f.connection.dispose();
  });

  testWidgets('opening another channel starts over from attempt 1', (t) async {
    final f = await opened(t);
    await t.pump(wait);
    expect(f.connection.attempt, 2);
    f.connection.open('b');
    await t.pump();
    expect(f.connection.attempt, 1);
    await t.pump(PlayerConnection.attemptTimeout ~/ 2);
    expect(f.opened, ['a', 'a', 'b']);
    f.connection.dispose();
  });

  testWidgets('a live stream that ends reconnects', (t) async {
    final f = await opened(t);
    await f.play(t, 0, 5);
    f.completed.add(true);
    await t.pump();
    expect(f.opened, ['a', 'a']);
    expect(f.connection.reconnecting, isTrue);
    expect(f.connection.attempt, 1);
    expect(f.connection.loading, isTrue);
    await f.play(t, 0, 3);
    expect(f.connection.loading, isFalse);
    f.connection.dispose();
  });

  testWidgets('a live stream that stops moving or loops reconnects', (t) async {
    final f = await opened(t);
    await f.play(t, 0, 20);
    f.buffering.add(true);
    expect(f.connection.loading, isTrue); // buffering shows the spinner
    await t.pump(PlayerConnection.stallTimeout - const Duration(seconds: 2));
    expect(f.opened, hasLength(1)); // a short wait is not a drop
    f.buffering.add(false);
    await f.play(t, 20, 5);

    await f.play(t, 10, 15); // replays the same stretch without advancing
    await t.pump();
    expect(f.opened, hasLength(2));
    expect(f.connection.reconnecting, isTrue);
    f.connection.dispose();
  });

  testWidgets('pause, movies and finite videos never reconnect', (t) async {
    final f = await opened(t);
    await f.play(t, 0, 5);
    f.playing.add(false);
    await t.pump(PlayerConnection.stallTimeout * 2);
    expect(f.opened, hasLength(1));
    f.playing.add(true);

    f.duration.add(const Duration(minutes: 90));
    await t.pump(PlayerConnection.stallTimeout * 2);
    f.completed.add(true); // the real end of a movie
    await t.pump(wait);
    expect(f.opened, hasLength(1));
    f.connection.dispose();
  });

  testWidgets('a reconnect that keeps failing shows the error', (t) async {
    final f = await opened(t);
    await f.play(t, 0, 5);
    f.completed.add(true);
    await t.pump();
    for (var i = 0; i < PlayerConnection.attempts; i++) {
      await t.pump(wait);
    }
    expect(f.connection.failed, isTrue);
    expect(f.connection.reconnecting, isTrue);
    f.connection.dispose();
  });
}
