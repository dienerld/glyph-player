import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

import '../../data/database.dart';
import '../../data/movie_title.dart';
import '../../data/resume.dart';
import '../../state/providers.dart';
import '../../ui/theme.dart';
import '../series/auto_advance_overlay.dart';
import '../shared/card_actions.dart';
import '../series/next_episode_banner.dart';

const _seekStep = Duration(seconds: 10);
const _saveEvery = Duration(seconds: 10);

/// Plays a movie (queue of one) or the episodes of a series. [nextOf] gives the
/// index to auto-advance to after the item at the given index ends, or null.
class VodPlayerPage extends ConsumerStatefulWidget {
  const VodPlayerPage({
    super.key,
    required this.queue,
    required this.index,
    this.nextOf,
    this.previousOf,
  });
  final List<Channel> queue;
  final int index;
  final int? Function(int index)? nextOf;
  final int? Function(int index)? previousOf;

  @override
  ConsumerState<VodPlayerPage> createState() => _VodPlayerPageState();
}

class _VodPlayerPageState extends ConsumerState<VodPlayerPage> {
  final Player _player = Player();
  late final VideoController _video = VideoController(_player);
  late final Db _db = ref.read(dbProvider);
  late int _index = widget.index;
  late final ValueNotifier<int> _cursor = ValueNotifier(widget.index);
  int? _upNext;
  bool _showBanner = false;
  bool _bannerDismissed = false;
  StreamSubscription<Duration>? _positionSub;

  /// Set when the current item ended, so a later save cannot overwrite the
  /// "finished" progress with the position the player resets to.
  bool _finished = false;
  Timer? _saver;
  StreamSubscription<bool>? _completedSub;

  Channel get _item => widget.queue[_index];

  @override
  void initState() {
    super.initState();
    _completedSub = _player.stream.completed.listen((done) {
      if (done) _onCompleted();
    });
    _positionSub = _player.stream.position.listen(_onPosition);
    _openCurrent();
    _saver = Timer.periodic(_saveEvery, (_) => _save());
  }

  Future<void> _openCurrent() async {
    final item = _item;
    _finished = false;
    _bannerDismissed = false;
    final saved = _db.progressOf(item.type, item.id);
    if (item.type == 'series') {
      _db.touchProgress(item.type, item.id, DateTime.now());
    }
    await _player.open(Media(item.url));
    if (saved == null) return;
    final at = resumePosition(saved.positionMs, saved.durationMs);
    if (at == null) return;
    // Seeking only works once mpv knows the duration.
    try {
      await _player.stream.duration
          .firstWhere((d) => d > Duration.zero)
          .timeout(const Duration(seconds: 15));
      if (mounted && item.id == _item.id) await _player.seek(at);
    } on TimeoutException {
      // Stream never reported a duration; play from the start.
    }
  }

  void _onCompleted() {
    final dur = _player.state.duration;
    final pos = _player.state.position;
    // A cut connection also raises "completed"; only the real end counts.
    if (!reachedEnd(pos.inMilliseconds, dur.inMilliseconds)) return;
    _markFinished();
    final next = widget.nextOf?.call(_index);
    if (next != null && mounted) setState(() => _upNext = next);
  }

  /// Records the current item as fully watched and stops further saves.
  void _markFinished() {
    final dur = _player.state.duration;
    if (dur > Duration.zero) {
      _db.saveProgress(
        _item.type,
        _item.id,
        dur.inMilliseconds,
        dur.inMilliseconds,
        DateTime.now(),
      );
    }
    _finished = true;
  }

  /// Offers "next episode" during the last minute (once per item).
  void _onPosition(Duration pos) {
    final next = widget.nextOf?.call(_index);
    final show =
        next != null &&
        _upNext == null &&
        !_bannerDismissed &&
        !_finished &&
        nearEnd(pos.inMilliseconds, _player.state.duration.inMilliseconds);
    if (show != _showBanner && mounted) setState(() => _showBanner = show);
  }

  /// Switches to another item of the queue, keeping the progress of the one
  /// being left.
  void _goTo(int index) {
    _save();
    setState(() {
      _index = index;
      _upNext = null;
      _showBanner = false;
    });
    _cursor.value = index;
    _openCurrent();
  }

  void _advance() {
    final next = _upNext;
    if (next != null) _goTo(next);
  }

  void _save() {
    if (_finished) return;
    final pos = _player.state.position;
    final dur = _player.state.duration;
    if (dur <= Duration.zero) return;
    _db.saveProgress(
      _item.type,
      _item.id,
      pos.inMilliseconds,
      dur.inMilliseconds,
      DateTime.now(),
    );
  }

  void _seekBy(Duration delta) {
    final target = _player.state.position + delta;
    _player.seek(target < Duration.zero ? Duration.zero : target);
  }

