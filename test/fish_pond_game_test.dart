import 'dart:math' as math;
import 'dart:ui';

import 'package:cat_tv_games/cat/engine/paw_input.dart';
import 'package:cat_tv_games/cat/render/fish_pond_game.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

/// The render layer is not supposed to decide anything, but it is the piece
/// that wires a screen touch to [PawInput] and [PawInput] to the pond. That
/// wiring is worth pinning: if it breaks, every touch silently becomes a miss
/// and the failure looks exactly like a cat that is not interested.
void main() {
  const screen = Size(800, 400);
  final now = DateTime(2026);

  FishPondGame pond({int seed = 2}) {
    final game = FishPondGame(random: math.Random(seed));
    game.onGameResize(Vector2(screen.width, screen.height));
    game.update(1 / 40);
    return game;
  }

  test('a touch on a fish catches that fish', () {
    final game = pond();
    final fish = game.rules.targets.first;

    final hit = game.contact(fish.center, now);

    expect(hit.tier, HitTier.direct);
    expect(hit.target?.id, fish.id);
    final after = game.rules.targets.firstWhere((t) => t.id == fish.id);
    expect(after.hittable, isFalse, reason: 'the fish should now be caught');
  });

  test('a touch that visibly misses still scores', () {
    // The whole reason PawInput exists. 90px from the centre of a fish drawn at
    // ~25px is a clear miss to a human eye and still has to count, or a cat
    // plays for five minutes and the owner reads a score of zero.
    final game = pond();
    final fish = game.rules.targets.first;

    final hit = game.contact(fish.center + const Offset(90, 0), now);

    expect(hit.scored, isTrue);
    expect(hit.tier, isNot(HitTier.miss));
  });

  test('a touch in empty water with no fish anywhere near it does not score',
      () {
    final game = pond();
    // Far corner, with the generous tier switched off so the assist cannot
    // rescue it. Without this the surface would score literally every contact
    // and the accuracy stat would be meaningless.
    game.input.config = const PawInputConfig(generosity: 0);

    var scored = false;
    for (final target in game.rules.targets) {
      if ((target.center - Offset.zero).distance < 200) scored = true;
    }

    final hit = game.contact(Offset.zero, now);
    if (!scored) {
      expect(hit.tier, HitTier.miss);
    }
  });

  test('the pond is sized from the surface it is drawn on', () {
    final game = pond();
    for (final target in game.rules.targets) {
      expect(target.center.dx, inInclusiveRange(0, screen.width));
      expect(target.center.dy, inInclusiveRange(0, screen.height));
    }
  });
}
