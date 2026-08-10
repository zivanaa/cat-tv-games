import 'dart:math' as math;
import 'dart:ui';

import '../audio/cat_sound.dart';
import '../games/laser/laser_game.dart';
import 'cat_surface_game.dart';

/// The Flame layer for the laser dot.
///
/// Draws, and nothing else — the chase, the escapes and the moment the dot
/// gives in all live in [LaserGame] as plain Dart, tested without a game loop.
///
/// The room is nearly black on purpose, and it is the one place this mode
/// deliberately departs from the pond. A laser only reads as a laser against
/// dark, and here the contrast rule that governs the whole cat surface works in
/// the mode's favour rather than against it: one small very bright thing on a
/// dim floor is the easiest target a cat will ever be given.
class LaserFieldGame extends CatSurfaceGame<LaserGame> {
  LaserFieldGame({
    LaserGame? rules,
    super.input,
    super.audio,
    super.sound,
    super.clock,
    super.limits,
    super.random,
  }) : super(rules: rules ?? LaserGame(random: random));

  static const _floor = Color(0xFF05080D);
  static const _rug = Color(0xFF101B26);

  /// Green rather than the red a real pointer uses, and this is a product
  /// decision rather than a palette one. docs/CAT_UX.md: cats are dichromatic,
  /// reds barely register, and a red dot on a dark floor is close to invisible
  /// to the animal being asked to chase it. Green sits where a cat sees well
  /// and stays recognisably "laser" to the person holding the phone.
  static const _beam = Color(0xFF9BFF6B);
  static const _halo = Color(0xFF3BE07A);

  LaserPhase _lastPhase = LaserPhase.resting;

  @override
  Color get backdrop => _floor;

  @override
  void updateMode(double dt) {
    // A noise on the frame the dot breaks away, so a cat that is looking
    // somewhere else still knows the chase moved.
    final phase = rules.view.phase;
    if (phase != _lastPhase) {
      if (phase == LaserPhase.fleeing) speak(CatSound.rustle, volume: 0.4);
      _lastPhase = phase;
    }
  }

  @override
  void renderMode(Canvas canvas, Rect bounds) {
    _renderRoom(canvas, bounds);

    final dot = rules.view;
    if (dot.brightness <= 0.01) return;

    final r = dot.radius;

    // Everything a bright point does on a dark surface: a wide soft bloom, a
    // tighter one, then the point itself. Three draws sharing one shader —
    // cheap enough for a surface that has to survive half an hour face-up on a
    // rug without throttling.
    _glow(canvas, dot.position, r * 9, 0.13 * dot.brightness);
    _glow(canvas, dot.position, r * 3.4, 0.3 * dot.brightness);

    canvas.drawCircle(
      dot.position,
      r,
      Paint()..color = _beam.withValues(alpha: dot.brightness),
    );

    // A hot white core, which is what makes it read as light rather than as a
    // green disc.
    canvas.drawCircle(
      dot.position,
      r * 0.45,
      Paint()
        ..color = const Color(0xFFFFFFFF).withValues(alpha: dot.brightness),
    );
  }

  /// The floor the dot is on. Barely there — a laser needs somewhere dark to be
  /// bright against, and anything busier would be competing with the one thing
  /// on screen that matters.
  void _renderRoom(Canvas canvas, Rect bounds) {
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = Gradient.radial(
          bounds.center.translate(
            math.sin(elapsed * 0.05) * bounds.width * 0.1,
            0,
          ),
          bounds.longestSide * 0.85,
          const [_rug, _floor],
        ),
    );
  }

  void _glow(Canvas canvas, Offset at, double radius, double alpha) {
    canvas
      ..save()
      ..translate(at.dx, at.dy)
      ..scale(radius, radius)
      ..drawCircle(
        Offset.zero,
        1,
        Paint()
          ..shader = Gradient.radial(Offset.zero, 1, [
            _halo.withValues(alpha: alpha),
            _halo.withValues(alpha: 0),
          ]),
      )
      ..restore();
  }
}
