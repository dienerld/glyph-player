import 'package:flutter_test/flutter_test.dart';
import 'package:glyph_player/data/title_fold.dart';
import 'package:sqlite3/sqlite3.dart';

void main() {
  test('trims, lowercases and strips Portuguese accents', () {
    expect(foldTitle('  Ação Máxima '), 'acao maxima');
    expect(
      foldTitle('ÁÀÂÃÄ ÉÊË ÍÎÏ ÓÔÕÖ ÚÛÜ Çç Ññ'),
      'aaaaa eee iii oooo uuu cc nn',
    );
  });

  test('folds exactly the letters SQLite trigram remove_diacritics folds', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.close);
    db.execute(
      "CREATE VIRTUAL TABLE t USING fts5(x, "
      "tokenize='trigram remove_diacritics 1')",
    );
    final letters = [for (var b = 0x61; b <= 0x7a; b++) String.fromCharCode(b)];
    for (var c = 0xC0; c <= 0x24F; c++) {
      final ch = String.fromCharCode(c);
      db.execute('DELETE FROM t');
      db.execute('INSERT INTO t(x) VALUES(?)', ['qq$ch']);
      final sqliteBase = letters.where(
        (l) =>
            db.select('SELECT 1 FROM t WHERE t MATCH ?', ['"qq$l"']).isNotEmpty,
      );
      final folded = foldTitle(ch);
      if (sqliteBase.isEmpty) {
        expect(letters, isNot(contains(folded)), reason: ch);
      } else {
        expect(folded, sqliteBase.first, reason: ch);
      }
    }
  });
}
