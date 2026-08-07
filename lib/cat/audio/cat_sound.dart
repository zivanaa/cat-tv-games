/// The sounds the cat surface can make.
///
/// docs/CAT_UX.md calls audio the single biggest engagement lever in the app:
/// many cats ignore the screen entirely until they hear something, and no mode
/// is supposed to ship without a sound layer. It also names what works — high
/// frequency chirps, squeaks, rustling — which is why there is nothing low and
/// booming in this list.
enum CatSound {
  /// A fish is caught. The reward, and the most important sound in the app.
  splash,

  /// Ambient interest, played on a slow timer to pull a cat back to the screen
  /// when it has stopped watching.
  chirp,

  /// A fish darts. Short and dry.
  rustle,

  /// The session is ending. Plays once, under the wind-down.
  windDown,
}

/// One request to make a noise, after policy has had its say.
class SoundCue {
  const SoundCue({
    required this.sound,
    required this.volume,
    required this.rate,
  });

  final CatSound sound;

  /// 0 to 1.
  final double volume;

  /// Playback rate, which is also pitch. A cat bats at the same fish many times
  /// a minute and a sample replayed identically starts to read as a machine
  /// rather than as prey.
  final double rate;
}
