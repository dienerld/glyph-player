import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/database.dart';
import 'package:glyph_player/data/task_queue.dart';
import 'package:glyph_player/data/tmdb_client.dart';
import 'package:glyph_player/state/providers.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Fake key: shape only, never a real one.
const fakeKey = '0123456789abcdef0123456789abcdef';

http.Response found(int id) => http.Response(
  jsonEncode({
    'results': [
      {
        'id': id,
        'release_date': '2021-01-01',
        'poster_path': '/p$id.jpg',
        'vote_average': 7.0,
        'vote_count': 10,
        'overview': 'Resumo $id',
      },
    ],
  }),
  200,
);

final notFound = http.Response('{"results":[]}', 200);

/// A fake TMDB: records each request's query and can hold them open.
class FakeTmdb {
  final sent = <String>[];
  int inflight = 0, maxInflight = 0;
  bool block = false;
  final _gates = <String, Completer<void>>{};
  http.Response Function(http.Request r) respond = (_) => found(1);

  late final client = MockClient((r) async {
    final q = r.url.queryParameters['query'] ?? r.url.path;
    sent.add(q);
    inflight++;
    maxInflight = max(maxInflight, inflight);
    try {
      if (block) await (_gates[q] ??= Completer()).future;
      return respond(r);
    } finally {
      inflight--;
    }
  });

  void release(String q) => (_gates[q] ??= Completer()).complete();
}

Future<TmdbInfo?> load(
  ProviderContainer c,
  AutoDisposeFutureProvider<TmdbInfo?> p,
) async {
  final sub = c.listen(p, (_, _) {});
  try {
    return await c.read(p.future);
  } finally {
    sub.close();
  }
}

