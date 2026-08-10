import 'dart:math' as math;
import 'dart:ui';

import '../../engine/cat_game.dart';
import '../../engine/paw_input.dart';

/// What the dot is doing, for the render layer.
enum LaserPhase {
  /// Sitting still-ish at a waypoint, twitching.
  resting,

  /// Crossing to its next waypoint.
  travelling,

  /// Getting away from a paw that just landed.
  fleeing,

  /// Caught. Dark, briefly.
  out,
}

/// A read-only snapshot for the render layer.
class LaserView {
  const LaserView({
    required this.position,
    required this.radius,
    required this.phase,
    required this.tiring,
    required this.brightness,
  });

  final Offset position;
  final double radius;
  final LaserPhase phase;

  /// 0 to 1, how close the dot is to letting itself be caught. The renderer
  /// dims and reddens nothing — see the note in [LaserGame] — but it does slow
  /// the flicker, which is the honest way to show a laser running out of fight.
  final double tiring;

  /// 0 when out, 1 when fully lit. Its own value so the dot can fade rather
  /// than blink, which is what stops a reappearance reading as a teleport.
  final double brightness;
}

/// The laser dot. It runs from the paw, and it always loses in the end.
///
/// The whole mode lives or dies on one tension, which is exactly what the TODO
/// in game_catalog.dart asked for: a dot that never lets the cat win instantly,
/// and always lets it win eventually. Get the first half wrong and there is no
/// chase. Get the second half wrong and the session ends on a score of zero,
/// which docs/NEXT_STEPS.md names as the most likely way this product fails.
///
/// It is resolved with a count rather than with chance. Every contact the dot
/// survives is an escape; after enough escapes it is tired and the next contact
/// takes it. Randomness would have made "eventually" a probability, and a cat
/// that rolled badly for five minutes would have got the zero-score session
/// anyway.
///
/// On speed: a laser is a faster thing than a fish, and CAT_UX.md warns that
/// fast random motion reads as noise. The resolution is that this is not random
/// — it is a dart to a point followed by a definite stop. The stop is what
/// makes it trackable, and it is also the thing real laser pointers do that
/// cats respond to. Motion without pauses would be the noise the doc means.
class LaserGame implements CatGame {
  LaserGame({math.Random? random}) : _random = random ?? math.Random();

  static const gameId = 'laser';

  /// How long the dot is dark after being caught. Long enough that the cat
  /// registers it won, short enough that it does not lose interest.
  static const caughtPause = 0.75;

  /// A cat that wanders off should not come back to a free catch, so pursuit
  /// that stops being pursuit is slowly forgotten.
  static const forgetAfter = 7.0;

  final math.Random _random;

  double _difficulty = 0.4;
  Size _screen = Size.zero;
  bool _placed = false;

  Offset _position = Offset.zero;
  Offset _waypoint = Offset.zero;
  double _restLeft = 0;
  double _outFor = 0;
  double _sinceContact = 0;
  double _twitch = 0;
  bool _fleeing = false;

  /// Contacts survived since the last catch.
  int _escapes = 0;

  /// Catches this session. The renderer does not use it; the session recorder
  /// gets the same information from PawInput, so this is only here to make the
  /// rules readable from a test.
  int caught = 0;

  @override
  String get id => gameId;

  @override
  String get displayName => 'Laser dot';

  @override
  double get difficulty => _difficulty;

  @override
  set difficulty(double value) =>
      _difficulty = value.clamp(0.0, 1.0).toDouble();

  /// Escapes the dot gets before it is catchable.
  ///
  /// One at the easy end, not zero: a dot taken on the very first swipe is not
  /// a chase, and the mode would be pointless. Five at the hard end, which at a
  /// realistic rate of contact is a chase of maybe fifteen seconds — long
  /// enough to be worth winning, short enough that a cat does not give up.
  int get escapesNeeded => 1 + (_difficulty * 4).round();

  /// True once the dot has run out of fight and the next contact takes it.
  bool get isTiring => _escapes >= escapesNeeded;

  double get _cruise => 190 + _difficulty * 190;
  double get _flee => 620 + _difficulty * 380;

  /// A tired dot moves slower and rests longer, so the cat can see it is
  /// winning before it wins. Feedback the animal can actually read beats a
  /// catch that arrives from nowhere.
  double get _speedNow {
    final base = _fleeing ? _flee : _cruise;
    return isTiring ? base * 0.55 : base;
  }

  double get _restDuration {
    final base = 0.28 + _random.nextDouble() * (0.75 - _difficulty * 0.35);
    return isTiring ? base * 1.8 : base;
  }

  /// The drawn dot is small on purpose. PawInput floors every target at
  /// minTargetRadius, so a cat still gets a fair reach at it — the gap between
  /// what is drawn and what is hit is the assist doing its job.
  double get _radius => 15 - _difficulty * 4;

