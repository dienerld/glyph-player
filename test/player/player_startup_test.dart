import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/player/player_startup.dart';

/// Stands in for the player: records opens and stops, emits its streams.
class _Fake {
  final position = StreamController<Duration>.broadcast(sync: true);
  final buffering = StreamController<bool>.broadcast(sync: true);
  final completed = StreamController<bool>.broadcast(sync: true);
  final error = StreamController<String>.broadcast(sync: true);
  final opened = <String>[];
  var stops = 0;

  late final startup = PlayerStartup(
    position: position.stream,
    buffering: buffering.stream,
    completed: completed.stream,
    error: error.stream,
    open: (url) async => opened.add(url),
    stop: () async => stops++,
  );
}

void main() {
  final wait = PlayerStartup.attemptTimeout + PlayerStartup.retryDelay;

  testWidgets('loads until the first frame, then hides', (t) async {
    final f = _Fake();
    f.startup.open('a');
    expect(f.startup.loading, isTrue);
    expect(f.startup.attempt, 1);
    f.position.add(const Duration(milliseconds: 40));
    expect(f.startup.loading, isFalse);
    await t.pump(wait * 3);
    expect(f.opened, ['a']); // a started stream is never reopened
    f.startup.dispose();
  });

  testWidgets('retries a stalled open, then fails after 3 attempts', (t) async {
    final f = _Fake();
    f.startup.open('a');
    await t.pump(wait);
    expect(f.startup.attempt, 2);
    expect(f.opened, ['a', 'a']);
    await t.pump(wait);
    expect(f.startup.attempt, 3);
    await t.pump(PlayerStartup.attemptTimeout);
    expect(f.startup.failed, isTrue);
    expect(f.startup.loading, isFalse);
    expect(f.opened, hasLength(3));
    expect(f.stops, 3);
    await t.pump(wait * 2);
    expect(f.opened, hasLength(3)); // stays on the error

    f.startup.retry();
    expect(f.startup.failed, isFalse);
    expect(f.startup.attempt, 1);
    expect(f.opened, hasLength(4));
    f.startup.dispose();
  });

  testWidgets('a refused connection fails the attempt without waiting', (
    t,
  ) async {
    final f = _Fake();
    f.startup.open('a');
    f.error.add('Failed to open http://host/x.ts.');
    await t.pump(PlayerStartup.retryDelay);
    expect(f.startup.attempt, 2);
    f.error.add('h264: error while decoding MB'); // not an open failure
    f.completed.add(true); // ended before the first frame
    await t.pump(PlayerStartup.retryDelay);
    expect(f.startup.attempt, 3);
    f.startup.dispose();
  });

  testWidgets('late events between attempts and after start are ignored', (
    t,
  ) async {
    final f = _Fake();
    f.startup.open('a');
    f.error.add('Failed to open a');
    f.error.add('Failed to open a'); // the aborted open failing again
    await t.pump(PlayerStartup.retryDelay);
    expect(f.startup.attempt, 2);
    f.position.add(const Duration(seconds: 1));
    f.completed.add(true); // the live stream dropping later is not a retry
    await t.pump(wait);
    expect(f.opened, hasLength(2));
    expect(f.startup.loading, isFalse);
    f.buffering.add(true);
    expect(f.startup.loading, isTrue);
    f.startup.dispose();
  });

  testWidgets('opening another channel starts over from attempt 1', (t) async {
    final f = _Fake();
    f.startup.open('a');
    await t.pump(wait);
    expect(f.startup.attempt, 2);
    f.startup.open('b');
    expect(f.startup.attempt, 1);
    await t.pump(PlayerStartup.attemptTimeout ~/ 2);
    expect(f.opened, ['a', 'a', 'b']);
    f.startup.dispose();
  });
}
