import 'dart:ui';

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

  HighlightTrigger? record(PawHit hit, {required DateTime at, bool multiTouch = false}) {
    contacts++;
    score += hit.weight;
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

  /// Feeds back into [PawInput] and the game's difficulty. A cat below this is
  /// not connecting and the game must get easier, not "fair".
  static const strugglingBelow = 0.15;

  double suggestedDifficulty(double current) {
    if (contacts < 12) return current;
    if (accuracy < strugglingBelow) return (current - 0.15).clamp(0.0, 1.0).toDouble();
    if (accuracy > 0.6) return (current + 0.1).clamp(0.0, 1.0).toDouble();
    return current;
  }
}