  @override
  List<PawTarget> get targets => [
        PawTarget(
          id: gameId,
          center: _position,
          radius: _radius,
          hittable: _outFor <= 0,
        ),
      ];

  LaserView get view => LaserView(
        position: _position,
        radius: _radius,
        phase: _outFor > 0
            ? LaserPhase.out
            : _fleeing
                ? LaserPhase.fleeing
                : _restLeft > 0
                    ? LaserPhase.resting
                    : LaserPhase.travelling,
        tiring:
            escapesNeeded == 0 ? 1 : (_escapes / escapesNeeded).clamp(0.0, 1.0),
        brightness:
            _outFor > 0 ? (1 - _outFor / caughtPause).clamp(0.0, 1.0) : 1,
      );

  @override
  void update(double dt, Size screen) {
    _screen = screen;
    if (!_placed) {
      _position = _somewhere(screen);
      _waypoint = _position;
      _placed = true;
    }

    _sinceContact += dt;
    if (_sinceContact >= forgetAfter && _escapes > 0) {
      _escapes--;
      _sinceContact = 0;
    }

    if (_outFor > 0) {
      _outFor -= dt;
      if (_outFor <= 0) {
        _outFor = 0;
        // Back on somewhere else. It went dark first, which is why this reads
        // as a lamp being switched rather than the target teleporting —
        // CAT_UX.md rules the second one out and this mode has to respect it
        // even though a laser is allowed to blink.
        _position = _somewhere(screen);
        _waypoint = _position;
        _restLeft = 0.2;
      }
      return;
    }

    if (_restLeft > 0) {
      _restLeft -= dt;
      // Never actually still. A dot that stops dead is a dot a cat stops
      // watching, and a real pointer never holds perfectly steady anyway.
      _twitch += dt * 17;
      _position = _clampIn(
        _waypoint.translate(
          math.sin(_twitch) * 2.1,
          math.cos(_twitch * 1.4) * 2.1,
        ),
        screen,
      );
      return;
    }

    final toGo = _waypoint - _position;
    final step = _speedNow * dt;
    if (toGo.distance <= step) {
      _position = _waypoint;
      _restLeft = _restDuration;
      _fleeing = false;
      _waypoint = _nextWaypoint(screen);
    } else {
      _position += toGo / toGo.distance * step;
    }
  }

  @override
  void onHit(PawHit hit) {
    if (!hit.scored || _outFor > 0) return;
    _sinceContact = 0;

    if (isTiring) {
      caught++;
      _escapes = 0;
      _outFor = caughtPause;
      _fleeing = false;
      return;
    }

    _escapes++;
    _fleeAt(hit.point);
  }

  /// Straight away from the paw, as far as the pond allows.
  void _fleeAt(Offset paw) {
    if (_screen == Size.zero) return;
    var away = _position - paw;
    if (away.distance < 1) {
      // Landed dead on it. Any direction will do, but it has to be a direction
      // — normalising a zero vector is how this would have produced NaN and
      // put the dot somewhere undrawable for the rest of the session.
      final angle = _random.nextDouble() * math.pi * 2;
      away = Offset(math.cos(angle), math.sin(angle));
    }
    final unit = away / away.distance;
    final reach = _screen.shortestSide * (0.45 + _random.nextDouble() * 0.3);

    _fleeing = true;
    _restLeft = 0;
    _waypoint = _clampIn(_position + unit * reach, _screen);
  }

  Offset _nextWaypoint(Size screen) {
    // Far enough to be worth following. Short hops read as jitter, which is
    // the noise CAT_UX.md says loses cats.
    final reach = screen.shortestSide * (0.25 + _random.nextDouble() * 0.45);
    final angle = _random.nextDouble() * math.pi * 2;
    return _clampIn(
      _position + Offset(math.cos(angle), math.sin(angle)) * reach,
      screen,
    );
  }

  Offset _somewhere(Size screen) => Offset(
        _margin(screen.width),
        _margin(screen.height),
      );

  double _margin(double extent) {
    final span = extent - _radius * 4;
    return span <= 0 ? extent / 2 : _radius * 2 + _random.nextDouble() * span;
  }

  /// Keeps the dot on screen.
  ///
  /// The bounds are themselves clamped against the middle, which looks
  /// paranoid until the pond is narrower than the margin — then the low bound
  /// would sit above the high one and clamp throws, taking the session with it.
  Offset _clampIn(Offset at, Size screen) {
    final r = _radius * 2;
    double axis(double value, double extent) {
      final middle = extent / 2;
      return value.clamp(
        math.min(r, middle),
        math.max(extent - r, middle),
      );
    }

    return Offset(axis(at.dx, screen.width), axis(at.dy, screen.height));
  }

  @override
  void reset() {
    _placed = false;
    _escapes = 0;
    caught = 0;
    _outFor = 0;
    _restLeft = 0;
    _fleeing = false;
    _sinceContact = 0;
  }
}
