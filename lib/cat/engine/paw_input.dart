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
    this.minTargetRadius = defaultMinTargetRadius,
    this.assistMultiplier = 2.5,
    this.generosity = 0.35,
    this.generousCooldown = const Duration(milliseconds: 1200),
    this.debounce = const Duration(milliseconds: 80),
  });

  static const defaultMinTargetRadius = 64.0;

  /// The screen width the generous tier is reasoned about against.
  ///
  /// A landscape phone. It only exists so [forDifficulty] can guarantee the
  /// generous reach lands outside the assist radius without being handed a
  /// screen — see the floor it computes.
  static const referenceWidth = 800.0;

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

  /// The assist that belongs with a given difficulty, 0 to 1.
  ///
  /// Without this the ladder has no teeth. Raising difficulty only ever made
  /// fish faster and smaller, and since hit testing floors every target at
  /// [minTargetRadius] and the assist radius is derived from that floor, the
  /// reach a cat actually had never changed. A simulated cat missing by 90px
  /// landed every single contact at difficulty 1.0 exactly as it did at 0.4, so
  /// the ladder climbed to the top and stayed there for everyone.
  ///
  /// Tightening the assist as the cat climbs is what closes the loop, and it is
  /// what docs/CAT_UX.md asks for: more reach for kittens and senior cats, less
  /// for a cat that is already scoring. The generous tier stays wider than the
  /// assist radius at every rung — `paw_input_test.dart` pins that, because a
  /// generous reach that falls inside the assist radius silently disables the
  /// tier and nothing else would fail.
  /// [catGenerosity] is the cat's own assist level, from its profile. Kittens
  /// and senior cats are given more, a cat that is already scoring less. It was
  /// documented on CatProfile from the first commit and read by nothing, so
  /// every cat got the same assist no matter what its profile said.
  factory PawInputConfig.forDifficulty(
    double difficulty, {
    double catGenerosity = 0.35,
  }) {
    final d = difficulty.clamp(0.0, 1.0).toDouble();
    final assist = 2.9 - d * 1.45;

    // The floor is the important line here. If the generous reach ever falls
    // inside the assist radius the tier is silently dead: nothing throws,
    // nothing logs, cats just quietly score less. It used to hold only because
    // the two constants happened to be chosen well, and a cat with a low
    // profile generosity would have broken it. Deriving the minimum from the
    // assist radius makes it true by construction instead of by luck.
    final floor = defaultMinTargetRadius * assist / referenceWidth * 1.25;
    final wanted = (0.5 - d * 0.3) * (catGenerosity.clamp(0.05, 1.0) / 0.35);

    return PawInputConfig(
      assistMultiplier: assist,
      generosity: math.max(floor, wanted),
    );
  }

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
  PawInput({this.config = const PawInputConfig()});

  /// Mutable on purpose: a session that is going badly swaps this for
  /// [PawInputConfig.moreForgiving] without rebuilding the input handler.
  PawInputConfig config;

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
      final effective = math.max(target.radius, config.minTargetRadius);

      if (distance <= effective) {
        return PawHit(tier: HitTier.direct, target: target, point: point);
      }
      if (distance < nearestDistance) {
        nearest = target;
        nearestDistance = distance;
      }
    }

    final assistRadius = math.max(nearest!.radius, config.minTargetRadius) *
        config.assistMultiplier;
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
    if (now.difference(last) >= config.debounce) return false;
    return (point - lastPoint).distance < config.minTargetRadius;
  }

  bool _canBeGenerous(double distance, Size screen, DateTime now) {
    if (config.generosity <= 0) return false;
    final reach = math.max(screen.width, screen.height) * config.generosity;
    if (distance > reach) return false;
    final last = _lastGenerousAt;
    return last == null || now.difference(last) >= config.generousCooldown;
  }

  void reset() {
    _lastGenerousAt = null;
    _lastContactAt = null;
    _lastContactPoint = null;
  }
}
