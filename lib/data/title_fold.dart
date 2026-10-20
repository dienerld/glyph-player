// Accented Latin letters and their base letter, exactly as SQLite's FTS5
// `remove_diacritics 1` folds them (read from SQLite itself, U+00C0 to
// U+024F). Letters it keeps, such as ø, ł and đ, are left out on purpose.
const _from =
    'ÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝàáâãäåçèéêëìíîïñòóôõöùúûüýÿĀāĂăĄąĆćĈĉĊċČčĎď'
    'ĒēĔĕĖėĘęĚěĜĝĞğĠġĢģĤĥĨĩĪīĬĭĮįİĴĵĶķĹĺĻļĽľŃńŅņŇňŌōŎŏŐőŔŕŖŗŘřŚśŜŝŞşŠšŢţ'
    'ŤťŨũŪūŬŭŮůŰűŲųŴŵŶŷŸŹźŻżŽžſƠơƯưǍǎǏǐǑǒǓǔǕǖǗǘǙǚǛǜǞǟǦǧǨǩǪǫǬǭǰǴǵǸǹǺǻȀȁȂȃ'
    'ȄȅȆȇȈȉȊȋȌȍȎȏȐȑȒȓȔȕȖȗȘșȚțȞȟȦȧȨȩȪȫȬȭȮȯȰȱȲȳ';
const _to =
    'aaaaaaceeeeiiiinooooouuuuyaaaaaaceeeeiiiinooooouuuuyyaaaaaaccccccccdd'
    'eeeeeeeeeegggggggghhiiiiiiiiijjkkllllllnnnnnnoooooorrrrrrsssssssstt'
    'ttuuuuuuuuuuuuwwyyyzzzzzzsoouuaaiioouuuuuuuuuuaaggkkoooojggnnaaaa'
    'aaeeeeiiiioooorrrruuuusstthhaaeeooooooooyy';

final Map<int, int> _fold = {
  for (var i = 0; i < _from.length; i++) _from.codeUnitAt(i): _to.codeUnitAt(i),
};

/// [text] trimmed, without accents and in lower case: the form a title
/// prefix search compares (`Ação` and `acao` both give `acao`).
String foldTitle(String text) => String.fromCharCodes(
  text.trim().codeUnits.map((c) => _fold[c] ?? c),
).toLowerCase();
