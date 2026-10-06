import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'app.dart';
import 'data/database.dart';
import 'data/thumb_cache.dart';
import 'state/providers.dart';

const _thumbCacheMaxBytes = 400 * 1024 * 1024;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  final dir = await getApplicationSupportDirectory();
  await dir.create(recursive: true);
  final paths = AppPaths(
    dbPath: p.join(dir.path, 'glyph.db'),
    downloadPath: p.join(dir.path, 'playlist.download'),
  );
  final thumbs = ThumbCache(
    Directory(p.join((await getApplicationCacheDirectory()).path, 'thumbs')),
  );
  // Keep the saved thumbnails bounded (least recently used go first).
  unawaited(thumbs.prune(_thumbCacheMaxBytes));
  runApp(
    ProviderScope(
      overrides: [
        appPathsProvider.overrideWithValue(paths),
        thumbCacheProvider.overrideWithValue(thumbs),
        dbProvider.overrideWithValue(Db.open(paths.dbPath)),
      ],
      child: const GlyphApp(),
    ),
  );
}
