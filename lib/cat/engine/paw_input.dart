import 'dart:math' as math;
import 'dart:ui' show Offset, Size;

/// Forgiving hit detection for paws.
///
/// Cats are bad at touchscreens for physical reasons we cannot design around:
/// paw pads are drier and less conductive than fingertips, claws do not
/// register at all, and a bat at the screen is a fast glancing contact rather
/// than a deliberate tap. Strict hit testing produces zero-score sessions.
///
/// So hit testing runs in tiers. A touch resolves to the best tier it qualifies
/// for, and the tier is reported back so scoring can weight it — a direct hit is
/// worth more than an assisted one, but an assisted one is still a hit and still
/// triggers the reward animation. The cat cannot tell the difference. That is
/// the point.
enum HitTier {
  /// Inside the target's real radius.
  direct,

  /// Inside the assist radius. The cat aimed at it and was close.
  assisted,

  /// Missed everything, but a target was on screen and reachable, so the
  /// nearest one is credited. Only granted when [PawInputConfig.generosity]
  /// allows it and the cooldown has elapsed.
  generous,

  /// No credit. Either no targets on screen, or the touch was nowhere near one.
  miss,
}

class PawInputConfig {
  const PawInputConfig({
    this.minTargetRadius = 64.0,
    this.assistMultiplier = 2.5,
    this.generosity = 0.35,
    this.generousCooldown = const Duration(milliseconds: 1200),
    this.debounce = const Duration(milliseconds: 80),
  });

  /// No target is ever smaller than this for hit-testing purposes, however
  /// small it is drawn. Visual size and hit size are deliberately decoupled.
  final double minTargetRadius;

  /// Assist radius = effective radius * this.
  final double assistMultiplier;

  /// Fraction of the screen's *longer* side within which a total miss can still
  /// be credited to the nearest target. 0 disables the generous tier entirely.
  /// Raise for kittens and senior cats, lower for cats that are already scoring.
  ///
  /// The longer side, not the shorter one: at the default assist radius of 160px
  /// a shorter-side reach on a landscape phone comes out *below* the assist
  /// radius, which makes this tier unreachable. Play is mostly horizontal anyway.
  final double generosity;

  /// Minimum gap between two generous awards, so a cat sitting on the screen
  /// does not farm points.
  final Duration generousCooldown;

  /// Two contacts closer together in time than this at nearly the same point
  /// are one bat, not two taps.
  final Duration debounce;

  /// Easier variant for a cat that is not connecting.
  PawInputConfig get moreForgiving => PawInputConfig(
        minTargetRadius: minTargetRadius * 1.25,
        assistMultiplier: assistMultiplier * 1.2,
        generosity: math.min(generosity + 0.15, 0.6),
        generousCooldown: generousCooldown,
        debounce: debounce,
      );
}

/// Anything a cat can hit. Deliberately not a Flame component — game rules stay
/// testable without a game loop.
class PawTarget {
  const PawTarget({
    required this.id,
    required this.center,
    required this.radius,
    this.hittable = true,
  });

  final Object id;
  final Offset center;

  /// The target's own radius. [PawInput] raises it to
  /// [PawInputConfig.minTargetRadius] if it is smaller.
  final double radius;

  /// False while the target is spawning, fleeing, or already caught.
  final bool hittable;
}

class PawHit {
  const PawHit({required this.tier, this.target, required this.point});

  final HitTier tier;
  final PawTarget? target;
  final Offset point;

  bool get scored => tier != HitTier.miss;

  /// Score weight. Assisted and generous hits are worth less so that a cat that
  /// genuinely improves sees its numbers climb — the stats are read by the
  /// owner, and they should mean something.
  double get weight => switch (tier) {
        HitTier.direct => 1.0,
        HitTier.assisted => 0.7,
        HitTier.generous => 0.3,
        HitTier.miss => 0.0,
      };
}

class PawInput {
  PawInput({PawInputConfig config = const PawInputConfig()}) : _config = config;

  PawInputConfig _config;
  PawInputConfig get config => _config;
  set config(PawInputConfig value) => _config = value;

  DateTime? _lastGenerousAt;
  DateTime? _lastContactAt;
  Offset? _lastContactPoint;

  /// Resolve one pointer-down against the targets currently on screen.
  ///
  /// [now] is injected so tests do not depend on the wall clock.
  PawHit resolve({
    required Offset point,
    required List<PawTarget> targets,
    required Size screen,
    required DateTime now,
  }) {
    if (_isDuplicateContact(point, now)) {
      return PawHit(tier: HitTier.miss, point: point);
    }
    _lastContactAt = now;
    _lastContactPoint = point;

    final live = targets.where((t) => t.hittable).toList();
    if (live.isEmpty) return PawHit(tier: HitTier.miss, point: point);

    PawTarget? nearest;
    var nearestDistance = double.infinity;
    for (final target in live) {
      final distance = (target.center - point).distance;
      final effective = math.max(target.radius, _config.minTargetRadius);

      if (distance <= effective) {
        return PawHit(tier: HitTier.direct, target: target, point: point);
      }
      if (distance < nearestDistance) {
        nearest = target;
        nearestDistance = distance;
      }
    }

    final assistRadius =
        math.max(nearest!.radius, _config.minTargetRadius) * _config.assistMultiplier;
    if (nearestDistance <= assistRadius) {
      return PawHit(tier: HitTier.assisted, target: nearest, point: point);
    }

    if (_canBeGenerous(nearestDistance, screen, now)) {
      _lastGenerousAt = now;
      return PawHit(tier: HitTier.generous, target: nearest, point: point);
    }

    return PawHit(tier: HitTier.miss, point: point);
  }

  /// A single bat can produce several pointer events in a few milliseconds.
  bool _isDuplicateContact(Offset point, DateTime now) {
    final last = _lastContactAt;
    final lastPoint = _lastContactPoint;
    if (last == null || lastPoint == null) return false;
    if (now.difference(last) >= _config.debounce) return false;
    return (point - lastPoint).distance < _config.minTargetRadius;
  }

  bool _canBeGenerous(double distance, Size screen, DateTime now) {
    if (_config.generosity <= 0) return false;
    final reach = math.max(screen.width, screen.height) * _config.generosity;
    if (distance > reach) return false;
    final last = _lastGenerousAt;
    return last == null || now.difference(last) >= _config.generousCooldown;
  }

  void reset() {
    _lastGenerousAt = null;
    _lastContactAt = null;
    _lastContactPoint = null;
  }
}
