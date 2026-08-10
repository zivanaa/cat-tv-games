import 'dart:math' as math;
import 'dart:ui';

import '../audio/cat_sound.dart';
import '../games/fish/fish.dart';
import '../games/fish/fish_game.dart';
import '../games/fish/fish_species.dart';
import 'cat_surface_game.dart';

/// The Flame layer for the fish pond.
///
/// It draws, and that is all it does. Where the fish are, what counts as a hit
/// and how hard the game is all live in plain Dart under `lib/cat/engine/` and
/// `lib/cat/games/`, so they stay testable without a game loop — see CLAUDE.md.
/// Nothing here decides anything a test would want to assert on.
class FishPondGame extends CatSurfaceGame<FishGame> {
  FishPondGame({
    FishGame? rules,
    super.input,
    super.audio,
    super.sound,
    super.clock,
    super.limits,
    super.random,
  }) : super(rules: rules ?? FishGame(random: random));

  /// Which fish were darting last frame, so a dart is noticed as it starts
  /// rather than re-firing for every frame it lasts.
  final Set<Object> _darting = {};

  /// The pond, from the lit middle out to the deep edge.
  ///
  /// The first pass was near enough one colour, because "do not compete with
  /// the fish" got read as "stay dark". That conflated two different things.
  /// What a cat resolves is luminance, not hue, so the water can carry real
  /// colour as long as it stays well below the fish in brightness — and blue
  /// and blue-green are exactly the range a dichromatic eye reads strongly.
  ///
  /// The margin is still there and it is wide: this teal sits around 0.37
  /// relative luminance against roughly 0.82 for the gold fish and 0.84 for the
  /// cyan darter. The fish remain the brightest things on screen by a distance,
  /// which is the rule that actually matters.
  static const _deep = Color(0xFF04182B);
  static const _mid = Color(0xFF0D4468);
  static const _lit = Color(0xFF1C7A96);

  /// Two slow colour washes that keep the pond from being one flat field.
  /// Green-water in one corner, cold depth in another, both drifting.
  static const _weedWash = Color(0xFF0E8C7A);
  static const _duskWash = Color(0xFF2B3A8F);

  /// Dappled sunlight on the surface, and the lily pads under it.
  static const _caustic = Color(0xFFA8F0FF);
  static const _pad = Color(0xFF0B6157);

  @override
  Color get backdrop => _deep;

  /// A rustle on the frame a fish breaks into a dart. The sound is the point of
  /// the dart: a movement a cat may not be looking at becomes one it hears.
  @override
  void updateMode(double dt) {
    for (final fish in rules.views) {
      if (fish.darting) {
        if (_darting.add(fish.id)) speak(CatSound.rustle, volume: 0.35);
      } else {
        _darting.remove(fish.id);
      }
    }
  }

  @override
  void renderMode(Canvas canvas, Rect bounds) {
    _renderWater(canvas, bounds);

    for (final fish in rules.views) {
      _renderFish(canvas, fish);
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
      math.sin(elapsed * 0.06) * bounds.width * 0.12,
      math.cos(elapsed * 0.045) * bounds.height * 0.12,
    );
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = Gradient.radial(
          bounds.center + drift,
          bounds.longestSide * 0.78,
          const [_lit, _mid, _deep],
          const [0, 0.42, 1],
        ),
    );

    // Green water on one side, cold depth on the other, both wandering. Two
    // draws is what turns a single radial ramp into a pond that has places in
    // it rather than a middle and an outside.
    _renderWash(canvas, bounds, _weedWash, 0.16, 0.7, phase: 0);
    _renderWash(canvas, bounds, _duskWash, 0.2, 0.85, phase: 2.6);

    _renderPads(canvas, bounds);
    _renderCaustics(canvas, bounds);
  }

  /// A slow, very large patch of colour drifting across the pond.
  void _renderWash(
    Canvas canvas,
    Rect bounds,
    Color colour,
    double alpha,
    double size, {
    required double phase,
  }) {
    final at = Offset(
      bounds.width * (0.5 + 0.36 * math.sin(elapsed * 0.035 + phase)),
      bounds.height * (0.5 + 0.36 * math.cos(elapsed * 0.028 + phase * 1.4)),
    );
    final radius = bounds.longestSide * size;

    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..scale(radius, radius * 0.72)
      ..drawCircle(
        Offset.zero,
        1,
        Paint()
          ..shader = Gradient.radial(Offset.zero, 1, [
            colour.withValues(alpha: alpha),
            colour.withValues(alpha: 0),
          ]),
      )
      ..restore();
  }

  /// Lily pads, seen from above like everything else in the pond.
  ///
  /// They turn and drift far too slowly to be mistaken for prey, which is the
  /// point: a decoy that never rewards a swipe teaches a cat that some moving
  /// things do not answer, and that is the lesson this app can least afford.
  void _renderPads(Canvas canvas, Rect bounds) {
    // A narrow notch, after the first attempt's wide wedge read as a hole
    // punched in the water rather than a leaf floating on it. The alpha came
    // back up once the water underneath had real colour to sit against — at
    // 0.32 over a near-black pond they had vanished entirely.
    final body = Paint()..color = _pad.withValues(alpha: 0.5);
    final rim = Paint()
      ..style = PaintingStyle.stroke
      ..color = _caustic.withValues(alpha: 0.1);

    for (var i = 0; i < 3; i++) {
      final seed = i * 2.4;
      final radius = bounds.shortestSide * (0.1 + 0.03 * math.sin(seed));
      rim.strokeWidth = radius * 0.09;

      // Kept off the middle. The centre is where the pool of light is and where
      // fish are most legible, so the pads sit around the outside of it.
      final at = Offset(
        bounds.width * (0.16 + 0.34 * i) +
            math.sin(elapsed * 0.05 + seed) * bounds.width * 0.025,
        bounds.height * (i.isEven ? 0.19 : 0.82) +
            math.cos(elapsed * 0.04 + seed) * bounds.height * 0.035,
      );

      canvas
        ..save()
        ..translate(at.dx, at.dy)
        ..rotate(elapsed * 0.03 + seed);

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
        _caustic.withValues(alpha: 0.13),
        _caustic.withValues(alpha: 0),
      ]);

    for (var i = 0; i < 6; i++) {
      final seed = i * 1.9;
      final at = Offset(
        bounds.width * (0.5 + 0.42 * math.sin(elapsed * 0.11 + seed)),
        bounds.height * (0.5 + 0.42 * math.cos(elapsed * 0.083 + seed * 1.3)),
      );
      final rx =
          bounds.shortestSide * (0.3 + 0.12 * math.sin(elapsed * 0.2 + seed));
      final ry = rx * (0.42 + 0.12 * math.cos(elapsed * 0.17 + seed));

      canvas
        ..save()
        ..translate(at.dx, at.dy)
        ..rotate(math.sin(elapsed * 0.05 + seed) * 0.8)
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
