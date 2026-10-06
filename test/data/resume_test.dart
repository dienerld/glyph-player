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
}