Future<void> settle(ProviderContainer c) async {
  for (var i = 0; i < 5; i++) {
    await c.pump();
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late Db db;
  late FakeTmdb tmdb;
  late ProviderContainer c;

  ProviderContainer container() => ProviderContainer(
    overrides: [
      dbProvider.overrideWithValue(db),
      tmdbHttpClientProvider.overrideWithValue(tmdb.client),
    ],
  );

  setUp(() {
    db = Db.memory();
    tmdb = FakeTmdb();
    c = container();
  });
  tearDown(() {
    c.dispose();
    db.close();
  });

  test('without a key nothing is requested and everything is null', () async {
    expect(c.read(tmdbEnabledProvider), isFalse);
    expect(await load(c, tmdbMovieProvider(('Duna', 2021))), isNull);
    expect(await load(c, tmdbSeriesProvider('Dark')), isNull);
    expect(
      await c.read(tmdbKeyProvider.notifier).check(),
      TmdbKeyStatus.invalid,
    );
    expect(tmdb.sent, isEmpty);
  });

  test('the key is trimmed, persisted and enables TMDB', () {
    c.read(tmdbKeyProvider.notifier).set('  $fakeKey \n');
    expect(c.read(tmdbKeyProvider), fakeKey);
    expect(db.setting('tmdb_key'), fakeKey);
    expect(c.read(tmdbEnabledProvider), isTrue);
    final c2 = container();
    addTearDown(c2.dispose);
    expect(c2.read(tmdbKeyProvider), fakeKey);
  });

  test('a cache hit makes no request', () async {
    const info = TmdbInfo(
      id: 5,
      posterPath: '/x.jpg',
      rating: 6,
      overview: 'o',
    );
    db.putTmdb(TmdbKind.movie, 'duna', info, DateTime(2020), year: 2021);
    db.putTmdb(TmdbKind.series, 'dark', null, DateTime.now());
    c.read(tmdbKeyProvider.notifier).set(fakeKey);
    expect(await load(c, tmdbMovieProvider(('Duna', 2021))), info);
    expect(await load(c, tmdbSeriesProvider('Dark')), isNull);
    expect(tmdb.sent, isEmpty);
  });

  test('a miss asks TMDB once and caches found and not-found', () async {
    c.read(tmdbKeyProvider.notifier).set(fakeKey);
    final m = await load(c, tmdbMovieProvider(('Ação', null)));
    expect(m!.id, 1);
    expect(db.tmdbCached(TmdbKind.movie, 'acao')!.info, m);
    tmdb.respond = (_) => notFound;
    expect(await load(c, tmdbSeriesProvider('Dark')), isNull);
    expect(db.tmdbCached(TmdbKind.series, 'dark')!.info, isNull);
    expect(tmdb.sent, ['Ação', 'Dark']);
    // Disposed and asked again: served from the cache.
    expect(await load(c, tmdbMovieProvider(('Ação', null))), m);
    expect(await load(c, tmdbSeriesProvider('Dark')), isNull);
    expect(tmdb.sent, hasLength(2));
  });

  test('an expired not-found is asked again', () async {
    db.putTmdb(
      TmdbKind.series,
      'dark',
      null,
      DateTime.now().subtract(const Duration(days: 31)),
    );
    c.read(tmdbKeyProvider.notifier).set(fakeKey);
    expect((await load(c, tmdbSeriesProvider('Dark')))!.id, 1);
    expect(tmdb.sent, ['Dark']);
  });

  for (final status in [401, 429, 500]) {
    test('HTTP $status gives null and is not cached', () async {
      tmdb.respond = (_) => http.Response('{}', status);
      c.read(tmdbKeyProvider.notifier).set(fakeKey);
      expect(await load(c, tmdbMovieProvider(('Duna', 2021))), isNull);
      expect(db.tmdbCached(TmdbKind.movie, 'duna', year: 2021), isNull);
    });
  }

  test('never more than 4 lookups at once, and all finish', () async {
    tmdb.block = true;
    c.read(tmdbKeyProvider.notifier).set(fakeKey);
    final titles = [for (var i = 0; i < 10; i++) 'T$i'];
    final subs = [
      for (final t in titles) c.listen(tmdbMovieProvider((t, null)), (_, _) {}),
    ];
    await settle(c);
    expect(tmdb.inflight, tmdbMaxConcurrent);
    expect(tmdb.sent, titles.take(4));
    for (final t in titles) {
      tmdb.release(t);
      await settle(c);
      expect(tmdb.maxInflight, lessThanOrEqualTo(tmdbMaxConcurrent));
    }
    expect(tmdb.sent, titles);
    for (final s in subs) {
      expect(s.read().value, isNotNull);
      s.close();
    }
  });

  test('a lookup disposed while queued is never sent', () async {
    tmdb.block = true;
    c.read(tmdbKeyProvider.notifier).set(fakeKey);
    final titles = [for (var i = 0; i < 6; i++) 'T$i'];
    final subs = [
      for (final t in titles) c.listen(tmdbMovieProvider((t, null)), (_, _) {}),
    ];
    await settle(c);
    expect(tmdb.sent, titles.take(4));
    subs[4].close();
    subs[5].close();
    await settle(c); // autoDispose runs
    for (final t in titles.take(4)) {
      tmdb.release(t);
    }
    await settle(c);
    expect(tmdb.sent, titles.take(4));
    expect(db.tmdbCached(TmdbKind.movie, 't4'), isNull);
    for (final s in subs.take(4)) {
      s.close();
    }
  });

  test('clearing the key turns lookups off', () async {
    c.read(tmdbKeyProvider.notifier).set(fakeKey);
    final p = tmdbMovieProvider(('Duna', null));
    final sub = c.listen(p, (_, _) {});
    addTearDown(sub.close);
    expect((await c.read(p.future))!.id, 1);
    db.clearTmdbCache();
    c.read(tmdbKeyProvider.notifier).set('');
    expect(c.read(tmdbEnabledProvider), isFalse);
    expect(await c.read(p.future), isNull);
    expect(tmdb.sent, hasLength(1));
  });

  test('clearCache empties the cache and refreshes lookups', () async {
    c.read(tmdbKeyProvider.notifier).set(fakeKey);
    final p = tmdbSeriesProvider('Dark');
    final sub = c.listen(p, (_, _) {});
    addTearDown(sub.close);
    expect((await c.read(p.future))!.id, 1);
    tmdb.respond = (_) => found(2);
    c.read(tmdbKeyProvider.notifier).clearCache();
    expect((await c.read(p.future))!.id, 2);
    expect(tmdb.sent, ['Dark', 'Dark']);
  });

  test('check tests the given key or the saved one', () async {
    tmdb.respond = (_) => http.Response('{"success":true}', 200);
    final n = c.read(tmdbKeyProvider.notifier);
    expect(await n.check(fakeKey), TmdbKeyStatus.ok);
    tmdb.respond = (_) => http.Response('{}', 401);
    n.set(fakeKey);
    expect(await n.check(), TmdbKeyStatus.invalid);
    tmdb.respond = (_) => http.Response('{}', 503);
    expect(await n.check(), TmdbKeyStatus.networkError);
  });

  group('TaskQueue', () {
    test('runs at most limit tasks and drops cancelled ones', () async {
      final q = TaskQueue(limit: 2);
      final gates = [for (var i = 0; i < 4; i++) Completer<int>()];
      final started = <int>[];
      var cancel3 = false;
      final results = [
        for (var i = 0; i < 4; i++)
          q.run(() {
            started.add(i);
            return gates[i].future;
          }, isCancelled: i == 3 ? () => cancel3 : null),
      ];
      expect(started, [0, 1]);
      expect(q.running, 2);
      expect(q.waiting, 2);
      cancel3 = true;
      gates[0].complete(0);
      await Future<void>.delayed(Duration.zero);
      expect(started, [0, 1, 2]);
      gates[1].complete(1);
      gates[2].complete(2);
      expect(await Future.wait(results), [0, 1, 2, null]);
      expect(started, [0, 1, 2]);
      expect(q.running, 0);
    });
  });
}
