/// The kinds of fish in the pond, and how each one swims.
///
/// Variety here is not decoration. A pond where every target moves identically
/// reads as one repeating pattern, and a cat that has predicted the pattern
/// stops watching. Four gaits give a cat something to keep re-reading.
///
/// What variety must not become is chaos. docs/CAT_UX.md is explicit that fast
/// random motion reads as noise and loses cats, so every species below is a
/// slow predictable base path with occasional darts — never a random walk. The
/// darting species exists because a dart is the single most arresting thing a
/// target can do; it is rationed on purpose.
///
/// These are movement rules, so they live here in plain Dart rather than in the
/// render layer, and they are unit tested without a game loop.
enum FishSpecies {
  /// The baseline. A lazy sine cruise with the occasional flick.
  goldfish(
    sizeScale: 1,
    speedScale: 1,
    wobbleRate: 1.4,
    wobbleAmount: 0.6,
    dartsPerSecond: 0.08,
    dartSpeedScale: 2.2,
    dartSeconds: 0.5,
    turnRate: 0.25,
  ),

  /// Small and quick, and the one that darts. Hardest to catch, so it is also
  /// the one PawInput's assist does the most work for — the drawn body is well
  /// under the minimum hit radius, which is exactly the decoupling that keeps a
  /// cat scoring on a target it can barely touch.
  darter(
    sizeScale: 0.65,
    speedScale: 1.35,
    wobbleRate: 2.6,
    wobbleAmount: 0.45,
    dartsPerSecond: 0.45,
    dartSpeedScale: 2.8,
    dartSeconds: 0.35,
    turnRate: 0.6,
  ),

  /// Big, slow and never darts. This is the mercy fish: when a cat is missing
  /// everything, a koi drifting across the screen is the target it can still
  /// land, and landing something is what keeps the session alive.
  koi(
    sizeScale: 1.5,
    speedScale: 0.55,
    wobbleRate: 0.7,
    wobbleAmount: 0.8,
    dartsPerSecond: 0,
    dartSpeedScale: 1,
    dartSeconds: 0,
    turnRate: 0.15,
  ),

  /// Tall and slow, with a deep rise-and-fall. Moves less far but sweeps more
  /// vertically, which reads very differently from the others without being any
  /// faster.
  angel(
    sizeScale: 1.15,
    speedScale: 0.75,
    wobbleRate: 1,
    wobbleAmount: 1.15,
    dartsPerSecond: 0.03,
    dartSpeedScale: 1.8,
    dartSeconds: 0.4,
    turnRate: 0.2,
  );

  const FishSpecies({
    required this.sizeScale,
    required this.speedScale,
    required this.wobbleRate,
    required this.wobbleAmount,
    required this.dartsPerSecond,
    required this.dartSpeedScale,
    required this.dartSeconds,
    required this.turnRate,
  });

  /// Multiplies the pond's base radius. Hit testing still floors every target
  /// at [PawInputConfig.minTargetRadius], so a small fish stays catchable.
  final double sizeScale;

  /// Multiplies the pond's base speed.
  final double speedScale;

  /// Radians per second the sine phase advances.
  final double wobbleRate;

  /// Peak deflection of the sine, in radians.
  final double wobbleAmount;

  /// Expected darts per second. Zero means the species never darts.
  final double dartsPerSecond;

  /// Speed multiplier while darting.
  final double dartSpeedScale;

  /// How long a dart lasts.
  final double dartSeconds;

  /// Radians per second of slow heading drift, so a fish wanders instead of
  /// tracking one bearing until it meets a wall.
  final double turnRate;
}
