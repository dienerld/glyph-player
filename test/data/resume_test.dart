import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/resume.dart';

void main() {
  test('resumes in the middle of a movie', () {
    expect(resumePosition(600000, 7200000), const Duration(minutes: 10));
  });

  test('does not resume in the first 30 seconds', () {
    expect(resumePosition(29000, 7200000), isNull);
  });

  test('does not resume when more than 95% was watched', () {
    expect(resumePosition(7000000, 7200000), isNull);
  });

  test('unknown duration still resumes past 30 seconds', () {
    expect(resumePosition(120000, 0), const Duration(minutes: 2));
  });

  test('isFinished is true only above 95% with a known duration', () {
    expect(isFinished(960, 1000), isTrue);
    expect(isFinished(950, 1000), isFalse);
    expect(isFinished(960, 0), isFalse);
  });

  test(
    'reachedEnd is true near the real end, false for a dropped connection',
    () {
      expect(reachedEnd(2700000, 2700000), isTrue); // played to the end
      expect(reachedEnd(2690000, 2700000), isTrue); // within the last 30 s
      expect(reachedEnd(1200000, 2700000), isFalse); // cut at minute 20 of 45
      expect(reachedEnd(0, 0), isFalse); // unknown duration
    },
  );

  test('nearEnd opens the "next episode" window in the last minute', () {
    expect(nearEnd(2640000, 2700000), isTrue); // exactly 60 s left
    expect(nearEnd(2699000, 2700000), isTrue);
    expect(nearEnd(2600000, 2700000), isFalse); // 100 s left
    expect(nearEnd(0, 0), isFalse); // unknown duration
    expect(nearEnd(30000, 45000), isTrue); // very short item
  });
}
