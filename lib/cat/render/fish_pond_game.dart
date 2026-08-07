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
import '../games/fish/fish.dart';
import '../games/fish/fish_game.dart';
import '../games/fish/fish_species.dart';

/// The Flame layer for the fish pond.
///
/// It draws, and that is all it does. Where the fish are, what counts as a hit
/// and how hard the game is all live in plain Dart under `lib/cat/engine/` and
/// `lib/cat/games/`, so they stay testable without a game loop — see CLAUDE.md.
/// Nothing here decides anything a test would want to assert on.
class FishPondGame extends FlameGame {
  FishPondGame({
    FishGame? rules,
    PawInput? input,
    CatAudio? audio,
    SoundPolicy? sound,
    SessionClock? clock,
    SessionLimits limits = const SessionLimits(),
    math.Random? random,
  })  : rules = rules ?? FishGame(random: random),
        input = input ?? PawInput(),
        audio = audio ?? SilentCatAudio(),
        sound = sound ?? SoundPolicy(random: random),
        clock = clock ?? SessionClock(limits: limits);

  final FishGame rules;
  final PawInput input;
  final CatAudio audio;
  final SoundPolicy sound;
  final SessionClock clock;

  SessionPhase _lastPhase = SessionPhase.playing;

  final List<_Splash> _splashes = [];

  /// Which fish were darting last frame, so a dart is noticed as it starts
  /// rather than re-firing for every frame it lasts.
  final Set<Object> _darting = {};

  /// Seconds since the pond last made a noise. Silence is what the ambient
  /// chirp is for: docs/CAT_UX.md notes that many cats ignore the screen
  /// entirely until they hear something, so a pond nobody is playing with has
  /// to speak up on its own.
  double _quietFor = 0;

  /// Long enough never to compete with play, short enough to catch a cat that
  /// has wandered off mid-session.
  static const _chirpAfterQuiet = 7.0;

  /// Deep water. Blues and yellows are what a dichromatic eye reads strongly;
  /// docs/CAT_UX.md rules out building a theme around red, so the whole palette
  /// below sits in the blue-cyan-gold range and never leans on it.
  static const _deep = Color(0xFF04121F);
  static const _shallow = Color(0xFF0B3A5C);

  /// Dappled sunlight on the water, and the weed under it.
  ///
  /// Both are deliberately low contrast. The pond has to look alive — a still
  /// image loses a cat — but every one of these is scenery competing with the
  /// only thing that matters on the screen, and contrast is what a cat actually
  /// resolves. The fish stay the brightest objects in the frame by some margin,
  /// which is why the caustics sit near 0.09 alpha and the pads are barely
  /// above the water they float on.
  static const _caustic = Color(0xFF6FD8FF);
  static const _pad = Color(0xFF0E3F52);

  /// Seconds since the session started, for anything that moves on its own.
  double _time = 0;

  @override
  Color backgroundColor() => _deep;

  @override
  void update(double dt) {
    super.update(dt);
    clock.advance(dt);

    if (clock.phase != _lastPhase) {
      _lastPhase = clock.phase;
      if (_lastPhase == SessionPhase.windingDown) {
        _speak(CatSound.windDown, volume: 0.7);
      }
    }

    // Once the session is over there is nothing on screen but the scrim, so
    // there is nothing worth simulating either. Fifteen minutes of full-screen
    // animation is exactly the load CAT_UX.md says throttles a phone lying on a
    // rug; the least this can do is stop drawing heat at the end of it.
    if (clock.phase == SessionPhase.ended) return;

    // Slowing simulated time rather than each fish's speed settles the whole
    // pond together — darts, respawns and drifts all ease off in step. The
    // water slows with them, so the light stops swimming as the session closes.
    _time += dt * clock.pace;
    rules.update(dt * clock.pace, size.toSize());

    for (final splash in _splashes) {
      splash.age += dt;
    }
    _splashes.removeWhere((splash) => splash.age >= _Splash.life);

    _quietFor += dt;
    _voiceDarts();
    if (_quietFor >= _chirpAfterQuiet && clock.phase == SessionPhase.playing) {
      _speak(CatSound.chirp, volume: 0.5);
    }
  }

