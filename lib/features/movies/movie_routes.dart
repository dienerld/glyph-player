import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/database.dart';
import 'vod_player_page.dart';

/// Builds the player screen of a movie queue. The player is native
/// (media_kit) and cannot be built in widget tests, which override this.
typedef MoviePlayerBuilder = Widget Function(List<Channel> queue, int index);

final moviePlayerBuilderProvider = Provider<MoviePlayerBuilder>(
  (ref) =>
      (queue, index) => VodPlayerPage(queue: queue, index: index),
);

/// Route that plays [movie] (a queue of one).
Route<void> moviePlayerRoute(WidgetRef ref, Channel movie) {
  final build = ref.read(moviePlayerBuilderProvider);
  return MaterialPageRoute(builder: (_) => build([movie], 0));
}
