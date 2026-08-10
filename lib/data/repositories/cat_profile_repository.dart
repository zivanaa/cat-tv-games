import '../models/cat_profile.dart';

/// Where a cat's settings come from and go back to.
///
/// An interface rather than a direct call into storage, for the reason
/// CLAUDE.md gives: repositories hand back domain models so the database stays
/// swappable and the models stay testable. Isar arrives in Milestone 2 and
/// should be able to slot in behind this without anything above it noticing.
abstract class CatProfileRepository {
  /// The cat currently playing. One for now; the picker is Milestone 2.
  Future<CatProfile> current();

  Future<void> save(CatProfile profile);
}

/// Holds one cat in memory and forgets it when the app closes.
///
/// The wiring is the point, not the storage. Without it every session opened at
/// difficulty 0.4 no matter what the cat had already reached — a cat that spent
/// twenty minutes climbing to 0.9 yesterday started again at the bottom today,
/// and the ladder only ever meant anything inside a single sitting. CatProfile
/// has said "persisted across sessions so a cat does not restart at baseline
/// every time" since the first commit and nothing read it.
///
/// What is still missing is the persisting. Close the app and the cat is back
/// to its starting numbers. That is Milestone 2's job; this is the seam it
/// plugs into.
class InMemoryCatProfileRepository implements CatProfileRepository {
  InMemoryCatProfileRepository([CatProfile? seed])
      : _profile = seed ??
            const CatProfile(id: 'default', name: 'Cat', difficulty: 0.4);

  CatProfile _profile;

  @override
  Future<CatProfile> current() async => _profile;

  @override
  Future<void> save(CatProfile profile) async => _profile = profile;
}
