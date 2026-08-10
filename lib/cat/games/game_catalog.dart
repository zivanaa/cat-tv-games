import '../engine/cat_game.dart';
import 'fish/fish_game.dart';
import 'laser/laser_game.dart';

/// Every playable mode. Registering here is what makes a mode appear on the
/// human surface's mode picker.
final Map<String, CatGame Function()> gameCatalog = {
  FishGame.gameId: () => FishGame(),
  LaserGame.gameId: () => LaserGame(),
  // TODO(mouse): scurrying mouse that hides under a virtual rug on hit.
};

/// What a mode is called and what it is, for the picker.
///
/// Kept beside the catalog so adding a mode is one place rather than three, and
/// deliberately not on CatGame itself: a description is copy for a person, and
/// the cat surface has no business carrying strings nobody on it can read.
const modeBlurbs = <String, String>{
  FishGame.gameId: 'Slow, bright and forgiving. Start here.',
  LaserGame.gameId: 'A dot that runs. Harder, and always catchable.',
};
