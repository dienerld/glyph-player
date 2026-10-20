import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../data/content_filter.dart';
import '../data/database.dart';
import '../data/downloader.dart';
import '../data/importer.dart';
import '../data/playlist_url_store.dart';
import '../data/task_queue.dart';
import '../data/thumb_cache.dart';
import '../data/tmdb_client.dart';
import '../data/updater.dart';

class AppPaths {
  const AppPaths({required this.dbPath, required this.downloadPath});
  final String dbPath, downloadPath;
}

final dbProvider = Provider<Db>(
  (ref) => throw UnimplementedError('override in main'),
);
final thumbCacheProvider = Provider<ThumbCache>(
  (ref) => throw UnimplementedError('override in main'),
);
final appPathsProvider = Provider<AppPaths>(
  (ref) => throw UnimplementedError('override in main'),
);
final playlistUrlStoreProvider = Provider<PlaylistUrlStore>(
  (ref) => const PlaylistUrlStore(),
);

final appVersionProvider = FutureProvider<String>(
  (ref) async => (await PackageInfo.fromPlatform()).version,
);

/// The newer release on GitHub, or null when up to date or the check failed
/// (offline is not an error worth showing). Invalidate to check again.
final availableUpdateProvider = FutureProvider<UpdateInfo?>((ref) async {
  final client = http.Client();
  try {
    return await fetchUpdate(
      await ref.watch(appVersionProvider.future),
      client: client,
    );
  } catch (_) {
    return null;
  } finally {
    client.close();
  }
});

class ShowAdultNotifier extends Notifier<bool> {
  static const _key = 'show_adult';

  @override
  bool build() => ref.read(dbProvider).setting(_key) == '1';

  void set(bool value) {
    ref.read(dbProvider).setSetting(_key, value ? '1' : '0');
    state = value;
  }
}

/// How Ao vivo lays out channels: a row per category, or a category picker
/// that opens one category at a time.
enum LiveView { rows, categories }

class LiveViewNotifier extends Notifier<LiveView> {
  static const _key = 'live_view';

  @override
  LiveView build() =>
      ref.read(dbProvider).setting(_key) == LiveView.categories.name
      ? LiveView.categories
      : LiveView.rows;

  void set(LiveView value) {
    ref.read(dbProvider).setSetting(_key, value.name);
    state = value;
  }
}

final liveViewProvider = NotifierProvider<LiveViewNotifier, LiveView>(
  LiveViewNotifier.new,
);

/// Sort order of a category grid, remembered per kind. Defaults to A-Z.
class SortNotifier extends Notifier<SortOrder> {
  SortNotifier(this._key);
  final String _key;

  @override
  SortOrder build() {
    final saved = ref.read(dbProvider).setting(_key);
    return SortOrder.values.firstWhere(
      (o) => o.name == saved,
      orElse: () => SortOrder.az,
    );
  }

  void set(SortOrder value) {
    ref.read(dbProvider).setSetting(_key, value.name);
    state = value;
  }
}

final movieSortProvider = NotifierProvider<SortNotifier, SortOrder>(
  () => SortNotifier('movie_sort'),
);
final seriesSortProvider = NotifierProvider<SortNotifier, SortOrder>(
  () => SortNotifier('series_sort'),
);

/// Items loaded so far in a category grid.
class Paged<T> {
  const Paged(this.items, {required this.hasMore, this.loading = false});
  final List<T> items;

  /// Whether another page may exist; false once a short page came back.
  final bool hasMore;

  /// A [PagedNotifier.loadMore] is in flight.
  final bool loading;
}

/// What a movie or series grid shows: one category or all of them ([group]
/// null), optionally narrowed by a title [query]. Value-equal, so it keys the
/// paged providers.
///
/// - one category: `GridScope.group('Ação')`
/// - search everywhere: `GridScope.search(text)`
/// - search one category: `GridScope.search(text, group: 'Ação')`
class GridScope {
  const GridScope({this.group, this.query = ''});

  const GridScope.group(String this.group) : query = '';

  /// Trims [text], so surrounding spaces map to the same scope.
  factory GridScope.search(String text, {String? group}) =>
      GridScope(group: group, query: text.trim());

  /// Null for every category.
  final String? group;

  /// Title filter; empty for none. One or two characters match the start of
  /// a title, more match anywhere in it.
  final String query;

  /// Whether [query] narrows the results.
  bool get searching => query.trim().isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is GridScope && other.group == group && other.query == query;

  @override
  int get hashCode => Object.hash(group, query);

  @override
  String toString() => 'GridScope(group: $group, query: $query)';
}

