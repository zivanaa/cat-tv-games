import 'dart:math' as math;
import 'dart:ui';

import '../../engine/cat_game.dart';
import '../../engine/paw_input.dart';
import 'fish.dart';
import 'fish_species.dart';

/// The first mode, and the one to get right before building any other.
///
/// Fish are slow, large, and numerous. This is the mode that decides whether a
/// cat engages with the app at all, so it errs heavily toward the cat winning.
class FishGame implements CatGame {
  FishGame({math.Random? random}) : _random = random ?? math.Random();

  static const gameId = 'fish';

  final math.Random _random;
  final List<Fish> _fish = [];
  double _difficulty = 0.4;
  bool _seeded = false;

  /// Ids never repeat within a session. [onHit] matches a [PawTarget] back to a
  /// fish by id, and the pond gains and loses fish as difficulty moves, so
  /// index-based ids would let a fish inherit the id of one caught moments ago.
  int _nextId = 0;

  @override
  String get id => gameId;

  @override
  String get displayName => 'Fish pond';

  @override
  double get difficulty => _difficulty;

  @override
  set difficulty(double value) {
    _difficulty = value.clamp(0.0, 1.0).toDouble();
    for (final fish in _fish) {
      fish.speed = _speed;
      fish.radius = _radius * fish.species.sizeScale;
    }
  }

  // Slower and bigger when the cat is struggling.
  //
  // The spreads were narrower and a level barely registered: speed moved 40 to
  // 130 and size 56 to 40, so a step up the ladder changed the pond by a few
  // pixels per second. These are wide enough that a single step is visible
  // while the extremes stay inside what CAT_UX.md allows — 190px/s is still a
  // trackable target rather than the fast random motion that loses cats, and
  // the smallest fish is still floored to minTargetRadius for hit testing.
  double get _speed => 40 + _difficulty * 150;
  double get _radius => 60 - _difficulty * 24;

  /// Rounding puts the step boundaries at 0.125, 0.375, 0.625 and 0.875, so the
  /// pond gains a fish four times across the ladder instead of three.
  int get _count => 3 + (_difficulty * 4).round();

  /// A read-only snapshot for the render layer. Kept separate from [targets],
  /// which is the input contract and deliberately knows nothing about how a
  /// fish looks.
  List<FishView> get views => [for (final fish in _fish) fish.view];

  /// Weighted so the pond still reads as a pond rather than an aquarium
  /// catalogue. Goldfish are the texture; the rest are the reason to keep
  /// looking. Koi are rarest because a slow easy target everywhere would
  /// flatten the difficulty curve the session recorder is trying to steer.
  FishSpecies _pickSpecies() {
    final roll = _random.nextDouble();
    if (roll < 0.45) return FishSpecies.goldfish;
    if (roll < 0.72) return FishSpecies.darter;
    if (roll < 0.89) return FishSpecies.angel;
    return FishSpecies.koi;
  }

  @override
  List<PawTarget> get targets => [
        for (final fish in _fish)
          PawTarget(
            id: fish.id,
            center: fish.position,
            radius: fish.radius,
            hittable: fish.hittable,
          ),
      ];

  @override
  void update(double dt, Size screen) {
    if (!_seeded) _seed(screen);
    _reconcileCount(screen);
    for (final fish in _fish) {
      fish.update(dt, screen);
    }
  }

  @override
  void onHit(PawHit hit) {
    final target = hit.target;
    if (target == null) return;
    // A generous hit still catches the fish. The cat must never be able to tell
    // that it missed, or the feedback loop that keeps it playing breaks.
    //
    // The lookup tolerates a miss instead of throwing: a hit resolves against a
    // snapshot of the targets, and reset() or a difficulty drop can retire that
    // fish before this runs. Losing one splash is nothing; throwing here kills
    // the session on a surface with no human watching and no error UI.
    for (final fish in _fish) {
      if (fish.id == target.id) {
        fish.catchIt();
        break;
      }
    }
    // TODO(audio): splash sample, pitched up slightly for direct hits.
  }

  /// Difficulty decides how many fish there are, not only how they swim, so the
  /// pond has to be resized when it moves. This lives in [update] rather than
  /// the setter because a new fish needs somewhere to spawn and only the caller
  /// knows the screen.
  ///
  /// Growing is immediate — an appearing fish looks like an ordinary respawn.
  /// Shrinking only ever retires a fish that is already caught and off screen.
  /// Deleting one mid-swim would blink a target out from under a watching cat,
  /// which is the tracking break CAT_UX.md rules out.
  void _reconcileCount(Size screen) {
    while (_fish.length < _count) {
      _fish.add(_spawn(screen));
    }
    var surplus = _fish.length - _count;
    if (surplus <= 0) return;
    _fish.removeWhere((fish) {
      if (surplus == 0 || !fish.isCaught) return false;
      surplus--;
      return true;
    });
  }

  Fish _spawn(Size screen) {
    final species = _pickSpecies();
    final radius = _radius * species.sizeScale;
    return Fish(
      id: _nextId++,
      species: species,
      position: randomSpawn(screen, radius, _random),
      speed: _speed,
      radius: radius,
      random: _random,
    );
  }

  void _seed(Size screen) {
    _fish
      ..clear()
      ..addAll([for (var i = 0; i < _count; i++) _spawn(screen)]);
    _seeded = true;
  }

  @override
  void reset() {
    _fish.clear();
    _seeded = false;
  }
}
