import 'package:cat_tv_games/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// The home screen has to fit the device rather than one mockup.
///
/// This matters more than it looks: main.dart pins the app to landscapeLeft
/// and landscapeRight, so the shape it actually ships in is short and wide.
/// The screen was first written as a tall centred column that was itself
/// taller than a landscape phone, which made the primary orientation the one
/// that had to be scrolled.
void main() {
  /// Sets a device size and puts it back afterwards, so one case cannot leak
  /// into the next.
  Future<void> at(
    WidgetTester tester,
    Size size,
    Future<void> Function() body,
  ) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(const CatTvApp());
    await tester.pumpAndSettle();
    await body();
  }

  /// Nothing may be laid out past the edges of the screen.
  void expectNoOverflow(WidgetTester tester) {
    expect(
      tester.takeException(),
      isNull,
      reason: 'a RenderFlex overflow is a layout that does not fit',
    );
  }

  /// Screens the app actually runs on. The start button has to be reachable on
  /// all of them without scrolling.
  const devices = <String, Size>{
    'landscape phone': Size(800, 360),
    'small landscape phone': Size(667, 320),
    'large landscape phone': Size(932, 430),
    'tablet landscape': Size(1180, 820),
    'tablet portrait': Size(820, 1180),
    'portrait phone': Size(390, 844),
    'desktop window': Size(1440, 900),
  };

  /// Shapes nobody ships in but a browser window can be dragged to. These only
  /// have to not break — scrolling a 300px-tall window is fair.
  const awkward = <String, Size>{
    'tiny window': Size(360, 300),
    'very narrow window': Size(300, 700),
    'letterbox': Size(1200, 260),
  };

  for (final entry in devices.entries) {
    testWidgets('it fits a ${entry.key}', (tester) async {
      await at(tester, entry.value, () async {
        expectNoOverflow(tester);

        final button = find.text('Let the cat play');
        expect(button, findsOneWidget);

        final box = tester.getRect(button);
        expect(box.left, greaterThanOrEqualTo(0));
        expect(box.right, lessThanOrEqualTo(entry.value.width));
        expect(box.top, greaterThanOrEqualTo(0));
        expect(
          box.bottom,
          lessThanOrEqualTo(entry.value.height),
          reason: 'the start button must be visible without scrolling',
        );
      });
    });
  }

  for (final entry in awkward.entries) {
    testWidgets('it survives a ${entry.key}', (tester) async {
      await at(tester, entry.value, () async {
        expectNoOverflow(tester);
        expect(find.text('Let the cat play'), findsOneWidget);
      });
    });
  }

  testWidgets('a short wide screen lays out across, not down', (tester) async {
    await at(tester, const Size(800, 360), () async {
      final mark = tester.getRect(find.byType(CustomPaint).first);
      final button = tester.getRect(find.text('Let the cat play'));

      // Side by side: the button starts to the right of the badge rather than
      // below it. On a 360-tall phone stacking them is what did not fit.
      expect(button.left, greaterThan(mark.right));
    });
  });

  testWidgets('a tall screen stacks', (tester) async {
    await at(tester, const Size(390, 844), () async {
      final mark = tester.getRect(find.byType(CustomPaint).first);
      final button = tester.getRect(find.text('Let the cat play'));

      expect(button.top, greaterThan(mark.bottom));
    });
  });

  testWidgets('the badge grows with the device', (tester) async {
    late Rect small;
    await at(tester, const Size(667, 320), () async {
      small = tester.getRect(find.byType(CustomPaint).first);
    });

    late Rect large;
    await at(tester, const Size(1440, 900), () async {
      large = tester.getRect(find.byType(CustomPaint).first);
    });

    expect(
      large.width,
      greaterThan(small.width),
      reason: 'proportions, not one fixed size',
    );
  });
}
