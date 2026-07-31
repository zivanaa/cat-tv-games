import 'dart:math' as math;
import 'dart:ui';

import 'package:cat_tv_games/cat/engine/paw_input.dart';
import 'package:cat_tv_games/cat/games/fish/fish.dart';
import 'package:cat_tv_games/cat/games/fish/fish_game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const screen = Size(800, 400);

  /// One frame at the 40fps the cat surface is capped to.
  const step = 1 / 40;

  PawHit hitOn(PawTarget target) =>
      PawHit(tier: HitTier.direct, target: target, point: target.center);

  test('no fish spends more than a bounce flattened against an edge', () {
    // Regression guard, and the reason this file exists.
    //
    // Two defects pressed fish into the border, and the second did nearly all
    // of the damage:
    //
    // 1. The bounce reflected the bare heading while the fish actually
    //    travelled heading + wobble, so the reflected course could still point
    //    into the wall and be clamped again on the next frame.
    // 2. _respawn drew from [0, extent] when the legal band is
    //    [radius, extent - radius], so roughly a fifth of respawns put the fish
    //    partly off screen. The bounce flattened it against the edge on its
    //    first frame and it stayed there.
    //
    // Measured across 12 seeds x 60s of play: the original code held a fish on
    // an edge for up to 91 consecutive frames, over two seconds of a target
    // pinned motionless to the border — the stillness CAT_UX.md says makes a
    // cat look away. Fixing the reflection alone only brought it to 81. Both
    // together bring it to 2.
    var worst = 0;

    // Several seeds, because one pond can get lucky and never meet a wall at an
    // awkward angle.
    for (var seed = 0; seed < 12; seed++) {
      final game = FishGame(random: math.Random(seed));
      final streaks = <Object, int>{};

      // Sixty seconds of play. At 76px/s across an 800px pond that is thousands
      // of pixels of travel, so every fish meets a wall repeatedly.
      for (var frame = 0; frame < 2400; frame++) {
        game.update(step, screen);
        for (final target in game.targets) {
          final r = target.radius;
          final onEdge = target.center.dx <= r + 0.001 ||
              target.center.dx >= screen.width - r - 0.001 ||
              target.center.dy <= r + 0.001 ||
              target.center.dy >= screen.height - r - 0.001;
          final streak = onEdge ? (streaks[target.id] ?? 0) + 1 : 0;
          streaks[target.id] = streak;
          if (streak > worst) worst = streak;
        }
      }
    }

    // One frame on the edge is the bounce itself; two is a corner. Beyond that
    // a fish is being held against the border again.
    expect(worst, lessThanOrEqualTo(2));
  });

  test('a fish is never spawned partly outside the pond', () {
    // The bounce hides this one frame later, so it has to be caught at birth.
    final random = math.Random(5);
    const radius = 49.6;
    for (var i = 0; i < 500; i++) {
      final at = randomSpawn(screen, radius, random);
      expect(at.dx, greaterThanOrEqualTo(radius));
      expect(at.dx, lessThanOrEqualTo(screen.width - radius));
      expect(at.dy, greaterThanOrEqualTo(radius));
      expect(at.dy, lessThanOrEqualTo(screen.height - radius));
    }
  });

  test('a pond narrower than the fish yields a point, not a crash', () {
    expect(
      randomSpawn(const Size(40, 40), 60, math.Random(1)),
      const Offset(20, 20),
    );
  });

  test('a hit on a fish that no longer exists is ignored, not thrown', () {
    // A hit resolves against a snapshot of the targets, so the fish it names can
    // be gone by the time onHit runs. The cat surface has no error UI and no
    // human watching it, so an exception here ends the session silently.
    final game = FishGame(random: math.Random(1));
    game.update(step, screen);
    final stale = game.targets.first;

    game.reset();

    expect(() => game.onHit(hitOn(stale)), returnsNormally);
  });

  test('raising difficulty actually adds fish', () {
    // The count getter existed but only ever ran at seed time, so difficulty
    // changed how the fish swam and never how many there were.
    final game = FishGame(random: math.Random(7));
    game.update(step, screen);
    expect(game.targets.length, 4, reason: 'difficulty starts at 0.4');

    game.difficulty = 1.0;
    game.update(step, screen);
    expect(game.targets.length, 6);
  });

  test('shrinking the pond never removes a fish mid-swim', () {
    final game = FishGame(random: math.Random(7));
    game.difficulty = 1.0;
    game.update(step, screen);
    expect(game.targets.length, 6);

    // Wants three, but every fish is on screen and being tracked.
    game.difficulty = 0.0;
    game.update(step, screen);
    expect(game.targets.length, 6);
  });

  test('the pond shrinks by retiring fish that are already caught', () {
    final game = FishGame(random: math.Random(7));
    game.difficulty = 1.0;
    game.update(step, screen);

    final caught = game.targets.first;
    game.onHit(hitOn(caught));
    game.difficulty = 0.0;
    game.update(step, screen);

    expect(game.targets.length, 5);
    expect(game.targets.any((t) => t.id == caught.id), isFalse);
  });

  test('fish ids are never reused', () {
    // onHit matches a target back to a fish by id. If a new fish could inherit
    // the id of one just retired, a stale hit would catch the wrong fish.
    final game = FishGame(random: math.Random(11));
    final seen = <Object>{};

    for (var frame = 0; frame < 200; frame++) {
      game.difficulty = frame.isEven ? 1.0 : 0.0;
      game.update(step, screen);
      for (final target in game.targets) {
        seen.add(target.id);
      }
    }

    // Every id ever handed out is still unique across the whole run.
    expect(seen.length, greaterThanOrEqualTo(6));
  });
}
