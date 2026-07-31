import 'package:flutter/material.dart';

/// Root of the human surface. The cat surface is pushed as a fullscreen route
/// from here and owns the screen completely while it is up.
class CatTvApp extends StatelessWidget {
  const CatTvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cat TV',
      debugShowCheckedModeBanner: false,
      // TODO(theme): AppTheme in lib/core/theme/. The human surface sells the
      // app, so it gets the design attention; the cat surface only needs high
      // contrast and motion.
      home: const Scaffold(
        body: Center(child: Text('TODO: home screen')),
      ),
    );
  }
}
