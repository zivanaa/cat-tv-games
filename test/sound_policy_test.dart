import 'dart:math' as math;

import 'package:cat_tv_games/cat/audio/cat_audio.dart';
import 'package:cat_tv_games/cat/audio/cat_sound.dart';
import 'package:cat_tv_games/cat/audio/sound_policy.dart';
import 'package:cat_tv_games/cat/engine/paw_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final start = DateTime(2026);

  PawHit hit(HitTier tier) => PawHit(
        tier: tier,
        target: const PawTarget(id: 'f', center: Offset.zero, radius: 40),
        point: Offset.zero,
      );

  test('an engaged cat does not produce a wall of sound', () {
    // The whole reason this class exists. HighlightDetector treats three
    // contacts a second as a full-strength burst and rewards more than that, so
    // the interesting case is precisely the one where naive wiring falls over.
    // Thirty contacts in a second must not become thirty overlapping voices on
    // a phone that has to survive a half-hour session on a rug.
    final policy = SoundPolicy(random: math.Random(1));
    var played = 0;

    for (var i = 0; i < 30; i++) {
      final at = start.add(Duration(milliseconds: i * 33));
      if (policy.forHit(hit(HitTier.direct), at) != null) played++;
    }

    expect(played, lessThanOrEqualTo(policy.maxPerSecond));
  });

  test('the cap lifts once the burst is over', () {
    // A cap that never recovers would silence the rest of the session.
    final policy = SoundPolicy(random: math.Random(1));
    for (var i = 0; i < 30; i++) {
      policy.forHit(hit(HitTier.direct), start.add(Duration(milliseconds: i)));
    }

    final later = policy.forHit(
      hit(HitTier.direct),
      start.add(const Duration(seconds: 2)),
    );
    expect(later, isNotNull);
  });

  test('a miss makes no sound', () {
    // The one place the audio layer is allowed to know the tier. A miss caught
    // no fish, and rewarding it would teach the cat the screen answers to
    // nothing in particular.
    final policy = SoundPolicy(random: math.Random(1));
    expect(policy.forHit(hit(HitTier.miss), start), isNull);
  });

  test('an assisted hit sounds like a hit', () {
    // Everywhere outside that one exception the cat must not be able to hear
    // the difference, or the feedback loop the assist exists to protect breaks.
    final policy = SoundPolicy(random: math.Random(1));
    expect(policy.forHit(hit(HitTier.assisted), start), isNotNull);

    final generous = SoundPolicy(random: math.Random(1));
    expect(generous.forHit(hit(HitTier.generous), start), isNotNull);
  });

  test('a direct hit is pitched a little higher', () {
    // Fulfils the TODO left in fish_game.dart. Same seed both times so the
    // random detune cancels and only the tier is left.
    final direct = SoundPolicy(
      random: math.Random(3),
    ).forHit(hit(HitTier.direct), start)!;
    final assisted = SoundPolicy(
      random: math.Random(3),
    ).forHit(hit(HitTier.assisted), start)!;

    expect(direct.rate, greaterThan(assisted.rate));
  });

  test('repeats are detuned so a sample does not read as a machine', () {
    final policy = SoundPolicy(random: math.Random(5));
    final rates = <double>{};
    for (var i = 0; i < 12; i++) {
      final cue = policy.request(
        CatSound.chirp,
        start.add(Duration(seconds: i)),
      );
      if (cue != null) rates.add(cue.rate);
    }

    expect(rates.length, greaterThan(3), reason: 'pitch should vary');
    for (final rate in rates) {
      expect(rate, inInclusiveRange(0.8, 1.3), reason: 'still recognisable');
    }
  });

  test('the same sound cannot retrigger instantly', () {
    final policy = SoundPolicy(random: math.Random(1));
    expect(policy.request(CatSound.rustle, start), isNotNull);
    final tooSoon = start.add(const Duration(milliseconds: 10));
    expect(policy.request(CatSound.rustle, tooSoon), isNull);

    final later = start.add(const Duration(milliseconds: 200));
    expect(policy.request(CatSound.rustle, later), isNotNull);
  });

  test('the silent player is a real implementation, not a crash', () {
    // Builds without samples must still run. A silent pond is worse than a
    // noisy one and far better than a dead session.
    final audio = SilentCatAudio();
    audio.play(const SoundCue(sound: CatSound.splash, volume: 1, rate: 1));
    expect(audio.played, hasLength(1));
  });
}
