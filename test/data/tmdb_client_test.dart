import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/tmdb_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// Fake credentials: shapes only, never real keys.
const v3Key = '0123456789abcdef0123456789abcdef';
final v4Token = 'eyJ${'a' * 120}.fake.token';

Map<String, dynamic> movie(
  int id,
  String date, {
  String? poster,
  num vote = 7.5,
  int votes = 100,
  String overview = 'Resumo',
}) => {
  'id': id,
  'title': 'Filme $id',
  'release_date': date,
  'poster_path': poster,
  'vote_average': vote,
  'vote_count': votes,
  'overview': overview,
};

http.Response ok(List<Map<String, dynamic>> results) =>
    http.Response(jsonEncode({'results': results}), 200);

void main() {
  late List<http.Request> sent;
  TmdbClient client(
    String key,
    FutureOr<http.Response> Function(http.Request) handler, {
    Duration timeout = const Duration(seconds: 10),
  }) => TmdbClient(
    key,
    client: MockClient((r) async {
      sent.add(r);
      return handler(r);
    }),
    baseUrl: Uri.parse('https://tmdb.test/3'),
    timeout: timeout,
  );

  setUp(() => sent = []);

  test('a v3 key goes as api_key, with pt-BR and the year', () async {
    final c = client(v3Key, (_) => ok([movie(1, '2021-09-15')]));
    await c.searchMovie('Duna', year: 2021);
    final u = sent.single.url;
    expect(u.path, '/3/search/movie');
    expect(u.queryParameters, {
      'query': 'Duna',
      'year': '2021',
      'language': 'pt-BR',
      'api_key': v3Key,
    });
    expect(sent.single.headers['Authorization'], isNull);
  });

  test('a v4 token goes as a Bearer header, not in the URL', () async {
    final c = client(v4Token, (_) => ok(const []));
    await c.searchTv('Dark');
    final r = sent.single;
    expect(r.url.path, '/3/search/tv');
    expect(r.url.queryParameters.containsKey('api_key'), isFalse);
    expect(r.url.queryParameters['language'], 'pt-BR');
    expect(r.headers['Authorization'], 'Bearer $v4Token');
  });

  test('isTmdbBearer tells the token from the short key', () {
    expect(isTmdbBearer(v3Key), isFalse);
    expect(isTmdbBearer(v4Token), isTrue);
    expect(isTmdbBearer('eyJshort'), isFalse);
  });

  test('found maps poster, rating and overview', () async {
    final c = client(
      v3Key,
      (_) => ok([movie(7, '2021-01-01', poster: '/p.jpg', overview: ' Oi ')]),
    );
    final r = await c.searchMovie('X');
    expect(r, isA<TmdbFound>());
    expect(
      (r as TmdbFound).info,
      const TmdbInfo(id: 7, posterPath: '/p.jpg', rating: 7.5, overview: 'Oi'),
    );
  });

  test('no votes means no rating; empty poster is null', () async {
    final c = client(
      v3Key,
      (_) => ok([movie(7, '', poster: '', vote: 0, votes: 0)]),
    );
    final info = (await c.searchTv('X') as TmdbFound).info;
    expect(info.rating, isNull);
    expect(info.posterPath, isNull);
  });

  test('prefers the result of the same year, else the first', () async {
    final results = [
      movie(1, '1984-12-14'),
      movie(2, '2021-09-15'),
      movie(3, '2021-10-22'),
    ];
    final c = client(v3Key, (_) => ok(results));
    expect(((await c.searchMovie('Duna', year: 2021)) as TmdbFound).info.id, 2);
    expect(((await c.searchMovie('Duna', year: 1999)) as TmdbFound).info.id, 1);
    expect(((await c.searchMovie('Duna')) as TmdbFound).info.id, 1);
  });

  test('empty results are not found', () async {
    final c = client(v3Key, (_) => ok(const []));
    expect(await c.searchMovie('Nada'), isA<TmdbNotFound>());
    expect(await c.searchTv('Nada'), isA<TmdbNotFound>());
  });

  test('401 is an invalid key', () async {
    final c = client(v3Key, (_) => http.Response('{}', 401));
    expect(await c.searchMovie('X'), isA<TmdbInvalidKey>());
  });

  for (final status in [500, 503, 429, 404]) {
    test('HTTP $status is a transient failure', () async {
      final c = client(v3Key, (_) => http.Response('{}', status));
      expect(await c.searchMovie('X'), isA<TmdbUnavailable>());
    });
  }

  test('network error, bad JSON and timeout are transient', () async {
    expect(
      await client(
        v3Key,
        (_) => throw const SocketException('down'),
      ).searchMovie('X'),
      isA<TmdbUnavailable>(),
    );
    expect(
      await client(v3Key, (_) => http.Response('<html>', 200)).searchMovie('X'),
      isA<TmdbUnavailable>(),
    );
    final never = Completer<http.Response>();
    expect(
      await client(
        v3Key,
        (_) => never.future,
        timeout: const Duration(milliseconds: 20),
      ).searchMovie('X'),
      isA<TmdbUnavailable>(),
    );
  });

  test('checkKey hits authentication and maps the outcome', () async {
    final good = client(v3Key, (_) => http.Response('{"success":true}', 200));
    expect(await good.checkKey(), TmdbKeyStatus.ok);
    expect(sent.single.url.path, '/3/authentication');
    expect(sent.single.url.queryParameters['language'], 'pt-BR');
    expect(
      await client(v3Key, (_) => http.Response('{}', 401)).checkKey(),
      TmdbKeyStatus.invalid,
    );
    expect(
      await client(v3Key, (_) => http.Response('{}', 500)).checkKey(),
      TmdbKeyStatus.networkError,
    );
    expect(
      await client(
        v3Key,
        (_) => throw const SocketException('down'),
      ).checkKey(),
      TmdbKeyStatus.networkError,
    );
  });

  test('image URLs use w342 for cards and w500 for details', () {
    expect(
      tmdbImageUrl('/p.jpg', TmdbImageSize.card),
      'https://image.tmdb.org/t/p/w342/p.jpg',
    );
    expect(
      tmdbImageUrl('/p.jpg', TmdbImageSize.details),
      'https://image.tmdb.org/t/p/w500/p.jpg',
    );
  });

  test('tmdbMovieQuery cleans the stream name', () {
    expect(tmdbMovieQuery('Duna (2021) [4K]'), ('Duna', 2021));
    expect(tmdbMovieQuery('Duna'), ('Duna', null));
    expect(tmdbTitleKey(' Ação '), 'acao');
  });
}
