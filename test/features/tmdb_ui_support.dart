import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:glyph_player/data/database.dart';
import 'package:glyph_player/data/stream_entry.dart';
import 'package:glyph_player/data/thumb_cache.dart';
import 'package:glyph_player/features/movies/movie_routes.dart';
import 'package:glyph_player/state/providers.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Shape of a TMDB key only, never a real one.
const fakeKey = '0123456789abcdef0123456789abcdef';

/// A [ThumbCache] that never touches disk or network: it only records which
/// image urls the UI asked for.
class FakeThumbs extends ThumbCache {
  FakeThumbs()
    : super(
        Directory.systemTemp,
        client: MockClient((_) async => http.Response('', 404)),
      );

  final requested = <String>[];

  @override
  Future<File?> get(String url) {
    requested.add(url);
    return Future.value(null);
  }

  @override
  File? peek(String url) => null;
}

/// One TMDB search result as the API sends it.
Map<String, Object?> tmdbResult(
  int id, {
  String? poster,
  double rating = 7,
  String overview = '',
}) => {
  'id': id,
  'release_date': '2021-01-01',
  'first_air_date': '2021-01-01',
  'poster_path': poster,
  'vote_average': rating,
  'vote_count': 100,
  'overview': overview,
};

/// A fake TMDB: answers searches from [catalog] by query (no entry means
/// "no results"), records every query, and can hold answers back or fail.
class FakeTmdb {
  FakeTmdb([this.catalog = const {}]);
  final Map<String, Map<String, Object?>> catalog;
  final sent = <String>[];

  /// When set, answers wait until it completes.
  Completer<void>? gate;

  /// HTTP status of every answer.
  int status = 200;

  late final client = MockClient((r) async {
    final q = r.url.queryParameters['query'] ?? '';
    sent.add(q);
    final g = gate;
    if (g != null) await g.future;
    if (status != 200) return http.Response('{}', status);
    final hit = catalog[q];
    // Bytes, as TMDB sends them: a String body would be encoded as latin-1.
    return http.Response.bytes(
      utf8.encode(
        jsonEncode({
          'results': [?hit],
        }),
      ),
      200,
    );
  });
}

StreamEntry movieEntry(String id, String name, {String logo = ''}) =>
    StreamEntry(
      type: StreamType.movie,
      id: id,
      name: name,
      group: 'Filmes | Drama',
      logo: logo,
      url: 'http://h/movie/U/P/$id.mp4',
    );

StreamEntry episodeEntry(String id, String series, int season, int episode) =>
    StreamEntry(
      type: StreamType.series,
      id: id,
      name: '$series S${season}E$episode',
      group: 'Series | Netflix',
      logo: '',
      url: 'http://h/series/U/P/$id.mp4',
      seriesName: series,
      season: season,
      episode: episode,
    );

Db seedDb(List<StreamEntry> items) {
  final db = Db.memory();
  final run = db.beginRun();
  db.upsertBatch(items, run);
  db.finishRun(run);
  return db;
}

/// Marker the fake player shows. The real one is native (media_kit).
String playerText(String movieName) => 'PLAYER $movieName';

/// [home] with the providers faked: no real network, no disk, no media_kit.
/// A TMDB key is set unless [withKey] is false.
Widget tmdbHost(
  Db db,
  FakeTmdb tmdb,
  FakeThumbs thumbs,
  Widget home, {
  bool withKey = true,
}) {
  if (withKey) db.setSetting('tmdb_key', fakeKey);
  return ProviderScope(
    overrides: [
      dbProvider.overrideWithValue(db),
      tmdbHttpClientProvider.overrideWithValue(tmdb.client),
      thumbCacheProvider.overrideWithValue(thumbs),
      moviePlayerBuilderProvider.overrideWithValue(
        (queue, index) => Scaffold(
          appBar: AppBar(),
          body: Text(playerText(queue[index].name)),
        ),
      ),
    ],
    child: MaterialApp(home: home),
  );
}
