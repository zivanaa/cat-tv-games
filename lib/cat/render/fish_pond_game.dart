import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/extensions.dart';
import 'package:flame/game.dart';

import '../engine/paw_input.dart';
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
  FishPondGame({FishGame? rules, PawInput? input, math.Random? random})
      : rules = rules ?? FishGame(random: random),
        input = input ?? PawInput();

  final FishGame rules;
  final PawInput input;

  final List<_Splash> _splashes = [];

  /// Deep water. Blues and yellows are what a dichromatic eye reads strongly;
  /// docs/CAT_UX.md rules out building a theme around red, so the whole palette
  /// below sits in the blue-cyan-gold range and never leans on it.
  static const _deep = Color(0xFF04121F);
  static const _shallow = Color(0xFF0B3A5C);

  @override
  Color backgroundColor() => _deep;

  @override
  void update(double dt) {
    super.update(dt);
    rules.update(dt, size.toSize());
    for (final splash in _splashes) {
      splash.age += dt;
    }
    _splashes.removeWhere((splash) => splash.age >= _Splash.life);
  }

  /// A paw landed. Resolved on pointer down rather than tap-up, because a bat at
  /// the screen is a glancing contact and waiting for a clean tap loses most of
  /// them (docs/CAT_UX.md).
  PawHit contact(Offset point, DateTime now) {
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
    return hit;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final bounds = Offset.zero & size.toSize();

    // A pool of light in the middle so the pond is not a flat field of one
    // colour. Motion holds attention, but contrast is what makes a fish legible
    // against the water in the first place.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = Gradient.radial(
          bounds.center,
          bounds.longestSide * 0.7,
          const [_shallow, _deep],
        ),
    );

    for (final fish in rules.views) {
      _renderFish(canvas, fish);
    }
    for (final splash in _splashes) {
      _renderSplash(canvas, splash);
    }
  }

  void _renderFish(Canvas canvas, FishView fish) {
    final shape = _shapes[fish.species]!;
    final palette = _palettes[fish.species]!;

    // A caught fish darts away small and bright rather than dimming in place.
    //
    // Fading it out across the full 900ms was the obvious thing and it looked
    // wrong: gold at low alpha over blue water turns olive, so a caught fish
    // spent most of a second as a muddy smear rather than reading as gone. It
    // now shrinks away over the first quarter of that window while staying
    // bright, and is simply absent for the rest — which is also the clearer
    // cause-and-effect signal for the cat that just hit it.
    // Note there is no alpha fade here at all, and that is the fix rather than
    // an omission. Any partial alpha composites a warm fish into the cold water
    // behind it and lands on olive, so fading was tried twice — over the whole
    // 900ms, then over a quarter of it — and read as mud both times. Shrinking
    // at full opacity keeps the colour honest for every frame it is visible.
    const opacity = 1.0;
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

    final body = Paint()..color = palette.body.withValues(alpha: opacity);
    final fin = Paint()..color = palette.fin.withValues(alpha: opacity * 0.95);
    final accent = Paint()
      ..color = palette.accent.withValues(alpha: opacity * 0.9);

    canvas
      ..save()
      ..translate(fish.position.dx, fish.position.dy)
      ..rotate(fish.facing);

    if (fish.darting) _renderWake(canvas, r, opacity, palette);

    _renderTail(canvas, shape, r, beat, fin);

    // Dorsal and ventral fins before the body, so the body edge cuts them
    // cleanly and the silhouette stays readable at speed.
    if (shape.dorsal > 0) {
      canvas.drawPath(
        Path()
          ..moveTo(-r * 0.3, -r * shape.height * 0.45)
          ..lineTo(r * 0.15, -r * shape.height * (0.45 + shape.dorsal))
          ..lineTo(r * 0.7, -r * shape.height * 0.4)
          ..close(),
        fin,
      );
    }
    if (shape.ventral > 0) {
      canvas.drawPath(
        Path()
          ..moveTo(-r * 0.2, r * shape.height * 0.45)
          ..lineTo(r * 0.1, r * shape.height * (0.45 + shape.ventral))
          ..lineTo(r * 0.6, r * shape.height * 0.4)
          ..close(),
        fin,
      );
    }

    canvas.drawOval(
      Rect.fromCenter(
        center: Offset.zero,
        width: r * shape.length,
        height: r * shape.height,
      ),
      body,
    );

    // Koi get their blotches, which is what makes them read as koi rather than
    // as a big goldfish.
    if (shape.blotches) {
      canvas
        ..drawCircle(Offset(-r * 0.35, -r * 0.12), r * 0.34, accent)
        ..drawCircle(Offset(r * 0.42, r * 0.16), r * 0.22, accent);
    }

    // A stripe along the flank gives the slimmer species some form.
    if (shape.stripe) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(-r * 0.1, 0),
          width: r * shape.length * 0.55,
          height: r * shape.height * 0.22,
        ),
        accent,
      );
    }

    final eyeAt = Offset(r * shape.length * 0.29, -r * shape.height * 0.14);
    canvas
      ..drawCircle(
        eyeAt,
        r * 0.15,
        Paint()..color = _deep.withValues(alpha: opacity),
      )
      ..restore();
  }

  void _renderTail(
    Canvas canvas,
    _Shape shape,
    double r,
    double beat,
    Paint fin,
  ) {
    final root = -r * shape.length * 0.42;
    canvas
      ..save()
      ..translate(root, 0)
      ..rotate(beat);

    final span = r * shape.tail;
    if (shape.forked) {
      // Two lobes with a notch, which is what makes a fast fish look fast even
      // while it is cruising.
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(-span * 1.2, -span * 0.95)
          ..lineTo(-span * 0.55, 0)
          ..lineTo(-span * 1.2, span * 0.95)
          ..close(),
        fin,
      );
    } else {
      canvas.drawPath(
        Path()
          ..moveTo(0, 0)
          ..lineTo(-span * 1.15, -span * 0.85)
          ..lineTo(-span * 1.15, span * 0.85)
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
  void _renderWake(Canvas canvas, double r, double opacity, _Palette palette) {
    canvas.drawPath(
      Path()
        ..moveTo(-r * 1.4, -r * 0.18)
        ..lineTo(-r * 3, 0)
        ..lineTo(-r * 1.4, r * 0.18)
        ..close(),
      Paint()..color = palette.body.withValues(alpha: opacity * 0.22),
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
