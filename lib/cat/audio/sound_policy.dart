import 'dart:math' as math;

import '../engine/paw_input.dart';
import 'cat_sound.dart';

/// Decides whether a sound is allowed to play, and how it should sound.
///
/// This exists because the obvious wiring — play a splash on every scored
/// contact — is unusable in the one situation the app is built for. A cat that
/// is engaged produces contacts in bursts; `HighlightDetector` treats three per
/// second as a full-strength burst and rewards more. Firing a sample on each of
/// those is a wall of overlapping voices, and it is the same mistake in sound
/// that CAT_UX.md warns about in pixels: the device is on a rug, the session is
/// half an hour, and thermal throttling ends it sooner than boredom does.
///
/// So the policy caps how many sounds start per second, keeps a minimum gap
/// between two of the same kind, and varies pitch so repeats stay animal rather
/// than mechanical. Plain Dart, no game loop, no plugin — every rule here is
/// unit tested.
class SoundPolicy {
  SoundPolicy({
    this.maxPerSecond = 5,
    this.sameSoundGap = const Duration(milliseconds: 90),
    math.Random? random,
  }) : _random = random ?? math.Random();

  /// A ceiling across every sound, not per sound. Voices are the cost, and the
  /// device does not care which sample they came from.
  final int maxPerSecond;

  /// Minimum gap between two plays of the same sound.
  final Duration sameSoundGap;

  final math.Random _random;
  final List<DateTime> _recent = [];
  final Map<CatSound, DateTime> _lastOf = {};

  /// The cue to play, or null when this one has to stay silent.
  SoundCue? request(CatSound sound, DateTime now, {double volume = 1.0}) {
    _recent.removeWhere(
      (at) => now.difference(at) >= const Duration(seconds: 1),
    );
    if (_recent.length >= maxPerSecond) return null;

    final last = _lastOf[sound];
    if (last != null && now.difference(last) < sameSoundGap) return null;

    _recent.add(now);
    _lastOf[sound] = now;
    return SoundCue(
      sound: sound,
      volume: volume.clamp(0.0, 1.0).toDouble(),
      rate: _rateFor(sound),
    );
  }

  /// The cue for a resolved contact, or null if it should be silent.
  ///
  /// A miss makes no sound at all. That is deliberate and it is the one place
  /// the audio layer is allowed to know what tier a hit was: everywhere else
  /// the cat must not be able to tell an assisted hit from a direct one, but a
  /// miss produced no catch to react to, and inventing a reward for it would
  /// teach the cat that the screen responds to nothing in particular.
  ///
  /// A direct hit is pitched up slightly. The cat cannot tell, but it keeps a
  /// long session from flattening into one repeated note.
  SoundCue? forHit(PawHit hit, DateTime now) {
    if (!hit.scored) return null;
    final cue = request(CatSound.splash, now);
    if (cue == null) return null;
    return SoundCue(
      sound: cue.sound,
      volume: cue.volume,
      rate: cue.rate * (hit.tier == HitTier.direct ? 1.08 : 1.0),
    );
  }

  /// Small random detune. Wide enough to break the repetition, narrow enough
  /// that a chirp stays a chirp.
  double _rateFor(CatSound sound) => switch (sound) {
        CatSound.splash => 0.94 + _random.nextDouble() * 0.16,
        CatSound.chirp => 0.9 + _random.nextDouble() * 0.25,
        CatSound.rustle => 0.95 + _random.nextDouble() * 0.12,
        CatSound.windDown => 1,
      };

  void reset() {
    _recent.clear();
    _lastOf.clear();
  }
}
