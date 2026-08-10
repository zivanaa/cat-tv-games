import 'package:flutter/material.dart';

import 'cat/render/cat_surface.dart';

/// Root of the human surface. The cat surface is pushed as a fullscreen route
/// from here and owns the screen completely while it is up.
class CatTvApp extends StatelessWidget {
  const CatTvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'Cat TV',
      debugShowCheckedModeBanner: false,
      // TODO(theme): AppTheme in lib/core/theme/. The human surface sells the
      // app, so it gets the design attention; the cat surface only needs high
      // contrast and motion.
      home: HomeScreen(),
    );
  }
}

/// Deliberately plain. This is the placeholder that gets the fish pond onto a
/// screen so it can be watched; the real home screen is Milestone 2.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _startSession(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder<void>(
        pageBuilder: (context, animation, secondaryAnimation) => CatSurface(
          // pop, not maybePop. maybePop asks PopScope for permission, and
          // ExitGuard wraps the surface in PopScope(canPop: false) to block the
          // system back gesture — so the guard was refusing its own exit. The
          // hold ring filled, onExit fired, and nothing happened: the cat
          // surface had no way out at all. This pop is the deliberate human
          // gesture the PopScope exists to distinguish from a cat's.
          onExit: () => Navigator.of(context).pop(),
        ),
        transitionDuration: Duration.zero,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF04121F),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Cat TV',
              style: TextStyle(
                color: Color(0xFFFFCF5C),
                fontSize: 44,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Fish pond',
              style: TextStyle(color: Color(0xFF7FA8C4), fontSize: 18),
            ),
            const SizedBox(height: 40),
            FilledButton(
              onPressed: () => _startSession(context),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFCF5C),
                foregroundColor: const Color(0xFF04121F),
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 20,
                ),
              ),
              child: const Text('Let the cat play'),
            ),
            const SizedBox(height: 24),
            const Text(
              'Hold the top-left corner for 2s to exit.',
              style: TextStyle(color: Color(0xFF4A6C85), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
