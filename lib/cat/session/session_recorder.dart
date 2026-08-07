import '../../capture/highlight_detector.dart';
import '../engine/paw_input.dart';

/// Accumulates one play session: what the stats screen reads, and what decides
/// difficulty mid-session.
class SessionRecorder {
  SessionRecorder({
    required this.catId,
    required this.gameId,
    required this.startedAt,
    HighlightDetector? highlights,
  }) : highlights = highlights ?? HighlightDetector();

  final String catId;
  final String gameId;
  final DateTime startedAt;
  final HighlightDetector highlights;

  int contacts = 0;
  int directHits = 0;
  int assistedHits = 0;
  int generousHits = 0;
  double score = 0;

  final List<HighlightTrigger> savedMoments = [];

  int get hits => directHits + assistedHits + generousHits;

  /// True hit rate, ignoring the assist. This is the number that actually tells
  /// an owner whether their cat is getting better, so it is the one the stats
  /// screen leads with.
  double get accuracy => contacts == 0 ? 0 : directHits / contacts;

  HighlightTrigger? record(
    PawHit hit, {
    required DateTime at,
    bool multiTouch = false,
  }) {
    contacts++;
    score += hit.weight;
    _recent.add(hit.weight);
    if (_recent.length > steeringWindow) _recent.removeAt(0);
    switch (hit.tier) {
      case HitTier.direct:
        directHits++;
      case HitTier.assisted:
        assistedHits++;
      case HitTier.generous:
        generousHits++;
      case HitTier.miss:
        break;
    }

    final trigger = highlights.record(at: at, multiTouch: multiTouch);
    if (trigger != null) savedMoments.add(trigger);
    return trigger;
  }

  /// How many recent contacts one steering decision is made from.
  ///
  /// Lifetime totals were the first attempt and they seize up: a few hundred
  /// contacts in, no run of play can move the average far enough to cross a
  /// threshold, so difficulty freezes wherever it happened to be. A window
  /// keeps the ladder responsive for the whole session.
  static const steeringWindow = 24;

  /// Mean hit weight below which the pond must get easier. Not "fair" — easier.
  static const strugglingBelow = 0.5;

  /// Mean hit weight above which the cat has earned a harder pond.
  static const confidentAbove = 0.78;

  final List<double> _recent = [];
  int _contactsAtLastStep = 0;

  /// Mean [PawHit.weight] over the last [steeringWindow] contacts.
  ///
  /// Weight rather than [accuracy], and this is the whole fix. Accuracy counts
  /// direct hits only, but the assist is doing its job precisely when a cat
  /// lands assisted hits, so a cat that connected with every single contact
  /// still scored 0.41 accuracy and never earned a level. Weight separates the
  /// three tiers instead of discarding two of them: a simulated session came
  /// out at 1.00 for a sharp cat, 0.82 for an average one and 0.46 for a cat
  /// that was mostly flailing.
  double get recentQuality =>
      _recent.isEmpty ? 0 : _recent.reduce((a, b) => a + b) / _recent.length;

  /// One step up or down the difficulty ladder, or [current] if it is not time
  /// to move yet.
  ///
  /// Stateful on purpose: calling this consumes the window, so call it once per
  /// contact and never in a loop. Steps are rationed to one per
  /// [steeringWindow] contacts — roughly every eight seconds of steady play —
  /// because re-deciding on every contact turned the ladder into a jump. A
  /// sharp cat used to hit maximum difficulty inside the first thirty seconds,
  /// which is not a progression a human watching could feel either.
  ///
  /// Down moves further than up. Getting a struggling cat back to scoring
  /// matters more than pushing a confident one, and the failure this product
  /// dies from is a session that ends on zero.
  double suggestedDifficulty(double current) {
    if (_recent.length < steeringWindow) return current;
    if (contacts - _contactsAtLastStep < steeringWindow) return current;
    _contactsAtLastStep = contacts;

    if (recentQuality < strugglingBelow) {
      return (current - 0.12).clamp(0.0, 1.0).toDouble();
    }
    if (recentQuality > confidentAbove) {
      return (current + 0.08).clamp(0.0, 1.0).toDouble();
    }
    return current;
  }
}
