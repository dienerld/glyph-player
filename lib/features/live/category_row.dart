import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../ui/theme.dart';
import 'channel_card.dart';

class CategoryRow extends StatelessWidget {
  const CategoryRow({
    super.key,
    required this.title,
    required this.channels,
    this.wide = false,
  });
  final String title;
  final List<Channel> channels;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final h = (wide ? Tokens.wideH : Tokens.cardH) + 12;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(width: 10),
              Text(
                '${channels.length}',
                style: const TextStyle(color: Tokens.textDim, fontSize: 13),
              ),
            ],
          ),
        ),
        SizedBox(
          height: h,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            itemCount: channels.length,
            separatorBuilder: (_, _) => const SizedBox(width: Tokens.gap),
            itemBuilder: (_, i) =>
                ChannelCard(queue: channels, index: i, wide: wide),
          ),
        ),
      ],
    );
  }
}
