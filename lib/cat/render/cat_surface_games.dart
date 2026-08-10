import '../audio/cat_audio.dart';
import '../engine/cat_game.dart';
import '../games/fish/fish_game.dart';
import '../games/laser/laser_game.dart';
import 'cat_surface_game.dart';
import 'fish_pond_game.dart';
import 'laser_field_game.dart';

/// Which renderer draws which mode.
///
/// Separate from `gameCatalog` on purpose. That map is the rules — plain Dart
/// that a test can build without a game loop — and it has to stay buildable
/// without dragging Flame in behind it. This is the render side of the same
/// list, and the test below the fold keeps the two from drifting apart.
typedef CatSurfaceGameBuilder = CatSurfaceGame<CatGame> Function({
  required CatAudio audio,
  required SessionLimits limits,
});

final Map<String, CatSurfaceGameBuilder> catSurfaceGames = {
  FishGame.gameId: ({required audio, required limits}) =>
      FishPondGame(audio: audio, limits: limits),
  LaserGame.gameId: ({required audio, required limits}) =>
      LaserFieldGame(audio: audio, limits: limits),
};
