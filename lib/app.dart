import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'human/home/home_screen.dart';

/// Root of the human surface. The cat surface is pushed as a fullscreen route
/// from here and owns the screen completely while it is up.
class CatTvApp extends StatelessWidget {
  const CatTvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cat TV',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const HomeScreen(),
    );
  }
}
