import 'package:flutter/material.dart';

import '../../ui/theme.dart';

/// Tinted tile for a section (movie category, series distributor). The tint is
/// a stable hue from [tintKey] so a grid of them is scannable without artwork.
class SectionTile extends StatefulWidget {
  const SectionTile({
    super.key,
    required this.label,
    required this.countText,
    required this.tintKey,
    required this.onTap,
  });
  final String label, countText, tintKey;
  final VoidCallback onTap;

  @override
  State<SectionTile> createState() => _SectionTileState();
}

class _SectionTileState extends State<SectionTile> {
  bool _active = false;

  Color get _tint {
    final hue = widget.tintKey.codeUnits.fold<int>(7, (h, c) => h * 31 + c);
    return HSLColor.fromAHSL(
      1,
      (hue.abs() % 360).toDouble(),
      0.32,
      0.2,
    ).toColor();
  }

  @override
  Widget build(BuildContext context) => FocusableActionDetector(
    onShowFocusHighlight: (v) => setState(() => _active = v),
    onShowHoverHighlight: (v) => setState(() => _active = v),
    actions: {
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          widget.onTap();
          return null;
        },
      ),
    },
    child: GestureDetector(
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: Tokens.hover,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _tint,
          borderRadius: BorderRadius.circular(Tokens.radius),
          border: Border.all(
            color: _active ? Tokens.tally : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              widget.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: Tokens.display,
                fontSize: 20,
                height: 24 / 20,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              widget.countText,
              style: const TextStyle(color: Tokens.textDim, fontSize: 13),
            ),
          ],
        ),
      ),
    ),
  );
}
