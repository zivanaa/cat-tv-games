import '../engine/cat_game.dart';

/// Where a session is in its own lifetime.
enum SessionPhase {
  playing,

  /// The last stretch before the cap. Targets slow and the light goes down.
  windingDown,

  /// Over. Nothing is simulated and nothing is drawn but the dark.
  ended,
}

/// Runs the session out and ends it.
///
/// This exists because cats do not stop. docs/CAT_UX.md is blunt about it —
/// the animal does not self-regulate, so the app has to, and a session that
/// runs until the battery dies is the app's fault rather than the cat's.
///
/// The wind-down is the part that matters and the part easiest to skip. Cutting
/// straight to black leaves a cat staring at a dead screen, and what it learns
/// from that is that the app stops being fun — which costs the next session,
/// not this one. Slowing the pond down and taking the light with it lets the
/// session end while the cat is already losing interest.
///
/// Plain Dart on purpose: every threshold here is worth a test, and none of it
/// needs a game loop to check.
class SessionClock {
  SessionClock({this.limits = const SessionLimits()});

  final SessionLimits limits;

  Duration _elapsed = Duration.zero;
  Duration get elapsed => _elapsed;

  /// When the light starts going down. Never negative, so a wind-down longer
  /// than the session itself simply means the whole session is one.
  Duration get windDownBegins {
    final start = limits.maxDuration - limits.windDown;
    return start.isNegative ? Duration.zero : start;
  }

  void advance(double dt) {
    if (dt <= 0) return;
    _elapsed += Duration(microseconds: (dt * 1e6).round());
  }

  SessionPhase get phase {
    if (_elapsed >= limits.maxDuration) return SessionPhase.ended;
    if (_elapsed >= windDownBegins) return SessionPhase.windingDown;
    return SessionPhase.playing;
  }

  /// 0 when the wind-down starts, 1 when the session is over.
  double get windDownProgress {
    if (phase == SessionPhase.ended) return 1;
    if (_elapsed <= windDownBegins) return 0;
    final span =
        limits.maxDuration.inMicroseconds - windDownBegins.inMicroseconds;
    // A zero-length wind-down is a valid setting and must not divide by zero.
    // It simply means the session snaps shut, which is what the caller asked
    // for even if CAT_UX.md would rather it did not.
    if (span <= 0) return 1;
    final into = _elapsed.inMicroseconds - windDownBegins.inMicroseconds;
    return (into / span).clamp(0.0, 1.0);
  }

  /// Multiplier on simulated time. The pond does not stop dead — it settles.
  ///
  /// Never reaches zero: a target frozen mid-screen is the stillness CAT_UX.md
  /// warns about, and while the light is still coming down there is something
  /// to see. Once the phase is [SessionPhase.ended] the caller stops simulating
  /// entirely, which is where the motion actually stops.
  double get pace => 1 - windDownProgress * 0.88;

  void reset() => _elapsed = Duration.zero;
}
