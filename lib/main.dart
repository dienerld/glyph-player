import 'dart:io';
import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const _Spike());
}

class _Spike extends StatefulWidget {
  const _Spike();
  @override
  State<_Spike> createState() => _SpikeState();
}

class _SpikeState extends State<_Spike> {
  final player = Player();
  late final controller = VideoController(player);

  @override
  void initState() {
    super.initState();
    player.stream.videoParams.listen((p) => stdout.writeln('SPIKE videoParams: ${p.w}x${p.h}'));
    player.stream.error.listen((e) => stdout.writeln('SPIKE error: $e'));
    player.open(Media(Platform.environment['GLYPH_TEST_URL']!));
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      MaterialApp(home: Scaffold(body: Video(controller: controller)));
}