  /// A rustle on the frame a fish breaks into a dart. The sound is the point of
  /// the dart: a movement a cat may not be looking at becomes one it hears.
  void _voiceDarts() {
    for (final fish in rules.views) {
      if (fish.darting) {
        if (_darting.add(fish.id)) _speak(CatSound.rustle, volume: 0.35);
      } else {
        _darting.remove(fish.id);
      }
    }
  }

  void _speak(CatSound which, {double volume = 1.0}) {
    final cue = sound.request(which, DateTime.now(), volume: volume);
    if (cue == null) return;
    audio.play(cue);
    _quietFor = 0;
  }

  /// A paw landed. Resolved on pointer down rather than tap-up, because a bat at
  /// the screen is a glancing contact and waiting for a clean tap loses most of
  /// them (docs/CAT_UX.md).
  PawHit contact(Offset point, DateTime now) {
    // The session is over. Nothing is on screen, so nothing can be caught, and
    // scoring against an empty dark pond would quietly corrupt the stats the
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
      // The splash lands on the fish, not on the paw. An assisted or generous
      // hit has to look identical to a direct one or the cat learns it missed.
      _splashes.add(_Splash(hit.target?.center ?? point));
    }
    final cue = sound.forHit(hit, now);
    if (cue != null) {
      audio.play(cue);
      _quietFor = 0;
    }
    return hit;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final bounds = Offset.zero & size.toSize();

    _renderWater(canvas, bounds);

    for (final fish in rules.views) {
      _renderFish(canvas, fish);
    }
    for (final splash in _splashes) {
      _renderSplash(canvas, splash);
    }

