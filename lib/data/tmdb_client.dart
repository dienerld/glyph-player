import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'tmdb_info.dart';

export 'tmdb_info.dart';

/// Outcome of a TMDB search. Only [TmdbFound] and [TmdbNotFound] are worth
/// caching; the other two must be retried later.
sealed class TmdbResult {
  const TmdbResult();
}

class TmdbFound extends TmdbResult {
  const TmdbFound(this.info);
  final TmdbInfo info;
}

class TmdbNotFound extends TmdbResult {
  const TmdbNotFound();
}

/// TMDB refused the key (HTTP 401).
class TmdbInvalidKey extends TmdbResult {
  const TmdbInvalidKey();
}

/// Network error, timeout, rate limit (429), server error or an unreadable
/// answer.
class TmdbUnavailable extends TmdbResult {
  const TmdbUnavailable();
}

/// Result of "Testar chave".
enum TmdbKeyStatus { ok, invalid, networkError }

/// Whether [key] looks like a v4 read access token (a long JWT) rather than
/// a v3 API key. A heuristic: v3 keys are 32 hex characters.
bool isTmdbBearer(String key) => key.length > 64 && key.startsWith('eyJ');

/// Minimal TMDB v3 client: title search for movies and TV shows, and a key
/// check. Sends only the title (and year) and the user's key. Never throws.
class TmdbClient {
  TmdbClient(
    String key, {
    required http.Client client,
    Uri? baseUrl,
    this.timeout = const Duration(seconds: 10),
  }) : _key = key.trim(),
       _client = client,
       _base = _withSlash(
         baseUrl ?? Uri.parse('https://api.themoviedb.org/3/'),
       );

  final String _key;
  final http.Client _client;
  final Uri _base;
  final Duration timeout;

  static Uri _withSlash(Uri u) =>
      u.path.endsWith('/') ? u : u.replace(path: '${u.path}/');

  /// Searches movies by [title]. With [year], TMDB narrows by it and the
  /// first result released that year wins; otherwise the first result.
  Future<TmdbResult> searchMovie(String title, {int? year}) async {
    final r = await _get('search/movie', {
      'query': title,
      if (year != null) 'year': '$year',
    });
    if (r is! _Ok) return r.result!;
    final list = r.results;
    if (list.isEmpty) return const TmdbNotFound();
    var pick = list.first;
    if (year != null) {
      pick = list.firstWhere(
        (m) => _year(m['release_date']) == year,
        orElse: () => list.first,
      );
    }
    return _found(pick);
  }

  /// Searches TV shows by [title]; the first result wins.
  Future<TmdbResult> searchTv(String title) async {
    final r = await _get('search/tv', {'query': title});
    if (r is! _Ok) return r.result!;
    if (r.results.isEmpty) return const TmdbNotFound();
    return _found(r.results.first);
  }

  /// A light call that tells whether TMDB accepts the key.
  Future<TmdbKeyStatus> checkKey() async {
    final r = await _get('authentication', const {});
    return switch (r.result) {
      null => TmdbKeyStatus.ok,
      TmdbInvalidKey() => TmdbKeyStatus.invalid,
      _ => TmdbKeyStatus.networkError,
    };
  }

  Future<_Response> _get(String path, Map<String, String> params) async {
    final bearer = isTmdbBearer(_key);
    final uri = _base
        .resolve(path)
        .replace(
          queryParameters: {
            ...params,
            'language': 'pt-BR',
            if (!bearer) 'api_key': _key,
          },
        );
    final headers = {
      'Accept': 'application/json',
      if (bearer) 'Authorization': 'Bearer $_key',
    };
    try {
      final res = await _client.get(uri, headers: headers).timeout(timeout);
      if (res.statusCode == 401) return const _Response(TmdbInvalidKey());
      if (res.statusCode != 200) return const _Response(TmdbUnavailable());
      final json = jsonDecode(utf8.decode(res.bodyBytes));
      if (json is! Map<String, dynamic>) {
        return const _Response(TmdbUnavailable());
      }
      final results = json['results'];
      return _Ok([
        if (results is List)
          for (final m in results)
            if (m is Map<String, dynamic> && m['id'] is int) m,
      ]);
    } catch (_) {
      // Socket, client, timeout or format errors: try again another time.
      return const _Response(TmdbUnavailable());
    }
  }

  static int? _year(Object? date) => date is String && date.length >= 4
      ? int.tryParse(date.substring(0, 4))
      : null;

  static TmdbFound _found(Map<String, dynamic> m) {
    final poster = m['poster_path'];
    final vote = m['vote_average'];
    final votes = m['vote_count'];
    final rating = vote is num && vote > 0 && (votes is! num || votes > 0)
        ? vote.toDouble()
        : null;
    final overview = m['overview'];
    return TmdbFound(
      TmdbInfo(
        id: m['id'] as int,
        posterPath: poster is String && poster.isNotEmpty ? poster : null,
        rating: rating,
        overview: overview is String ? overview.trim() : '',
      ),
    );
  }
}

class _Response {
  const _Response(this.result);

  /// The failure; null on success ([_Ok]).
  final TmdbResult? result;
}

class _Ok extends _Response {
  const _Ok(this.results) : super(null);
  final List<Map<String, dynamic>> results;
}
