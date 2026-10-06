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

const _seekStep = Duration(seconds: 10);
const _saveEvery = Duration(seconds: 10);

class MoviePlayerPage extends ConsumerStatefulWidget {
  const MoviePlayerPage({super.key, required this.movie});
  final Channel movie;

  @override
  ConsumerState<MoviePlayerPage> createState() => _MoviePlayerPageState();
}

class _MoviePlayerPageState extends ConsumerState<MoviePlayerPage> {
  final Player _player = Player();
  late final VideoController _video = VideoController(_player);
  late final Db _db = ref.read(dbProvider);
  Timer? _saver;

  @override
  void initState() {
    super.initState();
    _start();
    _saver = Timer.periodic(_saveEvery, (_) => _save());
  }

  Future<void> _start() async {
    final m = widget.movie;
    final saved = _db.progressOf(m.type, m.id);
    await _player.open(Media(m.url));
    if (saved == null) return;
    final at = resumePosition(saved.positionMs, saved.durationMs);
    if (at == null) return;
    // Seeking only works once mpv knows the duration.
    try {
      await _player.stream.duration
          .firstWhere((d) => d > Duration.zero)
          .timeout(const Duration(seconds: 15));
      if (mounted) await _player.seek(at);
    } on TimeoutException {
      // Stream never reported a duration; play from the start.
    }
  }

  void _save() {
    final pos = _player.state.position;
    final dur = _player.state.duration;
    if (dur <= Duration.zero) return;
    _db.saveProgress(
      widget.movie.type,
      widget.movie.id,
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
            parseMovieTitle(widget.movie.name).title,
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
      ref.invalidate(continueWatchingProvider);
    },
    child: Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        autofocus: true,
        child: MaterialDesktopVideoControlsTheme(
          normal: _controls(),
          fullscreen: _controls(),
          child: Video(
            controller: _video,
            controls: MaterialDesktopVideoControls,
          ),
        ),
      ),
    ),
  );
}
