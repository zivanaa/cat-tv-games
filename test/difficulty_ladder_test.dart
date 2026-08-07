import 'dart:math' as math;
import 'dart:ui';

import 'package:cat_tv_games/cat/engine/paw_input.dart';
import 'package:cat_tv_games/cat/games/fish/fish_game.dart';
import 'package:cat_tv_games/cat/session/session_recorder.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the difficulty ladder by playing a session rather than by asserting on
/// the arithmetic.
///
/// The ladder was broken for a long time in a way no unit test noticed. It was
/// steered by [SessionRecorder.accuracy], which counts direct hits only, while
/// the entire point of the assist is that a cat lands assisted hits instead. A
/// simulated cat that connected with every single one of 858 contacts scored
/// 0.41 accuracy, never crossed the threshold, and sat at its starting
/// difficulty for the whole session. Nothing failed; the game just never got
/// harder for anyone.
///
/// So these tests drive the real loop — pond, input, recorder, difficulty — and
/// assert on where a cat of a given steadiness ends up.
void main() {
  const screen = Size(800, 400);
  const step = 1 / 40;

  /// Plays [seconds] with a cat whose paw lands within [spread] px of the fish
  /// it aimed at, and reports the difficulty every 15s.
  List<double> play({required double spread, int seconds = 300}) {
    final random = math.Random(4);
    final game = FishGame(random: math.Random(9));
    final input = PawInput();
    final session = SessionRecorder(
      catId: 'sim',
      gameId: FishGame.gameId,
      startedAt: DateTime(2026),
    );
    var now = DateTime(2026);
    final ladder = <double>[];

    for (var frame = 0; frame < 40 * seconds; frame++) {
      game.update(step, screen);
      now = now.add(const Duration(milliseconds: 25));
      if (frame % (40 * 15) == 0) ladder.add(game.difficulty);

      // A bat roughly every 350ms, which is a relentless cat. A real one pauses
      // and gets distracted, so a real climb is slower than these numbers.
      if (frame % 14 != 0) continue;
      final live = game.targets.where((t) => t.hittable).toList();
      if (live.isEmpty) continue;

      final aim = live[random.nextInt(live.length)].center;
      final hit = input.resolve(
        point: Offset(
          aim.dx + (random.nextDouble() - 0.5) * 2 * spread,
          aim.dy + (random.nextDouble() - 0.5) * 2 * spread,
        ),
        targets: game.targets,
        screen: screen,
        now: now,
      );
      game.onHit(hit);
      session.record(hit, at: now);

      final next = session.suggestedDifficulty(game.difficulty);
      if (next != game.difficulty) {
        game.difficulty = next;
        input.config = PawInputConfig.forDifficulty(next);
      }
    }

    return ladder;
  }

  test('a cat that keeps connecting is given a harder pond', () {
    final ladder = play(spread: 30);
    expect(ladder.first, 0.4, reason: 'every session opens in the middle');
    expect(ladder.last, greaterThan(0.9));
  });

  test('a cat that is mostly missing is given an easier one', () {
    final ladder = play(spread: 200);
    expect(ladder.last, lessThan(0.15));
  });

  test('an average cat is not left stuck where it started', () {
    // This is the case that was broken. A cat missing by 90px lands almost
    // everything, but lands it with the assist, so the old accuracy gate never
    // opened and the pond never changed for it once in five minutes.
    final ladder = play(spread: 90);
    expect(ladder.last, greaterThan(0.6));
  });

  test('the ladder is climbed, not jumped', () {
    // Difficulty used to be re-decided on every single contact, which took a
    // sharp cat from 0.4 to maximum inside half a minute. A step is rationed to
    // one per steering window so the change is something a human watching can
    // actually see happen.
    final ladder = play(spread: 30, seconds: 90);
    final distinct = ladder.toSet().length;
    expect(
      distinct,
      greaterThanOrEqualTo(4),
      reason: 'visible intermediate steps',
    );
    for (var i = 1; i < ladder.length; i++) {
      expect(
        (ladder[i] - ladder[i - 1]).abs(),
        lessThanOrEqualTo(0.25),
        reason: 'no single 15s stretch should leap the whole ladder',
      );
    }
  });

  test('the generous tier stays reachable at every rung', () {
    // The regression that hides itself. If the generous reach ever falls inside
    // the assist radius the tier is silently dead: no test fails, no error is
    // logged, cats just quietly score less. Tightening the assist as difficulty
    // climbs is exactly the change that could cause it.
    for (var i = 0; i <= 10; i++) {
      final d = i / 10;
      final config = PawInputConfig.forDifficulty(d);
      final assist = config.minTargetRadius * config.assistMultiplier;
      final reach = 800 * config.generosity;
      expect(
        reach,
        greaterThan(assist),
        reason: 'difficulty $d leaves the generous tier unreachable',
      );
    }
  });

  test('the assist really does tighten as the pond gets harder', () {
    final easy = PawInputConfig.forDifficulty(0);
    final hard = PawInputConfig.forDifficulty(1);
    expect(hard.assistMultiplier, lessThan(easy.assistMultiplier));
    expect(hard.generosity, lessThan(easy.generosity));
  });
}
