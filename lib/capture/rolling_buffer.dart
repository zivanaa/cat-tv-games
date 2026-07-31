import 'dart:async';

import 'highlight_detector.dart';

/// A discarding video ring buffer, dashcam style.
///
/// The camera runs for the whole session but frames older than [duration] are
/// thrown away continuously. Only when [HighlightDetector] fires does anything
/// reach disk. This is the single most important decision in the capture
/// feature — see CLAUDE.md.
///
/// Implementation is platform-side. Dart holds the interface and the policy.
abstract class RollingBuffer {
  /// How much history is kept. Longer buffers mean more memory held per second.
  Duration get duration;

  bool get isRunning;

  /// Requests camera permission and begins buffering. Must be called from the
  /// human surface, with the owner looking at an explanation of what is being
  /// recorded and where it goes (on device, never uploaded).
  Future<void> start();

  /// Writes the current buffer to a file and returns its path.
  Future<String> flush(HighlightTrigger trigger);

  Future<void> stop();
}

/// No-op implementation so the rest of the app runs before the platform
/// channels exist. Every other layer should work against [RollingBuffer], so
/// swapping this out later touches nothing but the DI wiring.
class NoopRollingBuffer implements RollingBuffer {
  @override
  Duration get duration => const Duration(seconds: 15);

  @override
  bool get isRunning => false;

  @override
  Future<void> start() async {}

  @override
  Future<String> flush(HighlightTrigger trigger) async => '';

  @override
  Future<void> stop() async {}
}

// TODO(capture): implement AndroidRollingBuffer and IosRollingBuffer.
//
// Android: CameraX VideoCapture into a circular file segment set, or a manual
//   ImageReader ring encoded on flush. CameraX is far less work.
// iOS: AVCaptureMovieFileOutput cannot do a ring buffer. Use
//   AVAssetWriter with a rolling set of short segments and stitch on flush.
//
// Both: front camera by default (the cat's face is the content), 720p is plenty,
// audio on — the chirps and thumps are half of what makes a clip funny.
//
// Store clips in the app's private directory. Never auto-upload. The privacy
// story is a selling point, so it should be true.
