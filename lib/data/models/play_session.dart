/// A finished session, as stored and as shown on the stats screen.
class PlaySession {
  const PlaySession({
    required this.id,
    required this.catId,
    required this.gameId,
    required this.startedAt,
    required this.duration,
    required this.contacts,
    required this.directHits,
    required this.score,
    this.clipPaths = const [],
  });

  final String id;
  final String catId;
  final String gameId;
  final DateTime startedAt;
  final Duration duration;
  final int contacts;
  final int directHits;
  final double score;
  final List<String> clipPaths;

  double get accuracy => contacts == 0 ? 0 : directHits / contacts;

  /// Engagement is what an owner actually wants to know — did the cat care?
  /// Contacts per minute answers that better than score does.
  double get contactsPerMinute =>
      duration.inSeconds == 0 ? 0 : contacts / (duration.inSeconds / 60);
}
