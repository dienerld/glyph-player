import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/database.dart';
import '../data/downloader.dart';
import '../data/importer.dart';
import '../data/playlist_url_store.dart';

class AppPaths {
  const AppPaths({required this.dbPath, required this.downloadPath});
  final String dbPath, downloadPath;
}

final dbProvider = Provider<Db>((ref) => throw UnimplementedError('override in main'));
final appPathsProvider =
    Provider<AppPaths>((ref) => throw UnimplementedError('override in main'));
final playlistUrlStoreProvider = Provider<PlaylistUrlStore>((ref) => const PlaylistUrlStore());

final liveGroupsProvider =
    FutureProvider<List<String>>((ref) async => ref.watch(dbProvider).liveGroups());
final groupChannelsProvider = FutureProvider.family<List<Channel>, String>(
    (ref, group) async => ref.watch(dbProvider).liveChannels(group));
final favoritesProvider =
    FutureProvider<List<Channel>>((ref) async => ref.watch(dbProvider).favorites());
final recentsProvider =
    FutureProvider<List<Channel>>((ref) async => ref.watch(dbProvider).recents());
final searchProvider = FutureProvider.family<List<Channel>, String>(
    (ref, q) async => ref.watch(dbProvider).searchLive(q));

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

  Future<void> refresh() async {
    if (state is ImportRunning) return;
    final url = await ref.read(playlistUrlStoreProvider).read();
    if (url == null || Uri.tryParse(url)?.hasScheme != true) {
      state = const ImportFailed('Configure a URL da lista em Configurações.');
      return;
    }
    final paths = ref.read(appPathsProvider);
    final file = File(paths.downloadPath);
    state = const ImportRunning();
    try {
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
        ..invalidate(groupChannelsProvider)
        ..invalidate(favoritesProvider)
        ..invalidate(recentsProvider);
    } catch (e) {
      state = ImportFailed('Falha ao atualizar a lista: $e');
    } finally {
      if (await file.exists()) await file.delete();
    }
  }
}

final importControllerProvider =
    NotifierProvider<ImportController, ImportState>(ImportController.new);
