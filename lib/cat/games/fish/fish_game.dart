import 'dart:math' as math;
import 'dart:ui';

import '../../engine/cat_game.dart';
import '../../engine/paw_input.dart';
import 'fish.dart';

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

  @override
  String get id => gameId;

  @override
  String get displayName => 'Fish pond';

  @override
  set difficulty(double value) {
    _difficulty = value.clamp(0.0, 1.0).toDouble();
    for (final fish in _fish) {
      fish.speed = _speed;
      fish.radius = _radius;
    }
  }

  // Slower and bigger when the cat is struggling.
  double get _speed => 40 + _difficulty * 90;
  double get _radius => 56 - _difficulty * 16;
  int get _count => 3 + (_difficulty * 3).round();

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
    _fish.firstWhere((f) => f.id == target.id).catchIt();
    // TODO(audio): splash sample, pitched up slightly for direct hits.
  }

  void _seed(Size screen) {
    _fish
      ..clear()
      ..addAll([
        for (var i = 0; i < _count; i++)
          Fish(
            id: i,
            position: Offset(
              _random.nextDouble() * screen.width,
              _random.nextDouble() * screen.height,
            ),
            speed: _speed,
            radius: _radius,
            random: _random,
          ),
      ]);
    _seeded = true;
  }

  @override
  void reset() {
    _fish.clear();
    _seeded = false;
  }
}
