import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/thumb_cache.dart';
import 'package:glyph_player/features/shared/cached_thumb.dart';
import 'package:glyph_player/state/providers.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// The cache does real file I/O whose continuations run in the fake zone:
/// alternate real time and pumps until it settles.
Future<void> settleIo(WidgetTester t) async {
  for (var i = 0; i < 8; i++) {
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 40)));
    await t.pump();
  }
}

Widget host(ThumbCache cache, String url) => ProviderScope(
  overrides: [thumbCacheProvider.overrideWithValue(cache)],
  child: MaterialApp(
    home: Scaffold(
      body: CachedThumb(url: url, fallback: const Text('FALLBACK')),
    ),
  ),
);

void main() {
  testWidgets('an empty url shows the fallback without touching the cache', (
    t,
  ) async {
    final tmp = (await t.runAsync(
      () => Directory.systemTemp.createTemp('ct'),
    ))!;
    final cache = ThumbCache(
      tmp,
      client: MockClient((_) async => throw StateError('no network expected')),
    );
    await t.pumpWidget(host(cache, ''));
    expect(find.text('FALLBACK'), findsOneWidget);
    await t.runAsync(() => tmp.delete(recursive: true));
  });

  testWidgets('a failed download keeps showing the fallback', (t) async {
    final tmp = (await t.runAsync(
      () => Directory.systemTemp.createTemp('ct'),
    ))!;
    final cache = ThumbCache(
      tmp,
      client: MockClient((_) async => http.Response('', 404)),
    );
    await t.pumpWidget(host(cache, 'http://x/p.jpg'));
    await settleIo(t);
    expect(find.text('FALLBACK'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    await t.runAsync(() => tmp.delete(recursive: true));
  });

  testWidgets('a saved file is shown as an image', (t) async {
    final tmp = (await t.runAsync(
      () => Directory.systemTemp.createTemp('ct'),
    ))!;
    final cache = ThumbCache(
      tmp,
      client: MockClient((_) async => http.Response.bytes(_png, 200)),
    );
    await t.pumpWidget(host(cache, 'http://x/p.jpg'));
    await settleIo(t);
    expect(find.byType(Image), findsOneWidget);
    await t.runAsync(() => tmp.delete(recursive: true));
  });
}
