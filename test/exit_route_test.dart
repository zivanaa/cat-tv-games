import 'package:cat_tv_games/app.dart';
import 'package:cat_tv_games/shared/widgets/exit_guard.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether the cat surface can actually be left.
///
/// exit_guard_test.dart pins the timing of the hold, but it asserts on a
/// callback, and a callback that fires into a route which refuses to close is
/// worth nothing. That gap hid a real one: the exit called
/// `Navigator.maybePop`, maybePop asks PopScope for permission, and ExitGuard
/// wraps the surface in `PopScope(canPop: false)` to stop the system back
/// gesture. The guard was refusing its own exit — ring filled, callback fired,
/// screen stayed exactly where it was, with no way out at all.
///
/// So this drives the real app and asserts on where you end up.
void main() {
  Future<void> hold(WidgetTester tester, Duration total) async {
    const frame = Duration(milliseconds: 50);
    for (var ms = 0; ms < total.inMilliseconds; ms += frame.inMilliseconds) {
      await tester.pump(frame);
    }
  }

  testWidgets('a two-second hold really does close the cat surface', (
    tester,
  ) async {
    await tester.pumpWidget(const CatTvApp());
    expect(find.text('Let the cat play'), findsOneWidget);

    await tester.tap(find.text('Let the cat play'));
    await tester.pump();
    await tester.pump();
    expect(
      find.text('Let the cat play'),
      findsNothing,
      reason: 'the pond should own the screen now',
    );

    await tester.startGesture(const Offset(30, 30));
    await hold(tester, ExitGuard.holdDuration + const Duration(seconds: 1));

    expect(
      find.text('Let the cat play'),
      findsOneWidget,
      reason: 'the hold has to put a person back on the human surface',
    );
  });

  testWidgets('a brief touch in the corner leaves the cat where it is', (
    tester,
  ) async {
    await tester.pumpWidget(const CatTvApp());
    await tester.tap(find.text('Let the cat play'));
    await tester.pump();
    await tester.pump();

    final touch = await tester.startGesture(const Offset(30, 30));
    await hold(tester, const Duration(milliseconds: 600));
    await touch.up();
    await hold(tester, const Duration(seconds: 3));

    expect(find.text('Let the cat play'), findsNothing);
  });
}
