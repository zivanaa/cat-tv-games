/// One cat. Multi-cat households are the norm among people who would buy this,
/// and per-cat stats are most of the reason the owner opens the app at all.
class CatProfile {
  const CatProfile({
    required this.id,
    required this.name,
    this.photoPath,
    this.birthday,
    this.difficulty = 0.4,
    this.generosity = 0.35,
  });

  final String id;
  final String name;
  final String? photoPath;
  final DateTime? birthday;

  /// Persisted across sessions so a cat does not restart at baseline every time.
  final double difficulty;

  /// Per-cat assist level. Kittens and senior cats need more.
  final double generosity;

  CatProfile copyWith({double? difficulty, double? generosity}) => CatProfile(
        id: id,
        name: name,
        photoPath: photoPath,
        birthday: birthday,
        difficulty: difficulty ?? this.difficulty,
        generosity: generosity ?? this.generosity,
      );
}
