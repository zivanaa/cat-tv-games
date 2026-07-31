import 'dart:math' as math;
import 'dart:ui';

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
    final dx = math.cos(_heading + wobble) * speed * dt;
    final dy = math.sin(_heading + wobble) * speed * dt;
    position = position.translate(dx, dy);

    // Bounce off the edges rather than wrapping — a fish vanishing at one edge
    // and reappearing at the other breaks a cat's tracking.
    if (position.dx < radius || position.dx > screen.width - radius) {
      _heading = math.pi - _heading;
      position = Offset(
        position.dx.clamp(radius, screen.width - radius).toDouble(),
        position.dy,
      );
    }
    if (position.dy < radius || position.dy > screen.height - radius) {
      _heading = -_heading;
      position = Offset(
        position.dx,
        position.dy.clamp(radius, screen.height - radius).toDouble(),
      );
    }
  }

  /// Caught. Stays gone briefly so the cat registers cause and effect.
  void catchIt() => _caughtFor = const Duration(milliseconds: 900);

  void _respawn(Size screen) {
    position = Offset(
      _random.nextDouble() * screen.width,
      _random.nextDouble() * screen.height,
    );
    _heading = _random.nextDouble() * math.pi * 2;
  }
}
