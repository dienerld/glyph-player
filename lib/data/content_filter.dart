/// Words that mark a group as adult; matched case-insensitively anywhere in
/// the group name (also by the SQL filter in `Db`).
const adultGroupWords = ['adult', 'hentai', 'xxx'];

final _adult = RegExp(adultGroupWords.join('|'), caseSensitive: false);

/// Groups the provider labels as adult content (hidden unless the user opts in).
bool isAdultGroup(String group) => _adult.hasMatch(group);
