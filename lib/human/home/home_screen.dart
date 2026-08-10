import 'package:flutter/material.dart';

import '../../cat/engine/cat_game.dart';
import '../../cat/games/fish/fish_species.dart';
import '../../cat/render/cat_surface.dart';
import '../../core/theme/app_theme.dart';

/// Where a person starts a session.
///
/// Lives on the human surface and is built to be looked at, which is the split
/// CLAUDE.md draws: the cat surface needs contrast and motion and nothing else,
/// this one is the part that sells the app.
///
/// Still one game and one hardcoded cat. The mode card is a card rather than
/// plain text because the moment there are three of them it becomes a picker,
/// and that is the shape it will be.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _limits = SessionLimits();

  void _startSession(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => CatSurface(
          limits: _limits,
          // pop, not maybePop. maybePop asks PopScope for permission, and
          // ExitGuard wraps the surface in PopScope(canPop: false) to block the
          // system back gesture — so the guard was refusing its own exit.
          onExit: () => Navigator.of(context).pop(),
        ),
        transitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Scaffold(
      body: DecoratedBox(
        decoration: AppTheme.backdrop,
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
              child: ConstrainedBox(
                // The app is landscape on a phone and windowed on the web, so
                // the column is capped rather than stretched across a monitor.
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _PondMark(),
                    const SizedBox(height: 26),
                    Text('Cat TV', style: text.displaySmall),
                    const SizedBox(height: 8),
                    Text(
                      'Games your cat can actually win',
                      style: text.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 34),
                    const _ModeCard(),
                    const SizedBox(height: 30),
                    FilledButton(
                      onPressed: () => _startSession(context),
                      child: const Text('Let the cat play'),
                    ),
                    const SizedBox(height: 22),
                    const _ExitHint(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The one game there is, presented as the one game there is.
class _ModeCard extends StatelessWidget {
  const _ModeCard();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    const limits = SessionLimits();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColours.line),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: const RadialGradient(
                colors: [AppColours.shallow, AppColours.deep],
              ),
            ),
            child: const Center(child: _Fish(size: 30)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fish pond', style: text.titleMedium),
                const SizedBox(height: 3),
                Text(
                  '${FishSpecies.values.length} species · '
                  '${limits.maxDuration.inMinutes} minute session',
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: AppColours.teal, size: 20),
        ],
      ),
    );
  }
}

/// The badge above the title: a circle of pond with a fish in it.
class _PondMark extends StatelessWidget {
  const _PondMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 96,
      height: 96,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.2, -0.3),
          colors: [AppColours.shallow, AppColours.deep],
        ),
        border: Border.all(color: AppColours.line, width: 1.5),
      ),
      child: const Center(child: _Fish(size: 52)),
    );
  }
}

/// A small gold fish, drawn rather than shipped as an image.
///
/// Same silhouette as the pond's — tapered body, forked-off tail, an eye —
/// because the thing on the shelf should be the thing in the box.
class _Fish extends StatelessWidget {
  const _Fish({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) =>
      CustomPaint(size: Size.square(size), painter: const _FishPainter());
}

class _FishPainter extends CustomPainter {
  const _FishPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final a = size.width * 0.34;
    final b = size.height * 0.2;
    canvas.translate(size.width * 0.52, size.height / 2);

    final tail = Path()
      ..moveTo(-a * 0.85, 0)
      ..lineTo(-a * 1.75, -b * 0.95)
      ..quadraticBezierTo(-a * 1.25, 0, -a * 1.75, b * 0.95)
      ..close();
    canvas.drawPath(tail, Paint()..color = AppColours.amber);

    final body = Path()
      ..moveTo(a, 0)
      ..cubicTo(a * 0.55, -b, -a * 0.35, -b, -a, -b * 0.16)
      ..lineTo(-a, b * 0.16)
      ..cubicTo(-a * 0.35, b, a * 0.55, b, a, 0)
      ..close();
    canvas
      ..drawPath(body, Paint()..color = AppColours.gold)
      ..drawCircle(
        Offset(a * 0.5, -b * 0.22),
        size.width * 0.035,
        Paint()..color = AppColours.deep,
      );
  }

  @override
  bool shouldRepaint(_FishPainter oldDelegate) => false;
}

/// The one instruction that matters, and the one nobody discovers on their own.
class _ExitHint extends StatelessWidget {
  const _ExitHint();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.touch_app_outlined, size: 15, color: AppColours.faint),
        const SizedBox(width: 7),
        Flexible(
          child: Text(
            'Hold the top-left corner for 2s to exit',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