  @override
  void dispose() {
    _saver?.cancel();
    _completedSub?.cancel();
    _positionSub?.cancel();
    _cursor.dispose();
    _save();
    _player.dispose();
    super.dispose();
  }

  MaterialDesktopVideoControlsThemeData _controls() {
    Widget step(String tip, IconData icon, Duration d) => Tooltip(
      message: tip,
      child: MaterialDesktopCustomButton(
        icon: Icon(icon),
        onPressed: () => _seekBy(d),
      ),
    );
    // The controls theme is not rebuilt when state changes, so anything that
    // depends on the current item listens to [_cursor] itself.
    Widget episodeButton(
      String tip,
      IconData icon,
      int? Function(int index)? of,
    ) => ValueListenableBuilder<int>(
      valueListenable: _cursor,
      builder: (_, i, _) {
        final target = of?.call(i);
        return Tooltip(
          message: tip,
          child: MaterialDesktopCustomButton(
            icon: Icon(
              icon,
              color: target == null
                  ? Tokens.textDim.withValues(alpha: 0.4)
                  : null,
            ),
            onPressed: () {
              if (target != null) _goTo(target);
            },
          ),
        );
      },
    );
    final hasEpisodes = widget.nextOf != null || widget.previousOf != null;
    return MaterialDesktopVideoControlsThemeData(
      automaticallyImplySkipNextButton: false,
      automaticallyImplySkipPreviousButton: false,
      buttonBarButtonColor: Tokens.text,
      keyboardShortcuts: {
        const SingleActivator(LogicalKeyboardKey.space): _player.playOrPause,
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () =>
            _seekBy(-_seekStep),
        const SingleActivator(LogicalKeyboardKey.arrowRight): () =>
            _seekBy(_seekStep),
        const SingleActivator(LogicalKeyboardKey.arrowUp): () =>
            _player.setVolume((_player.state.volume + 5).clamp(0, 100)),
        const SingleActivator(LogicalKeyboardKey.arrowDown): () =>
            _player.setVolume((_player.state.volume - 5).clamp(0, 100)),
        const SingleActivator(LogicalKeyboardKey.keyM): () =>
            _player.setVolume(_player.state.volume == 0 ? 100 : 0),
        const SingleActivator(LogicalKeyboardKey.escape): () =>
            Navigator.of(context).pop(),
        if (hasEpisodes) ...{
          const SingleActivator(LogicalKeyboardKey.keyN): () {
            final t = widget.nextOf?.call(_cursor.value);
            if (t != null) _goTo(t);
          },
          const SingleActivator(LogicalKeyboardKey.keyP): () {
            final t = widget.previousOf?.call(_cursor.value);
            if (t != null) _goTo(t);
          },
        },
      },
      topButtonBar: [
        Tooltip(
          message: 'Voltar (Esc)',
          child: MaterialDesktopCustomButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        const SizedBox(width: 8),
        if (_item.type == 'movie')
          FavoriteStar(type: _item.type, id: _item.id, show: true),
        Flexible(
          child: ValueListenableBuilder<int>(
            valueListenable: _cursor,
            builder: (_, i, _) => Text(
              parseMovieTitle(widget.queue[i].name).title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
      bottomButtonBar: [
        if (hasEpisodes)
          episodeButton(
            'Episódio anterior (P)',
            Icons.skip_previous,
            widget.previousOf,
          ),
        step('Voltar 10 s (←)', Icons.replay_10, -_seekStep),
        const MaterialDesktopPlayOrPauseButton(),
        step('Avançar 10 s (→)', Icons.forward_10, _seekStep),
        if (hasEpisodes)
          episodeButton('Próximo episódio (N)', Icons.skip_next, widget.nextOf),
        const MaterialDesktopVolumeButton(),
        const MaterialDesktopPositionIndicator(),
        const Spacer(),
        const MaterialDesktopFullscreenButton(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) return;
      _save();
      ref
        ..invalidate(continueWatchingProvider)
        ..invalidate(continueSeriesProvider);
    },
    child: Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        child: Stack(
          children: [
            Positioned.fill(
              child: MaterialDesktopVideoControlsTheme(
                normal: _controls(),
                fullscreen: _controls(),
                child: Video(
                  controller: _video,
                  controls: MaterialDesktopVideoControls,
                ),
              ),
            ),
            if (_showBanner && _upNext == null)
              NextEpisodeBanner(
                title: widget.queue[widget.nextOf!(_index)!].name,
                onSkip: () {
                  _markFinished(); // skipping from the banner means "seen"
                  _goTo(widget.nextOf!(_index)!);
                },
                onDismiss: () => setState(() {
                  _showBanner = false;
                  _bannerDismissed = true;
                }),
              ),
            if (_upNext != null)
              AutoAdvanceOverlay(
                key: ValueKey(_upNext),
                title: widget.queue[_upNext!].name,
                onNow: _advance,
                onCancel: () => setState(() => _upNext = null),
              ),
          ],
        ),
      ),
    ),
  );
}
