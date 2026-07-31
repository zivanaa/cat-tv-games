import '../engine/cat_game.dart';
import 'fish/fish_game.dart';

/// Every playable mode. Registering here is what makes a mode appear on the
/// human surface's mode picker.
final Map<String, CatGame Function()> gameCatalog = {
  FishGame.gameId: () => FishGame(),
  // TODO(mouse): scurrying mouse that hides under a virtual rug on hit.
  // TODO(laser): dot that flees the paw — needs a movement model that never
  // lets the cat win instantly but always lets it win eventually.
};
