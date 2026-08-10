import 'dart:math' as math;
import 'dart:ui';

import 'package:cat_tv_games/cat/engine/paw_input.dart';
import 'package:cat_tv_games/cat/games/laser/laser_game.dart';
import 'package:flutter_test/flutter_test.dart';

/// The laser mode exists to satisfy one sentence from game_catalog.dart: a dot
/// that never lets the cat win instantly, but always lets it win eventually.
///
/// Both halves are failure modes rather than preferences. A dot that can be
/// taken on the first swipe is not a chase and the mode is pointless. A dot
/// that can outrun a cat forever produces the session that ends on zero, which
/// docs/NEXT_STEPS.md names as the most likely way this product fails.
void main() {
  const screen = Size(800, 400);
  const step = 1 / 40;

  LaserGame started({double difficulty = 0.4, int seed = 3}) {
    final game = LaserGame(random: math.Random(seed))..difficulty = difficulty;
    game.update(step, screen);
    return game;
  }

  /// A paw landing on wherever the dot currently is.
  PawHit swipeAt(LaserGame game) {
    final target = game.targets.single;
    return PawHit(tier: HitTier.direct, target: target, point: target.center);
  }

  /// Bats at the dot every [everyMs], for [seconds], and reports the catches.
  int chase(LaserGame game, {int seconds = 60, int everyMs = 400}) {
    var elapsed = 0.0;
    var nextSwipe = 0.0;
    for (var frame = 0; frame < 40 * seconds; frame++) {
      game.update(step, screen);
      elapsed += step;
      if (elapsed >= nextSwipe) {
        nextSwipe = elapsed + everyMs / 1000;
        if (game.targets.single.hittable) game.onHit(swipeAt(game));
      }
    }
    return game.caught;
  }

  test('the first swipe never takes it', () {
    for (var d = 0.0; d <= 1.0; d += 0.25) {
      final game = started(difficulty: d);
      game.onHit(swipeAt(game));
      expect(
        game.caught,
        0,
        reason: 'a dot caught on the first contact is not a chase (d=$d)',
      );
    }
  });

  test('it is always caught eventually, at every difficulty', () {
    // The half that matters most. A cat that keeps swiping has to win.
    for (var d = 0.0; d <= 1.0; d += 0.25) {
      final game = started(difficulty: d);
      expect(
        chase(game, seconds: 60),
        greaterThan(0),
        reason: 'a session that never scores is the way this product dies '
            '(d=$d)',
      );
    }
  });

  test('a harder dot costs more swipes than an easier one', () {
    final easy = started(difficulty: 0);
    final hard = started(difficulty: 1);

    expect(easy.escapesNeeded, lessThan(hard.escapesNeeded));
    expect(easy.escapesNeeded, greaterThan(0), reason: 'never instant');

    expect(
      chase(easy, seconds: 60),
      greaterThan(chase(hard, seconds: 60)),
      reason: 'the ladder has to be felt here too',
    );
  });

  test('it runs away from the paw, not toward it', () {
    final game = started();
    final before = game.targets.single.center;

    // A paw landing to its left should send it right.
    game.onHit(
      PawHit(
        tier: HitTier.direct,
        target: game.targets.single,
        point: before.translate(-40, 0),
      ),
    );
    for (var i = 0; i < 8; i++) {
      game.update(step, screen);
    }

    expect(
      game.targets.single.center.dx,
      greaterThan(before.dx),
      reason: 'it fled toward the paw',
    );
  });

  test('it goes dark when caught, and cannot be hit while it is', () {
    final game = started(difficulty: 0);
    while (!game.isTiring) {
      game.onHit(swipeAt(game));
      game.update(step, screen);
    }
    game.onHit(swipeAt(game));

    expect(game.caught, 1);
    expect(game.targets.single.hittable, isFalse);
    expect(game.view.phase, LaserPhase.out);

    // And it comes back.
    for (var i = 0; i < 40 * 2; i++) {
      game.update(step, screen);
    }
    expect(game.targets.single.hittable, isTrue);
  });

  test('a landing dead on the dot still sends it somewhere', () {
    // Normalising a zero-length vector is how this produces NaN and puts the
    // dot off the screen for the rest of the session.
    final game = started();
    final at = game.targets.single.center;
    game.onHit(
      PawHit(tier: HitTier.direct, target: game.targets.single, point: at),
    );
    for (var i = 0; i < 20; i++) {
      game.update(step, screen);
    }

    final now = game.targets.single.center;
    expect(now.dx.isFinite, isTrue);
    expect(now.dy.isFinite, isTrue);
  });

  test('the dot stays on the screen', () {
    final game = started(difficulty: 1);
    for (var frame = 0; frame < 40 * 120; frame++) {
      game.update(step, screen);
      if (frame % 17 == 0 && game.targets.single.hittable) {
        game.onHit(swipeAt(game));
      }
      final at = game.targets.single.center;
      expect(at.dx, inInclusiveRange(0, screen.width));
      expect(at.dy, inInclusiveRange(0, screen.height));
    }
  });

  test('the dot is never still', () {
    // Same rule the pond is held to: a target that stops moving is a target a
    // cat stops watching. The rests are real, so this is what makes them
    // twitch rather than freeze.
    final game = started();
    var stillest = 0;
    var run = 0;
    var previous = game.targets.single.center;

    for (var frame = 0; frame < 40 * 60; frame++) {
      game.update(step, screen);
      final at = game.targets.single.center;
      if (game.view.phase == LaserPhase.out) {
        run = 0;
      } else {
        run = (at - previous).distance < 0.15 ? run + 1 : 0;
        stillest = math.max(stillest, run);
      }
      previous = at;
    }

    expect(stillest, lessThan(40), reason: 'a second of nothing is too long');
  });

  test('a cat that wanders off does not come back to a free catch', () {
    final game = started(difficulty: 1);
    game.onHit(swipeAt(game));
    game.onHit(swipeAt(game));

    // Long enough for the pursuit to be forgotten several times over.
    for (var frame = 0; frame < 40 * 40; frame++) {
      game.update(step, screen);
    }

    expect(game.isTiring, isFalse);
    game.onHit(swipeAt(game));
    expect(game.caught, 0, reason: 'the escapes should have decayed');
  });

  test('reset puts it back to an untouched dot', () {
    final game = started(difficulty: 0);
    chase(game, seconds: 20);
    expect(game.caught, greaterThan(0));

    game.reset();
    expect(game.caught, 0);
    expect(game.isTiring, isFalse);
  });
}
