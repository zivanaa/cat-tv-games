import 'dart:ui';

import 'package:cat_tv_games/cat/engine/paw_input.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const screen = Size(800, 400);
  final now = DateTime(2026);

  PawTarget target(Offset at, {double radius = 40}) =>
      PawTarget(id: 'fish', center: at, radius: radius);

  test('a touch on the target is a direct hit', () {
    final input = PawInput();
    final hit = input.resolve(
      point: const Offset(400, 200),
      targets: [target(const Offset(400, 200))],
      screen: screen,
      now: now,
    );
    expect(hit.tier, HitTier.direct);
  });

  test('a small target is still hit-tested at the minimum radius', () {
    final input = PawInput();
    // 50px away from a 10px sprite — a miss visually, a hit for a paw.
    final hit = input.resolve(
      point: const Offset(450, 200),
      targets: [target(const Offset(400, 200), radius: 10)],
      screen: screen,
      now: now,
    );
    expect(hit.tier, HitTier.direct);
  });

  test('a near miss is assisted', () {
    final input = PawInput();
    final hit = input.resolve(
      point: const Offset(520, 200),
      targets: [target(const Offset(400, 200))],
      screen: screen,
      now: now,
    );
    expect(hit.tier, HitTier.assisted);
    expect(hit.target, isNotNull);
  });

  test('a generous hit is granted once, then blocked by cooldown', () {
    final input = PawInput();
    const far = Offset(300, 340);

    final first = input.resolve(
      point: far, targets: [target(const Offset(400, 200))], screen: screen, now: now);
    expect(first.tier, HitTier.generous);

    final second = input.resolve(
      point: far,
      targets: [target(const Offset(400, 200))],
      screen: screen,
      now: now.add(const Duration(milliseconds: 300)),
    );
    expect(second.tier, isNot(HitTier.generous));
  });

  test('two contacts in one bat count once', () {
    final input = PawInput();
    final targets = [target(const Offset(400, 200))];

    input.resolve(point: const Offset(400, 200), targets: targets, screen: screen, now: now);
    final repeat = input.resolve(
      point: const Offset(405, 202),
      targets: targets,
      screen: screen,
      now: now.add(const Duration(milliseconds: 20)),
    );
    expect(repeat.scored, isFalse);
  });

  test('the generous reach stays wider than the assist radius', () {
    // Regression guard. The reach was originally measured against the screen's
    // shorter side, which on a landscape phone lands *inside* the assist radius
    // and silently disables the generous tier — no test failed, cats just
    // scored less. Any change to these defaults has to keep this true.
    const config = PawInputConfig();
    final assistRadius = config.minTargetRadius * config.assistMultiplier;
    final reach = 800 * config.generosity; // longer side of the test screen
    expect(reach, greaterThan(assistRadius));
  });

  test('nothing on screen means nothing scores', () {
    final input = PawInput();
    final hit = input.resolve(
      point: const Offset(400, 200), targets: const [], screen: screen, now: now);
    expect(hit.tier, HitTier.miss);
  });
}
