import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/database.dart';
import 'package:glyph_player/data/stream_entry.dart';
import 'package:glyph_player/features/live/live_home_page.dart';
import 'package:glyph_player/state/providers.dart';

void main() {
  testWidgets('typing in search lists matching channels', (t) async {
    final db = Db.memory();
    final run = db.beginRun();
    db.upsertBatch([
      const StreamEntry(type: StreamType.live, id: '1', name: 'Globo SP', group: 'G', logo: '', url: 'http://h/live/U/P/1.ts'),
      const StreamEntry(type: StreamType.live, id: '2', name: 'SBT', group: 'G', logo: '', url: 'http://h/live/U/P/2.ts'),
    ], run);
    db.finishRun(run);
    await t.pumpWidget(ProviderScope(
      overrides: [
        dbProvider.overrideWithValue(db),
        appPathsProvider.overrideWithValue(const AppPaths(dbPath: ':memory:', downloadPath: '/tmp/x')),
      ],
      child: const MaterialApp(home: LiveHomePage()),
    ));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Buscar'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField), 'glo');
    await t.pumpAndSettle();
    expect(find.text('Globo SP'), findsWidgets);
    expect(find.text('SBT'), findsNothing);
    db.close();
  });
}
