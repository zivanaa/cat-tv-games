import 'dart:async';

import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import '../../data/models/cat_profile.dart';
import '../../shared/widgets/exit_guard.dart';
import '../audio/cat_audio.dart';
import '../engine/cat_game.dart';
import '../engine/paw_input.dart';
import '../games/fish/fish_game.dart';
import '../session/session_clock.dart';
import '../session/session_recorder.dart';
import 'cat_surface_game.dart';
import 'cat_surface_games.dart';

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
    required this.profile,
    this.onSessionEnd,
    this.mode = FishGame.gameId,
    this.limits = const SessionLimits(),
  });

  final VoidCallback onExit;

  /// The cat playing. Its difficulty is where this session starts, rather than
  /// the middle of the ladder every time, and its generosity sets how much
  /// reach PawInput gives it.
  final CatProfile profile;

  /// Called with the profile as the session leaves it, so the climb survives
  /// the session it happened in.
  final void Function(CatProfile)? onSessionEnd;

  /// Which mode to play, by its id in `gameCatalog`. An unknown id falls back
  /// to the pond rather than throwing: this is the surface a cat is left alone
  /// with, and a crash here is a dead screen nobody is watching.
  final String mode;

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
  late final CatSurfaceGame<CatGame> _game =
      (catSurfaceGames[widget.mode] ?? catSurfaceGames[FishGame.gameId]!)(
    audio: _audio,
    limits: widget.limits,
  );
  late final SessionRecorder _session = SessionRecorder(
    catId: widget.profile.id,
    gameId: _game.rules.id,
    startedAt: DateTime.now(),
  );

  @override
  void initState() {
    super.initState();

    // The session opens where the cat left off, not in the middle of the
    // ladder. Without this a cat that spent twenty minutes climbing to 0.9
    // started again at 0.4 the next time, and the whole adaptive difficulty
    // only ever meant anything within one sitting.
    _game.rules.difficulty = widget.profile.difficulty;
    _game.input.config = PawInputConfig.forDifficulty(
      widget.profile.difficulty,
      catGenerosity: widget.profile.generosity,
    );

    // Fire and forget. The pond is playable while the samples land; the only
    // cost of a contact before they do is a missing splash, and blocking the
    // first frame on an audio plugin would be worse.
    unawaited(_audio.preload());
  }

  @override
  void dispose() {
    // Where the cat got to, handed back on the way out. dispose rather than the
    // exit gesture, because a session can also end by its own clock or by the
    // route going away, and a climb that only survives one of those three is
    // worse than one that survives none — it would look like it worked.
    widget.onSessionEnd?.call(
      widget.profile.copyWith(difficulty: _game.rules.difficulty),
    );
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
      // The cat's own generosity rides along, so a kitten stays a kitten as
      // the pond gets harder.
      _game.input.config = PawInputConfig.forDifficulty(
        next,
        catGenerosity: widget.profile.generosity,
      );
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
