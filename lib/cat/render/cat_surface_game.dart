import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/extensions.dart';
import 'package:flame/game.dart';

import '../audio/cat_audio.dart';
import '../audio/cat_sound.dart';
import '../audio/sound_policy.dart';
import '../engine/cat_game.dart';
import '../engine/paw_input.dart';
import '../session/session_clock.dart';

/// Everything a cat-facing mode needs that has nothing to do with what it looks
/// like: the session clock, the paw input, the sound policy, the reward splash,
/// and the wind-down.
///
/// Pulled out when the laser mode arrived and it became obvious how much of the
/// pond was not about fish. The alternative was a second copy of the session
/// lifecycle, which is exactly the code you do not want two of — a wind-down
/// that ends one mode and not the other is the kind of bug nobody finds until a
/// cat has been staring at a live screen for an hour.
///
/// Generic on the rules type so each mode keeps its own, rather than every
/// renderer casting a CatGame back to the thing it already knew it had.
abstract class CatSurfaceGame<G extends CatGame> extends FlameGame {
  CatSurfaceGame({
    required this.rules,
    PawInput? input,
    CatAudio? audio,
    SoundPolicy? sound,
    SessionClock? clock,
    SessionLimits limits = const SessionLimits(),
    math.Random? random,
  })  : input = input ?? PawInput(),
        audio = audio ?? SilentCatAudio(),
        sound = sound ?? SoundPolicy(random: random),
        clock = clock ?? SessionClock(limits: limits);

  final G rules;
  final PawInput input;
  final CatAudio audio;
  final SoundPolicy sound;
  final SessionClock clock;

  final List<Splash> _splashes = [];
  SessionPhase _lastPhase = SessionPhase.playing;
  double _quietFor = 0;
  double _elapsed = 0;

  /// Seconds of play so far, slowed with the wind-down. Anything that animates
  /// on its own reads this rather than keeping its own clock, so the whole
  /// surface settles together at the end of a session.
  double get elapsed => _elapsed;

  /// Long enough never to compete with play, short enough to catch a cat that
  /// has wandered off mid-session.
  static const _chirpAfterQuiet = 7.0;

  /// Drawn under everything, and what the wind-down fades toward.
  Color get backdrop;

  @override
  Color backgroundColor() => backdrop;

  /// Draw the mode. Splashes and the wind-down scrim go on top of whatever this
  /// puts down.
  void renderMode(Canvas canvas, Rect bounds);

  /// Per-frame work that belongs to the mode — ambient noises, mostly. Not
  /// called once the session has ended.
  void updateMode(double dt) {}

  @override
  void update(double dt) {
    super.update(dt);
    clock.advance(dt);

    if (clock.phase != _lastPhase) {
      _lastPhase = clock.phase;
      if (_lastPhase == SessionPhase.windingDown) {
        speak(CatSound.windDown, volume: 0.7);
      }
    }

    // Once the session is over there is nothing on screen but the scrim, so
    // there is nothing worth simulating either. Fifteen minutes of full-screen
    // animation is exactly the load CAT_UX.md says throttles a phone lying on a
    // rug; the least this can do is stop drawing heat at the end of it.
    if (clock.phase == SessionPhase.ended) return;

    // Slowing simulated time rather than each thing's own speed settles the
    // whole surface together as the session closes.
    _elapsed += dt * clock.pace;
    rules.update(dt * clock.pace, size.toSize());

    for (final splash in _splashes) {
      splash.age += dt;
    }
    _splashes.removeWhere((splash) => splash.age >= Splash.life);

    _quietFor += dt;
    updateMode(dt);
    if (_quietFor >= _chirpAfterQuiet && clock.phase == SessionPhase.playing) {
      speak(CatSound.chirp, volume: 0.5);
    }
  }

  /// A paw landed. Resolved on pointer down rather than tap-up, because a bat at
  /// the screen is a glancing contact and waiting for a clean tap loses most of
  /// them (docs/CAT_UX.md).
  PawHit contact(Offset point, DateTime now) {
    // The session is over. Nothing is on screen, so nothing can be caught, and
    // scoring against an empty dark surface would quietly corrupt the stats the
    // owner reads.
    if (clock.phase == SessionPhase.ended) {
      return PawHit(tier: HitTier.miss, point: point);
    }

    final hit = input.resolve(
      point: point,
      targets: rules.targets,
      screen: size.toSize(),
      now: now,
    );
    rules.onHit(hit);
    if (hit.scored) {
      // The splash lands on the target, not on the paw. An assisted or generous
      // hit has to look identical to a direct one or the cat learns it missed.
      _splashes.add(Splash(hit.target?.center ?? point));
    }
    final cue = sound.forHit(hit, now);
    if (cue != null) {
      audio.play(cue);
      _quietFor = 0;
    }
    return hit;
  }

  void speak(CatSound which, {double volume = 1.0}) {
    final cue = sound.request(which, DateTime.now(), volume: volume);
    if (cue == null) return;
    audio.play(cue);
    _quietFor = 0;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final bounds = Offset.zero & size.toSize();

    renderMode(canvas, bounds);
    for (final splash in _splashes) {
      _renderSplash(canvas, splash);
    }

    // The light going down, drawn over the finished scene rather than folded
    // into anything's own alpha.
    //
    // That distinction is the whole reason this works. Fading a warm target
    // against cold water composites it to olive — the same mistake documented
    // on the pond's catch animation. A scrim moves everything toward one colour
    // at one rate, so it reads as a room going dark instead of the picture
    // turning the wrong hue on the way out.
    final dim = clock.windDownProgress;
    if (dim > 0) {
      canvas.drawRect(bounds, Paint()..color = backdrop.withValues(alpha: dim));
    }
  }

  void _renderSplash(Canvas canvas, Splash splash) {
    final t = splash.age / Splash.life;
    canvas.drawCircle(
      splash.at,
      18 + 70 * t,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * (1 - t)
        ..color = const Color(0xFFFFE9A8).withValues(alpha: (1 - t) * 0.8),
    );
  }
}

/// An expanding ring where something was caught. Purely a reward animation, and
/// the same one in every mode so a win reads the same wherever it happens.
class Splash {
  Splash(this.at);

  static const life = 0.45;

  final Offset at;
  double age = 0;
}
