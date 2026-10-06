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
