import 'package:flame_audio/flame_audio.dart';

import 'cat_sound.dart';

/// Plays the cat surface's sounds.
///
/// An interface rather than a direct call into the plugin, for the same reason
/// [RollingBuffer] is one: the rest of the app should work before the assets
/// exist, and tests must not need an audio device. [SilentCatAudio] is a real
/// implementation, not a stub for later.
abstract class CatAudio {
  /// Pull every sample into memory before play starts.
  ///
  /// Onset latency is the whole game here. A splash that arrives 200ms after
  /// the paw lands is not a reward, it is an unrelated noise, and the cause and
  /// effect the cat is supposed to learn never forms. docs/CAT_UX.md calls this
  /// out specifically.
  Future<void> preload();

  void play(SoundCue cue);

  Future<void> dispose();
}

/// The real one.
class FlameCatAudio implements CatAudio {
  static const _files = <CatSound, String>{
    CatSound.splash: 'splash.wav',
    CatSound.chirp: 'chirp.wav',
    CatSound.rustle: 'rustle.wav',
    CatSound.windDown: 'wind_down.wav',
  };

  var _ready = false;

  @override
  Future<void> preload() async {
    await FlameAudio.audioCache.loadAll(_files.values.toList());
    _ready = true;
  }

  @override
  void play(SoundCue cue) {
    if (!_ready) return;
    final file = _files[cue.sound];
    if (file == null) return;

    // Deliberately not awaited. Awaiting a sound on the contact path would put
    // a plugin round trip between the paw landing and the next frame.
    //
    // On web nothing will play until the page has seen a user gesture. That is
    // satisfied by construction: the first sound in a session is a splash,
    // which only happens because something touched the screen.
    FlameAudio.play(file, volume: cue.volume)
        .then((player) => player.setPlaybackRate(cue.rate))
        .catchError((Object _) {
      // A missing or unplayable sample must never take the session with it.
      // The cat surface has no error UI and nobody is watching it.
    });
  }

  @override
  Future<void> dispose() async {
    await FlameAudio.audioCache.clearAll();
    _ready = false;
  }
}

/// Makes no sound. Used by tests, and by any build where the samples are not
/// present — a silent pond is worse than a noisy one but far better than a
/// crash.
class SilentCatAudio implements CatAudio {
  final List<SoundCue> played = [];

  @override
  Future<void> preload() async {}

  @override
  void play(SoundCue cue) => played.add(cue);

  @override
  Future<void> dispose() async {}
}
