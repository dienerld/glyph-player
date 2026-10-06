import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';

/// A remote thumbnail served from the on-disk [ThumbCache]. Shows [fallback]
/// while loading and when there is no url or the download failed.
class CachedThumb extends ConsumerStatefulWidget {
  const CachedThumb({
    super.key,
    required this.url,
    required this.fallback,
    this.fit = BoxFit.cover,
    this.cacheWidth,
  });
  final String url;
  final Widget fallback;
  final BoxFit fit;
  final int? cacheWidth;

  @override
  ConsumerState<CachedThumb> createState() => _CachedThumbState();
}

class _CachedThumbState extends ConsumerState<CachedThumb> {
  Future<File?>? _file;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CachedThumb old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) _load();
  }

  void _load() {
    _file = widget.url.isEmpty
        ? null
        : ref.read(thumbCacheProvider).get(widget.url);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.url.isEmpty) return widget.fallback;
    // Already saved earlier in this session: no flash of the fallback.
    final known = ref.read(thumbCacheProvider).peek(widget.url);
    return FutureBuilder<File?>(
      future: _file,
      initialData: known,
      builder: (_, snap) {
        final f = snap.data;
        if (f == null) return widget.fallback;
        return Image.file(
          f,
          fit: widget.fit,
          cacheWidth: widget.cacheWidth,
          errorBuilder: (_, _, _) => widget.fallback,
        );
      },
    );
  }
}
