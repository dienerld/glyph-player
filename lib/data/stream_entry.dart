enum StreamType { live, movie, series }

class StreamEntry {
  const StreamEntry({
    required this.type,
    required this.id,
    required this.name,
    required this.group,
    required this.logo,
    required this.url,
  });

  final StreamType type;
  final String id;
  final String name;
  final String group;
  final String logo;
  final String url;
}
