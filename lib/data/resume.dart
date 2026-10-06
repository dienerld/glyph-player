const _minResumeMs = 30000;
const _finishedFraction = 0.95;

/// More than 95% watched, with a known duration.
bool isFinished(int positionMs, int durationMs) =>
    durationMs > 0 && positionMs / durationMs > _finishedFraction;

/// Where to resume playback, or null to start from the beginning.
Duration? resumePosition(int positionMs, int durationMs) {
  if (positionMs < _minResumeMs || isFinished(positionMs, durationMs)) {
    return null;
  }
  return Duration(milliseconds: positionMs);
}

const _endWindowMs = 30000;

/// True only when playback really reached the end of the item. mpv also raises
/// its end-of-file flag when a stream is cut, which must not count as "watched".
bool reachedEnd(int positionMs, int durationMs) =>
    durationMs > 0 &&
    (isFinished(positionMs, durationMs) ||
        durationMs - positionMs <= _endWindowMs);

const _nextWindowMs = 60000;

/// Last minute of an item: when the "next episode" banner is offered.
bool nearEnd(int positionMs, int durationMs) =>
    durationMs > 0 && durationMs - positionMs <= _nextWindowMs;