/// A movie or series grid loaded page by page ([gridPageSize] at a time).
/// Starts over from the first page when the sort order or the adult filter
/// changes. Adult groups are left out unless the user opts in.
abstract class PagedNotifier<T>
    extends AutoDisposeFamilyAsyncNotifier<Paged<T>, GridScope> {
  ProviderListenable<SortOrder> get _sort;
  List<T> _fetch(
    Db db,
    GridScope scope,
    SortOrder order,
    int offset, {
    required bool hideAdult,
  });

  /// Bumped on every rebuild and on dispose, so a loadMore started before
  /// either never writes stale items.
  int _gen = 0;

  @override
  Future<Paged<T>> build(GridScope scope) async {
    _gen++;
    ref.onDispose(() => _gen++);
    final order = ref.watch(_sort);
    final hideAdult = !ref.watch(showAdultProvider);
    final page = _fetch(
      ref.read(dbProvider),
      scope,
      order,
      0,
      hideAdult: hideAdult,
    );
    return Paged(page, hasMore: page.length >= gridPageSize);
  }

  /// Appends the next page. No-op while loading, before the first page, or
  /// when nothing is left.
  Future<void> loadMore() async {
    final cur = state.valueOrNull;
    if (cur == null || cur.loading || !cur.hasMore) return;
    final gen = _gen;
    state = AsyncData(Paged(cur.items, hasMore: true, loading: true));
    await Future<void>.delayed(Duration.zero); // let the grid show it
    if (gen != _gen) return;
    final next = _fetch(
      ref.read(dbProvider),
      arg,
      ref.read(_sort),
      cur.items.length,
      hideAdult: !ref.read(showAdultProvider),
    );
    state = AsyncData(
      Paged([...cur.items, ...next], hasMore: next.length >= gridPageSize),
    );
  }
}

class MoviesPageNotifier extends PagedNotifier<Channel> {
  @override
  ProviderListenable<SortOrder> get _sort => movieSortProvider;

  @override
  List<Channel> _fetch(
    Db db,
    GridScope scope,
    SortOrder order,
    int offset, {
    required bool hideAdult,
  }) => db.moviesPage(
    scope.group,
    order,
    query: scope.query,
    hideAdult: hideAdult,
    offset: offset,
  );
}

class SeriesPageNotifier extends PagedNotifier<SeriesSummary> {
  @override
  ProviderListenable<SortOrder> get _sort => seriesSortProvider;

  @override
  List<SeriesSummary> _fetch(
    Db db,
    GridScope scope,
    SortOrder order,
    int offset, {
    required bool hideAdult,
  }) => db.seriesPage(
    scope.group,
    order,
    query: scope.query,
    hideAdult: hideAdult,
    offset: offset,
  );
}

/// Movies of a [GridScope].
final moviesPageProvider = AsyncNotifierProvider.autoDispose
    .family<MoviesPageNotifier, Paged<Channel>, GridScope>(
      MoviesPageNotifier.new,
    );

/// Series of a [GridScope], one entry per (group, series).
final seriesPageProvider = AsyncNotifierProvider.autoDispose
    .family<SeriesPageNotifier, Paged<SeriesSummary>, GridScope>(
      SeriesPageNotifier.new,
    );

/// Adult groups are hidden unless the user opts in (Settings).
final showAdultProvider = NotifierProvider<ShowAdultNotifier, bool>(
  ShowAdultNotifier.new,
);

List<Channel> _visible(List<Channel> items, bool showAdult) =>
    showAdult ? items : items.where((c) => !isAdultGroup(c.group)).toList();

final liveGroupsProvider = FutureProvider<List<GroupCount>>((ref) async {
  final show = ref.watch(showAdultProvider);
  return ref
      .watch(dbProvider)
      .groups('live')
      .where((g) => show || !isAdultGroup(g.name))
      .toList();
});
final groupChannelsProvider = FutureProvider.family<List<Channel>, String>(
  (ref, group) async => ref.watch(dbProvider).channels('live', group),
);
final favoritesProvider = FutureProvider<List<Channel>>(
  (ref) async => _visible(
    ref.watch(dbProvider).favorites('live'),
    ref.watch(showAdultProvider),
  ),
);
final recentsProvider = FutureProvider<List<Channel>>(
  (ref) async =>
      _visible(ref.watch(dbProvider).recents(), ref.watch(showAdultProvider)),
);

