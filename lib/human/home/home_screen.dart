import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../cat/engine/cat_game.dart';
import '../../cat/games/fish/fish_species.dart';
import '../../cat/render/cat_surface.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/cat_profile_repository.dart';

/// Where a person starts a session.
///
/// Lives on the human surface and is built to be looked at, which is the split
/// CLAUDE.md draws: the cat surface needs contrast and motion and nothing else,
/// this one is the part that sells the app.
///
/// Still one game and one hardcoded cat. The mode card is a card rather than
/// plain text because the moment there are three of them it becomes a picker,
/// and that is the shape it will be.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.cats});

  /// Injectable so tests can hand in a cat rather than reaching for whatever
  /// the app happens to hold. Milestone 2 replaces the default with Isar.
  final CatProfileRepository? cats;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _limits = SessionLimits();

  late final CatProfileRepository _cats =
      widget.cats ?? InMemoryCatProfileRepository();

  Future<void> _startSession(BuildContext context) async {
    final profile = await _cats.current();
    if (!context.mounted) return;

    await Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => CatSurface(
          limits: _limits,
          profile: profile,
          // Where the cat got to goes straight back to the repository, so the
          // next session starts from the climb rather than from the middle of
          // the ladder again.
          onSessionEnd: (played) => unawaited(_cats.save(played)),
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
    return Scaffold(
      body: DecoratedBox(
        decoration: AppTheme.backdrop,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) {
              // Landscape is not an edge case here, it is the case. main.dart
              // pins the app to landscapeLeft and landscapeRight, so a phone
              // running this is roughly 800 by 360 — and the tall column this
              // screen started as was itself taller than that, which made the
              // primary orientation the one that scrolled.
              // Both conditions, and the width one was learned from a test at
              // 360x300: a squeezed browser window is wide by ratio while
              // having nowhere near the room for two columns, and splitting it
              // left each side 118px, which the mode card overflowed.
              final wide =
                  box.maxWidth >= 560 && box.maxWidth > box.maxHeight * 1.15;

              // Everything scales off the short side rather than off fixed
              // numbers, so a 360-tall phone, a tablet and a desktop window all
              // get proportions instead of one size that only suits a mockup.
              final short = math.min(box.maxWidth, box.maxHeight);
              final mark = short.clamp(280.0, 900.0) / 280 * 84;

              return Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: wide ? 40 : 28,
                    vertical: 24,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: wide ? 780 : 420),
                    child: wide
                        ? _WideLayout(mark: mark, onStart: _startSession)
                        : _TallLayout(mark: mark, onStart: _startSession),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Landscape, and the layout the app actually ships in: who we are on the
/// left, what to do about it on the right.
class _WideLayout extends StatelessWidget {
  const _WideLayout({required this.mark, required this.onStart});

  final double mark;
  final void Function(BuildContext) onStart;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: _Identity(mark: mark, centred: false),
        ),
        const SizedBox(width: 44),
        Expanded(child: _Actions(onStart: onStart, centred: false)),
      ],
    );
  }
}

/// Portrait: a browser window, a tablet held upright, the web preview.
class _TallLayout extends StatelessWidget {
  const _TallLayout({required this.mark, required this.onStart});

  final double mark;
  final void Function(BuildContext) onStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Identity(mark: mark, centred: true),
        const SizedBox(height: 34),
        _Actions(onStart: onStart, centred: true),
      ],
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.mark, required this.centred});

  final double mark;
  final bool centred;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          centred ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        _PondMark(size: mark),
        SizedBox(height: mark * 0.28),
        Text('Cat TV', style: text.displaySmall),
        const SizedBox(height: 8),
        Text(
          'Games your cat can actually win',
          style: text.bodyMedium,
          textAlign: centred ? TextAlign.center : TextAlign.start,
        ),
      ],
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.onStart, required this.centred});

  final void Function(BuildContext) onStart;
  final bool centred;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          centred ? CrossAxisAlignment.center : CrossAxisAlignment.stretch,
      children: [
        const _ModeCard(),
        const SizedBox(height: 26),
        FilledButton(
          onPressed: () => onStart(context),
          child: const Text('Let the cat play'),
        ),
        const SizedBox(height: 18),
        Align(
          alignment: centred ? Alignment.center : Alignment.centerLeft,
          child: const _ExitHint(),
        ),
      ],
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
                Text(
                  'Fish pond',
                  style: text.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                // Ellipsis rather than wrap, so a narrow card loses the end of
                // a detail line instead of growing a second row and pushing
                // the button off a short screen.
                Text(
                  '${FishSpecies.values.length} species · '
                  '${limits.maxDuration.inMinutes} minute session',
                  style: text.bodySmall,
                  overflow: TextOverflow.ellipsis,
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
  const _PondMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.2, -0.3),
          colors: [AppColours.shallow, AppColours.deep],
        ),
        border: Border.all(color: AppColours.line, width: 1.5),
      ),
      child: Center(child: _Fish(size: size * 0.55)),
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
