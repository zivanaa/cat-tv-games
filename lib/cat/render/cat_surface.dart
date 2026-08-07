import 'package:flame/game.dart';
import 'package:flutter/widgets.dart';

import '../../shared/widgets/exit_guard.dart';
import '../engine/paw_input.dart';
import '../session/session_recorder.dart';
import 'fish_pond_game.dart';

/// The cat surface. Once this is up, a cat owns the screen.
///
/// It takes the whole window, has no back button and no controls, and the only
/// way out is the long press in the corner that [ExitGuard] provides. Every
/// contact is fed to the session recorder, which is what later drives difficulty
/// and the stats the owner reads.
class CatSurface extends StatefulWidget {
  const CatSurface({super.key, required this.onExit, this.catId = 'default'});

  final VoidCallback onExit;
  final String catId;

  @override
  State<CatSurface> createState() => _CatSurfaceState();
}

class _CatSurfaceState extends State<CatSurface> {
  late final FishPondGame _game = FishPondGame();
  late final SessionRecorder _session = SessionRecorder(
    catId: widget.catId,
    gameId: _game.rules.id,
    startedAt: DateTime.now(),
  );

  void _onPointerDown(PointerDownEvent event) {
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
