import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../data/database.dart';
import '../state/providers.dart';
import '../ui/theme.dart';

const _panelWidth = 320.0;
const _seekStep = Duration(seconds: 10);

int zapIndex(int current, int delta, int length) => (current + delta) % length;

class PlayerPage extends ConsumerStatefulWidget {
  const PlayerPage({super.key, required this.queue, required this.index});
  final List<Channel> queue;
  final int index;
  @override
  ConsumerState<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends ConsumerState<PlayerPage> {
  late final Player _player = Player();
  late final VideoController _video = VideoController(_player);
  late int _index = widget.index;
  bool _panel = true;
  Timer? _hide;
  StreamSubscription<Duration>? _durationSub;

  /// Some "live" entries are really finite videos. mpv reports a duration only
  /// for those, so a known duration switches on the seek controls.
  bool _seekable = false;

  Channel get _current => widget.queue[_index];

  @override
  void initState() {
    super.initState();
    _durationSub = _player.stream.duration.listen((d) {
      final seekable = d > Duration.zero;
      if (seekable != _seekable && mounted) {
        setState(() => _seekable = seekable);
      }
    });
    _open();
    _poke();
  }

  void _open() {
    final c = _current;
    _seekable = false; // re-detected from the new stream's duration
    _player.open(Media(c.url));
    ref.read(dbProvider).markWatched(c.type, c.id, DateTime.now());
    // Riverpod forbids invalidating from initState; refresh after the frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(recentsProvider);
    });
  }

  /// Shows the panel and hides it again after 2.5 s without activity.
  void _poke() {
    _hide?.cancel();
    if (!_panel) setState(() => _panel = true);
    _hide = Timer(const Duration(milliseconds: 2500), () {
      if (mounted) setState(() => _panel = false);
    });
  }

  void _zap(int delta) {
    setState(() => _index = zapIndex(_index, delta, widget.queue.length));
    _open();
    _poke();
  }

  @override
  void dispose() {
    _hide?.cancel();
    _durationSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  void _seekBy(Duration delta) {
    final target = _player.state.position + delta;
    _player.seek(target < Duration.zero ? Duration.zero : target);
  }

  /// Live-TV controls: previous/next channel of the group, play/pause, volume,
  /// fullscreen. Shortcuts are replaced so up/down keep meaning "zap" (the
  /// defaults seek and change volume) and also work inside fullscreen.
  MaterialDesktopVideoControlsThemeData _controls({required bool fullscreen}) {
    Widget zapButton(String tip, IconData icon, int delta) => Tooltip(
      message: tip,
      child: MaterialDesktopCustomButton(
        icon: Icon(icon),
        onPressed: () => _zap(delta),
      ),
    );
    final barMargin = EdgeInsets.only(
      left: 16,
      right: !fullscreen && _panel ? _panelWidth + 16 : 16,
    );
    Widget seekButton(String tip, IconData icon, Duration d) => Tooltip(
      message: tip,
      child: MaterialDesktopCustomButton(
        icon: Icon(icon),
        onPressed: () => _seekBy(d),
      ),
    );
    return MaterialDesktopVideoControlsThemeData(
      displaySeekBar: _seekable,
      seekBarMargin: barMargin,
      automaticallyImplySkipNextButton: false,
      automaticallyImplySkipPreviousButton: false,
      buttonBarButtonColor: Tokens.text,
      keyboardShortcuts: {
        const SingleActivator(LogicalKeyboardKey.space): _player.playOrPause,
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _zap(-1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _zap(1),
        const SingleActivator(LogicalKeyboardKey.keyM): () =>
            _player.setVolume(_player.state.volume == 0 ? 100 : 0),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
        if (_seekable) ...{
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
              _seekBy(-_seekStep),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
              _seekBy(_seekStep),
        },
      },
      // Keep the bar clear of the channel panel (which is not shown in fullscreen).
      bottomButtonBarMargin: barMargin,
      bottomButtonBar: [
        zapButton('Canal anterior (↑)', Icons.skip_previous, -1),
        if (_seekable)
          seekButton('Voltar 10 s (←)', Icons.replay_10, -_seekStep),
        const MaterialDesktopPlayOrPauseButton(),
        if (_seekable)
          seekButton('Avançar 10 s (→)', Icons.forward_10, _seekStep),
        zapButton('Próximo canal (↓)', Icons.skip_next, 1),
        const MaterialDesktopVolumeButton(),
        if (_seekable) const MaterialDesktopPositionIndicator(),
        const Spacer(),
        const MaterialDesktopFullscreenButton(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);
    final reduce = MediaQuery.of(context).disableAnimations;
    final fav = db.isFavorite(_current.type, _current.id);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowUp): () => _zap(-1),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () => _zap(1),
        const SingleActivator(LogicalKeyboardKey.keyL): () {
          _hide?.cancel();
          setState(() => _panel = !_panel);
        },
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
        if (_seekable) ...{
          const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
              _seekBy(-_seekStep),
          const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
              _seekBy(_seekStep),
        },
      },
      child: Focus(
        autofocus: true,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: MouseRegion(
            onHover: (_) => _poke(),
            child: Stack(
              children: [
                Positioned.fill(
                  child: MaterialDesktopVideoControlsTheme(
                    normal: _controls(fullscreen: false),
                    fullscreen: _controls(fullscreen: true),
                    child: Video(
                      controller: _video,
                      controls: MaterialDesktopVideoControls,
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: AnimatedOpacity(
                    opacity: _panel ? 1 : 0,
                    duration: reduce ? Duration.zero : Tokens.hover,
                    child: IconButton(
                      tooltip: 'Voltar',
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
                AnimatedPositioned(
                  duration: reduce ? Duration.zero : Tokens.slide,
                  curve: Tokens.slideCurve,
                  top: 0,
                  bottom: 0,
                  right: _panel ? 0 : -_panelWidth,
                  width: _panelWidth,
                  child: Material(
                    color: Tokens.panel.withValues(alpha: 0.94),
                    child: Column(
                      children: [
                        ListTile(
                          title: Text(
                            _current.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            _current.group,
                            maxLines: 1,
                            style: const TextStyle(color: Tokens.textDim),
                          ),
                          trailing: IconButton(
                            tooltip: fav
                                ? 'Remover dos favoritos'
                                : 'Favoritar',
                            icon: Icon(
                              fav ? Icons.star : Icons.star_border,
                              color: fav ? Tokens.tally : null,
                            ),
                            onPressed: () {
                              db.setFavorite(_current.type, _current.id, !fav);
                              ref.invalidate(favoritesProvider);
                              setState(() {});
                            },
                          ),
                        ),
                        const Divider(height: 1, color: Tokens.line),
                        Expanded(
                          child: ListView.builder(
                            itemCount: widget.queue.length,
                            itemBuilder: (_, i) {
                              final sel = i == _index;
                              return ListTile(
                                dense: true,
                                tileColor: sel ? Tokens.tallyDim : null,
                                leading: sel
                                    ? const Icon(
                                        Icons.circle,
                                        size: 10,
                                        color: Tokens.tally,
                                      )
                                    : const SizedBox(width: 10),
                                title: Text(
                                  widget.queue[i].name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                onTap: () => _zap(i - _index),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
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
