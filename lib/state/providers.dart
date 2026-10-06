import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../data/content_filter.dart';
import '../data/database.dart';
import '../data/downloader.dart';
import '../data/importer.dart';
import '../data/playlist_url_store.dart';

class AppPaths {
  const AppPaths({required this.dbPath, required this.downloadPath});
  final String dbPath, downloadPath;
}

final dbProvider = Provider<Db>(
  (ref) => throw UnimplementedError('override in main'),
);
final appPathsProvider = Provider<AppPaths>(
  (ref) => throw UnimplementedError('override in main'),
);
final playlistUrlStoreProvider = Provider<PlaylistUrlStore>(
  (ref) => const PlaylistUrlStore(),
);

class ShowAdultNotifier extends Notifier<bool> {
  static const _key = 'show_adult';

  @override
  bool build() => ref.read(dbProvider).setting(_key) == '1';

  void set(bool value) {
    ref.read(dbProvider).setSetting(_key, value ? '1' : '0');
    state = value;
  }
}

/// Adult groups are hidden unless the user opts in (Settings).
final showAdultProvider = NotifierProvider<ShowAdultNotifier, bool>(
  ShowAdultNotifier.new,
);

List<Channel> _visible(List<Channel> items, bool showAdult) =>
    showAdult ? items : items.where((c) => !isAdultGroup(c.group)).toList();

final liveGroupsProvider = FutureProvider<List<String>>((ref) async {
  final show = ref.watch(showAdultProvider);
  return ref
      .watch(dbProvider)
      .groups('live')
      .map((g) => g.name)
      .where((n) => show || !isAdultGroup(n))
      .toList();
});
final groupChannelsProvider = FutureProvider.family<List<Channel>, String>(
  (ref, group) async => ref.watch(dbProvider).channels('live', group),
);
final favoritesProvider = FutureProvider<List<Channel>>(
  (ref) async =>
      _visible(ref.watch(dbProvider).favorites(), ref.watch(showAdultProvider)),
);
final recentsProvider = FutureProvider<List<Channel>>(
  (ref) async =>
      _visible(ref.watch(dbProvider).recents(), ref.watch(showAdultProvider)),
);

final movieGroupsProvider = FutureProvider<List<GroupCount>>((ref) async {
  final show = ref.watch(showAdultProvider);
  return ref
      .watch(dbProvider)
      .groups('movie')
      .where((g) => show || !isAdultGroup(g.name))
      .toList();
});
final moviesInProvider = FutureProvider.family<List<Channel>, String>(
  (ref, group) async => ref.watch(dbProvider).channels('movie', group),
);
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
final seriesInProvider = FutureProvider.family<List<SeriesSummary>, String>(
  (ref, group) async => ref.watch(dbProvider).seriesIn(group),
);
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
        ..invalidate(moviesInProvider)
        ..invalidate(continueWatchingProvider)
        ..invalidate(searchProvider)
        ..invalidate(seriesSectionsProvider)
        ..invalidate(seriesInProvider)
        ..invalidate(seriesEpisodesProvider)
        ..invalidate(seriesFavoritesProvider)
        ..invalidate(continueSeriesProvider)
        ..invalidate(groupChannelsProvider)
        ..invalidate(favoritesProvider)
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
