import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/database.dart';
import 'package:glyph_player/player/player_page.dart';

void main() {
  final queue = [
    for (var i = 0; i < 200; i++)
      Channel(
        type: 'live',
        id: '$i',
        name: 'Canal $i',
        group: 'G',
        logo: '',
        url: '',
      ),
  ];

  Widget host(int index) => MaterialApp(
    home: Scaffold(
      body: SizedBox(
        height: 400,
        child: QueueList(queue: queue, index: index, onSelect: (_) {}),
      ),
    ),
  );

  testWidgets('opens centred on the playing channel, not at the top', (
    t,
  ) async {
    await t.pumpWidget(host(180));
    expect(find.text('Canal 180'), findsOneWidget);
    expect(find.text('Canal 0'), findsNothing);
  });

  testWidgets('follows the playing channel when it changes', (t) async {
    await t.pumpWidget(host(0));
    expect(find.text('Canal 0'), findsOneWidget);
    await t.pumpWidget(host(150));
    await t.pumpAndSettle();
    expect(find.text('Canal 150'), findsOneWidget);
  });
}
