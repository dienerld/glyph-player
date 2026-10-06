import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// The playlist URL embeds credentials, so it lives in the OS secure store.
class PlaylistUrlStore {
  const PlaylistUrlStore();
  static const _key = 'playlist_url';
  static const _storage = FlutterSecureStorage();

  Future<String?> read() => _storage.read(key: _key);
  Future<void> write(String url) => _storage.write(key: _key, value: url);
}
