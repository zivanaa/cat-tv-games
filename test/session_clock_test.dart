import 'dart:math' as math;

import 'package:cat_tv_games/cat/audio/cat_audio.dart';
import 'package:cat_tv_games/cat/audio/cat_sound.dart';
import 'package:cat_tv_games/cat/engine/cat_game.dart';
import 'package:cat_tv_games/cat/engine/paw_input.dart';
import 'package:cat_tv_games/cat/render/fish_pond_game.dart';
import 'package:cat_tv_games/cat/session/session_clock.dart';
import 'package:flame/game.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const step = 1 / 40;

  SessionClock run(SessionClock clock, Duration forHowLong) {
    for (var i = 0; i < forHowLong.inMilliseconds / 25; i++) {
      clock.advance(step);
    }
    return clock;
  }

  group('the clock', () {
    test('plays for the whole session but the wind-down', () {
      final clock = SessionClock();
      expect(clock.phase, SessionPhase.playing);

      run(clock, const Duration(minutes: 14, seconds: 20));
      expect(clock.phase, SessionPhase.playing, reason: 'still 40s of room');
      expect(clock.pace, 1);
    });

    test('winds down over the last stretch, then ends itself', () {
      // The behaviour the product depends on. Cats do not stop, so this is the
      // only thing that ends a session.
      final clock = SessionClock();
      run(clock, const Duration(minutes: 14, seconds: 40));
      expect(clock.phase, SessionPhase.windingDown);

      run(clock, const Duration(seconds: 30));
      expect(clock.phase, SessionPhase.ended);
    });

    test('the pond settles rather than stopping dead', () {
      // A target frozen mid-screen is the stillness CAT_UX.md warns about, so
      // the pace eases off but never reaches zero while anything is visible.
      final clock = SessionClock();
      run(clock, const Duration(minutes: 14, seconds: 45));

      final paces = <double>[];
      for (var i = 0; i < 5; i++) {
        run(clock, const Duration(seconds: 4));
        if (clock.phase == SessionPhase.windingDown) paces.add(clock.pace);
      }

      expect(paces.length, greaterThan(2));
      for (var i = 1; i < paces.length; i++) {
        expect(paces[i], lessThan(paces[i - 1]), reason: 'must keep easing');
      }
      expect(paces.last, greaterThan(0));
    });

    test('the light comes down across the wind-down, not at the end', () {
      final clock = SessionClock();
      run(clock, const Duration(minutes: 14, seconds: 30));
      expect(clock.windDownProgress, 0);

      run(clock, const Duration(seconds: 15));
      expect(clock.windDownProgress, closeTo(0.5, 0.1));

      run(clock, const Duration(seconds: 20));
      expect(clock.windDownProgress, 1);
    });

    test('a zero-length wind-down does not divide by zero', () {
      final clock = SessionClock(
        limits: const SessionLimits(
          maxDuration: Duration(minutes: 1),
          windDown: Duration.zero,
        ),
      );
      run(clock, const Duration(seconds: 61));
      expect(clock.phase, SessionPhase.ended);
      expect(clock.windDownProgress, 1);
      expect(clock.pace.isFinite, isTrue);
    });

    test('a wind-down longer than the session starts one immediately', () {
      final clock = SessionClock(
        limits: const SessionLimits(
          maxDuration: Duration(seconds: 10),
          windDown: Duration(seconds: 30),
        ),
      );
      expect(clock.windDownBegins, Duration.zero);
      expect(clock.phase, SessionPhase.windingDown);
    });
  });

  group('the pond', () {
    FishPondGame pond({required SessionLimits limits, SilentCatAudio? audio}) {
      final game = FishPondGame(
        random: math.Random(4),
        audio: audio ?? SilentCatAudio(),
        limits: limits,
      );
      game.onGameResize(Vector2(800, 400));
      return game;
    }

    test('stops simulating once the session is over', () {
      // Fifteen minutes of full-screen animation is the load that throttles a
      // phone face-up on a rug. Nothing is visible under the scrim, so nothing
      // should still be burning cycles either.
      final game = pond(
        limits: const SessionLimits(
          maxDuration: Duration(seconds: 2),
          windDown: Duration(seconds: 1),
        ),
      );
      for (var i = 0; i < 200; i++) {
        game.update(step);
      }
      expect(game.clock.phase, SessionPhase.ended);

      final before = game.rules.views.map((f) => f.position).toList();
      for (var i = 0; i < 40; i++) {
        game.update(step);
      }
      final after = game.rules.views.map((f) => f.position).toList();
      expect(after, before, reason: 'the pond should be frozen, not running');
    });

    test('a contact after the session ends scores nothing', () {
      final game = pond(
        limits: const SessionLimits(
          maxDuration: Duration(seconds: 2),
          windDown: Duration(seconds: 1),
        ),
      );
      for (var i = 0; i < 200; i++) {
        game.update(step);
      }

      final hit = game.contact(const Offset(400, 200), DateTime(2026));
      expect(hit.tier, HitTier.miss);
      expect(hit.scored, isFalse);
    });

    test('the wind-down is announced once, not every frame', () {
      final audio = SilentCatAudio();
      final game = pond(
        limits: const SessionLimits(
          maxDuration: Duration(seconds: 4),
          windDown: Duration(seconds: 2),
        ),
        audio: audio,
      );
      for (var i = 0; i < 200; i++) {
        game.update(step);
      }

      final windDowns =
          audio.played.where((cue) => cue.sound == CatSound.windDown).length;
      expect(windDowns, 1);
    });
  });
}
