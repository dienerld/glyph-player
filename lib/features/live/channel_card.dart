import 'package:flutter/material.dart';
import '../../data/database.dart';
import '../../player/player_page.dart';
import '../../ui/theme.dart';
import '../shared/monogram.dart';

class ChannelCard extends StatefulWidget {
  const ChannelCard({
    super.key,
    required this.queue,
    required this.index,
    this.wide = false,
  });
  final List<Channel> queue;
  final int index;
  final bool wide;

  @override
  State<ChannelCard> createState() => _ChannelCardState();
}

class _ChannelCardState extends State<ChannelCard> {
  bool _active = false;

  void _open() => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => PlayerPage(queue: widget.queue, index: widget.index),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = widget.queue[widget.index];
    final w = widget.wide ? Tokens.wideW : Tokens.cardW;
    final h = widget.wide ? Tokens.wideH : Tokens.cardH;
    final reduce = MediaQuery.of(context).disableAnimations;
    return SizedBox(
      width: w,
      child: FocusableActionDetector(
        onShowFocusHighlight: (v) => setState(() => _active = v),
        onShowHoverHighlight: (v) => setState(() => _active = v),
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _open();
              return null;
            },
          ),
        },
        child: GestureDetector(
          onTap: _open,
          child: AnimatedScale(
            scale: _active && !reduce ? 1.03 : 1,
            duration: reduce ? Duration.zero : Tokens.hover,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedContainer(
                  duration: reduce ? Duration.zero : Tokens.hover,
                  height: h - 28,
                  decoration: BoxDecoration(
                    color: _active ? Tokens.tileHi : Tokens.tile,
                    borderRadius: BorderRadius.circular(Tokens.radius),
                    border: Border.all(
                      color: _active ? Tokens.tally : Colors.transparent,
                      width: 2,
                    ),
                  ),
                  padding: EdgeInsets.all(widget.wide ? 20 : 14),
                  child: Center(child: _Logo(channel: c)),
                ),
                const SizedBox(height: 8),
                Text(
                  c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 20 / 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.channel});
  final Channel channel;

  @override
  Widget build(BuildContext context) {
    final mono = Monogram(name: channel.name);
    if (channel.logo.isEmpty) return mono;
    return Image.network(
      channel.logo,
      fit: BoxFit.contain,
      cacheWidth: 360,
      errorBuilder: (_, _, _) => mono,
      loadingBuilder: (_, child, p) => p == null ? child : mono,
    );
  }
}
