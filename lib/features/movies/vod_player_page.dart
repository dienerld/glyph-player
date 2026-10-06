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
  });
  final List<Channel> queue;
  final int index;
  final int? Function(int index)? nextOf;

  @override
  ConsumerState<VodPlayerPage> createState() => _VodPlayerPageState();
}

class _VodPlayerPageState extends ConsumerState<VodPlayerPage> {
  final Player _player = Player();
  late final VideoController _video = VideoController(_player);
  late final Db _db = ref.read(dbProvider);
  late int _index = widget.index;
  int? _upNext;

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
    _openCurrent();
    _saver = Timer.periodic(_saveEvery, (_) => _save());
  }

  Future<void> _openCurrent() async {
    final item = _item;
    _finished = false;
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
    final next = widget.nextOf?.call(_index);
    if (next != null && mounted) setState(() => _upNext = next);
  }

  void _advance() {
    final next = _upNext;
    if (next == null) return;
    setState(() {
      _index = next;
      _upNext = null;
    });
    _openCurrent();
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
        Flexible(
          child: Text(
            parseMovieTitle(_item.name).title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
      bottomButtonBar: [
        step('Voltar 10 s (←)', Icons.replay_10, -_seekStep),
        const MaterialDesktopPlayOrPauseButton(),
        step('Avançar 10 s (→)', Icons.forward_10, _seekStep),
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