    // The light going down, drawn over the finished scene rather than folded
    // into each fish's own alpha.
    //
    // That distinction is the whole reason this works. Fading a warm fish
    // against cold water composites it to olive — that mistake is documented on
    // the catch animation above. A scrim moves the fish and the water toward
    // the same colour at the same rate, so it reads as a room going dark
    // instead of everything turning the wrong hue on the way out.
    final dim = clock.windDownProgress;
    if (dim > 0) {
      canvas.drawRect(bounds, Paint()..color = _deep.withValues(alpha: dim));
    }
  }

  /// The pond itself: a pool of light, weed drifting under it, and sunlight
  /// broken up on the surface.
  ///
  /// The whole budget here is eleven draw calls sharing two shaders. Effects
  /// have to stay cheap for the same reason the frame rate is meant to be
  /// capped — half an hour of full-screen animation on a phone lying on a rug
  /// throttles, and throttling ends a session more reliably than boredom does
  /// (docs/CAT_UX.md).
  void _renderWater(Canvas canvas, Rect bounds) {
    // The pool of light drifts, so the pond is never quite the same shape
    // twice. Slowly — this is depth, not something to look at.
    final drift = Offset(
      math.sin(_time * 0.06) * bounds.width * 0.12,
      math.cos(_time * 0.045) * bounds.height * 0.12,
    );
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = Gradient.radial(
          bounds.center + drift,
          bounds.longestSide * 0.72,
          const [_shallow, _deep],
        ),
    );

    _renderPads(canvas, bounds);
    _renderCaustics(canvas, bounds);
  }

  /// Lily pads, seen from above like everything else in the pond.
  ///
  /// They turn and drift far too slowly to be mistaken for prey, which is the
  /// point: a decoy that never rewards a swipe teaches a cat that some moving
  /// things do not answer, and that is the lesson this app can least afford.
  void _renderPads(Canvas canvas, Rect bounds) {
    // Low alpha and a narrow notch, both after looking at the first attempt.
    // At 0.55 with a wide wedge they read as flat dark cut-outs punched in the
    // water — high enough contrast to pull the eye off the fish, which is the
    // one thing scenery here must not do.
    final body = Paint()..color = _pad.withValues(alpha: 0.32);
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..color = _caustic.withValues(alpha: 0.05);

    for (var i = 0; i < 3; i++) {
      final seed = i * 2.4;
      final radius = bounds.shortestSide * (0.1 + 0.03 * math.sin(seed));
      rim.strokeWidth = radius * 0.09;

      // Kept off the middle. The centre is where the pool of light is and where
      // fish are most legible, so the pads sit around the outside of it.
      final at = Offset(
        bounds.width * (0.16 + 0.34 * i) +
            math.sin(_time * 0.05 + seed) * bounds.width * 0.025,
        bounds.height * (i.isEven ? 0.19 : 0.82) +
            math.cos(_time * 0.04 + seed) * bounds.height * 0.035,
      );

      canvas
        ..save()
        ..translate(at.dx, at.dy)
        ..rotate(_time * 0.03 + seed);

      // A disc with a wedge cut out, which is the one silhouette that reads as
      // a lily pad rather than a stone.
      final pad = Path()
        ..moveTo(0, 0)
        ..arcTo(
          Rect.fromCircle(center: Offset.zero, radius: radius),
          0.25,
          math.pi * 2 - 0.5,
          false,
        )
        ..close();

      // The rim is what stops it reading as a hole. A surface catches light at
      // its edge; a hole does not.
      canvas
        ..drawPath(pad, body)
        ..drawPath(pad, rim)
        ..restore();
    }
  }

  /// Sunlight broken up by the surface.
  ///
  /// One radial shader built for a unit circle at the origin and then moved and
  /// scaled by the canvas for each patch, rather than a shader per patch per
  /// frame. Soft edges without paying for a blur, which is the expensive way to
  /// get the same look.
  void _renderCaustics(Canvas canvas, Rect bounds) {
    final glow = Paint()
      ..shader = Gradient.radial(Offset.zero, 1, [
        _caustic.withValues(alpha: 0.09),
        _caustic.withValues(alpha: 0),
      ]);

    for (var i = 0; i < 6; i++) {
      final seed = i * 1.9;
      final at = Offset(
        bounds.width * (0.5 + 0.42 * math.sin(_time * 0.11 + seed)),
        bounds.height * (0.5 + 0.42 * math.cos(_time * 0.083 + seed * 1.3)),
      );
      final rx =
          bounds.shortestSide * (0.3 + 0.12 * math.sin(_time * 0.2 + seed));
      final ry = rx * (0.42 + 0.12 * math.cos(_time * 0.17 + seed));

      canvas
        ..save()
        ..translate(at.dx, at.dy)
        ..rotate(math.sin(_time * 0.05 + seed) * 0.8)
        ..scale(rx, ry)
        ..drawCircle(Offset.zero, 1, glow)
        ..restore();
    }
  }

  void _renderFish(Canvas canvas, FishView fish) {
    final shape = _shapes[fish.species]!;
    final palette = _palettes[fish.species]!;

    // A caught fish darts away small and bright rather than dimming in place.
    //
    // Note there is no alpha fade here at all, and that is the fix rather than
    // an omission. Any partial alpha composites a warm fish into the cold water
    // behind it and lands on olive, so fading was tried twice — over the whole
    // 900ms, then over a quarter of it — and read as mud both times. Shrinking
    // at full opacity keeps the colour honest for every frame it is visible,
    // and is the clearer cause-and-effect signal for the cat that just hit it.
    var scale = 1.0;
    if (fish.caughtProgress > 0) {
      const vanishOver = 0.25;
      final t = ((1 - fish.caughtProgress) / vanishOver).clamp(0.0, 1.0);
      if (t >= 1) return;
      scale = 1 - 0.88 * t;
    }

    // Drawn well under the radius PawInput tests against. The gap is the whole
    // point: visual size and hit size are decoupled so a cat that looks like it
    // missed still scores (docs/CAT_UX.md). The darter leans on this hardest.
    final r = fish.radius * 0.5 * scale;

    // The tail beats in time with the swim, and faster mid-dart. This is the
    // cheapest possible way to make a shape read as alive rather than as a
    // sprite being slid across the screen.
    final beat = math.sin(fish.wag * 2.2) * (fish.darting ? 0.55 : 0.32);

    final body = Paint()..color = palette.body;
    final fin = Paint()..color = palette.fin;
    final accent = Paint()..color = palette.accent;

    // Semi-axes of the body. Everything else is positioned from these so the
    // parts cannot drift apart when a species changes proportion.
    final a = r * shape.length / 2;
    final b = r * shape.height / 2;

    canvas
      ..save()
      ..translate(fish.position.dx, fish.position.dy)
      ..rotate(fish.facing);

    if (fish.darting) _renderWake(canvas, r, palette);

    _renderTail(canvas, shape, a, b, beat, fin);
    _renderFin(canvas, shape.dorsal, a, b, up: true, paint: fin);
    _renderFin(canvas, shape.ventral, a, b, up: false, paint: fin);

    final outline = _bodyPath(a, b);
    canvas.drawPath(outline, body);

    // Markings are clipped to the body rather than trusted to fit inside it.
    // Hand-placed circles spill over the edge the moment a proportion changes,
    // and a blotch hanging off a fish reads as a rendering fault.
    if (shape.blotches || shape.stripe) {
      canvas.save();
      canvas.clipPath(outline);
      if (shape.blotches) {
        canvas
          ..drawCircle(Offset(-a * 0.3, -b * 0.15), b * 0.62, accent)
          ..drawCircle(Offset(a * 0.35, b * 0.2), b * 0.4, accent);
      }
      if (shape.stripe) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(-a * 0.1, 0),
            width: a * 1.4,
            height: b * 0.45,
          ),
          accent,
        );
      }
      canvas.restore();
    }

    // A pectoral fin just behind the head. Small, but it is the difference
    // between a fish and a lozenge with a tail.
    canvas.drawPath(
      Path()
        ..moveTo(a * 0.16, b * 0.2)
        ..quadraticBezierTo(-a * 0.05, b * 1.05, -a * 0.28, b * 0.5)
        ..close(),
      fin,
    );

    canvas
      ..drawCircle(
        Offset(a * 0.55, -b * 0.22),
        r * 0.14,
        Paint()..color = _deep,
      )
      ..restore();
  }

  /// The body outline: a rounded belly narrowing to a caudal peduncle, rather
  /// than the plain oval this started as. The taper is what lets the tail read
  /// as attached to something instead of stuck onto the back of an egg.
  Path _bodyPath(double a, double b) => Path()
    ..moveTo(a, 0)
    ..cubicTo(a * 0.55, -b, -a * 0.35, -b, -a, -b * 0.16)
    ..lineTo(-a, b * 0.16)
    ..cubicTo(-a * 0.35, b, a * 0.55, b, a, 0)
    ..close();

  /// Half the body's height at [x], from the ellipse the outline follows.
  ///
  /// Fins are anchored with this rather than at a fixed fraction of the body
  /// height, which is what made them float: at the fin's x the body is
  /// narrower than at the centre, so a fixed offset left a visible gap between
  /// fin and fish on every species with a tall dorsal.
  double _edgeAt(double x, double a, double b) {
    final k = (x / a).clamp(-1.0, 1.0);
    return b * math.sqrt(1 - k * k);
  }

  void _renderFin(
    Canvas canvas,
    double size,
    double a,
    double b, {
    required bool up,
    required Paint paint,
  }) {
    if (size <= 0) return;
    final sign = up ? -1.0 : 1.0;
    final from = -a * 0.42;
    final to = a * 0.2;
    // Anchored inside the outline, so the joint is always covered by the body
    // drawn over it.
    canvas.drawPath(
      Path()
        ..moveTo(from, sign * _edgeAt(from, a, b) * 0.65)
        ..quadraticBezierTo(
          -a * 0.15,
          sign * b * (1 + size),
          to,
          sign * _edgeAt(to, a, b) * 0.65,
        )
        ..close(),
      paint,
    );
  }

  /// Hinged at the peduncle rather than at the body centre, so the beat swings
  /// the tail and not the whole fish.
  void _renderTail(
    Canvas canvas,
    _Shape shape,
    double a,
    double b,
    double beat,
    Paint fin,
  ) {
    canvas
      ..save()
      // Slightly inside the outline: the body is drawn afterwards and covers
      // the joint, so there is never a seam.
      ..translate(-a * 0.92, 0)
      ..rotate(beat);

    final span = b * shape.tail;
    if (shape.forked) {
      // Two lobes with a notch, which is what makes a fast fish look fast even
      // while it is cruising.
      canvas.drawPath(
        Path()
          ..moveTo(a * 0.1, 0)
          ..lineTo(-span * 1.3, -span * 1.1)
          ..quadraticBezierTo(-span * 0.5, 0, -span * 1.3, span * 1.1)
          ..close(),
        fin,
      );
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(a * 0.1, 0)
          ..lineTo(-span * 1.25, -span * 1.05)
          ..quadraticBezierTo(-span * 0.95, 0, -span * 1.25, span * 1.05)
          ..close(),
        fin,
      );
    }
    canvas.restore();
  }

  /// A tapered sliver of water behind a darting fish. One path, because a pond
  /// full of particles is what throttles a phone lying on a rug.
  ///
  /// It was a round-capped line first, which drew a hard stick poking out of
  /// the tail. A triangle narrowing to a point reads as displaced water.
  void _renderWake(Canvas canvas, double r, _Palette palette) {
    canvas.drawPath(
      Path()
        ..moveTo(-r * 1.4, -r * 0.18)
        ..lineTo(-r * 3, 0)
        ..lineTo(-r * 1.4, r * 0.18)
        ..close(),
      Paint()..color = palette.body.withValues(alpha: 0.22),
    );
  }

  void _renderSplash(Canvas canvas, _Splash splash) {
    final t = splash.age / _Splash.life;
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

/// How each species is drawn. Proportions only — nothing here affects where a
/// fish is or whether it can be hit.
class _Shape {
  const _Shape({
    required this.length,
    required this.height,
    required this.tail,
    this.forked = false,
    this.dorsal = 0,
    this.ventral = 0,
    this.blotches = false,
    this.stripe = false,
  });

  final double length;
  final double height;
  final double tail;
  final bool forked;
  final double dorsal;
  final double ventral;
  final bool blotches;
  final bool stripe;
}

const _shapes = <FishSpecies, _Shape>{
  FishSpecies.goldfish: _Shape(
    length: 2.4,
    height: 1.4,
    tail: 0.8,
    dorsal: 0.5,
  ),
  // Long and slim, so the quick one looks quick even when it is not darting.
  FishSpecies.darter: _Shape(
    length: 3,
    height: 0.85,
    tail: 0.75,
    forked: true,
    stripe: true,
  ),
  // Broad and round, and unmistakable at a glance — this is the target a
  // struggling cat is meant to pick out.
  FishSpecies.koi: _Shape(
    length: 2.5,
    height: 1.85,
    tail: 1.05,
    dorsal: 0.35,
    ventral: 0.3,
    blotches: true,
  ),
  // Tall rather than long, which reads completely differently in motion without
  // moving any faster.
  FishSpecies.angel: _Shape(
    length: 1.8,
    height: 2.2,
    tail: 0.6,
    dorsal: 0.75,
    ventral: 0.65,
  ),
};

class _Palette {
  const _Palette(this.body, this.fin, this.accent);
  final Color body;
  final Color fin;
  final Color accent;
}

/// Gold and cyan against blue water. Every one of these is chosen to sit far
/// from the water in luminance as well as hue, because contrast is what a cat
/// actually resolves — docs/CAT_UX.md.
const _palettes = <FishSpecies, _Palette>{
  FishSpecies.goldfish: _Palette(
    Color(0xFFFFCF5C),
    Color(0xFFFF9E2C),
    Color(0xFFFFE9A8),
  ),
  FishSpecies.darter: _Palette(
    Color(0xFF8CE8FF),
    Color(0xFF35B6DC),
    Color(0xFFDFF8FF),
  ),
  FishSpecies.koi: _Palette(
    Color(0xFFFFF6E0),
    Color(0xFFFFAE4D),
    Color(0xFFFFC978),
  ),
  FishSpecies.angel: _Palette(
    Color(0xFFFFE98A),
    Color(0xFF56D9C4),
    Color(0xFFFFF6C9),
  ),
};

/// An expanding ring where a fish was caught. Purely a reward animation.
class _Splash {
  _Splash(this.at);

  static const life = 0.45;

  final Offset at;
  double age = 0;
}
