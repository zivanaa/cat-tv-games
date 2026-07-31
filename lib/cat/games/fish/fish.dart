import 'dart:math' as math;
import 'dart:ui';

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

/// One fish. Swims a lazy sine path, darts when startled, respawns after being
/// caught. Movement is intentionally slow and predictable: a cat needs to be
/// able to track and predict the target, which is the whole appeal.
class Fish {
  Fish({
    required this.id,
    required this.position,
    required this.speed,
    required this.radius,
    math.Random? random,
  }) : _random = random ?? math.Random();

  final int id;
  Offset position;
  double speed;
  double radius;
  final math.Random _random;

  double _phase = 0;
  double _heading = 0;
  Duration _caughtFor = Duration.zero;

  bool get isCaught => _caughtFor > Duration.zero;
  bool get hittable => !isCaught;

  void update(double dt, Size screen) {
    if (isCaught) {
      _caughtFor -= Duration(microseconds: (dt * 1e6).round());
      if (_caughtFor <= Duration.zero) _respawn(screen);
      return;
    }

    _phase += dt * 1.4;
    final wobble = math.sin(_phase) * 0.6;

    // The direction actually travelled, which is the heading plus the wobble.
    // The distinction matters at the walls below.
    var course = _heading + wobble;
    position = position.translate(
      math.cos(course) * speed * dt,
      math.sin(course) * speed * dt,
    );

    // Bounce off the edges rather than wrapping — a fish vanishing at one edge
    // and reappearing at the other breaks a cat's tracking.
    //
    // Reflect the course, not the bare heading. Reflecting the heading alone
    // leaves the wobble still pointing into the wall, so the fish keeps being
    // clamped to the edge frame after frame and grinds along it until the sine
    // swings far enough to free it. A cat tracks that fish to the edge and then
    // watches it stop, which is exactly the stillness CAT_UX.md warns about.
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
    if (bounced) _heading = course - wobble;
  }

  /// Caught. Stays gone briefly so the cat registers cause and effect.
  void catchIt() => _caughtFor = const Duration(milliseconds: 900);

  void _respawn(Size screen) {
    position = randomSpawn(screen, radius, _random);
    _heading = _random.nextDouble() * math.pi * 2;
    // Start the sine over so the fish leaves on the heading it was given.
    _phase = 0;
  }
}
