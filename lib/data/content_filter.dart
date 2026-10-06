final _adult = RegExp(r'adult|hentai|xxx', caseSensitive: false);

/// Groups the provider labels as adult content (hidden unless the user opts in).
bool isAdultGroup(String group) => _adult.hasMatch(group);