final movieFavoritesProvider = FutureProvider<List<Channel>>(
  (ref) async => _visible(
    ref.watch(dbProvider).favorites('movie'),
    ref.watch(showAdultProvider),
  ),
);
final movieGroupsProvider = FutureProvider<List<GroupCount>>((ref) async {
  final show = ref.watch(showAdultProvider);
  return ref
      .watch(dbProvider)
      .groups('movie')
      .where((g) => show || !isAdultGroup(g.name))
      .toList();
});
final continueWatchingProvider = FutureProvider<List<Channel>>(
  (ref) async => _visible(
    ref.watch(dbProvider).continueWatching(),
    ref.watch(showAdultProvider),
  ),
);

final seriesSectionsProvider = FutureProvider<List<GroupCount>>((ref) async {
  final show = ref.watch(showAdultProvider);
  return ref
      .watch(dbProvider)
      .groups('series')
      .where((g) => show || !isAdultGroup(g.name))
      .toList();
});
final seriesEpisodesProvider =
    FutureProvider.family<List<Episode>, (String, String)>(
      (ref, key) async => ref.watch(dbProvider).episodes(key.$1, key.$2),
    );
List<SeriesSummary> _visibleSeries(List<SeriesSummary> l, bool show) =>
    show ? l : l.where((s) => !isAdultGroup(s.group)).toList();
final seriesFavoritesProvider = FutureProvider<List<SeriesSummary>>(
  (ref) async => _visibleSeries(
    ref.watch(dbProvider).seriesFavorites(),
    ref.watch(showAdultProvider),
  ),
);
final continueSeriesProvider = FutureProvider<List<SeriesSummary>>(
  (ref) async => _visibleSeries(
    ref.watch(dbProvider).continueSeries(),
    ref.watch(showAdultProvider),
  ),
);

/// Search keyed by (type, text): `('live', 'globo')`.
final searchProvider = FutureProvider.family<List<Channel>, (String, String)>((
  ref,
  q,
) async {
  final show = ref.watch(showAdultProvider);
  return _visible(ref.watch(dbProvider).search(q.$1, q.$2), show);
});

// --- TMDB metadata -------------------------------------------------------

/// TMDB lookups running at once, at most.
const tmdbMaxConcurrent = 4;

/// HTTP client of the TMDB calls; overridden in tests.
final tmdbHttpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

/// Shared queue of TMDB searches ([tmdbMaxConcurrent] at a time).
final tmdbQueueProvider = Provider<TaskQueue>(
  (ref) => TaskQueue(limit: tmdbMaxConcurrent),
);

/// The user's TMDB key (v3 API key or v4 token), '' when unset. Stored in
/// the local settings.
class TmdbKeyNotifier extends Notifier<String> {
  static const _key = 'tmdb_key';

  @override
  String build() => (ref.read(dbProvider).setting(_key) ?? '').trim();

  /// Saves [value] trimmed; '' turns TMDB off. Lookups follow the new key.
  void set(String value) {
    final v = value.trim();
    ref.read(dbProvider).setSetting(_key, v);
    if (v != state) state = v;
  }

  /// "Testar chave": asks TMDB whether [key] (the saved key when omitted)
  /// is accepted. An empty key is [TmdbKeyStatus.invalid], with no request.
  Future<TmdbKeyStatus> check([String? key]) async {
    final k = (key ?? state).trim();
    if (k.isEmpty) return TmdbKeyStatus.invalid;
    return TmdbClient(k, client: ref.read(tmdbHttpClientProvider)).checkKey();
  }

  /// "Limpar cache": forgets every TMDB answer; visible items ask again.
  void clearCache() {
    ref.read(dbProvider).clearTmdbCache();
    ref
      ..invalidate(tmdbMovieProvider)
      ..invalidate(tmdbSeriesProvider);
  }
}

final tmdbKeyProvider = NotifierProvider<TmdbKeyNotifier, String>(
  TmdbKeyNotifier.new,
);

/// Whether a TMDB key is set. Without one the app never calls TMDB.
final tmdbEnabledProvider = Provider<bool>(
  (ref) => ref.watch(tmdbKeyProvider).isNotEmpty,
);

/// Client for the current key; null without one.
final tmdbClientProvider = Provider<TmdbClient?>((ref) {
  final key = ref.watch(tmdbKeyProvider);
  if (key.isEmpty) return null;
  return TmdbClient(key, client: ref.watch(tmdbHttpClientProvider));
});

