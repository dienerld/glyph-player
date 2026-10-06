import 'database.dart';
import 'resume.dart';

/// First later index whose (season, episode) differs from the current one, so
/// duplicate rows of the same episode are skipped. Null on the last episode.
int? nextIndex(List<Episode> eps, int current) {
  final cur = eps[current];
  for (var i = current + 1; i < eps.length; i++) {
    if (eps[i].season != cur.season || eps[i].episode != cur.episode) return i;
  }
  return null;
}

/// Episode to open for "Continue": the last watched one, or the next when it
/// was finished (and there is a next).
int continueIndex(List<Episode> eps, int lastIndex, Progress progress) =>
    isFinished(progress.positionMs, progress.durationMs)
    ? (nextIndex(eps, lastIndex) ?? lastIndex)
    : lastIndex;
