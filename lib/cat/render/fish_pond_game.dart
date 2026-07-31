import 'dart:math' as math;
import 'dart:ui';

import 'package:flame/extensions.dart';
import 'package:flame/game.dart';

import '../engine/paw_input.dart';
import '../games/fish/fish_game.dart';

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

  /// Last known position per fish, used only to point the sprite the way it is
  /// swimming. Reading it back off the screen keeps [FishGame] from having to
  /// expose a heading it does not otherwise need.
  final Map<Object, Offset> _previous = {};
  final Map<Object, double> _facing = {};
  final List<_Splash> _splashes = [];

  /// Cats are dichromatic. Blues and yellows read strongly and reds do not, so
  /// the pond is blue and the fish are yellow. docs/CAT_UX.md is explicit that
  /// no theme should be built around red.
  static const _deep = Color(0xFF04121F);
  static const _shallow = Color(0xFF0B3A5C);
  static const _body = Color(0xFFFFCF5C);
  static const _fin = Color(0xFFFF9E2C);
  static const _caught = Color(0x33FFCF5C);

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
      _splashes.add(_Splash(hit.target?.center ?? point, hit.weight));
    }
    return hit;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final bounds = Offset.zero & size.toSize();

    // A little depth so the pond is not a flat field of one colour. Motion is
    // what holds attention, but contrast is what makes the fish readable.
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = Gradient.radial(
          bounds.center,
          bounds.longestSide * 0.7,
          const [_shallow, _deep],
        ),
    );

    for (final target in rules.targets) {
      _renderFish(canvas, target);
    }
    for (final splash in _splashes) {
      _renderSplash(canvas, splash);
    }
  }

  void _renderFish(Canvas canvas, PawTarget target) {
    final centre = target.center;
    final previous = _previous[target.id];
    if (previous != null && (centre - previous).distance > 0.01) {
      _facing[target.id] = math.atan2(
        centre.dy - previous.dy,
        centre.dx - previous.dx,
      );
    }
    _previous[target.id] = centre;
    final facing = _facing[target.id] ?? 0;

    // A caught fish fades rather than blinking out — the cat needs to connect
    // its own paw to the fish going away.
    final live = target.hittable;
    final paint = Paint()..color = live ? _body : _caught;
    final finPaint = Paint()..color = live ? _fin : _caught;

    // Drawn at roughly half the radius PawInput tests against. The gap is the
    // whole point: visual size and hit size are decoupled so a cat that looks
    // like it missed still scores (docs/CAT_UX.md).
    final r = target.radius * 0.5;

    canvas
      ..save()
      ..translate(centre.dx, centre.dy)
      ..rotate(facing);

    final tail = Path()
      ..moveTo(-r * 0.9, 0)
      ..lineTo(-r * 1.8, -r * 0.7)
      ..lineTo(-r * 1.8, r * 0.7)
      ..close();
    canvas
      ..drawPath(tail, finPaint)
      ..drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: r * 2.4,
          height: r * 1.4,
        ),
        paint,
      )
      ..drawCircle(Offset(r * 0.7, -r * 0.18), r * 0.13, Paint()..color = _deep)
      ..restore();
  }

  void _renderSplash(Canvas canvas, _Splash splash) {
    final t = splash.age / _Splash.life;
    final radius = 18 + 70 * t;
    canvas.drawCircle(
      splash.at,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4 * (1 - t)
        ..color = _body.withValues(alpha: (1 - t) * 0.8),
    );
  }
}

/// An expanding ring where a fish was caught. Purely a reward animation.
class _Splash {
  _Splash(this.at, this.weight);

  static const life = 0.45;

  final Offset at;
  final double weight;
  double age = 0;
}
