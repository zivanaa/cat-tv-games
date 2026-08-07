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

/// Where a fish joining an already-running pond starts, and the way it faces.
///
/// Just outside one edge, pointing in. A fish that is needed mid-session used
/// to be placed at a random point in open water, which meant it appeared out of
/// nothing in the middle of a screen a cat was watching. docs/CAT_UX.md rules
/// out teleporting a target from edge to edge because it breaks tracking;
/// materialising in clear water is the same break without even the excuse of
/// having been somewhere first.
({Offset at, double heading}) edgeEntry(
  Size screen,
  double radius,
  math.Random random,
) {
  final margin = radius * 1.3;
  // A spread rather than straight in, so arrivals do not all cross the pond on
  // the same rail.
  final skew = (random.nextDouble() - 0.5) * 1.1;
  return switch (random.nextInt(4)) {
    0 => (
        at: Offset(-margin, random.nextDouble() * screen.height),
        heading: skew,
      ),
    1 => (
        at: Offset(screen.width + margin, random.nextDouble() * screen.height),
        heading: math.pi + skew,
      ),
    2 => (
        at: Offset(random.nextDouble() * screen.width, -margin),
        heading: math.pi / 2 + skew,
      ),
    _ => (
        at: Offset(random.nextDouble() * screen.width, screen.height + margin),
        heading: -math.pi / 2 + skew,
      ),
  };
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
    required this.entering,
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

  /// Still crossing in from outside the pond, and not yet hittable.
  final bool entering;

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
    double heading = 0,
    bool entering = false,
    math.Random? random,
  })  : _heading = heading,
        _course = heading,
        _entering = entering,
        _random = random ?? math.Random();

  final int id;
  final FishSpecies species;
  Offset position;

  /// The pond's base speed. The species multiplier is applied on top.
  double speed;
  double radius;
  final math.Random _random;

  static const _caughtDuration = Duration(milliseconds: 900);

  double _phase = 0;
  double _heading;
  double _course;
  double _dartLeft = 0;

  /// Still swimming in from outside the pond. The wall bounce is suspended
  /// until it is fully inside, or the fish would be clamped flat against the
  /// edge it is entering through on its very first frame.
  bool _entering;
  double _enteringFor = 0;

  /// After this it is placed inside and told to get on with it. A fish whose
  /// wander happened to turn it around while entering would otherwise drift
  /// away from the pond and never come back.
  static const _enteringTimeout = 4.0;

  /// Which way the slow heading drift is currently turning.
  double _drift = 1;
  double _driftLeft = 0;

  Duration _caughtFor = Duration.zero;

  bool get isCaught => _caughtFor > Duration.zero;
  bool get isDarting => _dartLeft > 0;

  /// Still on its way in from the edge.
  bool get isEntering => _entering;

  /// Not while it is half off the screen. A target a cat cannot fully see is
  /// one it cannot fairly be asked to hit, and PawInput's assist would happily
  /// award a fish whose centre is still outside the pond.
  bool get hittable => !isCaught && !_entering;

  FishView get view => FishView(
        id: id,
        species: species,
        position: position,
        radius: radius,
        facing: _course,
        wag: _phase,
        darting: isDarting,
        entering: _entering,
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

    if (_entering) {
      _course = course;
      _advanceEntry(dt, screen);
      return;
    }

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

  /// Runs while a fish is still crossing in from outside. The bounce stays off
  /// until it is fully inside, then it becomes an ordinary fish.
  void _advanceEntry(double dt, Size screen) {
    _enteringFor += dt;
    final inside = position.dx >= radius &&
        position.dx <= screen.width - radius &&
        position.dy >= radius &&
        position.dy <= screen.height - radius;

    if (inside) {
      _entering = false;
      return;
    }
    if (_enteringFor >= _enteringTimeout) {
      // Gave up on swimming in. Better a fish that is simply there than one
      // that wandered off and left the pond a target short.
      position = Offset(
        position.dx.clamp(radius, screen.width - radius).toDouble(),
        position.dy.clamp(radius, screen.height - radius).toDouble(),
      );
      _entering = false;
    }
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

  /// A caught fish comes back by swimming in from an edge rather than blinking
  /// into open water. It was gone for 900ms and the cat watched it go; having
  /// it reappear mid-pond is the tracking break all over again.
  void _respawn(Size screen) {
    final entry = edgeEntry(screen, radius, _random);
    position = entry.at;
    _heading = entry.heading;
    _course = entry.heading;
    _entering = true;
    _enteringFor = 0;
    // Start the sine over so the fish leaves on the heading it was given.
    _phase = 0;
    _dartLeft = 0;
  }
}
