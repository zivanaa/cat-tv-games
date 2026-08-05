import 'dart:math' as math;
import 'dart:ui';

import 'fish_species.dart';

/// A point far enough from every edge that a fish of [radius] sits fully on
/// screen.
///
/// Spawning on the raw screen rectangle puts a fish partly outside the pond
/// about a fifth of the time — the legal band is `[radius, extent - radius]`,
/// not `[0, extent]`. The bounce then flattens it against the edge on its very
/// first frame, so a caught fish reappears already pinned to the glass instead
/// of swimming somewhere a cat can chase it.
Offset randomSpawn(Size screen, double radius, math.Random random) {
  double axis(double extent) {
    final span = extent - radius * 2;
    // A pond narrower than the fish is not a real case, but a negative span
    // would throw and take the session with it.
    return span <= 0 ? extent / 2 : radius + random.nextDouble() * span;
  }

  return Offset(axis(screen.width), axis(screen.height));
}

/// Everything the render layer needs about one fish, and nothing it could use
/// to change one.
///
/// The alternative was to let the renderer infer heading from where the fish
/// was last frame, which is guesswork that goes wrong exactly when it matters —
/// on the frame after a bounce. Handing it the real values keeps the split in
/// CLAUDE.md intact: rules decide, the Flame layer only draws.
class FishView {
  const FishView({
    required this.id,
    required this.species,
    required this.position,
    required this.radius,
    required this.facing,
    required this.wag,
    required this.darting,
    required this.caughtProgress,
  });

  final int id;
  final FishSpecies species;
  final Offset position;
  final double radius;

  /// The direction actually being travelled, in radians.
  final double facing;

  /// Sine phase, for a tail that beats in time with the swim.
  final double wag;

  final bool darting;

  /// 1.0 the instant it is caught, falling to 0 as it respawns. 0 when swimming.
  final double caughtProgress;
}

/// One fish. Swims a lazy sine path, darts when its species does, respawns
/// after being caught. Movement is intentionally slow and predictable: a cat
/// needs to be able to track and predict the target, which is the whole appeal.
class Fish {
  Fish({
    required this.id,
    required this.species,
    required this.position,
    required this.speed,
    required this.radius,
    math.Random? random,
  }) : _random = random ?? math.Random();

  final int id;
  final FishSpecies species;
  Offset position;

  /// The pond's base speed. The species multiplier is applied on top.
  double speed;
  double radius;
  final math.Random _random;

  static const _caughtDuration = Duration(milliseconds: 900);

  double _phase = 0;
  double _heading = 0;
  double _course = 0;
  double _dartLeft = 0;

  /// Which way the slow heading drift is currently turning.
  double _drift = 1;
  double _driftLeft = 0;

  Duration _caughtFor = Duration.zero;

  bool get isCaught => _caughtFor > Duration.zero;
  bool get hittable => !isCaught;
  bool get isDarting => _dartLeft > 0;

  FishView get view => FishView(
        id: id,
        species: species,
        position: position,
        radius: radius,
        facing: _course,
        wag: _phase,
        darting: isDarting,
        caughtProgress: isCaught
            ? _caughtFor.inMicroseconds / _caughtDuration.inMicroseconds
            : 0,
      );

  void update(double dt, Size screen) {
    if (isCaught) {
      _caughtFor -= Duration(microseconds: (dt * 1e6).round());
      if (_caughtFor <= Duration.zero) _respawn(screen);
      return;
    }

    _advanceDart(dt);
    _advanceDrift(dt);

    _phase += dt * species.wobbleRate;
    final wobble = math.sin(_phase) * species.wobbleAmount;

    // The direction actually travelled, which is the heading plus the wobble.
    // The distinction matters at the walls below.
    var course = _heading + wobble;
    final speedNow =
        speed * species.speedScale * (isDarting ? species.dartSpeedScale : 1);
    position = position.translate(
      math.cos(course) * speedNow * dt,
      math.sin(course) * speedNow * dt,
    );

    // Bounce off the edges rather than wrapping — a fish vanishing at one edge
    // and reappearing at the other breaks a cat's tracking.
    //
    // Reflect the course, not the bare heading. Reflecting the heading alone
    // leaves the wobble still pointing into the wall, so the fish keeps being
    // clamped to the edge frame after frame and grinds along it until the sine
    // swings far enough to free it.
    var bounced = false;
    if (position.dx < radius || position.dx > screen.width - radius) {
      course = math.pi - course;
      bounced = true;
      position = Offset(
        position.dx.clamp(radius, screen.width - radius).toDouble(),
        position.dy,
      );
    }
    if (position.dy < radius || position.dy > screen.height - radius) {
      course = -course;
      bounced = true;
      position = Offset(
        position.dx,
        position.dy.clamp(radius, screen.height - radius).toDouble(),
      );
    }
    // Store the heading that reproduces the reflected course once this frame's
    // wobble is added back to it.
    if (bounced) {
      _heading = course - wobble;
      // A fish that just hit a wall does not also dart into it.
      _dartLeft = 0;
    }
    _course = course;
  }

  /// Darts are rationed. They are the most arresting thing a target does, and a
  /// pond where everything is darting is the fast random motion that CAT_UX.md
  /// says loses cats.
  void _advanceDart(double dt) {
    if (_dartLeft > 0) {
      _dartLeft -= dt;
      return;
    }
    if (species.dartsPerSecond <= 0) return;
    if (_random.nextDouble() < species.dartsPerSecond * dt) {
      _dartLeft = species.dartSeconds;
    }
  }

  /// A slow wander, so a fish does not hold one bearing until it meets a wall.
  /// The turn reverses every couple of seconds rather than being re-rolled each
  /// frame, which would be a jitter rather than a curve.
  void _advanceDrift(double dt) {
    _driftLeft -= dt;
    if (_driftLeft <= 0) {
      _driftLeft = 1.5 + _random.nextDouble() * 2.5;
      _drift = _random.nextBool() ? 1 : -1;
    }
    _heading += _drift * species.turnRate * dt;
  }

  /// Caught. Stays gone briefly so the cat registers cause and effect.
  void catchIt() => _caughtFor = _caughtDuration;

  void _respawn(Size screen) {
    position = randomSpawn(screen, radius, _random);
    _heading = _random.nextDouble() * math.pi * 2;
    _course = _heading;
    // Start the sine over so the fish leaves on the heading it was given.
    _phase = 0;
    _dartLeft = 0;
  }
}
