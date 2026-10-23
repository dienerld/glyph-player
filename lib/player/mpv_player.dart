import 'dart:async';

import 'package:media_kit/media_kit.dart';

/// A [Player] for the live and movie/series players.
///
/// media_kit lowers mpv's `network-timeout` from 60 s to 5 s. A server that
/// stops sending for longer than that ends the stream: live TV freezes on the
/// last frame for good, and a movie counts as finished. Back to mpv's default.
Player createPlayer() {
  final player = Player();
  unawaited(
    (player.platform as NativePlayer).setProperty('network-timeout', '60'),
  );
  return player;
}
