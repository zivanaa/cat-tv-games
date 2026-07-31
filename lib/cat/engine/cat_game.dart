import 'dart:ui';

import 'paw_input.dart';

/// Contract every cat-facing game mode implements.
///
/// Rendering belongs to the Flame layer. Rules belong here, in plain Dart, so
/// they can be tested without spinning up a game loop.
abstract class CatGame {
  String get id;

  /// Shown on the human surface only. Cats do not read.
  String get displayName;

  /// Targets currently on screen, for [PawInput] to test against.
  List<PawTarget> get targets;

  /// Advance the simulation. [dt] is seconds.
  void update(double dt, Size screen);

  /// Called after [PawInput] resolves a contact. Implementations react to the
  /// tier — a direct hit can be celebrated harder than a generous one, as long
  /// as both still feel like a win.
  void onHit(PawHit hit);

  /// Difficulty in 0..1, driven by the cat's recent hit rate. Games are expected
  /// to slow targets down and grow them when this drops.
  ///
  /// Readable as well as writable because the adjustment is relative:
  /// [SessionRecorder.suggestedDifficulty] nudges the current value rather than
  /// setting an absolute one, so the caller has to be able to ask what it is.
  double get difficulty;
  set difficulty(double value);

  void reset();
}

/// Hard limits that apply to every mode. A cat will not stop on its own, and a
/// phone rendering full-screen animation on a rug will throttle.
class SessionLimits {
  const SessionLimits({
    this.maxDuration = const Duration(minutes: 15),
    this.windDown = const Duration(seconds: 30),
    this.targetFps = 40,
  });

  final Duration maxDuration;

  /// Targets slow and fade rather than the screen cutting to black — an abrupt
  /// end leaves a cat staring at a dead screen and teaches it the app is boring.
  final Duration windDown;

  /// Deliberately below 60. See CLAUDE.md rule 5.
  final int targetFps;
}
