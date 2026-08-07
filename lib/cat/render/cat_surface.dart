import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import '../../shared/widgets/exit_guard.dart';
import '../audio/cat_audio.dart';
import '../engine/cat_game.dart';
import '../engine/paw_input.dart';
import '../session/session_clock.dart';
import '../session/session_recorder.dart';
import 'fish_pond_game.dart';

/// The cat surface. Once this is up, a cat owns the screen.
///
/// It takes the whole window, has no back button and no controls, and the only
/// way out is the long press in the corner that [ExitGuard] provides. Every
/// contact is fed to the session recorder, which is what later drives difficulty
/// and the stats the owner reads.
class CatSurface extends StatefulWidget {
  const CatSurface({
    super.key,
    required this.onExit,
    this.catId = 'default',
    this.limits = const SessionLimits(),
  });

  final VoidCallback onExit;
  final String catId;

  /// How long the session runs and how long it takes to close. Configurable
  /// because the owner will eventually want to set it, and because a fifteen
  /// minute default is unwatchable to develop against — pass a few seconds to
  /// see the wind-down happen.
  final SessionLimits limits;

  @override
  State<CatSurface> createState() => _CatSurfaceState();
}

class _CatSurfaceState extends State<CatSurface> {
  final CatAudio _audio = FlameCatAudio();
  late final FishPondGame _game = FishPondGame(
    audio: _audio,
    limits: widget.limits,
  );
  late final SessionRecorder _session = SessionRecorder(
    catId: widget.catId,
    gameId: _game.rules.id,
    startedAt: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();
    // Fire and forget. The pond is playable while the samples land; the only
    // cost of a contact before they do is a missing splash, and blocking the
    // first frame on an audio plugin would be worse.
    unawaited(_audio.preload());
  }

  @override
  void dispose() {
    unawaited(_audio.dispose());
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    // The session ended itself. The screen is dark and the pond is gone, so a
    // contact here is a cat batting at a black rectangle — not something the
    // stats should count.
    //
    // Note what does *not* happen: the surface stays put. Returning to the
    // human screen on its own would hand an unsupervised cat a live UI with
    // buttons on it, which is the whole thing lib/cat exists to prevent. The
    // way out is still the long press in the corner, by a person.
    if (_game.clock.phase == SessionPhase.ended) return;

    final now = DateTime.now();
    final hit = _game.contact(event.localPosition, now);
    _session.record(hit, at: now);

    // The game gets easier when the cat is not connecting, never harder to be
    // "fair". A session that ends on a score of zero is the failure mode the
    // whole input design exists to avoid.
    final next = _session.suggestedDifficulty(_game.rules.difficulty);
    if (next != _game.rules.difficulty) {
      _game.rules.difficulty = next;
      // The assist moves with the ladder. Speed and size alone do not make a
      // level harder while every target is floored to the same hit radius.
      _game.input.config = PawInputConfig.forDifficulty(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ExitGuard(
      onExit: widget.onExit,
      child: Listener(
        // Pointer down, not tap. A paw swipe rarely produces a clean tap.
        onPointerDown: _onPointerDown,
        behavior: HitTestBehavior.opaque,
        child: GameWidget(game: _game),
      ),
    );
  }
}
