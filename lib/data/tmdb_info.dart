import 'movie_title.dart';
import 'title_fold.dart';

/// What a TMDB lookup is about; the name is stored in the cache.
enum TmdbKind { movie, series }

/// Cache key of a clean title (see [parseMovieTitle] for movies, the
/// `series_name` for series): lower case, no accents, trimmed.
String tmdbTitleKey(String cleanTitle) => foldTitle(cleanTitle);

/// The `(title, year)` a movie's stream name is looked up by:
/// `Duna (2021) [4K]` gives `('Duna', 2021)`. Keys `tmdbMovieProvider`.
(String, int?) tmdbMovieQuery(String streamName) {
  final t = parseMovieTitle(streamName);
  return (t.title, t.year);
}

/// What the app shows from TMDB for a movie or a series.
class TmdbInfo {
  const TmdbInfo({
    required this.id,
    this.posterPath,
    this.rating,
    this.overview = '',
  });

  /// TMDB's id of the movie or TV show.
  final int id;

  /// Poster path as TMDB gives it (`/abc.jpg`); null when there is none.
  /// Build the image URL with [tmdbImageUrl].
  final String? posterPath;

  /// Average vote, 0 to 10; null when nobody voted yet.
  final double? rating;

  /// Synopsis in pt-BR; empty when TMDB has none.
  final String overview;

  @override
  bool operator ==(Object other) =>
      other is TmdbInfo &&
      other.id == id &&
      other.posterPath == posterPath &&
      other.rating == rating &&
      other.overview == overview;

  @override
  int get hashCode => Object.hash(id, posterPath, rating, overview);

  @override
  String toString() => 'TmdbInfo($id, $posterPath, $rating)';
}

/// Poster widths served by TMDB that the app uses.
enum TmdbImageSize {
  /// Grid cards.
  card('w342'),

  /// The movie details panel.
  details('w500');

  const TmdbImageSize(this.path);
  final String path;
}

const tmdbImageBase = 'https://image.tmdb.org/t/p/';

/// Full image URL for a TMDB [posterPath] (`/abc.jpg`) at [size].
String tmdbImageUrl(String posterPath, TmdbImageSize size) =>
    '$tmdbImageBase${size.path}'
    '${posterPath.startsWith('/') ? '' : '/'}$posterPath';

/// How long a "not found" answer is trusted before asking TMDB again.
/// Found answers never expire.
const tmdbNotFoundTtl = Duration(days: 30);

/// A row of the local TMDB cache.
class TmdbCached {
  const TmdbCached(this.info, this.fetchedAt);

  /// Null when TMDB had no match for the title.
  final TmdbInfo? info;
  final DateTime fetchedAt;

  /// Whether the row can be used at [now] instead of asking TMDB: always
  /// for a match, for [tmdbNotFoundTtl] for a miss.
  bool isFresh(DateTime now) =>
      info != null || now.difference(fetchedAt) < tmdbNotFoundTtl;
}
