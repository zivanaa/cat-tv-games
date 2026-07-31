import 'dart:collection';

/// Decides when something worth keeping is happening.
///
/// The camera runs into a discarding ring buffer the whole session. This class
/// is what turns that buffer into a saved clip. Recording continuously instead
/// would fill storage, cook the battery, and make the App Store reviewer ask why
/// a cat app needs thirty minutes of camera footage.
///
/// The signals are deliberately cheap — no ML, no frame analysis. What makes a
/// clip funny to an owner is almost always a burst of frantic activity, and taps
/// per second measures that well enough.
class HighlightDetector {
  HighlightDetector({
    this.window = const Duration(seconds: 4),
    this.triggerScore = 1.0,
    this.cooldown = const Duration(seconds: 25),
    this.burstRate = 3.0,
  });

  /// How far back activity is measured.
  final Duration window;

  /// Score at or above which a clip is saved.
  final double triggerScore;

  /// Minimum gap between saved clips. Without this a single excited cat
  /// generates forty near-identical videos in one session.
  final Duration cooldown;

  /// Taps per second that counts as a full-strength burst.
  final double burstRate;

  final Queue<_Contact> _contacts = Queue();
  DateTime? _lastTriggerAt;

  /// Feed every resolved contact here, hit or miss. Misses matter — a cat
  /// flailing at a fish and missing is funnier than one that connects.
  ///
  /// Returns a trigger when the buffer should be flushed to disk, else null.
  HighlightTrigger? record({
    required DateTime at,
    required bool multiTouch,
  }) {
    _contacts.addLast(_Contact(at, multiTouch));
    _prune(at);

    if (_lastTriggerAt != null && at.difference(_lastTriggerAt!) < cooldown) {
      return null;
    }

    final score = _score();
    if (score < triggerScore) return null;

    _lastTriggerAt = at;
    return HighlightTrigger(at: at, score: score, contacts: _contacts.length);
  }

  /// 0.0 to roughly 1.6. Rate is the bulk of it; both paws at once is the
  /// single most reliable sign a cat is fully committed.
  double _score() {
    if (_contacts.isEmpty) return 0;
    final seconds = window.inMilliseconds / 1000;
    final rate = _contacts.length / seconds;
    final rateScore = (rate / burstRate).clamp(0.0, 1.2).toDouble();

    final bothPaws = _contacts.any((c) => c.multiTouch);
    return rateScore + (bothPaws ? 0.4 : 0.0);
  }

  void _prune(DateTime now) {
    while (
        _contacts.isNotEmpty && now.difference(_contacts.first.at) > window) {
      _contacts.removeFirst();
    }
  }

  void reset() {
    _contacts.clear();
    _lastTriggerAt = null;
  }
}

class HighlightTrigger {
  const HighlightTrigger({
    required this.at,
    required this.score,
    required this.contacts,
  });

  final DateTime at;
  final double score;
  final int contacts;

  /// Shown in the gallery so the owner knows why a clip was kept.
  String get label => score >= 1.3 ? 'Full send' : 'Busy paws';
}

class _Contact {
  const _Contact(this.at, this.multiTouch);
  final DateTime at;
  final bool multiTouch;
}
