import 'package:cat_tv_games/shared/widgets/exit_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The guard is the boundary between an unsupervised cat and a screen with
/// buttons on it, so its timing is worth pinning rather than trusting.
void main() {
  Future<Widget> guard(VoidCallback onExit) async => MaterialApp(
        home: ExitGuard(
          onExit: onExit,
          child: const ColoredBox(color: Color(0xFF04182B)),
        ),
      );

  const corner = Offset(30, 30);

  /// Advances the clock a frame at a time rather than in one jump.
  ///
  /// This is not fussiness. A single `pump(twoSeconds)` produces exactly one
  /// tick, and the first tick is what sets a Ticker's zero point, so the hold
  /// never advances at all and every timing assertion below would pass for
  /// entirely the wrong reason. Real devices deliver frames; so does this.
  Future<void> hold(WidgetTester tester, Duration total) async {
    const frame = Duration(milliseconds: 50);
    for (var ms = 0; ms < total.inMilliseconds; ms += frame.inMilliseconds) {
      await tester.pump(frame);
    }
  }

  testWidgets('half a second does not let a cat out', (tester) async {
    // The regression this file exists for. holdDuration said two seconds while
    // the widget wired GestureDetector.onLongPress, which fires at Flutter's
    // default 500ms. A cat resting a paw in the corner clears that easily, and
    // what it won was the human surface.
    var exited = false;
    await tester.pumpWidget(await guard(() => exited = true));

    final touch = await tester.startGesture(corner);
    await hold(tester, const Duration(milliseconds: 500));
    expect(exited, isFalse);

    await hold(tester, const Duration(milliseconds: 900));
    expect(exited, isFalse, reason: 'still short of two seconds');

    await touch.up();
    await tester.pumpAndSettle();
    expect(exited, isFalse);
  });

  testWidgets('a full two-second hold opens it', (tester) async {
    var exited = false;
    await tester.pumpWidget(await guard(() => exited = true));

    await tester.startGesture(corner);
    const past = Duration(milliseconds: 200);
    await hold(tester, ExitGuard.holdDuration + past);

    expect(exited, isTrue);
  });

  testWidgets('letting go early abandons the hold', (tester) async {
    var exited = false;
    await tester.pumpWidget(await guard(() => exited = true));

    final touch = await tester.startGesture(corner);
    await hold(tester, const Duration(milliseconds: 1800));
    await touch.up();
    await hold(tester, const Duration(seconds: 3));

    expect(exited, isFalse, reason: 'the timer must not run on after release');
  });

  testWidgets('a touch released before the first frame is not still running', (
    tester,
  ) async {
    // Found by these tests rather than by reading the code. _abandon was
    // guarded with `if (_hold.value > 0)`, and a release this early leaves the
    // value at zero — so nothing stopped the run and the guard opened two
    // seconds later with the finger long gone.
    var exited = false;
    await tester.pumpWidget(await guard(() => exited = true));

    final touch = await tester.startGesture(corner);
    await touch.up();
    await hold(tester, const Duration(seconds: 4));

    expect(exited, isFalse);
  });

  testWidgets('a hold that travels is a swipe, and does not count', (
    tester,
  ) async {
    // A paw dragged across the corner keeps contact the whole way. That is not
    // somebody deliberately pressing and waiting.
    var exited = false;
    await tester.pumpWidget(await guard(() => exited = true));

    final touch = await tester.startGesture(corner);
    await hold(tester, const Duration(milliseconds: 400));
    await touch.moveBy(const Offset(ExitGuard.slop + 20, 0));
    await hold(tester, const Duration(seconds: 3));

    expect(exited, isFalse);
  });

  testWidgets('a small wobble during the hold is forgiven', (tester) async {
    // Nobody holds a finger perfectly still for two seconds, and a guard that
    // demands it is one an owner cannot use.
    var exited = false;
    await tester.pumpWidget(await guard(() => exited = true));

    final touch = await tester.startGesture(corner);
    await hold(tester, const Duration(milliseconds: 600));
    await touch.moveBy(const Offset(6, -4));
    await hold(tester, const Duration(seconds: 2));

    expect(exited, isTrue);
  });

  testWidgets('the rest of the screen is not an exit', (tester) async {
    // Everything outside the corner belongs to the game. A cat sitting on the
    // middle of the screen must not end the session.
    var exited = false;
    await tester.pumpWidget(await guard(() => exited = true));

    await tester.startGesture(const Offset(400, 300));
    await hold(tester, const Duration(seconds: 5));

    expect(exited, isFalse);
  });

  testWidgets('the back gesture cannot pop the surface', (tester) async {
    // A cat produces back gestures constantly on Android.
    await tester.pumpWidget(await guard(() {}));
    expect(
      find.byWidgetPredicate((w) => w is PopScope && !w.canPop),
      findsOneWidget,
    );
  });
}