/// Cache first, then TMDB through the shared queue. A lookup still queued
/// when its provider is disposed (the card left the screen) is dropped.
/// Found and not-found answers are cached; failures are not and give null.
Future<TmdbInfo?> _tmdbLookup(
  Ref ref,
  TmdbKind kind,
  String title,
  int year,
  Future<TmdbResult> Function(TmdbClient client) search,
) async {
  final client = ref.watch(tmdbClientProvider);
  if (client == null) return null;
  final key = tmdbTitleKey(title);
  if (key.isEmpty) return null;
  final db = ref.watch(dbProvider);
  final cached = db.tmdbCached(kind, key, year: year);
  if (cached != null && cached.isFresh(DateTime.now())) return cached.info;
  var disposed = false;
  ref.onDispose(() => disposed = true);
  final result = await ref
      .read(tmdbQueueProvider)
      .run(() => search(client), isCancelled: () => disposed);
  switch (result) {
    case TmdbFound(:final info):
      db.putTmdb(kind, key, info, DateTime.now(), year: year);
      return info;
    case TmdbNotFound():
      db.putTmdb(kind, key, null, DateTime.now(), year: year);
      return null;
    default: // dropped, invalid key or unavailable: ask again next time
      return null;
  }
}

/// TMDB data of a movie keyed by `(clean title, year)`; build the key from
/// the stream name with [tmdbMovieQuery]. Null without a key, when TMDB has
/// no match, or when the lookup failed.
final tmdbMovieProvider = FutureProvider.autoDispose
    .family<TmdbInfo?, (String, int?)>(
      (ref, q) => _tmdbLookup(
        ref,
        TmdbKind.movie,
        q.$1,
        q.$2 ?? 0,
        (c) => c.searchMovie(q.$1.trim(), year: q.$2),
      ),
    );

/// TMDB data of a series keyed by its `series_name` ([SeriesSummary.name]).
/// Null without a key, when TMDB has no match, or when the lookup failed.
final tmdbSeriesProvider = FutureProvider.autoDispose.family<TmdbInfo?, String>(
  (ref, name) => _tmdbLookup(
    ref,
    TmdbKind.series,
    name,
    0,
    (c) => c.searchTv(name.trim()),
  ),
);

sealed class ImportState {
  const ImportState();
}

class ImportIdle extends ImportState {
  const ImportIdle();
}

class ImportRunning extends ImportState {
  const ImportRunning({this.count = 0, this.downloading = true});
  final int count;
  final bool downloading;
}

class ImportFailed extends ImportState {
  const ImportFailed(this.message);
  final String message;
}

class ImportController extends Notifier<ImportState> {
  @override
  ImportState build() => const ImportIdle();

  /// Downloads and imports the playlist. [newUrl], when given, is stored first.
  Future<void> refresh({String? newUrl}) async {
    if (state is ImportRunning) return;
    state = const ImportRunning(); // before any await: blocks re-entrancy
    final paths = ref.read(appPathsProvider);
    final file = File(paths.downloadPath);
    try {
      final String? url;
      try {
        final store = ref.read(playlistUrlStoreProvider);
        if (newUrl != null) await store.write(newUrl);
        url = newUrl ?? await store.read();
      } catch (_) {
        state = const ImportFailed(
          'Não foi possível acessar o cofre de senhas do sistema.',
        );
        return;
      }
      if (url == null || Uri.tryParse(url)?.hasScheme != true) {
        state = const ImportFailed(
          'Configure a URL da lista em Configurações.',
        );
        return;
      }
      await downloadTo(Uri.parse(url), file);
      state = const ImportRunning(downloading: false);
      await importInBackground(
        paths.dbPath,
        file,
        (n) => state = ImportRunning(count: n, downloading: false),
      );
      state = const ImportIdle();
      ref
        ..invalidate(liveGroupsProvider)
        ..invalidate(movieGroupsProvider)
        ..invalidate(moviesPageProvider)
        ..invalidate(continueWatchingProvider)
        ..invalidate(searchProvider)
        ..invalidate(seriesSectionsProvider)
        ..invalidate(seriesPageProvider)
        ..invalidate(seriesEpisodesProvider)
        ..invalidate(seriesFavoritesProvider)
        ..invalidate(continueSeriesProvider)
        ..invalidate(groupChannelsProvider)
        ..invalidate(favoritesProvider)
        ..invalidate(movieFavoritesProvider)
        ..invalidate(recentsProvider);
    } catch (e) {
      state = ImportFailed(_describe(e));
    } finally {
      if (await file.exists()) await file.delete();
    }
  }
}

/// Never includes the exception's URL: it carries the playlist credentials.
String _describe(Object e) => switch (e) {
  HttpException(:final message) => 'Falha ao baixar a lista: $message',
  TimeoutException() => 'Tempo esgotado ao baixar a lista.',
  SocketException() ||
  http.ClientException() => 'Sem conexão com o servidor da lista.',
  FormatException(:final message) => 'Lista inválida: $message',
  _ => 'Erro inesperado ao atualizar a lista.',
};

final importControllerProvider =
    NotifierProvider<ImportController, ImportState>(ImportController.new);
