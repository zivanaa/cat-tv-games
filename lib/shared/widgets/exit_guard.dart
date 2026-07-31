import 'package:flutter/material.dart';

/// The only way out of the cat surface.
///
/// A tap cannot exit, and neither can the system back gesture — a cat produces
/// both constantly. A two-second hold in a corner is beyond a paw but trivial
/// for a hand.
class ExitGuard extends StatelessWidget {
  const ExitGuard({super.key, required this.child, required this.onExit});

  final Widget child;
  final VoidCallback onExit;

  static const holdDuration = Duration(seconds: 2);

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Stack(
        children: [
          child,
          Positioned(
            top: 0,
            left: 0,
            width: 96,
            height: 96,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onLongPress: onExit,
              // TODO(ui): ring that fills over the hold so a human gets
              // feedback that it is working. Keep it invisible until touched —
              // anything animating in a corner pulls the cat's attention away
              // from the targets.
            ),
          ),
        ],
      ),
    );
  }
}
