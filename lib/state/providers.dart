import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

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

final liveGroupsProvider = FutureProvider<List<String>>(
  (ref) async => ref.watch(dbProvider).liveGroups(),
);
final groupChannelsProvider = FutureProvider.family<List<Channel>, String>(
  (ref, group) async => ref.watch(dbProvider).liveChannels(group),
);
final favoritesProvider = FutureProvider<List<Channel>>(
  (ref) async => ref.watch(dbProvider).favorites(),
);
final recentsProvider = FutureProvider<List<Channel>>(
  (ref) async => ref.watch(dbProvider).recents(),
);
final searchProvider = FutureProvider.family<List<Channel>, String>(
  (ref, q) async => ref.watch(dbProvider).searchLive(q),
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
