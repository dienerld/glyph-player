import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/features/series/next_episode_banner.dart';

Widget host(NextEpisodeBanner b) => MaterialApp(
  home: Scaffold(body: Stack(children: [b])),
);

void main() {
  testWidgets('shows the next episode and skips on tap', (t) async {
    var skipped = 0;
    await t.pumpWidget(
      host(
        NextEpisodeBanner(
          title: 'Dark S01E02',
          onSkip: () => skipped++,
          onDismiss: () {},
        ),
      ),
    );
    expect(find.text('A seguir'), findsOneWidget);
    expect(find.text('Dark S01E02'), findsOneWidget);
    await t.tap(find.text('Próximo episódio'));
    expect(skipped, 1);
  });

  testWidgets('the close button dismisses without skipping', (t) async {
    var skipped = 0, dismissed = 0;
    await t.pumpWidget(
      host(
        NextEpisodeBanner(
          title: 'x',
          onSkip: () => skipped++,
          onDismiss: () => dismissed++,
        ),
      ),
    );
    await t.tap(find.byTooltip('Dispensar'));
    expect((skipped, dismissed), (0, 1));
  });
}
