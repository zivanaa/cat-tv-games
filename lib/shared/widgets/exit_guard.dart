import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The only way out of the cat surface.
///
/// A tap cannot exit, and neither can the system back gesture — a cat produces
/// both constantly. A two-second hold in a corner is beyond a paw but trivial
/// for a hand.
///
/// That two seconds used to be a lie. [holdDuration] was declared and never
/// read: the widget wired `GestureDetector.onLongPress`, which fires on
/// Flutter's default long-press timeout of 500ms. Half a second is well inside
/// what a cat produces by resting a paw or settling down on the phone, and the
/// prize for doing it was the human surface, with its buttons, in front of an
/// unsupervised animal. The hold is now timed here so the constant and the
/// behaviour cannot drift apart again.
class ExitGuard extends StatefulWidget {
  const ExitGuard({super.key, required this.child, required this.onExit});

  final Widget child;
  final VoidCallback onExit;

  static const holdDuration = Duration(seconds: 2);

  /// The corner that listens. Big enough to find without looking, small enough
  /// that it is not somewhere a paw naturally lands during play.
  static const cornerSize = 96.0;

  /// How far a finger may wander mid-hold before it stops counting. A hold that
  /// travels is a swipe, and a paw dragged across the corner is exactly that.
  static const slop = 44.0;

  @override
  State<ExitGuard> createState() => _ExitGuardState();
}

class _ExitGuardState extends State<ExitGuard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _hold = AnimationController(
    vsync: this,
    duration: ExitGuard.holdDuration,
  )..addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onExit();
    });

  Offset? _from;

  @override
  void dispose() {
    _hold.dispose();
    super.dispose();
  }

  void _begin(PointerDownEvent event) {
    _from = event.localPosition;
    _hold.forward(from: 0);
  }

  void _travelled(PointerMoveEvent event) {
    final from = _from;
    if (from == null) return;
    if ((event.localPosition - from).distance > ExitGuard.slop) _abandon();
  }

  /// Winds back rather than snapping to zero, so a hold given up halfway is
  /// visibly lost instead of silently discarded.
  ///
  /// Unconditionally, which matters more than it looks. This was guarded with
  /// `if (_hold.value > 0)` and a release before the first frame left the value
  /// still at zero — so nothing stopped the run and the guard opened two
  /// seconds later, with the finger long gone. Reversing from zero simply
  /// settles at once; the point is that the forward run always ends here.
  void _abandon() {
    _from = null;
    _hold.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Stack(
        children: [
          widget.child,
          Positioned(
            top: 0,
            left: 0,
            width: ExitGuard.cornerSize,
            height: ExitGuard.cornerSize,
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: _begin,
              onPointerMove: _travelled,
              onPointerUp: (_) => _abandon(),
              onPointerCancel: (_) => _abandon(),
              child: AnimatedBuilder(
                animation: _hold,
                builder: (context, _) =>
                    CustomPaint(painter: _HoldRing(_hold.value)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A ring that fills over the hold, so a person can tell it is working.
///
/// Invisible until touched, and that is not politeness — anything animating in
/// a corner pulls a cat's attention off the targets, which is the one thing the
/// cat surface is for.
class _HoldRing extends CustomPainter {
  const _HoldRing(this.progress);

  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.01) return;
    final radius = size.shortestSide * 0.3;
    canvas.drawArc(
      Rect.fromCircle(center: size.center(Offset.zero), radius: radius),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFFFCF5C).withValues(alpha: 0.85 * progress),
    );
  }

  @override
  bool shouldRepaint(_HoldRing old) => old.progress != progress;
}
