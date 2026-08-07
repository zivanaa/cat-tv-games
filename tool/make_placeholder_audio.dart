// Generates the placeholder sound samples in assets/audio/.
//
//   dart run tool/make_placeholder_audio.dart
//
// These are synthesised here rather than downloaded, and that is the point.
// Anything shipped in an app store carries its licence with it, and a sample
// pulled off the internet makes the licence somebody's problem later. Every
// waveform below is generated from arithmetic, so there is nothing to attribute
// and nothing to audit.
//
// They are placeholders, not final art. They exist so the audio layer can be
// wired, heard and tuned before anyone records anything. docs/CAT_UX.md is the
// brief for replacing them: high-frequency chirps, squeaks and rustling, and
// onset latency matters more than fidelity.
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const sampleRate = 22050;

void main() {
  final out = Directory('assets/audio');
  if (!out.existsSync()) {
    // ignore: avoid_print
    print('run this from the project root');
    exitCode = 1;
    return;
  }

  _write('${out.path}/splash.wav', _splash());
  _write('${out.path}/chirp.wav', _chirp());
  _write('${out.path}/rustle.wav', _rustle());
  _write('${out.path}/wind_down.wav', _windDown());
}

void _write(String path, List<double> samples) {
  File(path).writeAsBytesSync(_wav(samples));
  // ignore: avoid_print
  print('wrote $path (${samples.length} frames)');
}

/// A fish going under. Mostly noise, because water is noise, with a short
/// downward tone under it so the ear reads a volume of water rather than a hiss.
List<double> _splash() {
  final random = math.Random(1);
  return _render(0.22, (t, n) {
    final env = math.exp(-t * 16);
    final noise = (random.nextDouble() * 2 - 1) * env;
    final plop = math.sin(2 * math.pi * (820 - 520 * t / 0.22) * t) * env * 0.5;
    return noise * 0.7 + plop;
  });
}

/// Prey. A fast sweep upward in the range cats actually orient to, with a hard
/// attack — the onset is what turns a head.
List<double> _chirp() {
  return _render(0.11, (t, n) {
    final env = math.min(1, t * 220) * math.exp(-t * 22);
    final freq = 2400 + 2900 * (t / 0.11);
    return math.sin(2 * math.pi * freq * t) * env;
  });
}

/// Something moving in dry grass. Noise pushed through an amplitude flutter,
/// which is cheaper than filtering and reads the same at this length.
List<double> _rustle() {
  final random = math.Random(7);
  return _render(0.16, (t, n) {
    final env = math.exp(-t * 9);
    final flutter = 0.55 + 0.45 * math.sin(2 * math.pi * 47 * t);
    return (random.nextDouble() * 2 - 1) * env * flutter * 0.8;
  });
}

/// The session ending. Long, falling and quiet — the audible half of the
/// wind-down, so the screen does not simply stop being interesting.
List<double> _windDown() {
  return _render(1.4, (t, n) {
    final env = math.min(1, t * 6) * math.exp(-t * 1.7);
    final freq = 1150 - 780 * (t / 1.4);
    final body = math.sin(2 * math.pi * freq * t);
    final shimmer = math.sin(2 * math.pi * freq * 2.02 * t) * 0.25;
    return (body + shimmer) * env * 0.55;
  });
}

List<double> _render(double seconds, double Function(double t, int n) f) {
  final frames = (seconds * sampleRate).round();
  final samples = List<double>.filled(frames, 0);
  for (var n = 0; n < frames; n++) {
    samples[n] = f(n / sampleRate, n);
  }

  // A short fade at each end. Without it the buffer starts and stops on a
  // non-zero sample and every play gets a click, which on a loop is maddening.
  final fade = math.min(220, frames ~/ 8);
  for (var n = 0; n < fade; n++) {
    final g = n / fade;
    samples[n] *= g;
    samples[frames - 1 - n] *= g;
  }

  // Normalise, so mixing decisions live in the volume argument rather than in
  // whatever amplitude the arithmetic happened to land on.
  var peak = 0.0;
  for (final s in samples) {
    peak = math.max(peak, s.abs());
  }
  if (peak > 0) {
    for (var n = 0; n < frames; n++) {
      samples[n] = samples[n] / peak * 0.89;
    }
  }
  return samples;
}

Uint8List _wav(List<double> samples) {
  const bitsPerSample = 16;
  const channels = 1;
  final dataBytes = samples.length * 2;
  final bytes = BytesBuilder();

  void ascii(String s) => bytes.add(s.codeUnits);
  void u32(int v) => bytes
      .add(Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.little));
  void u16(int v) => bytes
      .add(Uint8List(2)..buffer.asByteData().setUint16(0, v, Endian.little));

  ascii('RIFF');
  u32(36 + dataBytes);
  ascii('WAVE');
  ascii('fmt ');
  u32(16);
  u16(1); // PCM
  u16(channels);
  u32(sampleRate);
  u32(sampleRate * channels * bitsPerSample ~/ 8);
  u16(channels * bitsPerSample ~/ 8);
  u16(bitsPerSample);
  ascii('data');
  u32(dataBytes);

  final pcm = Uint8List(dataBytes);
  final view = pcm.buffer.asByteData();
  for (var n = 0; n < samples.length; n++) {
    final clamped = samples[n].clamp(-1.0, 1.0);
    view.setInt16(n * 2, (clamped * 32767).round(), Endian.little);
  }
  bytes.add(pcm);

  return bytes.toBytes();
}
