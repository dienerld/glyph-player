const _minResumeMs = 30000;
const _finishedFraction = 0.95;

/// Where to resume playback, or null to start from the beginning.
Duration? resumePosition(int positionMs, int durationMs) {
  if (positionMs < _minResumeMs) {
    return null;
  }
  if (durationMs > 0 && positionMs / durationMs > _finishedFraction)
    return null;
  return Duration(milliseconds: positionMs);
}
