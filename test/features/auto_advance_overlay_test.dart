import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/features/series/auto_advance_overlay.dart';

Widget host(AutoAdvanceOverlay o) => MaterialApp(
  home: Scaffold(body: Stack(children: [o])),
);

void main() {
  testWidgets('counts down and advances once at zero', (t) async {
    var now = 0;
    await t.pumpWidget(
      host(
        AutoAdvanceOverlay(
          title: 'Dark S01E02',
          seconds: 3,
          onNow: () => now++,
          onCancel: () {},
        ),
      ),
    );
    expect(find.text('Próximo episódio em 3 s'), findsOneWidget);
    await t.pump(const Duration(seconds: 1));
    expect(find.text('Próximo episódio em 2 s'), findsOneWidget);
    await t.pump(const Duration(seconds: 2));
    await t.pump(const Duration(seconds: 2));
    expect(now, 1);
  });

  testWidgets('Cancelar stops the countdown without advancing', (t) async {
    var now = 0, cancelled = 0;
    await t.pumpWidget(
      host(
        AutoAdvanceOverlay(
          title: 'x',
          seconds: 2,
          onNow: () => now++,
          onCancel: () => cancelled++,
        ),
      ),
    );
    await t.tap(find.text('Cancelar'));
    await t.pump(const Duration(seconds: 5));
    expect((now, cancelled), (0, 1));
  });

  testWidgets('Assistir agora advances immediately and only once', (t) async {
    var now = 0;
    await t.pumpWidget(
      host(
        AutoAdvanceOverlay(
          title: 'x',
          seconds: 2,
          onNow: () => now++,
          onCancel: () {},
        ),
      ),
    );
    await t.tap(find.text('Assistir agora'));
    await t.pump(const Duration(seconds: 5));
    expect(now, 1);
  });
}
