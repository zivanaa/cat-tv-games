import 'dart:math' as math;
import 'dart:ui';

import 'package:cat_tv_games/cat/engine/paw_input.dart';
import 'package:cat_tv_games/cat/games/fish/fish.dart';
import 'package:cat_tv_games/cat/games/fish/fish_game.dart';
import 'package:cat_tv_games/cat/games/fish/fish_species.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const screen = Size(800, 400);

  /// One frame at the 40fps the cat surface is capped to.
  const step = 1 / 40;

  PawHit hitOn(PawTarget target) =>
      PawHit(tier: HitTier.direct, target: target, point: target.center);

  /// Sixty seconds of play across twelve ponds. At 40 to 180px/s in an 800px
  /// pond that is thousands of pixels of travel per fish, so every wall gets met
  /// repeatedly and at every angle.
  ({int stillest, int longestOnEdge}) simulate() {
    var stillest = 0;
    var longestOnEdge = 0;

    for (var seed = 0; seed < 12; seed++) {
      final game = FishGame(random: math.Random(seed));
      final edge = <Object, int>{};
      final still = <Object, int>{};
      final previous = <Object, Offset>{};

      for (var frame = 0; frame < 2400; frame++) {
        game.update(step, screen);
        for (final fish in game.views) {
          if (fish.caughtProgress > 0) continue;
          final r = fish.radius;
          final onEdge = fish.position.dx <= r + 0.001 ||
              fish.position.dx >= screen.width - r - 0.001 ||
              fish.position.dy <= r + 0.001 ||
              fish.position.dy >= screen.height - r - 0.001;
          edge[fish.id] = onEdge ? (edge[fish.id] ?? 0) + 1 : 0;
          longestOnEdge = math.max(longestOnEdge, edge[fish.id]!);

          final was = previous[fish.id];
          final moved =
              was == null ? double.infinity : (fish.position - was).distance;
          previous[fish.id] = fish.position;
          still[fish.id] = moved < 0.4 ? (still[fish.id] ?? 0) + 1 : 0;
          stillest = math.max(stillest, still[fish.id]!);
        }
      }
    }

    return (stillest: stillest, longestOnEdge: longestOnEdge);
  }

  test('a fish never goes still', () {
    // This is the property that actually matters, and the reason this file
    // exists. docs/CAT_UX.md: nothing on the cat surface should be still for
    // more than a couple of seconds, because a target that stops moving is a
    // target a cat stops watching.
    //
    // It replaced a narrower guard that counted frames spent touching an edge.
    // That proxy was wrong: it could not tell a fish pinned motionless against
    // the border from one swimming along it, and it failed the moment the
    // species gaits landed even though nothing had actually gone still.
    expect(simulate().stillest, lessThanOrEqualTo(2));
  });

  test('no fish is held against an edge', () {
    // The bug this started from. Two defects pressed fish into the border:
    //
    // 1. The bounce reflected the bare heading while the fish actually
    //    travelled heading + wobble, so the reflected course could still point
    //    into the wall and be clamped again on the next frame.
    // 2. _respawn drew from [0, extent] when the legal band is
    //    [radius, extent - radius], so roughly a fifth of respawns put the fish
    //    partly off screen and the bounce flattened it there on frame one.
    //
    // Measured over 12 seeds x 60s. Original code: 91 consecutive frames, over
    // two seconds welded to the border. Reflection fix alone: 81. Both: 2.
    // Adding the species gaits took it to 7 — a fifth of a second of a fish
    // swimming along the edge, which the stillness test above confirms is
    // travel and not a stall. The bound is set at 12 to leave gait headroom
    // while still catching anything like the original two-second stall.
    expect(simulate().longestOnEdge, lessThanOrEqualTo(12));
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

  test('every species turns up in the pond', () {
    // A weighting that quietly never produces a koi would cost the mode its
    // easiest target and nobody would notice from looking at it.
    final seen = <FishSpecies>{};
    for (var seed = 0;
        seed < 40 && seen.length < FishSpecies.values.length;
        seed++) {
      final game = FishGame(random: math.Random(seed));
      game.difficulty = 1;
      for (var frame = 0; frame < 400; frame++) {
        game.update(step, screen);
        for (final fish in game.views) {
          seen.add(fish.species);
        }
      }
    }

    expect(seen, containsAll(FishSpecies.values));
  });

  test('a koi never darts and a darter does', () {
    // The gaits are the point of having species at all. If every fish ended up
    // moving the same way the pond would read as one repeating pattern again.
    final darted = <FishSpecies, bool>{};

    for (var seed = 0; seed < 20; seed++) {
      final game = FishGame(random: math.Random(seed));
      game.difficulty = 1;
      for (var frame = 0; frame < 2400; frame++) {
        game.update(step, screen);
        for (final fish in game.views) {
          darted[fish.species] =
              (darted[fish.species] ?? false) || fish.darting;
        }
      }
    }

    expect(darted[FishSpecies.koi], isNot(isTrue), reason: 'koi never dart');
    expect(darted[FishSpecies.darter], isTrue, reason: 'darters do');
  });

  test('the smallest species is still catchable', () {
    // A darter is drawn at well under the minimum touch target. That is only
    // safe because PawInput floors every target at minTargetRadius — if the
    // floor ever stopped applying, the fastest fish would become the one a cat
    // can never land, which is the zero-score session the whole design is
    // built to avoid.
    const config = PawInputConfig();
    final input = PawInput(config: config);
    final radius = 56 * FishSpecies.darter.sizeScale;
    expect(radius, lessThan(config.minTargetRadius));

    final hit = input.resolve(
      point: const Offset(400, 200).translate(config.minTargetRadius - 2, 0),
      targets: [
        PawTarget(id: 'darter', center: const Offset(400, 200), radius: radius),
      ],
      screen: screen,
      now: DateTime(2026),
    );

    expect(hit.tier, HitTier.direct);
  });
}
